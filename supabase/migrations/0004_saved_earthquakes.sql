
-- =========================================================
-- SAVED EARTHQUAKES
-- =========================================================

create table if not exists public.saved_earthquakes (
  user_id uuid not null
    references public.profiles(id)
    on delete cascade,

  sismo_id text not null,

  magnitud numeric(3, 1) not null,
  lugar text not null,

  latitud double precision not null,
  longitud double precision not null,
  profundidad double precision not null,

  tiempo timestamptz not null,
  url text not null default '',

  es_simulacion boolean not null default false,
  actualizado_evento_en timestamptz,

  guardado_en timestamptz not null default pg_catalog.now(),
  eliminado_en timestamptz,

  creado_en timestamptz not null default pg_catalog.now(),
  actualizado_en timestamptz not null default pg_catalog.now(),
  cliente_actualizado_en timestamptz not null default pg_catalog.now(),
  sincronizado_en timestamptz,

  primary key (user_id, sismo_id),

  constraint saved_earthquakes_sismo_id_valido
    check (
      char_length(sismo_id) between 1 and 120
      and sismo_id = btrim(sismo_id)
    ),

  constraint saved_earthquakes_magnitud_valida
    check (magnitud >= -2.0 and magnitud <= 10.0),

  constraint saved_earthquakes_lugar_valido
    check (char_length(btrim(lugar)) between 1 and 200),

  constraint saved_earthquakes_latitud_valida
    check (latitud >= -90 and latitud <= 90),

  constraint saved_earthquakes_longitud_valida
    check (longitud >= -180 and longitud <= 180),

  constraint saved_earthquakes_profundidad_valida
    check (profundidad >= -100 and profundidad <= 1000),

  constraint saved_earthquakes_url_valida
    check (
      url = ''
      or (
        char_length(url) <= 2048
        and url ~ '^https?://'
      )
    )
);


-- =========================================================
-- COMPATIBILITY
-- =========================================================

alter table public.saved_earthquakes
  drop constraint if exists saved_earthquakes_borrado_valido;


-- =========================================================
-- INDEXES
-- =========================================================

create index if not exists saved_earthquakes_user_tiempo_idx
  on public.saved_earthquakes (user_id, tiempo desc)
  where eliminado_en is null;

create index if not exists saved_earthquakes_user_magnitud_idx
  on public.saved_earthquakes (user_id, magnitud desc)
  where eliminado_en is null;


-- =========================================================
-- TRIGGERS
-- =========================================================

drop trigger if exists saved_earthquakes_set_sync_timestamps
  on public.saved_earthquakes;

create trigger saved_earthquakes_set_sync_timestamps
  before insert on public.saved_earthquakes
  for each row
  execute function public.set_sync_timestamps();


drop trigger if exists saved_earthquakes_apply_logical_delete
  on public.saved_earthquakes;

create trigger saved_earthquakes_apply_logical_delete
  before update on public.saved_earthquakes
  for each row
  execute function public.apply_logical_delete();


drop trigger if exists saved_earthquakes_enforce_immutable
  on public.saved_earthquakes;

create trigger saved_earthquakes_enforce_immutable
  before update on public.saved_earthquakes
  for each row
  execute function public.enforce_immutable_columns(
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


drop trigger if exists saved_earthquakes_touch_actualizado_en
  on public.saved_earthquakes;

create trigger saved_earthquakes_touch_actualizado_en
  before update on public.saved_earthquakes
  for each row
  execute function public.touch_actualizado_en();


-- =========================================================
-- ROW LEVEL SECURITY
-- =========================================================

alter table public.saved_earthquakes
  enable row level security;


drop policy if exists saved_earthquakes_select_own
  on public.saved_earthquakes;

create policy saved_earthquakes_select_own
  on public.saved_earthquakes
  for select
  to authenticated
  using (user_id = auth.uid());


drop policy if exists saved_earthquakes_insert_own
  on public.saved_earthquakes;

create policy saved_earthquakes_insert_own
  on public.saved_earthquakes
  for insert
  to authenticated
  with check (user_id = auth.uid());


drop policy if exists saved_earthquakes_update_own
  on public.saved_earthquakes;

create policy saved_earthquakes_update_own
  on public.saved_earthquakes
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());


drop policy if exists saved_earthquakes_delete_own
  on public.saved_earthquakes;


-- =========================================================
-- PRIVILEGES
-- =========================================================

revoke all on table public.saved_earthquakes
  from PUBLIC, anon;

revoke update, delete on table public.saved_earthquakes
  from authenticated;

grant select, insert on table public.saved_earthquakes
  to authenticated;

grant update (
  eliminado_en,
  cliente_actualizado_en
)
  on table public.saved_earthquakes
  to authenticated;
