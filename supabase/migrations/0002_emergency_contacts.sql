
-- ============================================================
-- EMERGENCY CONTACTS
-- Proyecto: Alerta Sísmica
-- ============================================================

create table if not exists public.emergency_contacts (
  id uuid primary key,

  user_id uuid not null
    references public.profiles(id)
    on delete cascade,

  nombre text not null,
  telefono text not null,

  telefono_digits text generated always as (
    pg_catalog.regexp_replace(telefono, '[^0-9]', '', 'g')
  ) stored,

  prioritario boolean not null default false,

  creado_en timestamptz not null default pg_catalog.now(),
  eliminado_en timestamptz,
  actualizado_en timestamptz not null default pg_catalog.now(),
  cliente_actualizado_en timestamptz not null default pg_catalog.now(),
  sincronizado_en timestamptz,

  constraint emergency_contacts_nombre_valido
    check (
      char_length(btrim(nombre)) between 2 and 60
    ),

  constraint emergency_contacts_telefono_valido
    check (
      char_length(telefono_digits) between 7 and 15
      and telefono_digits !~ '^0+$'
    )
);


-- ============================================================
-- INDEXES
-- ============================================================

create index if not exists emergency_contacts_user_activos_idx
  on public.emergency_contacts (user_id, creado_en desc)
  where eliminado_en is null;

create unique index if not exists emergency_contacts_user_telefono_activo_key
  on public.emergency_contacts (user_id, telefono_digits)
  where eliminado_en is null;


-- ============================================================
-- PROTECT DELETED CONTACTS
-- ============================================================

create or replace function public.emergency_contacts_guard_deleted()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if old.eliminado_en is not null then

    if new.nombre is distinct from old.nombre
       or new.telefono is distinct from old.telefono
       or new.prioritario is distinct from old.prioritario then

      raise exception
        using
          errcode = '23514',
          message = 'No se puede modificar el contenido de un contacto eliminado.';

    end if;

  end if;

  return new;
end;
$$;


revoke all on function public.emergency_contacts_guard_deleted()
  from PUBLIC, anon, authenticated;


-- ============================================================
-- TRIGGERS
-- ============================================================

drop trigger if exists emergency_contacts_set_sync_timestamps
  on public.emergency_contacts;

create trigger emergency_contacts_set_sync_timestamps
  before insert on public.emergency_contacts
  for each row
  execute function public.set_sync_timestamps();


drop trigger if exists emergency_contacts_apply_logical_delete
  on public.emergency_contacts;

create trigger emergency_contacts_apply_logical_delete
  before update on public.emergency_contacts
  for each row
  execute function public.apply_logical_delete();


drop trigger if exists emergency_contacts_enforce_immutable
  on public.emergency_contacts;

create trigger emergency_contacts_enforce_immutable
  before update on public.emergency_contacts
  for each row
  execute function public.enforce_immutable_columns(
    'id',
    'user_id',
    'creado_en',
    'actualizado_en',
    'sincronizado_en'
  );


drop trigger if exists emergency_contacts_guard_deleted
  on public.emergency_contacts;

create trigger emergency_contacts_guard_deleted
  before update on public.emergency_contacts
  for each row
  execute function public.emergency_contacts_guard_deleted();


drop trigger if exists emergency_contacts_touch_actualizado_en
  on public.emergency_contacts;

create trigger emergency_contacts_touch_actualizado_en
  before update on public.emergency_contacts
  for each row
  execute function public.touch_actualizado_en();


-- ============================================================
-- ROW LEVEL SECURITY
-- ============================================================

alter table public.emergency_contacts
  enable row level security;


drop policy if exists emergency_contacts_select_own
  on public.emergency_contacts;

create policy emergency_contacts_select_own
  on public.emergency_contacts
  for select
  to authenticated
  using (user_id = (select auth.uid());


drop policy if exists emergency_contacts_insert_own
  on public.emergency_contacts;

create policy emergency_contacts_insert_own
  on public.emergency_contacts
  for insert
  to authenticated
  with check (user_id = (select auth.uid()));


drop policy if exists emergency_contacts_update_own
  on public.emergency_contacts;

create policy emergency_contacts_update_own
  on public.emergency_contacts
  for update
  to authenticated
  using (user_id = (select auth.uid()))
  with check (user_id = (select auth.uid()));


drop policy if exists emergency_contacts_delete_own
  on public.emergency_contacts;


-- ============================================================
-- PRIVILEGES
-- ============================================================

revoke all on table public.emergency_contacts
  from PUBLIC, anon;

revoke update, delete on table public.emergency_contacts
  from authenticated;

grant select, insert on table public.emergency_contacts
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
