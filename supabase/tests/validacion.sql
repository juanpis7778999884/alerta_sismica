
\set ON_ERROR_STOP on

-- ============================================================
-- VALIDACION INTEGRAL DE MIGRACIONES SUPABASE
-- Alerta Sísmica
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


create or replace function pruebas.expect_error(
  p_sql text,
  p_estado text,
  p_mensaje text
)
returns void
language plpgsql
as $$
declare
  v_estado text;
begin
  begin
    execute p_sql;
  exception when others then
    get stacked diagnostics v_estado = returned_sqlstate;

    if v_estado = p_estado then
      return;
    end if;

    raise exception
      'FALLIDO: % (SQLSTATE %, esperado %)',
      p_mensaje,
      v_estado,
      p_estado;
  end;

  raise exception
    'FALLIDO: % no produjo error',
    p_mensaje;
end;
$$;


create or replace function pruebas.reset_vacio()
returns void
language plpgsql
set search_path = ''
as $$
begin
  truncate public.emergency_event_deliveries,
           public.emergency_events,
           public.emergency_contacts,
           public.saved_earthquakes,
           public.user_settings,
           public.profiles
    restart identity;
end;
$$;


create or replace function pruebas.reset()
returns void
language plpgsql
set search_path = ''
as $$
begin
  perform pruebas.reset_vacio();

  perform pg_catalog.set_config(
    'request.jwt.claim.sub',
    '11111111-1111-4111-8111-111111111111',
    true
  );

  insert into public.profiles (id, nombre, email)
  values (
    '11111111-1111-4111-8111-111111111111',
    'Usuario A',
    'usuario-a@example.test'
  );

  perform pg_catalog.set_config(
    'request.jwt.claim.sub',
    '22222222-2222-4222-8222-222222222222',
    true
  );

  insert into public.profiles (id, nombre, email)
  values (
    '22222222-2222-4222-8222-222222222222',
    'Usuario B',
    'usuario-b@example.test'
  );

  perform pg_catalog.set_config(
    'request.jwt.claim.sub',
    '',
    true
  );
end;
$$;


grant usage on schema pruebas to authenticated, anon;

grant execute on function pruebas.assert(boolean, text)
  to authenticated, anon;

grant execute on function pruebas.expect_error(text, text, text)
  to authenticated, anon;


-- ============================================================
-- TEST 01: ESTRUCTURA GENERAL
-- ============================================================

\echo 'TEST 01 estructura general'

select pruebas.assert(
  (
    select count(*) = 6
    from information_schema.tables
    where table_schema = 'public'
      and table_name = any(array[
        'profiles',
        'user_settings',
        'emergency_contacts',
        'emergency_events',
        'emergency_event_deliveries',
        'saved_earthquakes'
      ])
  ),
  'deben existir las seis tablas'
);

select pruebas.assert(
  (
    select count(*) = 10
    from pg_catalog.pg_proc p
    join pg_catalog.pg_namespace n
      on n.oid = p.pronamespace
    where n.nspname = 'public'
      and p.proname = any(array[
        'touch_actualizado_en',
        'set_server_timestamps',
        'set_sync_timestamps',
        'apply_logical_delete',
        'enforce_immutable_columns',
        'profiles_enforce_auth_identity',
        'auth_users_sync_profile_email',
        'enforce_sos_terminal_state',
        'set_sos_manual_close',
        'resolve_active_sos_conflict'
      ])
  ),
  'deben existir las diez funciones de auditoria'
);

\echo OK


-- ============================================================
-- TEST 02: OBJETOS Y TRIGGERS SIN DUPLICADOS
-- ============================================================

\echo 'TEST 02 unicidad de objetos'

select pruebas.assert(
  (
    select count(*) = 1
    from pg_catalog.pg_index
    where indrelid = 'public.saved_earthquakes'::regclass
      and indexrelid::regclass::text =
          'saved_earthquakes_user_sismo_activo_key'
  ),
  'indice de re-guardado debe existir una sola vez'
);

select pruebas.assert(
  (
    select count(*) = 1
    from pg_catalog.pg_trigger
    where tgrelid = 'public.emergency_events'::regclass
      and tgname = 'emergency_events_05_resolve_active_conflict'
      and not tgisinternal
  ),
  'trigger de conflicto SOS debe existir una sola vez'
);

select pruebas.assert(
  (
    select count(*) = 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.saved_earthquakes'::regclass
      and contype = 'p'
      and conkey = array[
        (
          select attnum
          from pg_catalog.pg_attribute
          where attrelid = 'public.saved_earthquakes'::regclass
            and attname = 'guardado_id'
        )
      ]::smallint[]
  ),
  'guardado_id debe ser la clave primaria'
);

\echo OK


-- ============================================================
-- TEST 03: CREACION DE PERFIL PROPIO
-- ============================================================

\echo 'TEST 03 creacion de perfil propio'

select pruebas.reset_vacio();

begin;

set local request.jwt.claim.sub =
  '11111111-1111-4111-8111-111111111111';

set local role authenticated;

insert into public.profiles (id, nombre, email)
values (
  '11111111-1111-4111-8111-111111111111',
  'Usuario A',
  'falso@example.test'
);

do $$
begin
  perform pruebas.assert(
    (
      select email = 'usuario-a@example.test'
      from public.profiles
      where id = '11111111-1111-4111-8111-111111111111'
    ),
    'el correo debe provenir de auth.users'
  );
end;
$$;

commit;

\echo OK


-- ============================================================
-- TEST 04: RECHAZO DE PERFIL AJENO
-- ============================================================

\echo 'TEST 04 rechazo de perfil ajeno'

select pruebas.reset();

begin;

set local request.jwt.claim.sub =
  '11111111-1111-4111-8111-111111111111';

set local role authenticated;

select pruebas.expect_error(
  $sql$
    insert into public.profiles (id, nombre, email)
    values (
      '22222222-2222-4222-8222-222222222222',
      'Invasor',
      'invasor@example.test'
    )
  $sql$,
  '42501',
  'un usuario no debe crear perfiles ajenos'
);

commit;

\echo OK


-- ============================================================
-- TEST 05: PROTECCION Y SINCRONIZACION DEL CORREO
-- ============================================================

\echo 'TEST 05 correo de Supabase Auth'

select pruebas.reset();

begin;

set local request.jwt.claim.sub =
  '11111111-1111-4111-8111-111111111111';

set local role authenticated;

select pruebas.expect_error(
  $sql$
    update public.profiles
       set email = 'falso@example.test'
     where id = '11111111-1111-4111-8111-111111111111'
  $sql$,
  '42501',
  'el cliente no debe cambiar el correo'
);

-- Intento de falsificar la señal interna de sincronización.
select pg_catalog.set_config(
  'app.internal_profile_email_sync',
  'on',
  true
);

select pruebas.expect_error(
  $sql$
    update public.profiles
       set email = 'falso@example.test'
     where id = '11111111-1111-4111-8111-111111111111'
  $sql$,
  '42501',
  'la variable interna no debe permitir falsificar el correo'
);

select pg_catalog.set_config(
  'app.internal_profile_email_sync',
  '',
  true
);

commit;


-- Cambio legítimo desde Auth.
begin;

update auth.users
   set email = 'NUEVO@example.test'
 where id = '11111111-1111-4111-8111-111111111111';

do $$
begin
  perform pruebas.assert(
    (
      select email = 'nuevo@example.test'
      from public.profiles
      where id = '11111111-1111-4111-8111-111111111111'
    ),
    'el cambio de correo debe propagarse al perfil'
  );
end;
$$;

update auth.users
   set email = 'usuario-a@example.test'
 where id = '11111111-1111-4111-8111-111111111111';

commit;

\echo OK


-- ============================================================
-- TEST 06: COLUMNAS INMUTABLES
-- ============================================================

\echo 'TEST 06 columnas inmutables'

select pruebas.reset();

begin;

set local request.jwt.claim.sub =
  '11111111-1111-4111-8111-111111111111';

set local role authenticated;

insert into public.emergency_contacts (
  id,
  user_id,
  nombre,
  telefono
)
values (
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  '11111111-1111-4111-8111-111111111111',
  'Contacto A',
  '3001234567'
);

insert into public.emergency_events (
  id,
  user_id,
  tipo,
  usuario_nombre,
  inicio,
  mensaje
)
values (
  'evt-inmutable',
  '11111111-1111-4111-8111-111111111111',
  'sos',
  'Usuario A',
  now(),
  'SOS'
);

insert into public.emergency_event_deliveries (
  event_id,
  contacto_id,
  nombre,
  telefono,
  estado
)
values (
  'evt-inmutable',
  'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa',
  'Contacto A',
  '3001234567',
  'pendiente'
);

insert into public.saved_earthquakes (
  user_id,
  sismo_id,
  magnitud,
  lugar,
  latitud,
  longitud,
  profundidad,
  tiempo
)
values (
  '11111111-1111-4111-8111-111111111111',
  'sismo-inmutable',
  4.2,
  'Bogota',
  4.6,
  -74.0,
  12,
  now()
);

select pruebas.expect_error(
  $sql$
    update public.profiles
       set legacy_local_id =
           '33333333-3333-4333-8333-333333333333'
     where id = '11111111-1111-4111-8111-111111111111'
  $sql$,
  '42501',
  'legacy_local_id debe ser inmutable'
);

select pruebas.expect_error(
  $sql$
    update public.emergency_contacts
       set user_id = '22222222-2222-4222-8222-222222222222'
     where id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  $sql$,
  '42501',
  'user_id del contacto debe ser inmutable'
);

select pruebas.expect_error(
  $sql$
    update public.emergency_event_deliveries
       set event_id = 'evt-otro'
     where contacto_id = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa'
  $sql$,
  '42501',
  'event_id de la entrega debe ser inmutable'
);

select pruebas.expect_error(
  $sql$
    update public.saved_earthquakes
       set sismo_id = 'otro-sismo'
     where sismo_id = 'sismo-inmutable'
  $sql$,
  '42501',
  'sismo_id debe ser inmutable'
);

commit;

\echo OK


-- ============================================================
-- TEST 07: AISLAMIENTO RLS
-- ============================================================

\echo 'TEST 07 aislamiento RLS'

select pruebas.reset();

begin;

set local request.jwt.claim.sub =
  '11111111-1111-4111-8111-111111111111';

set local role authenticated;

insert into public.emergency_contacts (
  id,
  user_id,
  nombre,
  telefono
)
values (
  'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb',
  '11111111-1111-4111-8111-111111111111',
  'Contacto A',
  '3111111111'
);

do $$
begin
  perform pruebas.assert(
    (
      select count(*) = 0
      from public.emergency_contacts
      where user_id = '22222222-2222-4222-8222-222222222222'
    ),
    'el usuario A no debe ver contactos del usuario B'
  );
end;
$$;

commit;


begin;

set local request.jwt.claim.sub =
  '22222222-2222-4222-8222-222222222222';

set local role authenticated;

insert into public.emergency_contacts (
  id,
  user_id,
  nombre,
  telefono
)
values (
  'cccccccc-cccc-4ccc-8ccc-cccccccccccc',
  '22222222-2222-4222-8222-222222222222',
  'Contacto B',
  '3222222222'
);

do $$
begin
  perform pruebas.assert(
    (
      select count(*) = 0
      from public.emergency_contacts
      where user_id = '11111111-1111-4111-8111-111111111111'
    ),
    'el usuario B no debe ver contactos del usuario A'
  );
end;
$$;

commit;

\echo OK


-- ============================================================
-- TEST 08: RECHAZO DE DELETE
-- ============================================================

\echo 'TEST 08 rechazo de DELETE'

select pruebas.reset();

begin;

set local request.jwt.claim.sub =
  '11111111-1111-4111-8111-111111111111';

set local role authenticated;

select pruebas.expect_error(
  $sql$delete from public.profiles where id = '11111111-1111-4111-8111-111111111111'$sql$,
  '42501',
  'DELETE profiles debe fallar'
);

select pruebas.expect_error(
  $sql$delete from public.user_settings where user_id = '11111111-1111-4111-8111-111111111111'$sql$,
  '42501',
  'DELETE user_settings debe fallar'
);

select pruebas.expect_error(
  $sql$delete from public.emergency_contacts where user_id = '11111111-1111-4111-8111-111111111111'$sql$,
  '42501',
  'DELETE contacts debe fallar'
);

select pruebas.expect_error(
  $sql$delete from public.emergency_events where user_id = '11111111-1111-4111-8111-111111111111'$sql$,
  '42501',
  'DELETE events debe fallar'
);

select pruebas.expect_error(
  $sql$delete from public.emergency_event_deliveries where contacto_id = 'x'$sql$,
  '42501',
  'DELETE deliveries debe fallar'
);

select pruebas.expect_error(
  $sql$delete from public.saved_earthquakes where user_id = '11111111-1111-4111-8111-111111111111'$sql$,
  '42501',
  'DELETE saved_earthquakes debe fallar'
);

commit;

\echo OK


-- ============================================================
-- TEST 09: RECHAZO DE TRUNCATE
-- ============================================================

\echo 'TEST 09 rechazo de TRUNCATE'

begin;

set local request.jwt.claim.sub =
  '11111111-1111-4111-8111-111111111111';

set local role authenticated;

select pruebas.expect_error(
  $sql$truncate table public.emergency_events$sql$,
  '42501',
  'TRUNCATE debe fallar'
);

select pruebas.expect_error(
  $sql$truncate table public.saved_earthquakes$sql$,
  '42501',
  'TRUNCATE saved debe fallar'
);

commit;

\echo OK


-- ============================================================
-- TEST 10: MODIFICACIONES PROTEGIDAS
-- ============================================================

\echo 'TEST 10 columnas protegidas'

select pruebas.reset();

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
  mensaje
)
values (
  'evt-protegido',
  '11111111-1111-4111-8111-111111111111',
  'sos',
  'Usuario A',
  now(),
  'SOS'
);

select pruebas.expect_error(
  $sql$update public.profiles set creado_en = now() where id = '11111111-1111-4111-8111-111111111111'$sql$,
  '42501',
  'creado_en debe estar protegido'
);

select pruebas.expect_error(
  $sql$update public.emergency_events set motivo_fin = 'manual' where id = 'evt-protegido'$sql$,
  '42501',
  'motivo_fin debe estar protegido'
);

select pruebas.expect_error(
  $sql$update public.saved_earthquakes set guardado_id = '44444444-4444-4444-8444-444444444444' where sismo_id = 'x'$sql$,
  '42501',
  'guardado_id debe estar protegido'
);

commit;

\echo OK


-- ============================================================
-- TEST 11: ELIMINACION LOGICA DE CONTACTOS
-- ============================================================

\echo 'TEST 11 tombstone de contactos'

select pruebas.reset();

begin;

set local request.jwt.claim.sub =
  '11111111-1111-4111-8111-111111111111';

set local role authenticated;

insert into public.emergency_contacts (
  id,
  user_id,
  nombre,
  telefono
)
values (
  'dddddddd-dddd-4ddd-8ddd-dddddddddddd',
  '11111111-1111-4111-8111-111111111111',
  'Contacto A',
  '3333333333'
);

update public.emergency_contacts
   set eliminado_en = now()
 where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';

do $$
declare
  v_primera timestamptz;
begin
  select eliminado_en
    into v_primera
    from public.emergency_contacts
   where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';

  perform pruebas.assert(
    v_primera is not null,
    'el contacto debe conservar tombstone'
  );

  update public.emergency_contacts
     set eliminado_en = '2030-01-01 00:00:00+00'::timestamptz
   where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd';

  perform pruebas.assert(
    (
      select eliminado_en = v_primera
      from public.emergency_contacts
      where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'
    ),
    'la primera fecha de eliminacion debe conservarse'
  );
end;
$$;

commit;

\echo OK


-- ============================================================
-- TEST 12: RECHAZO DE REACTIVACION DE CONTACTOS
-- ============================================================

\echo 'TEST 12 reactivacion de contactos'

begin;

set local request.jwt.claim.sub =
  '11111111-1111-4111-8111-111111111111';

set local role authenticated;

select pruebas.expect_error(
  $sql$
    update public.emergency_contacts
       set eliminado_en = null
     where id = 'dddddddd-dddd-4ddd-8ddd-dddddddddddd'
  $sql$,
  '23514',
  'un contacto eliminado no debe reactivarse'
);

commit;

\echo OK


-- ============================================================
-- TEST 13: TELEFONOS DUPLICADOS
-- ============================================================

\echo 'TEST 13 telefonos duplicados'

select pruebas.reset();

begin;

set local request.jwt.claim.sub =
  '11111111-1111-4111-8111-111111111111';

set local role authenticated;

insert into public.emergency_contacts (
  id,
  user_id,
  nombre,
  telefono
)
values (
  'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee',
  '11111111-1111-4111-8111-111111111111',
  'Contacto A',
  '3001234567'
);

select pruebas.expect_error(
  $sql$
    insert into public.emergency_contacts (
      id, user_id, nombre, telefono
    )
    values (
      'ffffffff-ffff-4fff-8fff-ffffffffffff',
      '11111111-1111-4111-8111-111111111111',
      'Contacto B',
      '(300) 123-4567'
    )
  $sql$,
  '23505',
  'telefonos activos duplicados deben fallar'
);

update public.emergency_contacts
   set eliminado_en = now()
 where id = 'eeeeeeee-eeee-4eee-8eee-eeeeeeeeeeee';

insert into public.emergency_contacts (
  id,
  user_id,
  nombre,
  telefono
)
values (
  'ffffffff-ffff-4fff-8fff-ffffffffffff',
  '11111111-1111-4111-8111-111111111111',
  'Contacto B',
  '(300) 123-4567'
);

do $$
begin
  perform pruebas.assert(
    (
      select count(*) = 1
      from public.emergency_contacts
      where user_id = '11111111-1111-4111-8111-111111111111'
        and eliminado_en is null
    ),
    'debe existir un solo contacto activo con ese telefono'
  );
end;
$$;

commit;

\echo OK


-- ============================================================
-- TEST 14: CIERRE MANUAL DE SOS
-- ============================================================

\echo 'TEST 14 cierre manual de SOS'

select pruebas.reset();

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
  mensaje
)
values (
  'evt-manual',
  '11111111-1111-4111-8111-111111111111',
  'sos',
  'Usuario A',
  now(),
  'SOS'
);

update public.emergency_events
   set activa = false,
       fin = inicio + interval '5 minutes',
       cliente_actualizado_en = now()
 where id = 'evt-manual';

do $$
begin
  perform pruebas.assert(
    (
      select
        activa = false
        and motivo_fin = 'manual'
        and fin is not null
      from public.emergency_events
      where id = 'evt-manual'
    ),
    'el cierre manual debe fijar motivo_fin=manual'
  );

  perform pruebas.assert(
    (
      select fin <= now()
      from public.emergency_events
      where id = 'evt-manual'
    ),
    'el cliente no debe poder imponer una hora de cierre futura'
  );
end;
$$;

commit;

\echo OK


-- ============================================================
-- TEST 15: ESTADO TERMINAL DE SOS
-- ============================================================

\echo 'TEST 15 estado terminal SOS'

begin;

set local request.jwt.claim.sub =
  '11111111-1111-4111-8111-111111111111';

set local role authenticated;

select pruebas.expect_error(
  $sql$update public.emergency_events set activa = true where id = 'evt-manual'$sql$,
  '23514',
  'un SOS cerrado no debe reactivarse'
);

select pruebas.expect_error(
  $sql$update public.emergency_events set fin = now() where id = 'evt-manual'$sql$,
  '23514',
  'la hora de cierre no debe modificarse'
);

commit;

\echo OK


-- ============================================================
-- TEST 16: CONFLICTO SOS MULTIDISPOSITIVO
-- ============================================================

\echo 'TEST 16 conflicto SOS multidispositivo'

select pruebas.reset();

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
  'sos-d1',
  '11111111-1111-4111-8111-111111111111',
  'sos',
  'Usuario A',
  '2026-01-01 00:00:00+00',
  'Dispositivo 1',
  '2026-01-01 00:00:00+00'
);

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
  'sos-d2',
  '11111111-1111-4111-8111-111111111111',
  'sos',
  'Usuario A',
  '2026-01-01 00:01:00+00',
  'Dispositivo 2',
  '2026-01-01 00:01:00+00'
);

do $$
begin
  perform pruebas.assert(
    (select count(*) = 2 from public.emergency_events),
    'deben conservarse ambos eventos'
  );

  perform pruebas.assert(
    (
      select activa
         and motivo_fin is null
      from public.emergency_events
      where id = 'sos-d2'
    ),
    'el evento con marca mayor debe quedar activo'
  );

  perform pruebas.assert(
    (
      select not activa
         and motivo_fin = 'conflicto_multidispositivo'
      from public.emergency_events
      where id = 'sos-d1'
    ),
    'el evento perdedor debe conservar motivo de conflicto'
  );

  perform pruebas.assert(
    (
      select count(*) = 1
      from public.emergency_events
      where user_id = '11111111-1111-4111-8111-111111111111'
        and activa
        and eliminado_en is null
    ),
    'debe existir un solo SOS activo'
  );
end;
$$;

commit;

\echo OK


-- ============================================================
-- TEST 17: CONFLICTO DETERMINISTA
-- ============================================================

\echo 'TEST 17 resolucion determinista'

select pruebas.reset();

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
  'sos-tie-a',
  '11111111-1111-4111-8111-111111111111',
  'sos',
  'Usuario A',
  '2026-02-01 00:00:00+00',
  'Empate A',
  '2026-02-01 00:00:00+00'
);

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
  'sos-tie-b',
  '11111111-1111-4111-8111-111111111111',
  'sos',
  'Usuario A',
  '2026-02-01 00:00:00+00',
  'Empate B',
  '2026-02-01 00:00:00+00'
);

do $$
begin
  perform pruebas.assert(
    (
      select activa
      from public.emergency_events
      where id = 'sos-tie-b'
    ),
    'con empate debe ganar el id mayor'
  );

  perform pruebas.assert(
    (
      select not activa
         and motivo_fin = 'conflicto_multidispositivo'
      from public.emergency_events
      where id = 'sos-tie-a'
    ),
    'con empate el id menor debe perder'
  );
end;
$$;

commit;

\echo OK


-- ============================================================
-- TEST 18: UNICO SOS ACTIVO
-- ============================================================

\echo 'TEST 18 garantia de un solo SOS activo'

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
  'sos-tercero',
  '11111111-1111-4111-8111-111111111111',
  'sos',
  'Usuario A',
  '2026-01-15 00:00:00+00',
  'Tercero',
  '2026-01-15 00:00:00+00'
);

do $$
begin
  perform pruebas.assert(
    (
      select count(*) = 1
      from public.emergency_events
      where user_id = '11111111-1111-4111-8111-111111111111'
        and activa
        and eliminado_en is null
    ),
    'un tercer SOS no debe romper la unicidad activa'
  );

  perform pruebas.assert(
    (
      select count(*) = 3
      from public.emergency_events
    ),
    'el historial de los tres eventos debe conservarse'
  );

  perform pruebas.assert(
    (
      select count(*) = 1
      from pg_catalog.pg_index
      where indrelid = 'public.emergency_events'::regclass
        and indisunique
        and indpred is not null
    ),
    'debe existir el indice unico parcial de SOS activo'
  );
end;
$$;

commit;

\echo OK


-- ============================================================
-- TEST 19: AISLAMIENTO DE ENTREGAS
-- ============================================================

\echo 'TEST 19 aislamiento de entregas'

select pruebas.reset();

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
  mensaje
)
values (
  'evt-a',
  '11111111-1111-4111-8111-111111111111',
  'sos',
  'Usuario A',
  now(),
  'SOS A'
);

insert into public.emergency_event_deliveries (
  event_id,
  contacto_id,
  nombre,
  telefono,
  estado
)
values (
  'evt-a',
  'contacto-a',
  'Contacto A',
  '3000000001',
  'pendiente'
);

commit;


begin;

set local request.jwt.claim.sub =
  '22222222-2222-4222-8222-222222222222';

set local role authenticated;

insert into public.emergency_events (
  id,
  user_id,
  tipo,
  usuario_nombre,
  inicio,
  mensaje
)
values (
  'evt-b',
  '22222222-2222-4222-8222-222222222222',
  'sos',
  'Usuario B',
  now(),
  'SOS B'
);

do $$
begin
  perform pruebas.assert(
    (
      select count(*) = 0
      from public.emergency_event_deliveries
    ),
    'el usuario B no debe ver entregas del usuario A'
  );
end;
$$;

select pruebas.expect_error(
  $sql$
    insert into public.emergency_event_deliveries (
      event_id,
      contacto_id,
      nombre,
      telefono,
      estado
    )
    values (
      'evt-a',
      'contacto-b',
      'Contacto B',
      '3000000002',
      'pendiente'
    )
  $sql$,
  '42501',
  'no deben insertarse entregas en eventos ajenos'
);

commit;

\echo OK


-- ============================================================
-- TEST 20: INMUTABILIDAD DE SNAPSHOTS
-- ============================================================

\echo 'TEST 20 snapshot de contactos'

begin;

set local request.jwt.claim.sub =
  '11111111-1111-4111-8111-111111111111';

set local role authenticated;

select pruebas.expect_error(
  $sql$update public.emergency_event_deliveries set contacto_id = 'otro' where event_id = 'evt-a'$sql$,
  '42501',
  'contacto_id debe ser inmutable'
);

select pruebas.expect_error(
  $sql$update public.emergency_event_deliveries set nombre = 'Modificado' where event_id = 'evt-a'$sql$,
  '42501',
  'nombre del snapshot debe ser inmutable'
);

select pruebas.expect_error(
  $sql$update public.emergency_event_deliveries set telefono = '999' where event_id = 'evt-a'$sql$,
  '42501',
  'telefono del snapshot debe ser inmutable'
);

select pruebas.expect_error(
  $sql$update public.emergency_event_deliveries set prioritario = true where event_id = 'evt-a'$sql$,
  '42501',
  'prioritario del snapshot debe ser inmutable'
);

commit;


begin;

select pruebas.expect_error(
  $sql$
    update public.emergency_event_deliveries
       set nombre = 'Modificado admin'
     where event_id = 'evt-a'
  $sql$,
  '42501',
  'el trigger de inmutabilidad debe actuar incluso con privilegios administrativos'
);

commit;

\echo OK


-- ============================================================
-- TEST 21: ELIMINACION LOGICA DE SISMOS
-- ============================================================

\echo 'TEST 21 tombstone de sismos'

select pruebas.reset();

begin;

set local request.jwt.claim.sub =
  '11111111-1111-4111-8111-111111111111';

set local role authenticated;

insert into public.saved_earthquakes (
  user_id,
  sismo_id,
  magnitud,
  lugar,
  latitud,
  longitud,
  profundidad,
  tiempo
)
values (
  '11111111-1111-4111-8111-111111111111',
  'us1000abc',
  4.2,
  'Bogota',
  4.6,
  -74.0,
  12,
  now()
);

update public.saved_earthquakes
   set eliminado_en = now()
 where sismo_id = 'us1000abc';

do $$
begin
  perform pruebas.assert(
    (
      select eliminado_en is not null
      from public.saved_earthquakes
      where sismo_id = 'us1000abc'
    ),
    'el sismo debe conservar tombstone'
  );
end;
$$;

commit;

\echo OK


-- ============================================================
-- TEST 22: REGUARDADO DE SISMOS
-- ============================================================

\echo 'TEST 22 re-guardado seguro'

begin;

set local request.jwt.claim.sub =
  '11111111-1111-4111-8111-111111111111';

set local role authenticated;

select pruebas.expect_error(
  $sql$
    update public.saved_earthquakes
       set eliminado_en = null
     where sismo_id = 'us1000abc'
  $sql$,
  '23514',
  'un sismo eliminado no debe reactivarse'
);

insert into public.saved_earthquakes (
  user_id,
  sismo_id,
  magnitud,
  lugar,
  latitud,
  longitud,
  profundidad,
  tiempo
)
values (
  '11111111-1111-4111-8111-111111111111',
  'us1000abc',
  4.2,
  'Bogota',
  4.6,
  -74.0,
  12,
  now()
);

do $$
begin
  perform pruebas.assert(
    (
      select count(*) = 2
      from public.saved_earthquakes
      where sismo_id = 'us1000abc'
    ),
    'el re-guardado debe conservar el historial'
  );

  perform pruebas.assert(
    (
      select count(*) = 1
      from public.saved_earthquakes
      where sismo_id = 'us1000abc'
        and eliminado_en is null
    ),
    'debe existir una sola fila activa despues del re-guardado'
  );

  perform pruebas.assert(
    (
      select count(distinct guardado_id) = 2
      from public.saved_earthquakes
      where sismo_id = 'us1000abc'
    ),
    'cada guardado debe tener identidad propia'
  );
end;
$$;

commit;

\echo OK


-- ============================================================
-- TEST 23: SEGURIDAD DE FUNCIONES SECURITY DEFINER
-- ============================================================

\echo 'TEST 23 funciones SECURITY DEFINER'

do $$
begin
  perform pruebas.assert(
    (
      select count(*) = 3
      from pg_catalog.pg_proc p
      join pg_catalog.pg_namespace n
        on n.oid = p.pronamespace
      where n.nspname = 'public'
        and p.proname = any(array[
          'profiles_enforce_auth_identity',
          'auth_users_sync_profile_email',
          'resolve_active_sos_conflict'
        ])
        and p.prosecdef
        and p.proconfig::text like '%search_path=%'
        and p.proowner = 'postgres'::regrole
        and not has_function_privilege(
          'authenticated',
          p.oid,
          'EXECUTE'
        )
        and not has_function_privilege(
          'anon',
          p.oid,
          'EXECUTE'
        )
        and not exists (
          select 1
          from pg_catalog.aclexplode(p.proacl) a
          where a.grantee = 0
            and a.privilege_type = 'EXECUTE'
        )
    ),
    'las funciones SECURITY DEFINER deben estar acotadas y sin EXECUTE publico'
  );
end;
$$;

\echo OK


-- ============================================================
-- TEST 24: PRIVILEGIOS EFECTIVOS
-- ============================================================

\echo 'TEST 24 privilegios anon y authenticated'

do $$
declare
  r record;
begin
  for r in
    select *
    from (
      values
        ('profiles'),
        ('user_settings'),
        ('emergency_contacts'),
        ('emergency_events'),
        ('emergency_event_deliveries'),
        ('saved_earthquakes')
    ) as t(tabla)
  loop

    if has_table_privilege(
         'anon',
         'public.' || r.tabla,
         'SELECT'
       )
       or has_table_privilege(
         'anon',
         'public.' || r.tabla,
         'INSERT'
       )
       or has_table_privilege(
         'anon',
         'public.' || r.tabla,
         'UPDATE'
       )
       or has_table_privilege(
         'anon',
         'public.' || r.tabla,
         'DELETE'
       )
       or has_table_privilege(
         'anon',
         'public.' || r.tabla,
         'TRUNCATE'
       )
       or has_table_privilege(
         'anon',
         'public.' || r.tabla,
         'TRIGGER'
       )
       or has_table_privilege(
         'anon',
         'public.' || r.tabla,
         'REFERENCES'
       ) then

      raise exception
        'FALLIDO: anon tiene privilegios sobre %',
        r.tabla;
    end if;


    if not has_table_privilege(
         'authenticated',
         'public.' || r.tabla,
         'SELECT'
       )
       or not has_table_privilege(
         'authenticated',
         'public.' || r.tabla,
         'INSERT'
       )
       or not has_any_column_privilege(
         'authenticated',
         'public.' || r.tabla,
         'UPDATE'
       ) then

      raise exception
        'FALLIDO: faltan privilegios minimos sobre %',
        r.tabla;
    end if;


    if has_table_privilege(
         'authenticated',
         'public.' || r.tabla,
         'DELETE'
       )
       or has_table_privilege(
         'authenticated',
         'public.' || r.tabla,
         'TRUNCATE'
       )
       or has_table_privilege(
         'authenticated',
         'public.' || r.tabla,
         'TRIGGER'
       )
       or has_table_privilege(
         'authenticated',
         'public.' || r.tabla,
         'REFERENCES'
       ) then

      raise exception
        'FALLIDO: authenticated tiene privilegios indebidos sobre %',
        r.tabla;
    end if;

  end loop;


  for r in
    select *
    from (
      values
        ('profiles', 'id'),
        ('profiles', 'email'),
        ('profiles', 'creado_en'),
        ('user_settings', 'user_id'),
        ('emergency_contacts', 'user_id'),
        ('emergency_contacts', 'creado_en'),
        ('emergency_events', 'user_id'),
        ('emergency_events', 'motivo_fin'),
        ('emergency_events', 'creado_en'),
        ('emergency_event_deliveries', 'event_id'),
        ('emergency_event_deliveries', 'contacto_id'),
        ('emergency_event_deliveries', 'nombre'),
        ('emergency_event_deliveries', 'telefono'),
        ('saved_earthquakes', 'guardado_id'),
        ('saved_earthquakes', 'user_id'),
        ('saved_earthquakes', 'sismo_id')
    ) as t(tabla, columna)
  loop

    if has_column_privilege(
      'authenticated',
      'public.' || r.tabla,
      r.columna,
      'UPDATE'
    ) then

      raise exception
        'FALLIDO: authenticated puede actualizar %.%',
        r.tabla,
        r.columna;
    end if;

  end loop;

end;
$$;

\echo OK


-- ============================================================
-- TEST 25: ELIMINACION LOGICA DE SOS
-- ============================================================

\echo 'TEST 25 eliminacion logica de SOS'

select pruebas.reset();

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
  mensaje
)
values (
  'evt-eliminado',
  '11111111-1111-4111-8111-111111111111',
  'sos',
  'Usuario A',
  now(),
  'SOS eliminado'
);

update public.emergency_events
   set eliminado_en = now()
 where id = 'evt-eliminado';

do $$
begin
  perform pruebas.assert(
    (
      select
        activa = false
        and eliminado_en is not null
        and fin is not null
        and motivo_fin = 'manual'
      from public.emergency_events
      where id = 'evt-eliminado'
    ),
    'eliminar logicamente un SOS debe cerrarlo de forma definitiva'
  );
end;
$$;

commit;

\echo OK


-- ============================================================
-- TEST 26: NO REACTIVACION TRAS ELIMINACION DE SOS
-- ============================================================

\echo 'TEST 26 no reactivacion de SOS eliminado'

begin;

set local request.jwt.claim.sub =
  '11111111-1111-4111-8111-111111111111';

set local role authenticated;

select pruebas.expect_error(
  $sql$
    update public.emergency_events
       set activa = true
     where id = 'evt-eliminado'
  $sql$,
  '23514',
  'un SOS eliminado no debe reactivarse'
);

commit;

\echo OK


-- ============================================================
-- TEST 27: VALIDACION FINAL DE ESTADO
-- ============================================================

\echo 'TEST 27 estado final de estructura'

select pruebas.assert(
  (
    select count(*) = 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.saved_earthquakes'::regclass
      and contype = 'p'
  ),
  'saved_earthquakes debe tener una unica clave primaria'
);

select pruebas.assert(
  (
    select count(*) = 1
    from pg_catalog.pg_index
    where indrelid = 'public.emergency_events'::regclass
      and indisunique
      and indpred is not null
  ),
  'debe existir el indice unico parcial SOS'
);

select pruebas.assert(
  (
    select count(*) = 1
    from pg_catalog.pg_trigger
    where tgrelid = 'public.emergency_events'::regclass
      and tgname = 'emergency_events_05_resolve_active_conflict'
      and not tgisinternal
  ),
  'debe existir un unico trigger de conflictos'
);

\echo OK

\echo 'VALIDACION GENERAL TERMINADA'
