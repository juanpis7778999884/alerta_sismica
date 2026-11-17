# Manual de uso

Este manual describe el flujo completo de Alerta Sísmica. La app está pensada
para consultar sismos y preparar un aviso de emergencia; no reemplaza a los
servicios oficiales ni confirma la entrega de mensajes.

## 1. Primer inicio y cuenta local

1. Abre la app. Si no existe una cuenta en el dispositivo verás el formulario de
   registro.
2. Escribe tu nombre, correo y una contraseña de al menos 8 caracteres con letras
   y números.
3. Decide si quieres recordar la sesión durante 30 días.
4. Al crear la cuenta se muestra un código de recuperación con formato
   `XXXX-XXXX-XXXX`. Anótalo y guárdalo en un lugar seguro: se muestra una sola
   vez.
5. Si cierras la app y no marcaste "recordar sesión", vuelve a entrar con tu
   correo y contraseña.

La cuenta es local. No se envía a ningún servidor y no se puede recuperar desde
otro dispositivo.

### Recuperar la contraseña

1. En la pantalla de inicio de sesión elige "Olvidé mi contraseña".
2. Escribe tu correo, el código de recuperación y la nueva contraseña.
3. Al confirmar se genera un código de recuperación nuevo. El anterior deja de
   ser válido y la sesión guardada se cierra.

### Cerrar sesión o eliminar la cuenta

- "Cerrar sesión" en el menú lateral solo elimina la sesión guardada. Tus
  contactos, historial y preferencias permanecen.
- "Borrar todos los datos locales" en Configuración elimina cuenta, contactos,
  emergencia activa, historial, caché de sismos y preferencias. Es irreversible.

## 2. Pantalla de inicio

Muestra un saludo, la fecha actual y el estado de la conexión. Incluye:

- Aviso cuando no hay Internet confirmado, con acceso al diagnóstico.
- Tarjeta de emergencia activa, si existe, con cronómetro y acceso directo.
- Botón para activar el SOS o ir a la pestaña SOS.
- Último sismo visible dentro del filtro de magnitud y su distancia aproximada.
- Tarjetas con el número de sismos de las últimas 24 horas, la mayor magnitud y
  la cantidad de contactos.
- Accesos rápidos a mapa, lista, contactos e historial.

Desliza hacia abajo para actualizar sismos y conectividad.

## 3. Contactos de emergencia

Abre el menú lateral o el acceso rápido "Contactos".

- Agrega un contacto con nombre y teléfono. Se aceptan espacios, guiones y
  prefijos internacionales; se guardan al menos 7 y como máximo 15 dígitos.
- El primer contacto queda como prioritario automáticamente. Siempre debe existir
  al menos uno prioritario.
- Puedes marcar o desmarcar la prioridad con el interruptor de cada contacto.
- Para editar o eliminar, usa el menú de cada fila. Si eliminas el último
  prioritario, otro contacto pasa a serlo automáticamente.
- No se permiten teléfonos duplicados.

Los contactos se guardan solo en este dispositivo.

## 4. Sismos, filtros y mapa

### Lista de sismos

La pestaña "Sismos" muestra los eventos de las últimas 24 horas que superan la
magnitud mínima configurada. Puedes:

- Buscar por lugar o magnitud.
- Ordenar por recientes, magnitud o cercanía.
- Abrir el detalle de cada evento.
- Deslizar hacia abajo para actualizar.

El detalle incluye magnitud, hora, profundidad, coordenadas, enlace al evento de
USGS y acceso al mapa.

### Mapa

La pestaña "Mapa" dibuja hasta 300 eventos visibles sobre OpenStreetMap.

- Toca un marcador para abrir el detalle.
- Usa los botones para acercar, alejar o centrar en tu ubicación.
- "Solo cercanos" filtra eventos a menos de 750 km de tu posición.
- La leyenda explica los colores por magnitud.
- El botón de actualizar consulta USGS de nuevo.

Sin Internet, los marcadores guardados pueden seguir visibles, pero los mosaicos
del mapa pueden aparecer en blanco.

## 5. Notificaciones locales

En Configuración puedes:

- Activar o desactivar los avisos de sismos nuevos.
- Ajustar el umbral de magnitud a partir del cual se notifica.
- Enviar una notificación de prueba.
- Abrir los ajustes de notificaciones del sistema.

Las notificaciones son locales. No se reciben alertas remotas ni con la app
cerrada. Los sismos simulados no generan notificaciones.

## 6. Emergencia SOS

La pestaña SOS ofrece dos estados.

### Sin emergencia activa

1. Pulsa "Activar SOS".
2. La app intenta obtener tu ubicación (GPS o última conocida) y una dirección
   aproximada. Si no puede, la emergencia se activa sin ubicación.
3. La emergencia queda guardada en el dispositivo antes de cualquier envío.
4. La app intenta preparar el aviso para los contactos prioritarios. Si no hay
   contactos, muestra una advertencia y no envía nada.

También se puede iniciar una emergencia relacionada con un sismo desde la
pantalla de alerta sísmica.

### Emergencia activa

La pantalla muestra el tiempo transcurrido, la ubicación, el mensaje generado y
la lista de contactos con su estado. Acciones disponibles:

- **Enviar SMS a todos**: abre la app de mensajes con los números y el texto
  preparado.
- **Compartir**: abre el selector del sistema para elegir una app o contacto.
- **Enviar por WhatsApp**: abre WhatsApp con el mensaje para un contacto
  concreto.
- **SMS individual**: abre la app de mensajes para ese contacto.
- **Abrir mapa**: abre las coordenadas en una app de mapas.
- **Llamar a emergencias**: abre el marcador con el número configurado. La
  llamada no es automática.
- **Finalizar**: cierra la emergencia y la guarda en el historial.

Estados de cada aviso:

- **Pendiente**: todavía no se intentó.
- **Canal abierto (entrega sin confirmar)**: se abrió el SMS, WhatsApp o el
  selector, pero no se puede verificar que el mensaje haya llegado.
- **Cancelado por el usuario**: se cerró el selector sin compartir.
- **Fallido**: el canal no pudo abrirse.
- **No disponible**: no hay app o número válido para ese canal.

La app no afirma que un mensaje haya sido entregado en ningún momento.

### Finalizar una emergencia

Pulsa "Finalizar" y confirma. La emergencia deja de estar activa, se guarda en el
historial con su hora de fin y el aviso persistente desaparece.

## 7. Historial SOS

El historial guarda hasta 50 emergencias finalizadas, ordenadas de la más reciente
a la más antigua. Cada entrada muestra tipo, fecha, duración, cantidad de
contactos y si tiene ubicación. Al abrirla puedes ver el mensaje completo, las
coordenadas y el estado final de cada envío.

- Desliza hacia abajo para recargar.
- Usa el icono de papelera para borrar todo el historial.
- Una emergencia activa no aparece en el historial hasta que la finalices.

## 8. Configuración

- **Tema**: claro, oscuro o según el sistema.
- **Magnitud mínima**: filtra lista, mapa y conteos. No cambia el umbral de
  notificaciones.
- **Actualización automática**: consulta USGS cada 2 minutos mientras la app está
  abierta y al volver a primer plano.
- **Notificaciones**: permiso, avisos de sismos nuevos, umbral y prueba.
- **Número de emergencia**: opcional; solo se usa para abrir el marcador.
- **Datos y privacidad**: restablecer preferencias, borrar caché de sismos,
  consultar "Acerca de" y borrar todos los datos locales.

## 9. Conectividad y permisos

La pantalla "Conectividad y permisos" muestra:

- Tipo de interfaz de red, acceso real a Internet y respuesta de USGS.
- Si el sistema reporta red satelital.
- Hora de la última verificación y de la última conexión confirmada.
- Permiso y estado del GPS, ubicación actual, precisión y origen.
- Disponibilidad de SMS, WhatsApp y marcador telefónico.
- Estado del permiso de notificaciones.

Los botones permiten actualizar la ubicación, abrir los ajustes de la app o del
GPS, solicitar el permiso de notificaciones y enviar una prueba.

## 10. Recomendaciones de uso

- Configura al menos un contacto prioritario y prueba el flujo de SMS antes de
  necesitarlo.
- Mantén el número de emergencia local actualizado.
- Activa las notificaciones solo si aceptas que son locales y no sustituyen una
  alerta oficial.
- Revisa el estado de cada contacto después de un SOS: la app no confirma la
  entrega.
- Ante una emergencia real, sigue las instrucciones de las autoridades y usa los
  números oficiales de tu país.

## 11. Solución de problemas

- **No aparece mi ubicación**: revisa el permiso de ubicación y que el GPS esté
  activo en la pantalla de conectividad. Sin GPS se usa la última ubicación
  conocida o se guarda la emergencia sin coordenadas.
- **No se abren SMS o WhatsApp**: el dispositivo puede no tener una app
  compatible. Usa "Compartir" como alternativa.
- **No hay sismos**: revisa la conexión, el filtro de magnitud y pulsa
  actualizar. Sin Internet se muestra la última caché.
- **El mapa está en blanco**: los mosaicos de OpenStreetMap requieren conexión o
  caché del navegador; los marcadores pueden seguir visibles.
- **No llegan notificaciones**: verifica el permiso en el sistema y que la app no
  esté restringida en segundo plano. Las notificaciones son locales.
- **Olvidé el código de recuperación**: no hay recuperación remota. Si no puedes
  iniciar sesión, la única opción es borrar los datos locales desde el sistema y
  crear una cuenta nueva.
- **La app no está disponible en mi idioma**: la interfaz está en español y la
  localización está fijada a `es`.
