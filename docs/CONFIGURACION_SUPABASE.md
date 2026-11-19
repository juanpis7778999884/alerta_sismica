# Configuración de Supabase

La app usa Supabase Auth y PostgREST para cuentas, ajustes, contactos,
emergencias y sismos guardados, manteniendo el funcionamiento offline y la
sincronización pendiente en un outbox local.

## Archivo local de credenciales

El proyecto toma los valores de `supabase.env.json` ubicado en la raíz del
repositorio y mantiene una copia incluida en `assets/supabase.env.json` para que
`flutter run` funcione sin flags. Ambos archivos están excluidos en `.gitignore`,
por lo que nunca deben subirse a Git.

Plantilla sin credenciales reales (`supabase.env.example.json`):

```json
{
  "SUPABASE_URL": "",
  "SUPABASE_PUBLISHABLE_KEY": ""
}
```

Copia la plantilla como `supabase.env.json` y rellena ambos valores con los de tu
proyecto. No compartas ni imprimas el contenido del archivo.

## Comandos

Desde la raíz del paquete Flutter (`alerta_sismica-main/`) basta con:

```powershell
flutter run
```

La configuración se lee primero con `String.fromEnvironment` y, si no hay
defines, se carga en runtime desde `assets/supabase.env.json` mediante
`rootBundle`. No se usa `dotenv`.

Si prefieres pasar los defines o necesitas sobrescribir el asset:

```powershell
flutter run --dart-define-from-file=..\supabase.env.json
flutter build apk --debug --dart-define-from-file=..\supabase.env.json
```

Cuando cambies las credenciales del archivo local, vuelve a copiarlo a
`assets/supabase.env.json` y reinicia la app por completo.

## Validación

`SupabaseConfig.validate` comprueba:

- URL y Publishable key no vacías.
- URI válida con esquema HTTP/HTTPS; HTTPS obligatorio en producción.
- Host válido.
- Ausencia de credenciales incrustadas en la URL.
- Rechazo de claves `service_role`, `sb_secret_`, secretas o privadas.

Los mensajes de error no incluyen valores de credenciales. `SupabaseInitializer`
registra un diagnóstico controlado solo en debug si falta configuración o falla
la inicialización, y permite que la app siga funcionando sin Supabase.

## Seguridad

- El cliente Flutter usa exclusivamente la Publishable key.
- Nunca se usan service_role keys, secret keys ni contraseñas en el cliente.
- `Supabase.initialize` se invoca con `debug: false` para evitar volcados de
  registros con información sensible.
- La conectividad remota se comprobó contra el proyecto real mediante el
  endpoint público de salud de GoTrue; no se consultaron tablas ni datos
  privados.

## Comprobación remota inocua

La sonda `SupabaseRemoteProbe` realiza un `GET` a
`https://<proyecto>.supabase.co/auth/v1/health` con la cabecera `apikey`
correspondiente a la Publishable key. No consulta tablas, no escribe datos y no
requiere permisos administrativos. Si Supabase no expusiera un endpoint público
de salud, la alternativa sería crear una función RPC pública y de solo lectura,
lo cual queda fuera de esta fase.

`SupabaseConnectivityCheck` distingue estos estados:

- `configuration.missing`: faltan variables de entorno.
- `configuration.invalid`: variables presentes pero inválidas.
- `initialization.failed`: el SDK no pudo inicializarse.
- `initialization.success`: SDK inicializado.
- `remote.accessible`: el proyecto remoto respondió `200`.
- `remote.networkError`: error de red o tiempo de espera.
- `remote.authorizationError`: el proyecto respondió `401`/`403`.
- `remote.endpointError`: respuesta HTTP inesperada.

La utilidad aislada `tool/check_supabase_connection.dart` permite repetir la
comprobación sin iniciar la app:

```powershell
dart run tool/check_supabase_connection.dart ..\supabase.env.json
```

Solo imprime estados y códigos HTTP; nunca imprime credenciales.
