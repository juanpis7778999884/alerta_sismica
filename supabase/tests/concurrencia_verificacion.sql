
\set ON_ERROR_STOP on

-- ============================================================
-- CONCURRENCIA_SOS_VALIDACION.SQL
-- Validacion de la prueba de concurrencia SOS.
--
-- Ejecutar despues de finalizar las dos sesiones:
--   1. concurrencia_sos_01.sql
--   2. concurrencia_sos_02.sql
--
-- Ejecutar con un rol administrativo.
-- ============================================================


-- ============================================================
-- 00. FUNCION DE ASERCION
-- ============================================================

create schema if not exists pruebas;

create or replace function pruebas.assert(
  p_condicion boolean,
  p_mensaje text
)
returns void
language plpgsql
as $$
begin
  if p_condicion is not true then
    raise exception 'FALLIDO: %', p_mensaje;
  end if;
end;
$$;


-- ============================================================
-- TEST 01: CONSERVACION DE AMBOS EVENTOS
-- ============================================================

\echo 'CONCURRENCIA 01 - ambos eventos deben conservarse'

select pruebas.assert(
  (
    select count(*) = 2
    from public.emergency_events
    where id in ('sos-conc-1', 'sos-conc-2')
      and user_id = '11111111-1111-4111-8111-111111111111'
      and tipo = 'sos'
  ),
  'deben conservarse los dos eventos SOS del mismo usuario'
);


-- ============================================================
-- TEST 02: EL EVENTO CON MARCA MAYOR DEBE QUEDAR ACTIVO
-- ============================================================

\echo 'CONCURRENCIA 02 - evento ganador'

select pruebas.assert(
  (
    select activa
       and motivo_fin is null
       and fin is null
       and eliminado_en is null
    from public.emergency_events
    where id = 'sos-conc-2'
      and user_id = '11111111-1111-4111-8111-111111111111'
  ),
  'el evento con cliente_actualizado_en mayor debe quedar activo'
);


-- ============================================================
-- TEST 03: EL EVENTO CON MARCA MENOR DEBE CERRARSE
-- ============================================================

\echo 'CONCURRENCIA 03 - evento desplazado'

select pruebas.assert(
  (
    select not activa
       and motivo_fin = 'conflicto_multidispositivo'
       and fin is not null
       and eliminado_en is null
    from public.emergency_events
    where id = 'sos-conc-1'
      and user_id = '11111111-1111-4111-8111-111111111111'
  ),
  'el evento con marca menor debe cerrarse por conflicto multidispositivo'
);


-- ============================================================
-- TEST 04: ORDEN CRONOLOGICO DE LAS MARCAS
-- ============================================================

\echo 'CONCURRENCIA 04 - marcas de sincronizacion'

select pruebas.assert(
  (
    select e2.cliente_actualizado_en > e1.cliente_actualizado_en
    from public.emergency_events e1
    cross join public.emergency_events e2
    where e1.id = 'sos-conc-1'
      and e2.id = 'sos-conc-2'
      and e1.user_id = e2.user_id
  ),
  'el segundo evento debe tener una marca de sincronizacion mayor'
);


-- ============================================================
-- TEST 05: EXACTAMENTE UN SOS ACTIVO
-- ============================================================

\echo 'CONCURRENCIA 05 - unico SOS activo'

select pruebas.assert(
  (
    select count(*) = 1
    from public.emergency_events
    where user_id = '11111111-1111-4111-8111-111111111111'
      and tipo = 'sos'
      and activa = true
      and eliminado_en is null
  ),
  'debe existir exactamente un SOS activo para el usuario'
);


-- ============================================================
-- TEST 06: EL EVENTO CERRADO NO DEBE REACTIVARSE
-- ============================================================

\echo 'CONCURRENCIA 06 - estado terminal'

do $$
begin

  if exists (
    select 1
    from public.emergency_events
    where id = 'sos-conc-1'
      and activa = true
  ) then
    raise exception
      'FALLIDO: el evento desplazado no debe volver a estar activo';
  end if;

end;
$$;


-- ============================================================
-- RESULTADO
-- ============================================================

\echo 'OK - todas las pruebas de concurrencia finalizaron correctamente'
\echo 'CONCURRENCIA SOS VALIDADA'
