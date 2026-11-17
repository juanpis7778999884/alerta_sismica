# Alerta Sísmica

Aplicación Flutter de monitoreo sísmico, consulta offline y solicitud de ayuda
SOS con contactos de emergencia. Toda la información del usuario permanece en el
dispositivo; la app no tiene servidor propio.

- Versión: `1.0.0+1`
- Plataforma principal: Android (`minSdk 24`, Android 7.0 o superior)
- APK de depuración generado:
  `build/app/outputs/flutter-apk/app-debug.apk`
- Estado de verificación: `flutter analyze` sin incidencias, 37 pruebas
  unitarias aprobadas y compilación Android correcta.

## Qué hace la app

- Consulta el feed público de sismos de las últimas 24 horas de USGS
  (`all_day.geojson`).
- Muestra los eventos en una lista y en un mapa de OpenStreetMap, con filtros por
  magnitud y orden por recientes, magnitud o cercanía.
- Guarda una caché local de sismos para consultarlos sin Internet.
- Gestiona contactos de emergencia con prioridad y validación de teléfonos.
- Permite iniciar una emergencia SOS, preparar el aviso por SMS o WhatsApp,
  compartirlo con el selector del sistema, abrir la ubicación en un mapa y
  abrir el marcador telefónico del número de emergencia configurado.
- Lleva un historial local de emergencias finalizadas y el estado de cada aviso.
- Registra una cuenta local con contraseña protegida mediante
  PBKDF2-HMAC-SHA256, sesión de 30 días y código de recuperación de un solo uso
  mostrado una única vez.
- Ofrece notificaciones locales de sismos nuevos y de emergencia activa.
- Incluye diagnóstico de conectividad, permisos de ubicación, canales de aviso
  y notificaciones.

## Qué no hace

- No es un sistema oficial de alerta temprana.
- No envía SMS, WhatsApp ni llamadas por sí misma: abre la app externa o el
  marcador y requiere confirmación del usuario.
- No puede confirmar la entrega de los mensajes. El estado "canal abierto
  (entrega sin confirmar)" significa exactamente eso.
- No recibe notificaciones push remotas ni funciona como servicio en segundo
  plano con la app cerrada.
- No sincroniza datos entre dispositivos ni posee backend de cuentas.
- No activa la red satelital; solo reporta si el sistema operativo la detecta.

## Requisitos de desarrollo

- Flutter 3.47.4 (stable) y Dart 3.13.3.
- Android SDK con `compileSdk 37`; el proyecto usa Java 17 para compilar.
- Para Android: `minSdk 24`, AGP 9.1.1 y desugaring de bibliotecas.
- Opcional para escritorio: Visual Studio completo solo si se compila Windows.

## Ejecutar y compilar

```powershell
flutter pub get
flutter run
```

Comprobaciones de calidad:

```powershell
dart format .
flutter analyze
flutter test
flutter build apk --debug
```

El APK queda en `build/app/outputs/flutter-apk/app-debug.apk`. Es una compilación
de depuración firmada con la clave de depuración; para distribuir en tiendas hace
falta configurar una firma de release y cambiar el `applicationId` de ejemplo
(`com.example.alerta_sismica`).

## Estructura

```text
lib/
  main.dart                 Arranque, MultiProvider y compuerta de autenticación
  theme.dart                Tema claro/oscuro, colores de magnitud y estilos
  core/
    errors/                 Excepciones de aplicación
    navigation/             navigatorKey global
    utils/                  Validadores y formatos de fecha/duración
  models/                   Sismo, contacto, emergencia, usuario y configuración
  repositories/             Persistencia local (SharedPreferences) y USGS
  services/                 Red, ubicación, geocodificación, canales, notificaciones
  providers/                Estado de la app con ChangeNotifier
  screens/                  Pantallas de autenticación, inicio, mapa, SOS, etc.
  widgets/                  Componentes reutilizables
test/                       Pruebas unitarias de modelos y utilidades
docs/                       Manual de uso y documentación de seguridad
INFORME_FINAL.md            Informe técnico de entrega (secciones A–H)
```

## Arquitectura resumida

`main.dart` crea repositorios y servicios una sola vez, los inyecta en los
`ChangeNotifierProvider` y arranca las cargas iniciales. Las pantallas consumen
estado con `provider`; nunca acceden directamente a `SharedPreferences` ni a las
APIs de plataforma. Los repositorios concentran la persistencia y los servicios
las integraciones externas.

Flujo de datos principal:

1. USGS devuelve GeoJSON; `SismosRepository` valida y transforma cada evento.
2. Si la red falla, se usa la caché local y se marca el estado como
   desactualizado.
3. `SismosProvider` aplica el filtro de magnitud y notifica sismos nuevos.
4. Las pantallas de inicio, mapa y lista comparten la misma fuente de eventos.

Una emergencia se persiste antes de intentar cualquier envío. Los cambios de
estado se guardan en el historial, de modo que una entrega nunca se presenta como
confirmada.

## Datos y servicios externos

- Sismos: USGS Earthquake Hazards Program, feed `all_day.geojson`.
- Mapa base: mosaicos de OpenStreetMap.
- Geocodificación inversa del SOS: Nominatim (OpenStreetMap), con límite de una
  solicitud por segundo.
- Comprobación de Internet: `https://www.gstatic.com/generate_204`.
- Comprobación del servicio sísmico: feed horario de USGS.
- Avisos: app de SMS del sistema, WhatsApp/`wa.me`, selector de compartir,
  Google Maps y marcador telefónico.

No hay servidores propios, analítica ni publicidad.

## Documentación

- [Manual de uso](docs/MANUAL_DE_USO.md)
- [Seguridad y privacidad](docs/SEGURIDAD_Y_PRIVACIDAD.md)
- [Informe final A–H](INFORME_FINAL.md)

## Limitaciones conocidas y pendientes externos

- Firma de release, cambio de `applicationId`, revisión legal y publicación en
  tiendas.
- Notificaciones push remotas: requieren un servicio externo (por ejemplo,
  Firebase Cloud Messaging) y un backend; no están implementadas.
- La cuenta local no sustituye una autenticación de servidor. Las credenciales se
  guardan en `SharedPreferences`, que no está cifrado en reposo.
- El APK de depuración pesa aproximadamente 160 MiB porque incluye todas las
  arquitecturas y símbolos de depuración.
- Sin Internet, los sismos guardados siguen disponibles, pero los mosaicos del
  mapa pueden no cargar si no están en caché.
- La app no sustituye a los servicios de emergencia ni a los sistemas oficiales
  de alerta.

## Licencias de terceros

La app incluye una pantalla de licencias (`showLicensePage`) con los textos de
los paquetes utilizados. Los datos sísmicos pertenecen a USGS y los mosaicos y la
geocodificación a OpenStreetMap y sus colaboradores; respeta sus condiciones de
uso.
