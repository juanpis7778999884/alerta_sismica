# Arquitectura Supabase propuesta

## 1. Estado y alcance

Este documento describe la arquitectura de base de datos, seguridad y sincronización propuesta para Alerta Sísmica, incluidas la FASE 3.1 de auditoría de seguridad y la FASE 4 de corrección, ejecución local y validación de migraciones SQL.

La propuesta sigue siendo exclusivamente local: no se ejecutó SQL en Supabase, no se crearon tablas ni usuarios remotos, no se modificaron políticas en el proyecto remoto, no se cambió la autenticación actual, no se tocó el flujo SOS, no se introdujeron credenciales y no se realizó commit ni push.

Las sentencias de `supabase/migrations/` son propuestas revisables. Su ejecución futura requiere aprobación explícita y un entorno controlado con privilegios de propietario, porque referencian `auth.users`, crean políticas RLS, ajustan privilegios y crean triggers.

Principios rectores:

- El SOS continúa siendo local-first; Supabase nunca bloquea su activación.
- El cliente Flutter solo usa la Publishable key; nunca service_role, secret keys ni contraseñas.
- RLS está habilitado y se complementa con privileges por columna y triggers de integridad.
- Los identificadores generados en el dispositivo se conservan para garantizar idempotencia.
- Los estados de envío no afirman entrega: solo describen canal abierto, cancelado, fallido o no disponible.
- La eliminación normal es lógica; el borrado físico queda fuera del alcance del cliente.

## 2. Auditoría de la FASE 3.1

### 2.1 Problemas encontrados

| # | Problema | Impacto |
| --- | --- | --- |
| 1 | `profiles_delete_own` permitía al cliente borrar directamente su perfil. | Riesgo de pérdida de identidad y ruptura de relaciones dependientes. |
| 2 | `profiles_update_own` permitía cambiar `email`, `legacy_local_id` y otros metadatos sensibles. | Posible desincronización con Supabase Auth y corrupción del puente de migración. |
| 3 | No existía validación automática de que `profiles.email` coincidiera con la identidad autenticada. | Un cliente podría guardar un correo arbitrario. |
| 4 | Las tablas con `eliminado_en` tenían políticas DELETE directas. | Podían contradecir la estrategia de tombstones y permitir resurrecciones o pérdida de historial. |
| 5 | Las restricciones `*_borrado_valido` comparaban marcas de relojes distintos. | Un dispositivo con reloj desajustado podía ver rechazada una eliminación legítima. |
| 6 | El índice parcial de un único SOS activo por usuario rechazaba la segunda inserción concurrente. | Sin resolución, el evento perdedor podía perderse durante la sincronización. |
| 7 | RLS por sí sola no impedía actualizaciones de columnas sensibles. | Un cliente con UPDATE de tabla podía modificar claves, timestamps de servidor o snapshots. |
| 8 | `emergency_event_deliveries` no tenía protección explícita sobre el snapshot ni sobre operaciones DELETE. | Podía modificarse el histórico del envío o borrarse rastros de un SOS. |
| 9 | No se habían revocado explícitamente privilegios de `anon` ni de `PUBLIC`. | Activar RLS no elimina por sí solo privilegios de tabla otorgados por defecto. |

### 2.2 Decisiones tomadas

- Se eliminó la capacidad del cliente de borrar perfiles, ajustes, contactos, eventos, envíos y sismos guardados.
- Se conservaron las políticas SELECT e INSERT propietarias y se limitaron las políticas UPDATE a columnas legítimas.
- Se añadieron privileges por columna con `REVOKE`/`GRANT` para `anon`, `PUBLIC` y `authenticated`.
- Se añadieron triggers para proteger columnas inmutables y evitar resurrección de tombstones.
- Se eliminaron las restricciones temporales que comparaban `eliminado_en` con timestamps de otro origen.
- Se mantuvo el índice parcial de un SOS activo por usuario y se añadió resolución determinista de conflictos.
- Se conservó el snapshot de contacto en cada envío sin FK directa a `emergency_contacts`.
- Se usan tres funciones `SECURITY DEFINER` justificadas y acotadas: validación de identidad del perfil, sincronización de `profiles.email` desde `auth.users` y resolución de conflictos SOS.

### 2.4 Corrección final de `0003_emergency_events.sql`

Auditoría adicional sobre `resolve_active_sos_conflict()`:

| Problema | Corrección |
| --- | --- |
| La función se ejecutaba como invocador y su UPDATE interno escribía `motivo_fin`, columna no concedida a `authenticated`. | La función pasa a `SECURITY DEFINER` con controles explícitos de identidad y propiedad; no se amplía el GRANT de `authenticated`. |
| Se usaba `pg_catalog.greatest(...)`, que no es la forma válida de PostgreSQL. | Se sustituye por `GREATEST(...)`, expresión SQL correcta. |
| El UPDATE del evento anterior no restringía suficientemente la propiedad. | Se añaden `e.user_id = new.user_id`, `e.user_id = auth.uid()`, `e.activa` y `e.eliminado_en is null`, con verificación `FOUND`. |
| No se validaba explícitamente la identidad del llamador dentro de la función. | Se añade rechazo si `auth.uid()` es nulo o si `new.user_id` difiere de `auth.uid()`. |

## 3. Protección de perfiles

### 3.1 Política definitiva

| Operación | Decisión |
| --- | --- |
| SELECT | Solo `id = auth.uid()`. |
| INSERT | Solo `id = auth.uid()`. El trigger fuerza `email` desde `auth.users`. |
| UPDATE | Solo `id = auth.uid()` y únicamente `nombre` y `cliente_actualizado_en`. |
| DELETE | No permitida al cliente. Política eliminada y privilegio revocado. |

### 3.2 Trigger `profiles_enforce_auth_identity`

En INSERT:

- Verifica que exista `auth.uid()` y que `NEW.id = auth.uid()`.
- Lee `auth.users.email` para ese ID.
- Fuerza `profiles.email` a la forma normalizada del correo de Auth.
- Fuerza `creado_en`, `actualizado_en` y `sincronizado_en` a valores de servidor.

En UPDATE:

- Rechaza cambios de `id`.
- Rechaza cambios de `legacy_local_id`.
- Rechaza cambios de `email`.
- Rechaza cambios de `creado_en` y `sincronizado_en`.
- Permite cambios legítimos de `nombre` y `cliente_actualizado_en`.

### 3.3 Justificación del `SECURITY DEFINER`

Se utiliza `SECURITY DEFINER` únicamente en `public.profiles_enforce_auth_identity()` porque `auth.users` no es legible desde el rol `authenticated` y el correo debe derivarse de la fuente auténtica de identidad.

Validaciones de seguridad aplicadas:

- `set search_path = ''`.
- Objetos referenciados de forma totalmente cualificada: `auth.users`, `auth.uid()`, `pg_catalog.*`.
- Sin SQL dinámico.
- Sin credenciales ni secretos.
- Comprobación explícita de `auth.uid()`.
- `EXECUTE` revocado a `PUBLIC`, `anon` y `authenticated`.
- La función solo se invoca desde el trigger de `public.profiles`.
- Las columnas sensibles además están protegidas por privileges por columna.

La eliminación física de un perfil solo puede ocurrir por cascada desde una operación administrativa sobre `auth.users`, no desde el cliente.

## 4. Eliminación lógica

### 4.1 Políticas DELETE definitivas

| Tabla | DELETE del cliente | Mecanismo correcto |
| --- | --- | --- |
| `profiles` | No permitida | Cascada administrativa desde `auth.users`. |
| `user_settings` | No permitida | Actualizar valores a preferencias iniciales si aplica. |
| `emergency_contacts` | No permitida | Marcar `eliminado_en` mediante UPDATE controlado. |
| `emergency_events` | No permitida | Marcar `eliminado_en` mediante UPDATE controlado. |
| `emergency_event_deliveries` | No permitida | Permanecen como snapshot del evento. |
| `saved_earthquakes` | No permitida | Marcar `eliminado_en` mediante UPDATE controlado. |

En todas esas tablas se eliminaron las políticas `*_delete_own` y se revocó el privilegio DELETE a `authenticated`. `anon` y `PUBLIC` no tienen privilegios sobre las tablas.

### 4.2 Tombstones

- SELECT continúa viendo filas con `eliminado_en` no nulo para que otros dispositivos puedan sincronizar el borrado.
- Los índices parciales activos excluyen tombstones.
- `apply_logical_delete()` rechaza pasar de `eliminado_en` no nulo a `null`.
- `apply_logical_delete()` fija `eliminado_en = now()` cuando una fila activa pasa a eliminada.
- `set_sync_timestamps()` hace lo mismo cuando una tombstone se inserta desde un dispositivo sin conexión.
- Un intento de reactivación directa falla con violación de restricción.

La reactivación de un sismo guardado previamente eliminado queda pendiente de decisión: requiere una RPC controlada o una nueva convención de identidad; no se permite un UPDATE directo que ponga `eliminado_en` en `null`.

## 5. Estrategia de timestamps

| Campo | Propietario | Uso |
| --- | --- | --- |
| `creado_en` | Servidor | Auditoría de creación. |
| `actualizado_en` | Servidor | Auditoría de modificación; actualizado por trigger. |
| `sincronizado_en` | Servidor | Momento en que el servidor aceptó la operación. |
| `eliminado_en` | Servidor | Tombstone lógica; se fija con `now()`. |
| `cliente_actualizado_en` | Cliente | Marca lógica para resolución de conflictos. |

Se eliminaron:

- `emergency_contacts_creado_antes_borrado`.
- `emergency_events_borrado_valido`.
- `saved_earthquakes_borrado_valido`.

Motivo: comparar una marca generada por un dispositivo con una marca generada por el servidor puede rechazar eliminaciones legítimas cuando existen relojes desajustados. Ahora no se comparan relojes entre sí. La decisión de sincronización se basa en `cliente_actualizado_en` y reglas deterministas; los timestamps de servidor solo auditan.

## 6. Eventos SOS concurrentes

### 6.1 Riesgo analizado

Si dos dispositivos del mismo usuario activan un SOS mientras están sin conexión, ambos eventos tienen IDs distintos y marcas de cliente distintas. Al sincronizar, el índice parcial permite solo un evento activo. Sin una resolución explícita, el segundo INSERT podría fallar y el evento perdedor podría descartarse.

### 6.2 Decisión

Se mantiene el índice:

```sql
create unique index emergency_events_activa_por_usuario_key
  on public.emergency_events (user_id)
  where activa and eliminado_en is null;
```

Se añade el trigger `resolve_active_sos_conflict()`:

- Se ejecuta con `SECURITY DEFINER` acotado para poder escribir `motivo_fin` sin conceder esa columna a `authenticated`.
- Verifica explícitamente que `auth.uid()` exista y que `new.user_id = auth.uid()`.
- Toma un lock advisory por usuario para serializar resoluciones concurrentes.
- Busca otro evento activo del mismo usuario con `e.user_id = new.user_id` y `e.user_id = auth.uid()`.
- Compara de forma determinista `(cliente_actualizado_en, inicio, id)`.
- Si gana el evento nuevo, el anterior pasa a `activa = false`, `fin = GREATEST(inicio, now())` y `motivo_fin = 'conflicto_multidispositivo'`.
- Si gana el evento anterior, el nuevo se conserva como inactivo con el mismo `motivo_fin`.
- Todos los envíos asociados se conservan porque las filas no se eliminan.

Esto mantiene la integridad de un único SOS activo por usuario y evita pérdida de información. El índice parcial queda como última barrera de integridad.

### 6.3 Campo añadido

`emergency_events.motivo_fin` acepta `null`, `manual` o `conflicto_multidispositivo`. El cliente no tiene privilegio de UPDATE sobre esta columna; solo el trigger de resolución puede escribirla.

### 6.4 Decisión sobre `SECURITY DEFINER`

Se implementa `SECURITY DEFINER` en `public.resolve_active_sos_conflict()` porque el UPDATE interno debe escribir `motivo_fin`, columna deliberadamente no concedida a `authenticated`. Conceder esa columna al cliente debilitaría la auditoría del conflicto.

Efecto analizado sobre RLS:

- Una función `SECURITY DEFINER` se ejecuta con los privilegios del propietario de la función, normalmente el rol administrativo que aplica la migración.
- Ese propietario puede no estar sujeto a RLS, o puede bypassearla según la configuración de la tabla; por tanto, RLS no puede ser la única defensa dentro de la función.
- La función valida `auth.uid()` y exige `new.user_id = auth.uid()` antes de cualquier lectura o escritura.
- La consulta del evento rival y el UPDATE posterior incluyen `e.user_id = new.user_id` y `e.user_id = auth.uid()`.
- El UPDATE también exige que el rival siga activo y no eliminado; si no se actualiza ninguna fila, se lanza error de serialización.
- `EXECUTE` permanece revocado para `PUBLIC`, `anon` y `authenticated`; la función solo se invoca desde el trigger.
- `SET search_path = ''` se mantiene y todos los objetos y funciones se cualifican: `auth.uid()`, `public.emergency_events`, `pg_catalog.pg_advisory_xact_lock()`, `pg_catalog.hashtext()` y `pg_catalog.now()`. `GREATEST` se usa como expresión SQL, no como función esquemática.

El propietario de la función debe ser un rol administrativo de confianza y nunca un rol usado por el cliente Flutter. Si el proyecto cambia el propietario, debe repetirse esta auditoría.

## 7. Relación de envíos SOS

### 7.1 Decisión

`emergency_event_deliveries` conserva `contacto_id` como texto snapshot y no usa FK directa a `emergency_contacts`.

Razones:

- El historial debe conservar nombre, teléfono y prioridad aunque el contacto se edite o elimine.
- Un contacto eliminado lógicamente no debe romper la lectura del historial.
- La FK directa a `emergency_events` garantiza que los envíos desaparezcan solo por cascada administrativa del evento.

### 7.2 Protecciones

- SELECT, INSERT y UPDATE exigen que exista un evento propio: `exists (... e.user_id = auth.uid())`.
- No hay política DELETE y el privilegio fue revocado.
- `event_id`, `contacto_id`, `nombre`, `telefono` y `prioritario` son inmutables mediante trigger.
- El cliente solo puede actualizar `canal`, `estado`, `detalle` y `cliente_actualizado_en`.
- No es necesario consultar `emergency_contacts` para validar propiedad: el acceso se decide por el evento padre, que ya está protegido por RLS.
- Un usuario no puede insertar ni modificar envíos de un evento ajeno porque la política `WITH CHECK` falla.

## 8. Permisos y RLS definitivos

RLS no se considera suficiente por sí sola. Cada tabla tiene:

- RLS habilitado.
- Políticas solo para `authenticated`.
- Sin políticas para `anon`.
- `REVOKE ALL ... FROM PUBLIC, anon`.
- `REVOKE UPDATE, DELETE ... FROM authenticated`.
- `GRANT SELECT, INSERT ... TO authenticated`.
- `GRANT UPDATE (<columnas permitidas>) ... TO authenticated`.

| Tabla | SELECT | INSERT | UPDATE permitido | DELETE |
| --- | --- | --- | --- | --- |
| `profiles` | `id = auth.uid()` | `id = auth.uid()` | `nombre`, `cliente_actualizado_en` | No |
| `user_settings` | `user_id = auth.uid()` | `user_id = auth.uid()` | preferencias y `cliente_actualizado_en` | No |
| `emergency_contacts` | `user_id = auth.uid()` | `user_id = auth.uid()` | `nombre`, `telefono`, `prioritario`, `eliminado_en`, `cliente_actualizado_en` | No |
| `emergency_events` | `user_id = auth.uid()` | `user_id = auth.uid()` | `fin`, `activa`, `envio_inicial_intentado`, `estado_compartir`, `compartido_en`, `eliminado_en`, `cliente_actualizado_en` | No |
| `emergency_event_deliveries` | evento propio | evento propio | `canal`, `estado`, `detalle`, `cliente_actualizado_en` | No |
| `saved_earthquakes` | `user_id = auth.uid()` | `user_id = auth.uid()` | `eliminado_en`, `cliente_actualizado_en` | No |

`service_role` puede bypassar RLS por diseño de Supabase; por eso no debe existir en el cliente Flutter y su uso queda limitado a administración externa.

## 9. Archivos modificados en FASE 3.1

- `supabase/migrations/0001_profiles_user_settings.sql`
  - Triggers de timestamps, inmutabilidad y protección de identidad.
  - `SECURITY DEFINER` justificado para `profiles.email`.
  - Eliminación de DELETE en perfiles y preferencias.
  - Privilegios por columna.
- `supabase/migrations/0002_emergency_contacts.sql`
  - Eliminación de restricción temporal.
  - Tombstone protegido.
  - Eliminación de DELETE.
  - Privilegios por columna.
- `supabase/migrations/0003_emergency_events.sql`
  - Eliminación de restricción temporal.
  - Campo `motivo_fin`.
  - Resolución de SOS concurrentes con `SECURITY DEFINER` acotado, `GREATEST`, verificación de propiedad y `REVOKE EXECUTE`.
  - Snapshot de envíos inmutable.
  - Eliminación de DELETE.
  - Privilegios por columna.
- `supabase/migrations/0004_saved_earthquakes.sql`
  - Eliminación de restricción temporal.
  - Tombstone protegido.
  - Eliminación de DELETE.
  - Privilegios por columna.
- `docs/ARQUITECTURA_SUPABASE.md`
  - Hallazgos, riesgos, decisiones y políticas definitivas de FASE 3.1.

## 10. Riesgos que todavía requieren decisión

| Riesgo | Estado | Decisión pendiente |
| --- | --- | --- |
| Reactivación de sismos guardados eliminados | Bloqueada deliberadamente | Definir RPC controlada o nueva convención de guardado. |
| RPC de sincronización con comparación de `cliente_actualizado_en` | No implementada | Diseñar RPC con validación de `auth.uid()` y `search_path` seguro. |
| Pruebas PostgreSQL/RLS con dos usuarios reales | Ejecutadas localmente en PostgreSQL 17 aislado; 24/24 OK, reejecución OK y concurrencia OK | Repetir en staging de Supabase antes de producción. |
| Política de retención remota del historial SOS | No definida | Definir cuánto tiempo conservar eventos y tombstones. |
| Cambio de correo en Supabase Auth | Trigger controlado añadido en `0005_fase4_hardening.sql` | Verificar privilegios del trigger sobre `auth.users` en el entorno remoto. |
| `service_role` en operaciones administrativas | Fuera del cliente | Definir backend y controles de auditoría si se llega a necesitar. |

## 11. Validación realizada

- `flutter analyze`: `No issues found!`
- `flutter test`: `All tests passed!` — 61/61 pruebas.
- Revisión coherente de las cuatro migraciones SQL propuestas y de la correctiva `0005_fase4_hardening.sql`.
- Revisión final de `resolve_active_sos_conflict()`: `SECURITY DEFINER`, `auth.uid()`, propiedad reforzada, `GREATEST`, `FOUND` y `REVOKE EXECUTE`.
- Pruebas PostgreSQL ejecutadas localmente con PostgreSQL 17 aislado: 24/24 OK, reejecución OK y concurrencia real OK.
- Harness `supabase/tests/run_local_tests.ps1`: `RESULTADO_FINAL=APROBADO`.
- Detalle completo en `docs/VALIDACION_MIGRACIONES_SUPABASE.md`.
- No se ejecutaron migraciones en Supabase remoto.
- No se consultaron ni modificaron tablas remotas.
- No se crearon usuarios ni tablas en Supabase.
- No se modificó la autenticación local ni el flujo SOS.
- No se introdujeron credenciales, claves ni secretos.
- No se realizó commit ni push.

## 12. Informe final de FASE 3.1

### 12.1 Problemas encontrados

Los nueve problemas listados en la sección 2.1, principalmente borrado directo del perfil, columnas sensibles editables, DELETE contradictorio con tombstones, restricciones temporales frágiles, concurrencia SOS y privilegios por defecto no verificados. La auditoría final añadió los cuatro problemas de la sección 2.4 sobre `resolve_active_sos_conflict()`.

### 12.2 Correcciones realizadas

- Perfiles protegidos con trigger de identidad, columnas inmutables y sin DELETE.
- Eliminación lógica obligatoria en contactos, eventos, envíos, sismos guardados y preferencias.
- Restricciones temporales eliminadas y sustituidas por estrategia cliente/servidor coherente.
- Concurrencia SOS resuelta sin pérdida de eventos.
- `resolve_active_sos_conflict()` corregido como `SECURITY DEFINER` acotado, con validación de identidad, propiedad reforzada, `GREATEST`, verificación `FOUND` y `REVOKE EXECUTE`.
- Snapshot de envíos protegido.
- RLS complementado con `REVOKE`/`GRANT` explícitos y triggers de integridad.

### 12.3 Archivos modificados

Ver sección 9.

### 12.4 Políticas RLS definitivas propuestas

Ver sección 8.

### 12.5 Riesgos que requieren decisión

Ver sección 10.

### 12.6 Resultado de pruebas

Ver sección 11 y `docs/VALIDACION_MIGRACIONES_SUPABASE.md`. Las pruebas PostgreSQL se ejecutaron localmente; no se ejecutaron migraciones ni SQL contra Supabase remoto.

## 13. Conclusión

Las propuestas quedan endurecidas para FASE 3.1 y FASE 4: el cliente no puede borrar datos directamente, no puede alterar identidad ni metadatos de servidor, las eliminaciones preservan tombstones, los conflictos SOS concurrentes conservan ambos eventos y los privilegios efectivos están definidos explícitamente. Las migraciones fueron ejecutadas y validadas en PostgreSQL local aislado. La ejecución en Supabase y cualquier cambio remoto siguen pendientes de aprobación.

## 14. Pruebas PostgreSQL propuestas

Estas pruebas quedaron automatizadas en `supabase/tests/` y se ejecutaron contra un clúster PostgreSQL 17 local y desechable, nunca contra el proyecto Supabase remoto. El detalle de ejecución está en `docs/VALIDACION_MIGRACIONES_SUPABASE.md`. PostgreSQL 17 está instalado localmente en `C:\Program Files\PostgreSQL\17\bin`; no hay Docker ni Supabase CLI.

### 14.1 Preparación del entorno local

Aplicar las cuatro migraciones en una base PostgreSQL de prueba con roles `anon` y `authenticated`. Si el entorno no es Supabase, crear un shim local de `auth.uid()`:

```sql
create schema if not exists auth;

create or replace function auth.uid()
returns uuid
language sql
stable
set search_path = ''
as $$
  select nullif(pg_catalog.current_setting('request.jwt.claim.sub', true), '')::uuid;
$$;

do $$
begin
  if not exists (select 1 from pg_catalog.pg_roles where rolname = 'anon') then
    create role anon nologin;
  end if;

  if not exists (select 1 from pg_catalog.pg_roles where rolname = 'authenticated') then
    create role authenticated nologin;
  end if;
end $$;
```

Sembrar dos usuarios con identidades separadas antes de probar RLS:

```sql
insert into auth.users (id, email)
values
  ('11111111-1111-4111-8111-111111111111', 'usuario-a@example.test'),
  ('22222222-2222-4222-8222-222222222222', 'usuario-b@example.test');

set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
insert into public.profiles (id, nombre, email)
values ('11111111-1111-4111-8111-111111111111', 'Usuario A', 'usuario-a@example.test');

set local request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
insert into public.profiles (id, nombre, email)
values ('22222222-2222-4222-8222-222222222222', 'Usuario B', 'usuario-b@example.test');
```

Reiniciar datos entre escenarios con una sesión administrativa:

```sql
truncate public.emergency_event_deliveries, public.emergency_events restart identity;
```

Salvo en 14.9, cada prueba debe ejecutarse dentro de una transacción con el usuario correspondiente:

```sql
begin;
set local request.jwt.claim.sub = '<uuid del usuario>';
set local role authenticated;
```

### 14.2 Inserción del primer SOS activo

```sql
begin;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
set local role authenticated;

insert into public.emergency_events (
  id, user_id, tipo, usuario_nombre, inicio, mensaje, cliente_actualizado_en
) values (
  'sos-a-1',
  '11111111-1111-4111-8111-111111111111',
  'sos',
  'Usuario A',
  pg_catalog.now(),
  'Primer SOS',
  pg_catalog.now()
);

do $$
begin
  if not exists (
    select 1
    from public.emergency_events
    where id = 'sos-a-1'
      and user_id = '11111111-1111-4111-8111-111111111111'
      and activa
      and eliminado_en is null
  ) then
    raise exception 'Fallo prueba 1: el primer SOS no quedó activo';
  end if;
end $$;
commit;
```

Resultado esperado: una fila activa `sos-a-1`.

### 14.3 Segundo SOS que gana

Reiniciar datos y ejecutar como usuario A:

```sql
insert into public.emergency_events (
  id, user_id, tipo, usuario_nombre, inicio, mensaje, cliente_actualizado_en
) values (
  'sos-a-1', '11111111-1111-4111-8111-111111111111', 'sos', 'Usuario A',
  '2026-01-01 00:00:00+00'::timestamptz, 'Primero',
  '2026-01-01 00:00:00+00'::timestamptz
);

insert into public.emergency_events (
  id, user_id, tipo, usuario_nombre, inicio, mensaje, cliente_actualizado_en
) values (
  'sos-a-2', '11111111-1111-4111-8111-111111111111', 'sos', 'Usuario A',
  '2026-01-01 00:01:00+00'::timestamptz, 'Segundo',
  '2026-01-01 00:01:00+00'::timestamptz
);
```

Afirmaciones esperadas:

- Existen dos filas: `sos-a-1` y `sos-a-2`.
- `sos-a-2` queda `activa`.
- `sos-a-1` queda inactiva con `motivo_fin = 'conflicto_multidispositivo'`.
- Exactamente una fila activa para el usuario A.

### 14.4 Segundo SOS que pierde

Reiniciar datos y ejecutar como usuario A con marcas invertidas:

```sql
insert into public.emergency_events (
  id, user_id, tipo, usuario_nombre, inicio, mensaje, cliente_actualizado_en
) values (
  'sos-a-1', '11111111-1111-4111-8111-111111111111', 'sos', 'Usuario A',
  '2026-01-01 00:01:00+00'::timestamptz, 'Primero',
  '2026-01-01 00:01:00+00'::timestamptz
);

insert into public.emergency_events (
  id, user_id, tipo, usuario_nombre, inicio, mensaje, cliente_actualizado_en
) values (
  'sos-a-2', '11111111-1111-4111-8111-111111111111', 'sos', 'Usuario A',
  '2026-01-01 00:00:00+00'::timestamptz, 'Segundo',
  '2026-01-01 00:00:00+00'::timestamptz
);
```

Afirmaciones esperadas:

- Existen dos filas.
- `sos-a-1` permanece activa.
- `sos-a-2` queda inactiva con `motivo_fin = 'conflicto_multidispositivo'`.
- Exactamente una fila activa para el usuario A.

### 14.5 Conservación de ambos eventos

Incluida en 14.3 y 14.4. Después de cada conflicto, `select count(*)` sobre `public.emergency_events` para el usuario A debe devolver `2`. Ninguna rama del trigger debe eliminar filas.

### 14.6 Un solo SOS activo

Incluida en 14.3 y 14.4. La afirmación mínima es:

```sql
select count(*) = 1
from public.emergency_events
where user_id = '11111111-1111-4111-8111-111111111111'
  and activa
  and eliminado_en is null;
```

### 14.7 Actualización de `motivo_fin`

Incluida en 14.3 y 14.4. El evento perdedor debe cumplir:

```sql
select motivo_fin = 'conflicto_multidispositivo'
from public.emergency_events
where id = 'sos-a-1';
```

Además, la siguiente sentencia ejecutada como `authenticated` sobre una fila propia debe fallar con `insufficient_privilege`, porque `motivo_fin` no está concedido:

```sql
update public.emergency_events
set motivo_fin = 'manual'
where id = 'sos-a-1';
```

### 14.8 Imposibilidad de modificar eventos ajenos

Reiniciar datos, crear `sos-a-1` como usuario A y luego ejecutar como usuario B:

```sql
begin;
set local request.jwt.claim.sub = '22222222-2222-4222-8222-222222222222';
set local role authenticated;

do $$
declare
  v_count integer;
begin
  update public.emergency_events
  set activa = false
  where id = 'sos-a-1';

  get diagnostics v_count = row_count;

  if v_count <> 0 then
    raise exception 'Fallo prueba 8: el usuario B actualizó un evento del usuario A';
  end if;

  begin
    insert into public.emergency_event_deliveries (
      id, event_id, contacto_id, nombre, telefono, canal, estado, cliente_actualizado_en
    ) values (
      'delivery-invasor', 'sos-a-1', 'contacto-b', 'Contacto B', '600000000',
      'sms', 'pendiente', pg_catalog.now()
    );

    raise exception 'Fallo prueba 8: el usuario B insertó un envío en evento ajeno';
  exception
    when insufficient_privilege then null;
  end;
end $$;
commit;
```

Afirmación adicional: `sos-a-1` debe seguir activo y con `user_id` del usuario A.

### 14.9 Dos inserciones concurrentes

Ejecutar en dos sesiones reales, no secuenciales en la misma transacción.

Sesión 1:

```sql
begin;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
set local role authenticated;

insert into public.emergency_events (
  id, user_id, tipo, usuario_nombre, inicio, mensaje, cliente_actualizado_en
) values (
  'sos-c1', '11111111-1111-4111-8111-111111111111', 'sos', 'Usuario A',
  pg_catalog.now(), 'Concurrente 1', pg_catalog.now()
);

select pg_catalog.pg_sleep(2);
commit;
```

Sesión 2 iniciada inmediatamente después:

```sql
begin;
set local request.jwt.claim.sub = '11111111-1111-4111-8111-111111111111';
set local role authenticated;

insert into public.emergency_events (
  id, user_id, tipo, usuario_nombre, inicio, mensaje, cliente_actualizado_en
) values (
  'sos-c2', '11111111-1111-4111-8111-111111111111', 'sos', 'Usuario A',
  pg_catalog.now(), 'Concurrente 2', pg_catalog.now()
);

commit;
```

Resultado esperado: la segunda sesión puede esperar por el lock advisory, pero no debe fallar por el índice único. Deben existir `sos-c1` y `sos-c2`; exactamente uno activo; el perdedor con `motivo_fin = 'conflicto_multidispositivo'`.

### 14.10 Igualdad de marca de actualización

Reiniciar datos y ejecutar como usuario A:

```sql
insert into public.emergency_events (
  id, user_id, tipo, usuario_nombre, inicio, mensaje, cliente_actualizado_en
) values (
  'sos-tie-a', '11111111-1111-4111-8111-111111111111', 'sos', 'Usuario A',
  '2026-02-01 00:00:00+00'::timestamptz, 'Empate A',
  '2026-02-01 00:00:00+00'::timestamptz
);

insert into public.emergency_events (
  id, user_id, tipo, usuario_nombre, inicio, mensaje, cliente_actualizado_en
) values (
  'sos-tie-b', '11111111-1111-4111-8111-111111111111', 'sos', 'Usuario A',
  '2026-02-01 00:00:00+00'::timestamptz, 'Empate B',
  '2026-02-01 00:00:00+00'::timestamptz
);
```

Resultado esperado con desempate `(cliente_actualizado_en, inicio, id)`:

- `sos-tie-b` queda activo por tener mayor `id`.
- `sos-tie-a` queda inactivo con `motivo_fin = 'conflicto_multidispositivo'`.
- Exactamente una fila activa y dos filas en total.

## 15. FASE 4: corrección y validación ejecutada

Se añadió `supabase/migrations/0005_fase4_hardening.sql` como migración correctiva sin reescribir el historial de `0001` a `0004`.

Cambios principales:

- `profiles_enforce_auth_identity()` reforzada como `SECURITY DEFINER` acotada, con correo tomado de `auth.users` y bandera interna `app.internal_profile_email_sync`.
- `auth_users_sync_profile_email()` y su trigger sobre `auth.users after update of email` para propagar cambios de correo sin permitir edición directa desde el cliente.
- `enforce_sos_terminal_state()`: impide reactivar un SOS cerrado o modificar `fin`/`motivo_fin`.
- `set_sos_manual_close()`: el cierre manual del cliente fija `motivo_fin = 'manual'`.
- `resolve_active_sos_conflict()` reescrita con lock advisory determinista, validación de `auth.uid()`, `SET search_path = ''` y resolución sin pérdida del evento perdedor.
- Triggers de `emergency_events` ordenados explícitamente del `00` al `06`; el conflicto solo se resuelve en INSERT, nunca en UPDATE.
- `saved_earthquakes.guardado_id uuid` como nueva PK, con backfill y defaults, más índice único parcial por usuario/sismo activo.
- Trigger de inmutabilidad para `saved_earthquakes`.
- RLS y privilegios recreados para las seis tablas: sin `DELETE`, `TRUNCATE`, `TRIGGER` ni `REFERENCES` para `anon`/`authenticated`.

La validación real se ejecutó con `supabase/tests/run_local_tests.ps1` y terminó con `RESULTADO_FINAL=APROBADO`. Incluyó 24 pruebas funcionales, reejecución de migraciones y una prueba de concurrencia con dos sesiones PostgreSQL independientes. Ver `docs/VALIDACION_MIGRACIONES_SUPABASE.md`.

Limitación operativa: el trigger sobre `auth.users` y el `ALTER FUNCTION ... OWNER TO postgres` requieren privilegios administrativos adecuados en el proyecto Supabase remoto. Deben revisarse antes de cualquier aplicación controlada en staging.
