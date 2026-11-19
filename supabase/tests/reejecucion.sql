
\set ON_ERROR_STOP on

-- ============================================================
-- REEJECUCION Y VALIDACION DE MIGRACIONES
-- Proyecto: Alerta Sísmica
--
-- IMPORTANTE:
-- Este archivo valida el estado DESPUES de volver a ejecutar
-- las migraciones 0001 a 0005.
--
-- Primero se deben ejecutar nuevamente las cinco migraciones
-- en orden y después ejecutar este archivo.
--
-- No elimina datos ni modifica registros existentes.
-- ============================================================


-- ============================================================
-- 00. PREPARACION
-- ============================================================

create schema if not exists pruebas_reexec;

create or replace function pruebas_reexec.assert(
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

grant usage on schema pruebas_reexec to authenticated;

grant execute on function pruebas_reexec.assert(boolean, text)
to authenticated;


-- ============================================================
-- TEST 01: TABLAS PRINCIPALES
-- ============================================================

\echo 'REEJECUCION 01 - tablas principales'

select pruebas_reexec.assert(
  (
    select count(*) = 6
    from information_schema.tables
    where table_schema = 'public'
      and table_type = 'BASE TABLE'
      and table_name = any(array[
        'profiles',
        'user_settings',
        'emergency_contacts',
        'emergency_events',
        'emergency_event_deliveries',
        'saved_earthquakes'
      ])
  ),
  'deben existir las seis tablas principales'
);


-- ============================================================
-- TEST 02: CLAVE PRIMARIA DE SAVED_EARTHQUAKES
-- ============================================================

\echo 'REEJECUCION 02 - clave primaria'

select pruebas_reexec.assert(
  (
    select count(*) = 1
    from pg_catalog.pg_constraint
    where conrelid = 'public.saved_earthquakes'::regclass
      and conname = 'saved_earthquakes_pkey'
      and contype = 'p'
  ),
  'saved_earthquakes debe tener una sola clave primaria'
);

select pruebas_reexec.assert(
  (
    select count(*) = 1
    from pg_catalog.pg_constraint c
    join pg_catalog.pg_attribute a
      on a.attrelid = c.conrelid
     and a.attnum = c.conkey[1]
    where c.conrelid = 'public.saved_earthquakes'::regclass
      and c.contype = 'p'
      and a.attname = 'guardado_id'
      and cardinality(c.conkey) = 1
  ),
  'guardado_id debe ser la unica columna de la clave primaria'
);


-- ============================================================
-- TEST 03: TRIGGERS DE EMERGENCY_EVENTS
-- ============================================================

\echo 'REEJECUCION 03 - triggers SOS'

select pruebas_reexec.assert(
  (
    select count(*) = 1
    from pg_catalog.pg_trigger
    where tgrelid = 'public.emergency_events'::regclass
      and tgname = 'emergency_events_05_resolve_active_conflict'
      and not tgisinternal
  ),
  'el trigger de conflictos SOS debe existir una sola vez'
);

select pruebas_reexec.assert(
  (
    select count(*) = 0
    from pg_catalog.pg_trigger
    where tgrelid = 'public.emergency_events'::regclass
      and tgname in (
        'emergency_events_resolve_active_conflict',
        'emergency_events_enforce_immutable'
      )
      and not tgisinternal
  ),
  'los triggers heredados deben haberse retirado'
);


-- ============================================================
-- TEST 04: TRIGGERS DE HARDENING
-- ============================================================

\echo 'REEJECUCION 04 - triggers de hardening'

select pruebas_reexec.assert(
  (
    select count(*) = 7
    from pg_catalog.pg_trigger
    where tgrelid = 'public.emergency_events'::regclass
      and tgname = any(array[
        '00_set_sync_timestamps',
        '01_apply_logical_delete',
        '02_enforce_immutable',
        '03_enforce_sos_state',
        '04_set_manual_close',
        '05_resolve_active_conflict',
        '06_touch_actualizado_en'
      ])
      and not tgisinternal
  ),
  'deben existir los siete triggers ordenados de emergency_events'
);


-- ============================================================
-- TEST 05: INDICE UNICO DE SOS ACTIVO
-- ============================================================

\echo 'REEJECUCION 05 - indice SOS'

select pruebas_reexec.assert(
  (
    select count(*) = 1
    from pg_catalog.pg_indexes
    where schemaname = 'public'
      and tablename = 'emergency_events'
      and indexname = 'emergency_events_activa_por_usuario_key'
  ),
  'debe existir un solo indice de SOS activo'
);

select pruebas_reexec.assert(
  (
    select count(*) = 1
    from pg_catalog.pg_indexes
    where schemaname = 'public'
      and tablename = 'saved_earthquakes'
      and indexname = 'saved_earthquakes_user_sismo_activo_key'
  ),
  'debe existir un solo indice de sismos guardados activos'
);


-- ============================================================
-- TEST 06: RLS HABILITADO
-- ============================================================

\echo 'REEJECUCION 06 - RLS'

select pruebas_reexec.assert(
  (
    select count(*) = 6
    from pg_catalog.pg_class c
    join pg_catalog.pg_namespace n
      on n.oid = c.relnamespace
    where n.nspname = 'public'
      and c.relname = any(array[
        'profiles',
        'user_settings',
        'emergency_contacts',
        'emergency_events',
        'emergency_event_deliveries',
        'saved_earthquakes'
      ])
      and c.relrowsecurity
  ),
  'RLS debe estar habilitado en las seis tablas'
);


-- ============================================================
-- TEST 07: FUNCIONES IMPORTANTES
-- ============================================================

\echo 'REEJECUCION 07 - funciones'

select pruebas_reexec.assert(
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
  'deben existir las diez funciones principales'
);


-- ============================================================
-- TEST 08: FUNCIONES SECURITY DEFINER
-- ============================================================

\echo 'REEJECUCION 08 - seguridad de funciones'

select pruebas_reexec.assert(
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
  ),
  'las funciones SECURITY DEFINER deben conservar su configuracion segura'
);


-- ============================================================
-- TEST 09: NO DUPLICACION DE POLITICAS RLS
-- ============================================================

\echo 'REEJECUCION 09 - politicas RLS'

select pruebas_reexec.assert(
  (
    select count(*) > 0
    from pg_catalog.pg_policies
    where schemaname = 'public'
      and tablename = 'profiles'
  ),
  'profiles debe conservar sus politicas RLS'
);

select pruebas_reexec.assert(
  (
    select count(*) > 0
    from pg_catalog.pg_policies
    where schemaname = 'public'
      and tablename = 'user_settings'
  ),
  'user_settings debe conservar sus politicas RLS'
);

select pruebas_reexec.assert(
  (
    select count(*) > 0
    from pg_catalog.pg_policies
    where schemaname = 'public'
      and tablename = 'emergency_contacts'
  ),
  'emergency_contacts debe conservar sus politicas RLS'
);

select pruebas_reexec.assert(
  (
    select count(*) > 0
    from pg_catalog.pg_policies
    where schemaname = 'public'
      and tablename = 'emergency_events'
  ),
  'emergency_events debe conservar sus politicas RLS'
);

select pruebas_reexec.assert(
  (
    select count(*) > 0
    from pg_catalog.pg_policies
    where schemaname = 'public'
      and tablename = 'emergency_event_deliveries'
  ),
  'emergency_event_deliveries debe conservar sus politicas RLS'
);

select pruebas_reexec.assert(
  (
    select count(*) > 0
    from pg_catalog.pg_policies
    where schemaname = 'public'
      and tablename = 'saved_earthquakes'
  ),
  'saved_earthquakes debe conservar sus politicas RLS'
);


-- ============================================================
-- TEST 10: USUARIO DE PRUEBA DISPONIBLE
-- ============================================================

\echo 'REEJECUCION 10 - usuario de prueba'

do $$
begin
  if not exists (
    select 1
    from auth.users
    where email is not null
  ) then
    raise exception
      'No existe ningun usuario con correo en auth.users. '
      'Crea un usuario de prueba en Supabase Auth antes de continuar.';
  end if;
end;
$$;


-- Obtener un usuario real de Auth.
-- No se inventan UUID ni correos.

select
  id::text as reexec_user_id,
  email as reexec_email
from auth.users
where email is not null
order by created_at
limit 1
\gset


-- Generar un identificador nuevo para el evento de prueba.

select
  'evt-reexec-' || gen_random_uuid()::text
  as reexec_event_id
\gset


-- ============================================================
-- TEST 11: FUNCIONALIDAD TRAS LA REEJECUCION
-- ============================================================

\echo 'REEJECUCION 11 - funcionalidad basica'

begin;

set local request.jwt.claim.sub = :'reexec_user_id';

set local role authenticated;


-- Crear el perfil si todavía no existe.
-- El trigger debe obtener el correo desde auth.users.

insert into public.profiles (
  id,
  nombre,
  email
)
values (
  :'reexec_user_id'::uuid,
  'Usuario de prueba reejecucion',
  'correo-falso@example.test'
)
on conflict (id) do nothing;


-- Crear un evento SOS.

insert into public.emergency_events (
  id,
  user_id,
  tipo,
  usuario_nombre,
  inicio,
  mensaje
)
values (
  :'reexec_event_id',
  :'reexec_user_id'::uuid,
  'sos',
  'Usuario de prueba',
  now(),
  'Prueba posterior a reejecucion'
);


-- Comprobar funcionamiento.

do $$
begin

  perform pruebas_reexec.assert(
    (
      select lower(email) = lower(
        (
          select email
          from auth.users
          where id = current_setting('request.jwt.claim.sub')::uuid
        )
      )
      from public.profiles
      where id = current_setting('request.jwt.claim.sub')::uuid
    ),
    'la identidad del perfil debe seguir sincronizada con Auth'
  );


  perform pruebas_reexec.assert(
    (
      select activa
         and motivo_fin is null
         and eliminado_en is null
      from public.emergency_events
      where id = current_setting('app.reexec_event_id', true)
    ),
    'el SOS debe quedar activo despues de la reejecucion'
  );

end;
$$;


-- El evento se comprueba usando su identificador generado.
-- La variable se establece dentro de esta transaccion.

select pg_catalog.set_config(
  'app.reexec_event_id',
  :'reexec_event_id',
  true
);


-- Repetir comprobacion con la variable ya establecida.

do $$
begin
  perform pruebas_reexec.assert(
    (
      select activa
      from public.emergency_events
      where id = current_setting('app.reexec_event_id')
    ),
    'el evento SOS debe permanecer activo'
  );
end;
$$;

rollback;

\echo OK


-- ============================================================
-- TEST 12: PRIVILEGIOS TRAS REEJECUCION
-- ============================================================

\echo 'REEJECUCION 12 - privilegios'

do $$
declare
  v_tabla text;
begin

  foreach v_tabla in array array[
    'profiles',
    'user_settings',
    'emergency_contacts',
    'emergency_events',
    'emergency_event_deliveries',
    'saved_earthquakes'
  ]
  loop

    if has_table_privilege(
      'anon',
      'public.' || v_tabla,
      'SELECT'
    ) then
      raise exception
        'FALLIDO: anon tiene SELECT sobre %',
        v_tabla;
    end if;


    if has_table_privilege(
      'authenticated',
      'public.' || v_tabla,
      'DELETE'
    ) then
      raise exception
        'FALLIDO: authenticated tiene DELETE sobre %',
        v_tabla;
    end if;

  end loop;

end;
$$;

\echo OK


-- ============================================================
-- RESULTADO FINAL
-- ============================================================

\echo '=============================================='
\echo 'REEJECUCION Y VALIDACION TERMINADAS'
\echo '=============================================='
