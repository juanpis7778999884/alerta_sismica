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
