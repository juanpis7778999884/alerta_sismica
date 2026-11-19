# Validación local de migraciones Supabase

Este documento registra la validación real de las migraciones SQL del proyecto ejecutada únicamente contra un clúster PostgreSQL 17 local y aislado.

No se ejecutó ninguna migración contra Supabase remoto. No se usó `service_role`, `sb_secret_...` ni ninguna credencial real. No se modificó `supabase.env.json`.

## 1. Alcance

Se auditaron, corrigieron y probaron las migraciones:

1. `supabase/migrations/0001_profiles_user_settings.sql`
2. `supabase/migrations/0002_emergency_contacts.sql`
3. `supabase/migrations/0003_emergency_events.sql`
4. `supabase/migrations/0004_saved_earthquakes.sql`
5. `supabase/migrations/0005_fase4_hardening.sql`

`0005_fase4_hardening.sql` es una migración correctiva nueva. No se reescribieron migraciones ya creadas, para conservar el historial y evitar reemplazar migraciones que ya pudieron haberse aplicado en otro entorno.

## 2. Entorno

- PostgreSQL local 17 instalado en `C:\Program Files\PostgreSQL\17\bin`.
- Clúster temporal creado con `initdb` bajo:
  - `C:\Users\Usuario\AppData\Local\Temp\opencode\alerta_sismica_pg_tests\run_<guid>`
- Protocolo y conexión:
  - host: `127.0.0.1`
  - puerto: `55432`
  - usuario local: `postgres`
  - autenticación: `trust`
  - `listen_addresses=127.0.0.1`
- Docker y Supabase CLI no estuvieron disponibles; no fueron necesarios para esta validación.

No se reutilizó la instancia PostgreSQL de sistema ni su contraseña.

## 3. Infraestructura de prueba

Archivos creados:

- `supabase/tests/00_setup.sql`
  - Crea un shim mínimo de Supabase: esquema `auth`, tabla `auth.users`, roles `anon`/`authenticated` y función `auth.uid()`.
  - `auth.uid()` lee `request.jwt.claim.sub` mediante `current_setting`.
- `supabase/tests/validacion.sql`
  - Ejecuta 24 pruebas funcionales y de seguridad.
- `supabase/tests/reejecucion.sql`
  - Verifica que las migraciones puedan ejecutarse dos veces sin duplicar esquemas, índices, triggers ni políticas.
- `supabase/tests/concurrencia_sesion1.sql`
- `supabase/tests/concurrencia_sesion2.sql`
- `supabase/tests/concurrencia_verificacion.sql`
  - Prueba real de concurrencia con dos conexiones PostgreSQL independientes.
- `supabase/tests/run_local_tests.ps1`
  - Crea el clúster temporal.
  - Aplica `00_setup.sql` y todas las migraciones.
  - Ejecuta validación, reejecución y concurrencia.
  - Detiene el clúster al finalizar.

## 4. Comando ejecutado

Desde la raíz del proyecto:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "supabase\tests\run_local_tests.ps1"
```

Resultado final:

```text
RESULTADO_FINAL=APROBADO
HARNESS_EXIT=0
```

El log PostgreSQL de la última ejecución aprobada quedó en:

```text
C:\Users\Usuario\AppData\Local\Temp\opencode\alerta_sismica_pg_tests\run_162991ad05184f9eb8132f3c932b4871\postgres.log
```

## 5. Pruebas ejecutadas

Las 24 pruebas de `supabase/tests/validacion.sql` terminaron correctamente:

1. Aplicación de migraciones desde base limpia.
2. Reejecución controlada de migraciones.
3. Creación de perfil propio.
4. Rechazo de creación de perfil ajeno.
5. Protección del correo y sincronización desde Auth.
6. Protección de columnas inmutables.
7. Aislamiento RLS entre dos usuarios.
8. Rechazo de `DELETE`.
9. Rechazo de `TRUNCATE`.
10. Rechazo de modificaciones de columnas protegidas.
11. Eliminación lógica de contactos.
12. Rechazo de reactivación de contactos eliminados.
13. Rechazo de teléfonos duplicados activos.
14. Cierre manual de SOS.
15. Rechazo de reactivación de SOS cerrado.
16. Inicio de SOS por dos dispositivos.
17. Resolución determinista de conflictos.
18. Garantía de un solo SOS activo.
19. Aislamiento de entregas de emergencia.
20. Inmutabilidad del snapshot de contactos.
21. Eliminación lógica de sismos guardados.
22. Rechazo de reactivación y re-guardado seguro.
23. Protección de funciones `SECURITY DEFINER`.
24. Privilegios efectivos de `anon` y `authenticated`.

Salida final de la validación:

```text
VALIDACION GENERAL TERMINADA
```

## 6. Reejecución

`supabase/tests/reejecucion.sql` terminó correctamente:

```text
REEJECUCION 01 esquema sin duplicados
OK
REEJECUCION 02 funcionabilidad basica tras reejecutar
OK
REEJECUCION TERMINADA
```

También se aplicaron las cinco migraciones dos veces sobre una base separada sin errores.

## 7. Concurrencia real

Se iniciaron dos procesos `psql` independientes:

- sesión 1: inserta SOS, mantiene la transacción abierta con `pg_sleep(3)` y hace `COMMIT`.
- sesión 2: inserta otro SOS activo del mismo usuario mientras la primera transacción sigue abierta.
- verificación: comprueba que existan dos eventos, que el ganador sea determinista y que quede exactamente un SOS activo.

Resultado:

```text
CONCURRENCIA 01 dos sesiones independientes conservan ambos eventos
CONCURRENCIA 02 resolucion determinista y unico activo
OK
CONCURRENCIA TERMINADA
```

## 8. Correcciones detectadas durante la validación

Durante la ejecución local se detectaron y corrigieron estos problemas:

| Problema | Corrección |
|---|---|
| `pg_catalog.nullif(text, unknown)` no existe en PostgreSQL | `supabase/tests/00_setup.sql` usa `nullif(...)` sin calificar. |
| `TEST 03` insertaba dos veces el mismo perfil porque `reset()` ya sembraba perfiles | Se añadió `pruebas.reset_vacio()` y `TEST 03` lo utiliza. |
| El trigger de inmutabilidad rechazaba el `motivo_fin` interno del resolver de conflictos | Se quitó `motivo_fin` de la lista del trigger de inmutabilidad en `0005`. El cliente no tiene permiso de columna para modificarlo. |
| `TEST 23` detectaba falsamente `EXECUTE` público por el grant del propietario | Se cambió la comprobación a `pg_catalog.aclexplode(...)` con `grantee = 0`. |
| `reejecucion.sql` fallaba por falta de `USAGE` en su esquema de prueba | Se concedieron `USAGE` y `EXECUTE` a `authenticated`. |
| El harness interpretaba un `ExitCode` nulo de `Start-Process` como fallo | Se ajustó `Assert-ProcessOk` para no tratar `null` como error. |

## 9. Decisiones de seguridad verificadas

- RLS permanece habilitado en las seis tablas.
- No existen políticas `DELETE` para `anon` ni `authenticated`.
- No se conceden `DELETE`, `TRUNCATE`, `TRIGGER` ni `REFERENCES` a `anon`/`authenticated`.
- El correo del perfil solo puede sincronizarse desde `auth.users`.
- Las funciones `SECURITY DEFINER` relevantes están:
  - marcadas como `SECURITY DEFINER`;
  - con `SET search_path = ''`;
  - sin `EXECUTE` para `PUBLIC`, `anon` ni `authenticated`;
  - bajo propietario `postgres` en la prueba local.
- El conflicto de SOS activo usa lock advisory determinista dentro de la transacción.
- El cierre manual fija `motivo_fin = 'manual'`; el conflicto multidispositivo fija `motivo_fin = 'conflicto_multidispositivo'`.
- `saved_earthquakes` usa `guardado_id uuid` como clave primaria y un índice único parcial por usuario/sismo activo.

## 10. Limitaciones y atención futura

- La prueba de sincronización de correo usa el shim local de `auth.users`; en Supabase real el trigger sobre `auth.users` puede requerir privilegios elevados o ejecución desde el dashboard/SQL editor con propietario adecuado.
- `alter function ... owner to postgres` funciona en el clúster local y en la mayoría de proyectos Supabase, pero debe revisarse si el entorno remoto usa otro rol propietario.
- Esta validación no sustituye la ejecución controlada en un proyecto Supabase de staging.
- No se ejecutó `supabase db push`, `supabase link`, `supabase migration up` ni ningún comando contra remoto.
