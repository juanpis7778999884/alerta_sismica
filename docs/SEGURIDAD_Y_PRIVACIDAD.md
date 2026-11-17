# Seguridad y privacidad

## 1. Modelo de privacidad

Alerta Sísmica es una aplicación local. No tiene backend propio, analítica,
publicidad ni sincronización en la nube. La cuenta, los contactos, la
configuración, la emergencia activa y el historial se guardan en el
almacenamiento privado de la app en el dispositivo.

Datos almacenados:

| Dato | Ubicación | Contenido |
| --- | --- | --- |
| Cuenta | `SharedPreferences` (`auth_cuenta_v1`) | Usuario, sal y hash PBKDF2 de contraseña y código de recuperación, iteraciones |
| Sesión | `SharedPreferences` (`auth_sesion_v1`) | ID de usuario, token aleatorio y fecha de expiración |
| Contactos | `SharedPreferences` | Nombre, teléfono, prioridad y fecha de creación |
| Emergencia e historial | `SharedPreferences` | Mensaje, fechas, coordenadas, dirección aproximada y estados de envío |
| Configuración | `SharedPreferences` | Tema, filtros, notificaciones, umbral y número de emergencia |
| Caché de sismos | `SharedPreferences` | Eventos de USGS y fecha de actualización |

`SharedPreferences` no está cifrado en reposo. Un dispositivo con root, un backup
del sistema o acceso físico al almacenamiento podría leer estos datos. Para un
entorno de producción se recomienda migrar credenciales y datos sensibles a
`flutter_secure_storage` o al Keystore/Keychain del sistema.

## 2. Autenticación local

- La contraseña no se guarda en texto plano. Se deriva con
  **PBKDF2-HMAC-SHA256**, 60 000 iteraciones y una sal aleatoria de 16 bytes
  generada con `Random.secure()`.
- El código de recuperación también se guarda como hash PBKDF2 con su propia sal.
- La comparación de hashes es de tiempo constante para reducir filtraciones por
  temporización.
- El código de recuperación se muestra una sola vez al registrarse o al
  restablecer la contraseña. Al recuperar se genera uno nuevo y el anterior deja
  de ser válido.
- La sesión dura 30 días y se invalida al cerrar sesión, recuperar la contraseña
  o eliminar la cuenta. El token de sesión es aleatorio y no se usa contra ningún
  servidor.
- Los errores de inicio de sesión no distinguen si el fallo fue el correo o la
  contraseña.

Limitaciones:

- No hay límite de intentos ni bloqueo tras varios fallos. En un entorno real
  conviene añadir retrasos progresivos y bloqueo local.
- La cuenta local no ofrece las garantías de una autenticación remota: quien
  controle el almacenamiento del dispositivo puede alterar o borrar la cuenta.
- No hay verificación de correo ni recuperación remota. Si se pierde el código y
  la contraseña, no es posible recuperar la cuenta.

## 3. Ubicación

- Se solicita ubicación precisa (`ACCESS_FINE_LOCATION`) y aproximada
  (`ACCESS_COARSE_LOCATION`) solo cuando el usuario usa el mapa o activa un SOS.
- Si el GPS falla o el permiso no está disponible, se intenta la última ubicación
  conocida del sistema.
- La dirección aproximada se obtiene con Nominatim (OpenStreetMap) enviando las
  coordenadas por HTTPS. Esta es una comunicación con un tercero y debe tenerse en
  cuenta al activar un SOS.
- La app no envía la ubicación a servidores propios. Las coordenadas se incluyen
  en el mensaje que el usuario decide compartir por SMS, WhatsApp, el selector del
  sistema o el mapa.
- No se solicita ubicación en segundo plano.

## 4. Permisos de Android

| Permiso | Uso |
| --- | --- |
| `INTERNET` | USGS, mosaicos de OpenStreetMap, Nominatim y comprobaciones de red |
| `ACCESS_NETWORK_STATE` | Diagnóstico de conectividad |
| `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION` | Mapa y mensaje SOS |
| `POST_NOTIFICATIONS` | Notificaciones locales (Android 13+) |
| `VIBRATE` | Avisos locales |

La app no solicita `SEND_SMS`, `CALL_PHONE` ni permisos de contactos. Los SMS y
las llamadas se abren mediante intents en la app externa y requieren confirmación
del usuario. El acceso a contactos del sistema no está implementado.

## 5. Comunicaciones externas

| Destino | Datos enviados | Finalidad |
| --- | --- | --- |
| USGS | Ninguno del usuario; solo la solicitud GET del feed | Obtener sismos |
| OpenStreetMap | Solicitudes de mosaicos y coordenadas del área visible | Mapa base |
| Nominatim | Latitud y longitud | Dirección aproximada del SOS |
| gstatic (`generate_204`) | Ninguno | Comprobar Internet real |
| WhatsApp / `wa.me` | Teléfono y mensaje preparados | Abrir aviso SOS |
| Google Maps | Coordenadas | Abrir ubicación |
| Selector de compartir | Mensaje preparado | Compartir aviso |

Todas las integraciones usan HTTPS. No hay certificados fijados (pinning), por lo
que la seguridad depende de la cadena de confianza del sistema operativo.

## 6. Honestidad de los estados de envío

La app distingue entre:

- Canal abierto: se lanzó correctamente la app externa o el selector.
- Cancelado: el usuario cerró el selector sin compartir.
- Fallido o no disponible: no se pudo abrir el canal.

Ningún estado implica entrega confirmada. Esta decisión evita prometer una
garantía que la app no puede verificar. El historial conserva el último estado
conocido de cada contacto.

## 7. Notificaciones

- Son notificaciones locales programadas por la app mediante
  `flutter_local_notifications`.
- No hay tokens push, servidores de notificaciones ni recepción con la app
  cerrada.
- Para alertas remotas haría falta un backend y un servicio como Firebase Cloud
  Messaging, además de consentimiento y tratamiento de datos.

## 8. Borrado de datos

- "Cerrar sesión" elimina solo la sesión guardada.
- "Restablecer preferencias" vuelve a los valores iniciales de tema, filtros y
  notificaciones.
- "Borrar caché de sismos" elimina los eventos guardados.
- "Borrar todos los datos locales" elimina cuenta, contactos, emergencia activa,
  historial, caché y preferencias. La app vuelve al registro inicial.

El borrado se realiza en el almacenamiento de la app. No se puede garantizar el
borrado de copias de seguridad del sistema, registros del operador o mensajes ya
enviados a terceros.

## 9. Riesgos y recomendaciones

1. Migrar secretos a almacenamiento cifrado y valorar el bloqueo biométrico.
2. Configurar firma de release y cambiar `com.example.alerta_sismica` por un
   identificador propio.
3. Añadir límite de intentos y bloqueo local.
4. Revisar las políticas de uso de Nominatim o usar un servicio de geocodificación
   con SLA y acuerdo de tratamiento de datos.
5. Evaluar el pinning de certificados si se añade un backend propio.
6. Redactar una política de privacidad y revisar el cumplimiento legal antes de
   publicar.
7. Probar en dispositivos reales los flujos de permisos, SMS, WhatsApp, mapas y
   notificaciones, incluidos escenarios sin conexión.

## 10. Reporte de problemas

No se incluyen credenciales reales, claves API ni datos personales en el
repositorio. Si agregas integraciones futuras, mantén las claves fuera del código
y usa variables de entorno o almacenamiento seguro.
