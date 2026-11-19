# Informe final de entrega A–H

## A. Resumen ejecutivo

Se completó Alerta Sísmica como aplicación Flutter funcional, con monitoreo de
sismos de USGS, mapa, lista, caché offline, contactos de emergencia, flujo SOS,
historial, autenticación local y diagnóstico de conectividad y permisos. El
proyecto compila en Android, el análisis estático no reporta incidencias y las 37
pruebas unitarias pasan.

Entregable principal:

- APK de depuración:
  `build/app/outputs/flutter-apk/app-debug.apk`
- Tamaño: 167 615 043 bytes (aproximadamente 160 MiB)
- SHA-256:
  `119B836F10A5FAC8999B4B38AC04AFD960C1BE63698AD6D6C907661512AB23F0`
- Versión: `1.0.0+1`

## B. Alcance implementado

### Sismos y mapa

- Lectura y validación del GeoJSON de USGS (`all_day.geojson`).
- Caché local y modo offline con indicación de datos desactualizados.
- Lista con búsqueda y orden por recientes, magnitud o cercanía.
- Mapa con OpenStreetMap, marcadores por magnitud, leyenda, filtro de cercanía y
  controles de zoom y centrado.
- Detalle del evento con enlace a USGS y mapa.
- Avisos locales de sismos nuevos con umbral configurable.

### Emergencias

- Activación de SOS general o por sismo, con persistencia previa al envío.
- Ubicación GPS o última conocida, dirección aproximada opcional.
- Envío preparado por SMS a todos o a un contacto, WhatsApp, selector del sistema,
  mapa y marcador telefónico.
- Estados honestos: pendiente, canal abierto sin confirmación, cancelado, fallido
  y no disponible.
- Historial de hasta 50 emergencias finalizadas.
- Notificación local de emergencia activa.

### Cuenta y configuración

- Registro e inicio de sesión local con PBKDF2-HMAC-SHA256.
- Código de recuperación de un solo uso y sesión de 30 días.
- Preferencias de tema, magnitud mínima, auto-refresco, notificaciones, umbral y
  número de emergencia.
- Borrado selectivo y borrado total de datos locales.

### Calidad de plataforma

- Temas claro y oscuro, localización en español y diseño adaptado a móvil.
- Diagnóstico de red, Internet real, USGS, red satelital reportada, ubicación,
  canales de aviso y notificaciones.
- Configuración Android: `compileSdk 37`, `minSdk 24`, Java 17 y permisos mínimos.
- Sin credenciales ficticias ni servicios inventados.

## C. Arquitectura

La app sigue una separación por capas:

- `models/`: entidades inmutables y serialización JSON.
- `services/`: integraciones con USGS, geolocalización, Nominatim, canales
  externos, notificaciones, conectividad y criptografía.
- `repositories/`: persistencia en `SharedPreferences` y normalización de datos.
- `providers/`: estado reactivo con `ChangeNotifier` y reglas de negocio.
- `screens/` y `widgets/`: interfaz Material 3.
- `core/`: errores, validadores, formatos y navegación global.

Las dependencias se inyectan en `main.dart` mediante `provider`. Esto permite
sustituir servicios en pruebas y evita que la interfaz acceda directamente a las
APIs de plataforma.

## D. Seguridad y privacidad

- Contraseña y código de recuperación derivados con PBKDF2-HMAC-SHA256 (60 000
  iteraciones) y sales aleatorias; comparación de tiempo constante.
- Sin backend propio ni telemetría.
- SMS y llamadas mediante intents; no se solicita `SEND_SMS` ni `CALL_PHONE`.
- Los estados de envío no afirman entrega.
- El borrado total restaura la app a su estado inicial.
- Limitación documentada: `SharedPreferences` no está cifrado en reposo; para
  producción se recomienda almacenamiento seguro y firma de release.

El detalle está en [docs/SEGURIDAD_Y_PRIVACIDAD.md](docs/SEGURIDAD_Y_PRIVACIDAD.md).

## E. Pruebas y calidad

Comandos ejecutados y resultado:

| Comprobación | Resultado |
| --- | --- |
| `dart format .` | Código formateado |
| `flutter analyze` | `No issues found!` |
| `flutter test` | 37 pruebas aprobadas |
| `flutter build apk --debug` | APK generado correctamente |

Cobertura de pruebas unitarias:

- Validadores de teléfono, correo, contraseña, código de recuperación y número de
  emergencia.
- Formatos de duración, coordenadas y tiempos relativos.
- Parseo, validación, caché, simulación y distancia de sismos.
- Serialización, finalización y resúmenes de emergencias.
- Serialización y límites de la configuración.
- Derivación, verificación, códigos y tokens del hasher.

Las pruebas son unitarias. No se ejecutaron pruebas instrumentadas ni E2E en un
dispositivo físico en este entorno.

Advertencias no bloqueantes del build: opciones Java 8 obsoletas en dependencias
y uso de una API deprecada en `geolocator_android`. No afectan al APK generado.

## F. Compilación y entrega

Entorno verificado:

- Flutter 3.47.4 stable, Dart 3.13.3.
- Android SDK 36.1.0 disponible; `compileSdk 37` en el proyecto.
- Java 17 para compilación; APK firmado con la clave de depuración.

Para reproducir:

```powershell
flutter pub get
flutter analyze
flutter test
flutter build apk --debug
```

Salida:

```text
build/app/outputs/flutter-apk/app-debug.apk
```

El APK de depuración incluye todas las arquitecturas y símbolos de depuración, de
ahí su tamaño. Para distribución se debe generar una compilación release firmada.

## G. Limitaciones y pendientes externos

1. **Firma de release y publicación**: falta configurar keystore de producción,
   cambiar el `applicationId` `com.example.alerta_sismica`, revisar la política de
   privacidad y publicar.
2. **Notificaciones push remotas**: requieren un backend y FCM u otro proveedor;
   no forman parte de esta entrega.
3. **Pruebas en dispositivo real**: validar permisos, SMS, WhatsApp, mapas,
   notificaciones, rotación, modo oscuro y ausencia de red.
4. **Almacenamiento cifrado**: migrar credenciales y datos sensibles a Keystore o
   almacenamiento seguro.
5. **Entorno Android**: `flutter doctor` reporta `cmdline-tools` faltante y
   licencias sin aceptar; no impidió la compilación debug. Visual Studio está
   incompleto, lo que solo afecta a compilaciones de escritorio Windows.
6. **Geocodificación**: Nominatim es un servicio público con límites; para
   producción conviene evaluar un proveedor con SLA.
7. **Mapa offline**: los mosaicos de OpenStreetMap no se cachean de forma
   persistente en la app.
8. **Idioma**: la interfaz está fijada al español.

## H. Recomendaciones y próximos pasos

1. Configurar firma release y pipelines de compilación.
2. Añadir pruebas de widgets e integración para los flujos críticos de SOS y
   autenticación.
3. Incorporar límite de intentos y bloqueo local tras fallos de contraseña.
4. Evaluar almacenamiento seguro y bloqueo biométrico.
5. Diseñar, si se requiere, un backend de notificaciones push con consentimiento
   explícito, gestión de tokens y política de retención.
6. Sustituir las llamadas directas a Nominatim por un servicio con SLA o
   autohospedado.
7. Validar el flujo completo en dispositivos Android reales, incluidos operadores
   sin datos y terminales sin app de WhatsApp.
8. Revisar el cumplimiento legal y de privacidad antes de cualquier publicación.

## Evidencia de archivos clave

- Entrada: `lib/main.dart`
- Autenticación: `lib/repositories/auth_repository.dart`,
  `lib/services/password_hasher.dart`
- Sismos: `lib/repositories/sismos_repository.dart`,
  `lib/providers/sismos_provider.dart`
- Emergencias: `lib/providers/emergencia_provider.dart`,
  `lib/services/emergency_channels.dart`
- Interfaz: `lib/screens/`, `lib/widgets/`, `lib/theme.dart`
- Pruebas: `test/`
- Documentación: `README.md`, `docs/MANUAL_DE_USO.md`,
  `docs/SEGURIDAD_Y_PRIVACIDAD.md`

## I. Infraestructura inicial de Supabase (fase actual)

Se incorporó únicamente la capa de configuración e inicialización del SDK, sin
modificar autenticación local, contactos, emergencias, SOS, SharedPreferences ni
proveedores existentes.

Cambios:

- `lib/core/config/supabase_config.dart`: validación de URL y Publishable key
  desde `String.fromEnvironment`, con rechazo de claves administrativas/secretas
  y mensajes que no exponen credenciales.
- `lib/core/config/supabase_initializer.dart`: inicialización idempotente del
  SDK antes de `runApp()`, con diagnóstico controlado en debug y continuidad de
  la app si falta configuración o falla la inicialización.
- `lib/main.dart`: una única llamada al initializer; se preservan todos los
  repositorios, servicios, providers y cargas iniciales previas.
- `.gitignore`: exclusión de `supabase.env.json` y archivos equivalentes.
- `supabase.env.example.json`: plantilla sin credenciales reales.
- Pruebas unitarias de configuración e initializer sin red ni secretos reales.

Verificación ejecutada en este entorno:

- `flutter pub get`: correcto.
- `dart format --output=none --set-exit-if-changed` sobre los 67 archivos Dart
  de `lib/` y `test/`: correcto, sin cambios. El escaneo directo de `.` puede
  fallar por artefactos temporales del directorio `build/` generados durante
  las compilaciones.
- `flutter analyze`: sin incidencias.
- `flutter test`: 51 pruebas aprobadas.
- `flutter build apk --debug --dart-define-from-file=<archivo local>`: correcto.
- Inicialización local del SDK verificada con un smoke test aislado; en el
  entorno de `flutter test` el plugin de SharedPreferences no está disponible,
  por lo que la inicialización real se validó mediante la compilación Android y
  el initializer inyectado en pruebas unitarias.
- No se consultó ni modificó ningún dato privado de Supabase. No se ha
  demostrado conectividad contra un proyecto real; por tanto, esta fase queda
  descrita como infraestructura local preparada, no como integración completa
  validada contra backend remoto.
- No se imprimieron ni registraron credenciales en ninguna prueba o informe.
- No se encontró `supabase.env.json` versionado ni en el historial de commits
  revisado.

## J. Verificación real de conexión con Supabase (fase actual)

Archivos revisados:

- `lib/core/config/supabase_config.dart`: validación de variables de entorno.
- `lib/core/config/supabase_initializer.dart`: inicialización del SDK y acceso
  al singleton mediante `Supabase.instance.isInitialized` dentro de un bloque
  `try` que evita assertions en entornos sin inicializar.
- `lib/main.dart`: inicialización antes de `runApp()`.
- `docs/CONFIGURACION_SUPABASE.md` y pruebas de la fase anterior.

Archivos modificados o añadidos:

- `lib/core/config/supabase_remote_probe.dart` (nuevo): sonda HTTP al endpoint
  público `/auth/v1/health`, con cabecera `apikey` usando solo la Publishable key.
- `lib/core/config/supabase_connectivity.dart` (nuevo): informe que distingue
  configuración ausente/inválida, inicialización fallida/correcta y resultados
  remotos: accesible, error de red, error de autorización o error de endpoint.
- `test/core/config/supabase_connectivity_test.dart` (nuevo): 10 pruebas con
  cliente HTTP simulado, sin red ni credenciales reales.
- `tool/check_supabase_connection.dart` (nuevo): utilidad de diagnóstico aislada
  que lee el archivo local fuera de la app e imprime solo estados y códigos.
- `docs/CONFIGURACION_SUPABASE.md`: documentación del método de comprobación.

Método y resultado real:

- `--dart-define-from-file` comprobado con un test temporal: las dos variables
  se cargaron correctamente y `SupabaseConfig.validate` las aceptó. El test
  temporal fue eliminado.
- Primera llamada a `/auth/v1/health` sin cabecera `apikey`: `401`. Se añadió la
  cabecera con la Publishable key, sin secretos.
- Segunda llamada: `CONFIGURATION=valid`, `REMOTE=accessible`, `HTTP_STATUS=200`.
  Esto confirma que el proyecto remoto es accesible; no es solo inicialización
  local.
- No se crearon tablas, no se ejecutaron migraciones, no se consultaron datos
  privados, no se modificaron filas y no se cambiaron políticas RLS ni
  permisos.
- No se usaron service_role keys, secret keys ni credenciales administrativas.
  No se imprimieron credenciales en comandos, pruebas, registros ni informes.

Ejecución y errores encontrados:

- `flutter pub get`: correcto.
- `flutter analyze`: sin incidencias.
- `flutter test`: 61 pruebas aprobadas.
- Formato Dart verificado con `dart format --output=none --set-exit-if-changed`
  sobre `lib/`, `test/` y `tool/`.
- `flutter run -d windows --dart-define-from-file=..\supabase.env.json`: falló
  por `Building with plugins requires symlink support`, limitación del entorno
  Windows, no de Supabase.
- `flutter run -d chrome --dart-define-from-file=..\supabase.env.json`: la app
  inició correctamente (`Flutter run key commands`); no se detectaron errores
  ni patrones de credenciales en los registros capturados.
- No hay dispositivo Android conectado; no se ejecutó `flutter run` en Android.

## K. Auditoría final de FASE 3.1 y diseño Supabase

Archivos principales:

- `supabase/migrations/0001_profiles_user_settings.sql`
- `supabase/migrations/0002_emergency_contacts.sql`
- `supabase/migrations/0003_emergency_events.sql`
- `supabase/migrations/0004_saved_earthquakes.sql`
- `docs/ARQUITECTURA_SUPABASE.md`

Problemas encontrados:

- Borrado directo de perfiles y otras tablas con tombstones.
- Columnas sensibles de `profiles` editables por el cliente.
- Restricciones temporales que comparaban relojes de origen distinto.
- Concurrencia SOS sin resolución determinista.
- Privilegios por defecto de `PUBLIC`/`anon` no controlados explícitamente.
- `resolve_active_sos_conflict()` se ejecutaba como invocador y escribía
  `motivo_fin`, columna no concedida a `authenticated`.
- Uso de `pg_catalog.greatest(...)` y filtrado insuficiente de propiedad en el
  UPDATE del evento perdedor.

Correcciones:

- Eliminación lógica obligatoria; sin políticas ni privilegios DELETE para el
  cliente.
- `profiles.email` forzado desde `auth.users`; columnas inmutables protegidas.
- Resolución de SOS concurrentes con lock advisory, comparación determinista y
  conservación de ambos eventos.
- `resolve_active_sos_conflict()` corregido con validación de `auth.uid()`,
  `e.user_id = new.user_id`, `GREATEST`, verificación `FOUND` y `REVOKE EXECUTE`.
- RLS complementado con `REVOKE`/`GRANT` explícitos y triggers de integridad.

Decisión de seguridad sobre `SECURITY DEFINER`:

- Se mantienen tres funciones `SECURITY DEFINER` acotadas: validación de
  identidad de perfiles, sincronización de correo desde `auth.users` y resolución
  de conflictos SOS.
- La del trigger SOS es necesaria para escribir `motivo_fin` sin conceder esa
  columna a `authenticated`.
- Usa `SET search_path = ''`, objetos cualificados, validación de identidad y
  propiedad, y no amplía privilegios al cliente.
- El propietario debe ser un rol administrativo de confianza; RLS no se considera
  suficiente dentro de la función.

Pruebas:

- Ejecutadas: `flutter analyze` sin incidencias; `flutter test` 61/61; revisión
  estática de las cuatro migraciones.
- Ejecutadas localmente en PostgreSQL 17 aislado: 24 pruebas SQL, reejecución de
  migraciones y concurrencia real con dos sesiones; detalle en la sección L y en
  `docs/VALIDACION_MIGRACIONES_SUPABASE.md`.
- No ejecutadas contra Supabase remoto por decisión explícita.

Riesgos restantes:

- RPC de sincronización con comparación de marcas aún no implementada.
- Retención remota del historial SOS sin definir.
- Propagación de cambios de correo en Supabase Auth sin flujo automático.
- Uso administrativo futuro de `service_role` requiere backend y auditoría.

No se ejecutaron migraciones ni SQL en Supabase, no se modificaron datos remotos,
no se introdujeron credenciales y no se realizó commit ni push.

## L. FASE 4: corrección, ejecución local y validación de migraciones

Se añadió `supabase/migrations/0005_fase4_hardening.sql` como migración correctiva,
conservando el historial de `0001` a `0004`.

Correcciones principales:

- Identidad de `profiles` y correo sincronizado desde `auth.users` mediante
  trigger controlado y `SECURITY DEFINER` acotadas.
- SOS cerrado inmutable y cierre manual con `motivo_fin = 'manual'`.
- Resolución determinista de SOS concurrentes con lock advisory, sin perder el
  evento perdedor y con `motivo_fin = 'conflicto_multidispositivo'`.
- Triggers de `emergency_events` ordenados explícitamente del `00` al `06`.
- `saved_earthquakes.guardado_id uuid` como PK, backfill, default y unicidad
  parcial por usuario/sismo activo.
- RLS y privilegios recreados sin `DELETE`, `TRUNCATE`, `TRIGGER` ni `REFERENCES`
  para `anon`/`authenticated`.

Infraestructura de prueba creada:

- `supabase/tests/00_setup.sql`
- `supabase/tests/validacion.sql`
- `supabase/tests/reejecucion.sql`
- `supabase/tests/concurrencia_sesion1.sql`
- `supabase/tests/concurrencia_sesion2.sql`
- `supabase/tests/concurrencia_verificacion.sql`
- `supabase/tests/run_local_tests.ps1`

Resultado real:

- Harness: `RESULTADO_FINAL=APROBADO`.
- Validación SQL: 24/24 pruebas OK.
- Reejecución de migraciones: OK.
- Concurrencia con dos sesiones PostgreSQL independientes: OK.
- Evidencia detallada: `docs/VALIDACION_MIGRACIONES_SUPABASE.md`.

Sigue pendiente la aplicación controlada a un proyecto Supabase de staging. El
trigger sobre `auth.users` y el cambio de propietario de funciones requieren
privilegios administrativos adecuados. No se usaron credenciales remotas, no se
modificó Supabase y no se realizó commit ni push.
