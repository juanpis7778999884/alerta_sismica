
create or replace function public.touch_actualizado_en()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.actualizado_en = pg_catalog.now();
  return new;
end;
$$;

create or replace function public.set_server_timestamps()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.creado_en = pg_catalog.now();
  new.actualizado_en = pg_catalog.now();
  new.sincronizado_en = null;
  return new;
end;
$$;

create or replace function public.set_sync_timestamps()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.creado_en = pg_catalog.now();
  new.actualizado_en = pg_catalog.now();
  new.sincronizado_en = null;

  if new.eliminado_en is not null then
    new.eliminado_en = pg_catalog.now();
  end if;

  return new;
end;
$$;

create or replace function public.apply_logical_delete()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;

  if old.eliminado_en is not null and new.eliminado_en is null then
    raise exception
      using errcode = '23514',
            message = 'No se puede reactivar un registro eliminado lógicamente.';
  end if;

  if new.eliminado_en is not null and old.eliminado_en is null then
    new.eliminado_en = pg_catalog.now();
  elsif old.eliminado_en is not null then
    new.eliminado_en = old.eliminado_en;
  end if;

  return new;
end;
$$;

create or replace function public.enforce_immutable_columns()
returns trigger
language plpgsql
set search_path = ''
as $$
declare
  v_columna text;
begin
  foreach v_columna in array tg_argv loop
    if (pg_catalog.to_jsonb(new) -> v_columna)
       is distinct from
       (pg_catalog.to_jsonb(old) -> v_columna) then
      raise exception
        using errcode = '42501',
              message = pg_catalog.format(
                'La columna %s no es modificable.',
                v_columna
              );
    end if;
  end loop;

  return new;
end;
$$;

create or replace function public.profiles_enforce_auth_identity()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_email text;
begin
  if tg_op = 'INSERT' then
    if auth.uid() is null or new.id is distinct from auth.uid() then
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

    new.email = pg_catalog.lower(pg_catalog.btrim(v_email));
    new.creado_en = pg_catalog.now();
    new.actualizado_en = pg_catalog.now();
    new.sincronizado_en = null;

    return new;
  end if;

  if new.id is distinct from old.id
     or new.legacy_local_id is distinct from old.legacy_local_id
     or new.email is distinct from old.email
     or new.creado_en is distinct from old.creado_en
     or new.sincronizado_en is distinct from old.sincronizado_en then
    raise exception
      using errcode = '42501',
            message = 'La identidad del perfil no es modificable.';
  end if;

  return new;
end;
$$;

revoke all on function public.touch_actualizado_en()
  from PUBLIC, anon, authenticated;

revoke all on function public.set_server_timestamps()
  from PUBLIC, anon, authenticated;

revoke all on function public.set_sync_timestamps()
  from PUBLIC, anon, authenticated;

revoke all on function public.apply_logical_delete()
  from PUBLIC, anon, authenticated;

revoke all on function public.enforce_immutable_columns()
  from PUBLIC, anon, authenticated;

revoke all on function public.profiles_enforce_auth_identity()
  from PUBLIC, anon, authenticated;


-- =========================================================
-- PROFILES
-- =========================================================

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  legacy_local_id uuid unique,
  nombre text not null,
  email text not null,

  creado_en timestamptz not null default pg_catalog.now(),
  actualizado_en timestamptz not null default pg_catalog.now(),
  cliente_actualizado_en timestamptz not null default pg_catalog.now(),
  sincronizado_en timestamptz,

  constraint profiles_nombre_valido
    check (char_length(btrim(nombre)) between 2 and 80),

  constraint profiles_email_valido
    check (
      char_length(email) between 3 and 254
      and btrim(email) = email
      and email = lower(email)
      and email ~ '^[^@[:space:]]+@[^@[:space:]]+\.[^@[:space:]]+$'
    )
);

create unique index if not exists profiles_email_unique
  on public.profiles (lower(email));


drop trigger if exists profiles_enforce_auth_identity
  on public.profiles;

create trigger profiles_enforce_auth_identity
  before insert or update on public.profiles
  for each row
  execute function public.profiles_enforce_auth_identity();


drop trigger if exists profiles_touch_actualizado_en
  on public.profiles;

create trigger profiles_touch_actualizado_en
  before update on public.profiles
  for each row
  execute function public.touch_actualizado_en();


alter table public.profiles enable row level security;


drop policy if exists profiles_select_own
  on public.profiles;

create policy profiles_select_own
  on public.profiles
  for select
  to authenticated
  using (id = auth.uid());


drop policy if exists profiles_insert_own
  on public.profiles;

create policy profiles_insert_own
  on public.profiles
  for insert
  to authenticated
  with check (id = auth.uid());


drop policy if exists profiles_update_own
  on public.profiles;

create policy profiles_update_own
  on public.profiles
  for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());


drop policy if exists profiles_delete_own
  on public.profiles;


revoke all on table public.profiles from PUBLIC, anon;

revoke update, delete on table public.profiles
  from authenticated;

grant select, insert on table public.profiles
  to authenticated;

grant update (nombre, cliente_actualizado_en)
  on table public.profiles
  to authenticated;


-- =========================================================
-- USER SETTINGS
-- =========================================================

create table if not exists public.user_settings (
  user_id uuid primary key references public.profiles(id) on delete cascade,

  tema text not null default 'claro',
  magnitud_minima numeric(3, 1) not null default 2.5,
  auto_refresco boolean not null default true,
  notificar_sismos boolean not null default false,
  umbral_notificacion numeric(3, 1) not null default 4.5,
  numero_emergencia text not null default '',

  creado_en timestamptz not null default pg_catalog.now(),
  actualizado_en timestamptz not null default pg_catalog.now(),
  cliente_actualizado_en timestamptz not null default pg_catalog.now(),
  sincronizado_en timestamptz,

  constraint user_settings_tema_valido
    check (tema in ('claro', 'oscuro', 'sistema')),

  constraint user_settings_magnitud_valida
    check (magnitud_minima >= 1.0 and magnitud_minima <= 7.0),

  constraint user_settings_umbral_valido
    check (umbral_notificacion >= 2.5 and umbral_notificacion <= 7.0),

  constraint user_settings_numero_emergencia_valido
    check (
      char_length(numero_emergencia) <= 32
      and (
        numero_emergencia = ''
        or char_length(
          regexp_replace(numero_emergencia, '[^0-9]', '', 'g')
        ) between 3 and 15
      )
    )
);


drop trigger if exists user_settings_set_server_timestamps
  on public.user_settings;

create trigger user_settings_set_server_timestamps
  before insert on public.user_settings
  for each row
  execute function public.set_server_timestamps();


drop trigger if exists user_settings_enforce_immutable
  on public.user_settings;

create trigger user_settings_enforce_immutable
  before update on public.user_settings
  for each row
  execute function public.enforce_immutable_columns(
    'user_id',
    'creado_en'
  );


drop trigger if exists user_settings_touch_actualizado_en
  on public.user_settings;

create trigger user_settings_touch_actualizado_en
  before update on public.user_settings
  for each row
  execute function public.touch_actualizado_en();


alter table public.user_settings enable row level security;


drop policy if exists user_settings_select_own
  on public.user_settings;

create policy user_settings_select_own
  on public.user_settings
  for select
  to authenticated
  using (user_id = auth.uid());


drop policy if exists user_settings_insert_own
  on public.user_settings;

create policy user_settings_insert_own
  on public.user_settings
  for insert
  to authenticated
  with check (user_id = auth.uid());


drop policy if exists user_settings_update_own
  on public.user_settings;

create policy user_settings_update_own
  on public.user_settings
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());


drop policy if exists user_settings_delete_own
  on public.user_settings;


revoke all on table public.user_settings from PUBLIC, anon;

revoke update, delete on table public.user_settings
  from authenticated;

grant select, insert on table public.user_settings
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
