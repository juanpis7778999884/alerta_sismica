
-- ============================================================
-- 0005_fase4_hardening.sql
-- Endurecimiento de identidad, eventos SOS y sismos guardados
-- ============================================================


-- ============================================================
-- 1. SINCRONIZACIÓN DEL CORREO CON SUPABASE AUTH
-- ============================================================

create or replace function public.profiles_enforce_auth_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text;
  v_sync boolean;
begin
  v_sync :=
    pg_catalog.current_setting(
      'app.internal_profile_email_sync',
      true
    ) = 'on';

  if tg_op = 'INSERT' then
    if auth.uid() is null
       or new.id is distinct from auth.uid() then
      raise exception
        using errcode = '42501',
              message = 'El perfil debe pertenecer al usuario autenticado.';
    end if;

    select u.email
      into v_email
      from auth.users u
     where u.id = new.id;

    if v_email is null then
      raise exception
        using errcode = '42501',
              message = 'No existe identidad de autenticación para este perfil.';
    end if;

    new.email := pg_catalog.lower(pg_catalog.btrim(v_email));
    new.creado_en := pg_catalog.now();
    new.actualizado_en := pg_catalog.now();
    new.sincronizado_en := null;

    return new;
  end if;

  if new.id is distinct from old.id
     or new.legacy_local_id is distinct from old.legacy_local_id
     or new.creado_en is distinct from old.creado_en
     or new.sincronizado_en is distinct from old.sincronizado_en then
    raise exception
      using errcode = '42501',
            message = 'La identidad del perfil no es modificable.';
  end if;

  if v_sync then
    select u.email
      into v_email
      from auth.users u
     where u.id = new.id;

    if v_email is null
       or new.email is distinct from
          pg_catalog.lower(pg_catalog.btrim(v_email)) then
      raise exception
        using errcode = '42501',
              message = 'El correo sincronizado no coincide con Supabase Auth.';
    end if;

  elsif new.email is distinct from old.email then
    raise exception
      using errcode = '42501',
            message = 'El correo del perfil solo puede cambiar desde Supabase Auth.';
  end if;

  return new;
end;
$$;


create or replace function public.auth_users_sync_profile_email()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text;
  v_old_email text;
  v_previous_sync text;
begin
  if new.id is null then
    return null;
  end if;

  v_old_email :=
    pg_catalog.lower(pg_catalog.btrim(old.email));

  if new.email is null then
    if exists (
      select 1
        from public.profiles p
       where p.id = new.id
    ) then
      raise exception
        using errcode = '23502',
              message = 'No se puede eliminar el correo de una cuenta que tiene perfil.';
    end if;

    return null;
  end if;

  v_email :=
    pg_catalog.lower(pg_catalog.btrim(new.email));

  if v_email is distinct from v_old_email then
    v_previous_sync :=
      pg_catalog.current_setting(
        'app.internal_profile_email_sync',
        true
      );

    perform pg_catalog.set_config(
      'app.internal_profile_email_sync',
      'on',
      true
    );

    begin
      update public.profiles p
         set email = v_email
       where p.id = new.id
         and p.email is distinct from v_email;

    exception when others then
      perform pg_catalog.set_config(
        'app.internal_profile_email_sync',
        coalesce(v_previous_sync, ''),
        true
      );
      raise;
    end;

    perform pg_catalog.set_config(
      'app.internal_profile_email_sync',
      coalesce(v_previous_sync, ''),
      true
    );
  end if;

  return null;
end;
$$;


alter function public.profiles_enforce_auth_identity()
  owner to postgres;

alter function public.auth_users_sync_profile_email()
  owner to postgres;


revoke all on function public.profiles_enforce_auth_identity()
  from PUBLIC, anon, authenticated;

revoke all on function public.auth_users_sync_profile_email()
  from PUBLIC, anon, authenticated;


drop trigger if exists profiles_enforce_auth_identity
  on public.profiles;

create trigger profiles_enforce_auth_identity
  before insert or update on public.profiles
  for each row
  execute function public.profiles_enforce_auth_identity();


drop trigger if exists auth_users_sync_profile_email
  on auth.users;

create trigger auth_users_sync_profile_email
  after update of email on auth.users
  for each row
  execute function public.auth_users_sync_profile_email();


-- ============================================================
-- 2. PROTECCIÓN DEL ESTADO TERMINAL DE LOS EVENTOS SOS
-- ============================================================

create or replace function public.enforce_sos_terminal_state()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.tipo is distinct from 'sos' then
    return new;
  end if;

  -- Un evento cerrado no puede reactivarse.
  if old.activa is false and new.activa is true then
    raise exception
      using errcode = '23514',
            message = 'Un SOS cerrado no puede reactivarse; cree un nuevo evento.';
  end if;

  -- Un SOS activo no puede tener datos de cierre.
  if new.activa is true
     and (
       new.fin is not null
       or new.motivo_fin is not null
     ) then
    raise exception
      using errcode = '23514',
            message = 'Un SOS activo no puede tener datos de cierre.';
  end if;

  -- Una vez establecida, la hora de cierre es definitiva.
  if old.fin is not null
     and new.fin is distinct from old.fin then
    raise exception
      using errcode = '23514',
            message = 'La hora de cierre de un SOS es definitiva.';
  end if;

  -- Una vez establecido, el motivo de cierre es definitivo.
  if old.motivo_fin is not null
     and new.motivo_fin is distinct from old.motivo_fin then
    raise exception
      using errcode = '23514',
            message = 'El motivo de cierre de un SOS es definitivo.';
  end if;

  return new;
end;
$$;


create or replace function public.set_sos_manual_close()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.tipo is distinct from 'sos' then
    return new;
  end if;

  -- Un cierre manual o una eliminación lógica de un SOS activo
  -- debe producir un cierre definitivo controlado por el servidor.
  if old.activa is true
     and (
       new.activa is false
       or (
         old.eliminado_en is null
         and new.eliminado_en is not null
       )
     )
     and old.motivo_fin is null then

    new.activa := false;
    new.motivo_fin := 'manual';
    new.fin := pg_catalog.greatest(
      old.inicio,
      pg_catalog.now()
    );
  end if;

  return new;
end;
$$;


-- ============================================================
-- 3. RESOLUCIÓN DE CONFLICTOS SOS MULTIDISPOSITIVO
-- ============================================================

create or replace function public.resolve_active_sos_conflict()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_other_id text;
  v_other_cliente timestamptz;
  v_other_inicio timestamptz;
  v_new_wins boolean;
begin
  if new.tipo is distinct from 'sos'
     or new.activa is not true
     or new.eliminado_en is not null then
    return new;
  end if;

  if auth.uid() is null
     or new.user_id is distinct from auth.uid() then
    raise exception
      using errcode = '42501',
            message = 'El evento debe pertenecer al usuario autenticado.';
  end if;

  -- Serializa la resolución de conflictos por usuario.
  perform pg_catalog.pg_advisory_xact_lock(
    1548980001::integer,
    pg_catalog.hashtext(new.user_id::text)::integer
  );

  select
    e.id,
    e.cliente_actualizado_en,
    e.inicio
  into
    v_other_id,
    v_other_cliente,
    v_other_inicio
  from public.emergency_events e
  where e.user_id = new.user_id
    and e.user_id = auth.uid()
    and e.tipo = 'sos'
    and e.activa is true
    and e.eliminado_en is null
    and e.id is distinct from new.id
  order by
    e.cliente_actualizado_en desc,
    e.inicio desc,
    e.id desc
  limit 1;

  if v_other_id is null then
    return new;
  end if;

  v_new_wins :=
    (
      new.cliente_actualizado_en,
      new.inicio,
      new.id
    )
    >
    (
      v_other_cliente,
      v_other_inicio,
      v_other_id
    );

  if v_new_wins then

    update public.emergency_events e
       set activa = false,
           fin = pg_catalog.greatest(
             e.inicio,
             pg_catalog.now()
           ),
           motivo_fin = 'conflicto_multidispositivo'
     where e.id = v_other_id
       and e.user_id = new.user_id
       and e.user_id = auth.uid()
       and e.tipo = 'sos'
       and e.activa is true
       and e.eliminado_en is null;

    if not found then
      raise exception
        using errcode = '40001',
              message = 'No se pudo resolver el conflicto SOS; reintente la sincronización.';
    end if;

  else
    new.activa := false;
    new.fin := pg_catalog.greatest(
      new.inicio,
      pg_catalog.now()
    );
    new.motivo_fin := 'conflicto_multidispositivo';
  end if;

  return new;
end;
$$;


alter function public.resolve_active_sos_conflict()
  owner to postgres;


revoke all on function public.enforce_sos_terminal_state()
  from PUBLIC, anon, authenticated;

revoke all on function public.set_sos_manual_close()
  from PUBLIC, anon, authenticated;

revoke all on function public.resolve_active_sos_conflict()
  from PUBLIC, anon, authenticated;


-- ============================================================
-- 4. RECREACIÓN ORDENADA DE TRIGGERS DE EMERGENCY_EVENTS
-- ============================================================

drop trigger if exists emergency_events_set_sync_timestamps
  on public.emergency_events;

drop trigger if exists emergency_events_apply_logical_delete
  on public.emergency_events;

drop trigger if exists emergency_events_enforce_immutable
  on public.emergency_events;

drop trigger if exists emergency_events_resolve_active_conflict
  on public.emergency_events;

drop trigger if exists emergency_events_touch_actualizado_en
  on public.emergency_events;

drop trigger if exists emergency_events_00_set_sync_timestamps
  on public.emergency_events;

drop trigger if exists emergency_events_01_apply_logical_delete
  on public.emergency_events;

drop trigger if exists emergency_events_02_enforce_immutable
  on public.emergency_events;

drop trigger if exists emergency_events_03_enforce_sos_state
  on public.emergency_events;

drop trigger if exists emergency_events_04_set_manual_close
  on public.emergency_events;

drop trigger if exists emergency_events_05_resolve_active_conflict
  on public.emergency_events;

drop trigger if exists emergency_events_06_touch_actualizado_en
  on public.emergency_events;


create trigger emergency_events_00_set_sync_timestamps
  before insert on public.emergency_events
  for each row
  execute function public.set_sync_timestamps();


create trigger emergency_events_01_apply_logical_delete
  before update on public.emergency_events
  for each row
  execute function public.apply_logical_delete();


create trigger emergency_events_02_enforce_immutable
  before update on public.emergency_events
  for each row
  execute function public.enforce_immutable_columns(
    'id',
    'user_id',
    'tipo',
    'usuario_nombre',
    'inicio',
    'mensaje',
    'latitud',
    'longitud',
    'precision_metros',
    'ubicacion_legible',
    'referencia_evento_id',
    'fuente_ubicacion',
    'creado_en',
    'actualizado_en',
    'sincronizado_en'
  );


create trigger emergency_events_03_enforce_sos_state
  before update on public.emergency_events
  for each row
  execute function public.enforce_sos_terminal_state();


create trigger emergency_events_04_set_manual_close
  before update on public.emergency_events
  for each row
  execute function public.set_sos_manual_close();


create trigger emergency_events_05_resolve_active_conflict
  before insert or update on public.emergency_events
  for each row
  execute function public.resolve_active_sos_conflict();


create trigger emergency_events_06_touch_actualizado_en
  before update on public.emergency_events
  for each row
  execute function public.touch_actualizado_en();


-- Mantiene un único SOS activo por usuario.
drop index if exists public.emergency_events_activa_por_usuario_key;

create unique index emergency_events_activa_por_usuario_key
  on public.emergency_events (user_id)
  where tipo = 'sos'
    and activa is true
    and eliminado_en is null;


-- ============================================================
-- 5. TRANSFORMACIÓN DE LA CLAVE PRIMARIA DE SAVED_EARTHQUAKES
-- ============================================================

alter table public.saved_earthquakes
  add column if not exists guardado_id uuid;


update public.saved_earthquakes
   set guardado_id = pg_catalog.gen_random_uuid()
 where guardado_id is null;


alter table public.saved_earthquakes
  alter column guardado_id
  set default pg_catalog.gen_random_uuid();


alter table public.saved_earthquakes
  alter column guardado_id
  set not null;


alter table public.saved_earthquakes
  drop constraint if exists saved_earthquakes_pkey;


alter table public.saved_earthquakes
  add constraint saved_earthquakes_pkey
  primary key (guardado_id);


-- Permite guardar nuevamente un sismo después de eliminar
-- lógicamente su registro anterior.
create unique index if not exists saved_earthquakes_user_sismo_activo_key
  on public.saved_earthquakes (user_id, sismo_id)
  where eliminado_en is null;


drop trigger if exists saved_earthquakes_enforce_immutable
  on public.saved_earthquakes;


create trigger saved_earthquakes_enforce_immutable
  before update on public.saved_earthquakes
  for each row
  execute function public.enforce_immutable_columns(
    'guardado_id',
    'user_id',
    'sismo_id',
    'magnitud',
    'lugar',
    'latitud',
    'longitud',
    'profundidad',
    'tiempo',
    'url',
    'es_simulacion',
    'actualizado_evento_en',
    'guardado_en',
    'creado_en',
    'actualizado_en',
    'sincronizado_en'
  );


-- ============================================================
-- 6. RLS: ACTIVACIÓN Y POLÍTICAS
-- ============================================================

alter table public.profiles enable row level security;
alter table public.user_settings enable row level security;
alter table public.emergency_contacts enable row level security;
alter table public.emergency_events enable row level security;
alter table public.emergency_event_deliveries enable row level security;
alter table public.saved_earthquakes enable row level security;


-- PROFILES

drop policy if exists profiles_select_own
  on public.profiles;

create policy profiles_select_own
  on public.profiles
  for select to authenticated
  using (id = auth.uid());


drop policy if exists profiles_insert_own
  on public.profiles;

create policy profiles_insert_own
  on public.profiles
  for insert to authenticated
  with check (id = auth.uid());


drop policy if exists profiles_update_own
  on public.profiles;

create policy profiles_update_own
  on public.profiles
  for update to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());


-- USER SETTINGS

drop policy if exists user_settings_select_own
  on public.user_settings;

create policy user_settings_select_own
  on public.user_settings
  for select to authenticated
  using (user_id = auth.uid());


drop policy if exists user_settings_insert_own
  on public.user_settings;

create policy user_settings_insert_own
  on public.user_settings
  for insert to authenticated
  with check (user_id = auth.uid());


drop policy if exists user_settings_update_own
  on public.user_settings;

create policy user_settings_update_own
  on public.user_settings
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());


-- EMERGENCY CONTACTS

drop policy if exists emergency_contacts_select_own
  on public.emergency_contacts;

create policy emergency_contacts_select_own
  on public.emergency_contacts
  for select to authenticated
  using (user_id = auth.uid());


drop policy if exists emergency_contacts_insert_own
  on public.emergency_contacts;

create policy emergency_contacts_insert_own
  on public.emergency_contacts
  for insert to authenticated
  with check (user_id = auth.uid());


drop policy if exists emergency_contacts_update_own
  on public.emergency_contacts;

create policy emergency_contacts_update_own
  on public.emergency_contacts
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());


-- EMERGENCY EVENTS

drop policy if exists emergency_events_select_own
  on public.emergency_events;

create policy emergency_events_select_own
  on public.emergency_events
  for select to authenticated
  using (user_id = auth.uid());


drop policy if exists emergency_events_insert_own
  on public.emergency_events;

create policy emergency_events_insert_own
  on public.emergency_events
  for insert to authenticated
  with check (user_id = auth.uid());


drop policy if exists emergency_events_update_own
  on public.emergency_events;

create policy emergency_events_update_own
  on public.emergency_events
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());


-- EMERGENCY EVENT DELIVERIES

drop policy if exists emergency_event_deliveries_select_own
  on public.emergency_event_deliveries;

create policy emergency_event_deliveries_select_own
  on public.emergency_event_deliveries
  for select to authenticated
  using (
    exists (
      select 1
        from public.emergency_events e
       where e.id = event_id
         and e.user_id = auth.uid()
    )
  );


drop policy if exists emergency_event_deliveries_insert_own
  on public.emergency_event_deliveries;

create policy emergency_event_deliveries_insert_own
  on public.emergency_event_deliveries
  for insert to authenticated
  with check (
    exists (
      select 1
        from public.emergency_events e
       where e.id = event_id
         and e.user_id = auth.uid()
    )
  );


drop policy if exists emergency_event_deliveries_update_own
  on public.emergency_event_deliveries;

create policy emergency_event_deliveries_update_own
  on public.emergency_event_deliveries
  for update to authenticated
  using (
    exists (
      select 1
        from public.emergency_events e
       where e.id = event_id
         and e.user_id = auth.uid()
    )
  )
  with check (
    exists (
      select 1
        from public.emergency_events e
       where e.id = event_id
         and e.user_id = auth.uid()
    )
  );


-- SAVED EARTHQUAKES

drop policy if exists saved_earthquakes_select_own
  on public.saved_earthquakes;

create policy saved_earthquakes_select_own
  on public.saved_earthquakes
  for select to authenticated
  using (user_id = auth.uid());


drop policy if exists saved_earthquakes_insert_own
  on public.saved_earthquakes;

create policy saved_earthquakes_insert_own
  on public.saved_earthquakes
  for insert to authenticated
  with check (user_id = auth.uid());


drop policy if exists saved_earthquakes_update_own
  on public.saved_earthquakes;

create policy saved_earthquakes_update_own
  on public.saved_earthquakes
  for update to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());


-- ============================================================
-- 7. PRIVILEGIOS DE TABLAS
-- ============================================================

-- PROFILES

revoke all on table public.profiles
  from PUBLIC, anon, authenticated;

grant select, insert
  on table public.profiles
  to authenticated;

grant update (
  nombre,
  cliente_actualizado_en
)
  on table public.profiles
  to authenticated;


-- USER SETTINGS

revoke all on table public.user_settings
  from PUBLIC, anon, authenticated;

grant select, insert
  on table public.user_settings
  to authenticated;

grant update (
  tema,
  magnitud_minima,
  auto_refresco,
  notificar_sismos,
  umbral_notificacion,
  numero_emergencia,
  cliente_actualizado_en
)
  on table public.user_settings
  to authenticated;


-- EMERGENCY CONTACTS

revoke all on table public.emergency_contacts
  from PUBLIC, anon, authenticated;

grant select, insert
  on table public.emergency_contacts
  to authenticated;

grant update (
  nombre,
  telefono,
  prioritario,
  eliminado_en,
  cliente_actualizado_en
)
  on table public.emergency_contacts
  to authenticated;


-- EMERGENCY EVENTS

revoke all on table public.emergency_events
  from PUBLIC, anon, authenticated;

grant select, insert
  on table public.emergency_events
  to authenticated;

grant update (
  fin,
  activa,
  envio_inicial_intentado,
  estado_compartir,
  compartido_en,
  eliminado_en,
  cliente_actualizado_en
)
  on table public.emergency_events
  to authenticated;


-- EMERGENCY EVENT DELIVERIES

revoke all on table public.emergency_event_deliveries
  from PUBLIC, anon, authenticated;

grant select, insert
  on table public.emergency_event_deliveries
  to authenticated;

grant update (
  canal,
  estado,
  detalle,
  cliente_actualizado_en
)
  on table public.emergency_event_deliveries
  to authenticated;


-- SAVED EARTHQUAKES

revoke all on table public.saved_earthquakes
  from PUBLIC, anon, authenticated;

grant select, insert
  on table public.saved_earthquakes
  to authenticated;

grant update (
  eliminado_en,
  cliente_actualizado_en
)
  on table public.saved_earthquakes
  to authenticated;
