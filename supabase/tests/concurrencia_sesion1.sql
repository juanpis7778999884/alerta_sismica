
\set ON_ERROR_STOP on

-- ============================================================
-- CONCURRENCIA_SOS_01.SQL
-- Primera sesion: registra un SOS y mantiene abierta
-- la transaccion para permitir una prueba desde otra sesion.
--
-- Ejecutar en una base de datos de pruebas.
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
  'sos-conc-1',
  '11111111-1111-4111-8111-111111111111',
  'sos',
  'Usuario A',
  '2026-03-01 00:00:00+00'::timestamptz,
  'Dispositivo 1',
  '2026-03-01 00:00:00+00'::timestamptz
);

\echo 'SOS de la primera sesion insertado.'
\echo 'Ahora ejecuta el INSERT de la segunda sesion.'
\echo 'La primera transaccion permanecera abierta durante 15 segundos.'

select pg_catalog.pg_sleep(15);

commit;

\echo 'Primera transaccion finalizada.'
