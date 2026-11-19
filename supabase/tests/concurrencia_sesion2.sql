
\set ON_ERROR_STOP on

-- ============================================================
-- CONCURRENCIA_SOS_02.SQL
-- Segunda sesion: intenta registrar otro SOS para el mismo
-- usuario mientras la primera transaccion sigue abierta.
--
-- Ejecutar en una SEGUNDA sesion de PostgreSQL mientras
-- concurrencia_sos_01.sql permanece en espera.
-- ============================================================

begin;

set local request.jwt.claim.sub =
  '11111111-1111-4111-8111-111111111111';

set local role authenticated;

insert into public.emergency_events (
  id,
  user_id,
  tipo,
  usuario_nombre,
  inicio,
  mensaje,
  cliente_actualizado_en
)
values (
  'sos-conc-2',
  '11111111-1111-4111-8111-111111111111',
  'sos',
  'Usuario A',
  '2026-03-01 00:01:00+00'::timestamptz,
  'Dispositivo 2',
  '2026-03-01 00:01:00+00'::timestamptz
);

commit;

\echo 'Segundo SOS insertado. Verifica el resultado desde una sesion administrativa.'

-- Comprobacion posterior desde una sesion con permisos administrativos:
-- Debe existir exactamente un SOS activo para el usuario.
--
-- Ejecutar esta consulta DESPUES de terminar ambas sesiones.

select
  user_id,
  count(*) filter (
    where tipo = 'sos'
      and activa = true
      and eliminado_en is null
  ) as sos_activos
from public.emergency_events
where user_id = '11111111-1111-4111-8111-111111111111'
group by user_id;
