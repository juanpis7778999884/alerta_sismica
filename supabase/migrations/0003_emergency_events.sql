
-- =========================================================
-- EMERGENCY EVENTS: CONFLICT RESOLUTION
-- =========================================================

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
  if auth.uid() is null or new.user_id is distinct from auth.uid() then
    raise exception
      using errcode = '42501',
            message = 'El evento debe pertenecer al usuario autenticado.';
  end if;

  -- Los eventos de sismo no participan en conflictos SOS.
  if new.tipo <> 'sos'
     or new.activa is not true
     or new.eliminado_en is not null then
    return new;
  end if;

  -- Serializa la resolución de conflictos por usuario.
  perform pg_catalog.pg_advisory_xact_lock(
    pg_catalog.hashtextextended(new.user_id::text, 0)
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
    and e.activa
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

  -- Gana el evento con mayor tupla de prioridad.
  v_new_wins :=
    (new.cliente_actualizado_en, new.inicio, new.id)
    > (v_other_cliente, v_other_inicio, v_other_id);

  if v_new_wins then
    update public.emergency_events e
       set activa = false,
           fin = GREATEST(e.inicio, pg_catalog.now()),
           motivo_fin = 'conflicto_multidispositivo'
     where e.id = v_other_id
       and e.user_id = new.user_id
       and e.user_id = auth.uid()
       and e.tipo = 'sos'
       and e.activa
       and e.eliminado_en is null;

    if not found then
      raise exception
        using errcode = '40001',
              message = 'No se pudo resolver el conflicto SOS; reintente la sincronización.';
    end if;
  else
    new.activa = false;
    new.fin = GREATEST(new.inicio, pg_catalog.now());
    new.motivo_fin = 'conflicto_multidispositivo';
  end if;

  return new;
end;
$$;

revoke all on function public.resolve_active_sos_conflict()
  from PUBLIC, anon, authenticated;


-- =========================================================
-- EMERGENCY EVENTS
-- =========================================================

create table if not exists public.emergency_events (
  id text primary key,

  user_id uuid not null
    references public.profiles(id)
    on delete cascade,

  tipo text not null,
  usuario_nombre text not null,
  inicio timestamptz not null,
  fin timestamptz,
  activa boolean not null default true,
  motivo_fin text,

  mensaje text not null default '',
  envio_inicial_intentado boolean not null default false,

  latitud double precision,
  longitud double precision,
  precision_metros double precision,
  ubicacion_legible text,

  estado_compartir text,
  compartido_en timestamptz,
  referencia_evento_id text,
  fuente_ubicacion text,

  eliminado_en timestamptz,

  creado_en timestamptz not null default pg_catalog.now(),
  actualizado_en timestamptz not null default pg_catalog.now(),
  cliente_actualizado_en timestamptz not null default pg_catalog.now(),
  sincronizado_en timestamptz,

  constraint emergency_events_id_valido
    check (char_length(id) between 1 and 80),

  constraint emergency_events_tipo_valido
    check (tipo in ('sos', 'sismo')),

  constraint emergency_events_usuario_nombre_valido
    check (char_length(btrim(usuario_nombre)) between 1 and 80),

  constraint emergency_events_motivo_fin_valido
    check (
      motivo_fin is null
      or motivo_fin in ('manual', 'conflicto_multidispositivo')
    ),

  constraint emergency_events_mensaje_valido
    check (char_length(mensaje) <= 8000),

  constraint emergency_events_tiempo_valido
    check (fin is null or fin >= inicio),

  constraint emergency_events_latitud_valido
    check (latitud is null or (latitud >= -90 and latitud <= 90)),

  constraint emergency_events_longitud_valido
    check (longitud is null or (longitud >= -180 and longitud <= 180)),

  constraint emergency_events_precision_valido
    check (precision_metros is null or precision_metros >= 0),

  constraint emergency_events_coordenadas_completas
    check (
      (latitud is null and longitud is null)
      or (latitud is not null and longitud is not null)
    ),

  constraint emergency_events_ubicacion_legible_valida
    check (
      ubicacion_legible is null
      or char_length(ubicacion_legible) <= 500
    ),

  constraint emergency_events_estado_compartir_valido
    check (
      estado_compartir is null
      or estado_compartir in (
        'pendiente',
        'abiertoEnApp',
        'cancelado',
        'fallido',
        'noDisponible'
      )
    ),

  constraint emergency_events_referencia_valida
    check (
      referencia_evento_id is null
      or char_length(referencia_evento_id) <= 120
    ),

  constraint emergency_events_fuente_ubicacion_valida
    check (
      fuente_ubicacion is null
      or fuente_ubicacion in ('gps', 'ultimaConocida')
    )
);


-- Compatibilidad con instalaciones donde la tabla ya existía.
alter table public.emergency_events
  add column if not exists motivo_fin text;

alter table public.emergency_events
  drop constraint if exists emergency_events_borrado_valido;


do $$
begin
  if not exists (
    select 1
    from pg_catalog.pg_constraint c
    where c.conrelid = 'public.emergency_events'::regclass
      and c.conname = 'emergency_events_motivo_fin_valido'
  ) then
    alter table public.emergency_events
      add constraint emergency_events_motivo_fin_valido
      check (
        motivo_fin is null
        or motivo_fin in ('manual', 'conflicto_multidispositivo')
      );
  end if;
end;
$$;


-- =========================================================
-- INDEXES
-- =========================================================

create index if not exists emergency_events_user_inicio_idx
  on public.emergency_events (user_id, inicio desc);

-- Solamente puede existir un SOS activo por usuario.
-- Los eventos de tipo sismo no participan en esta restricción.
drop index if exists public.emergency_events_activa_por_usuario_key;

create unique index emergency_events_activa_por_usuario_key
  on public.emergency_events (user_id)
  where tipo = 'sos'
    and activa
    and eliminado_en is null;


-- =========================================================
-- TRIGGERS
-- =========================================================

drop trigger if exists emergency_events_set_sync_timestamps
  on public.emergency_events;

create trigger emergency_events_set_sync_timestamps
  before insert on public.emergency_events
  for each row
  execute function public.set_sync_timestamps();


drop trigger if exists emergency_events_apply_logical_delete
  on public.emergency_events;

create trigger emergency_events_apply_logical_delete
  before update on public.emergency_events
  for each row
  execute function public.apply_logical_delete();


drop trigger if exists emergency_events_enforce_immutable
  on public.emergency_events;

create trigger emergency_events_enforce_immutable
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


drop trigger if exists emergency_events_resolve_active_conflict
  on public.emergency_events;

create trigger emergency_events_resolve_active_conflict
  before insert or update on public.emergency_events
  for each row
  execute function public.resolve_active_sos_conflict();


drop trigger if exists emergency_events_touch_actualizado_en
  on public.emergency_events;

create trigger emergency_events_touch_actualizado_en
  before update on public.emergency_events
  for each row
  execute function public.touch_actualizado_en();


-- =========================================================
-- ROW LEVEL SECURITY: EMERGENCY EVENTS
-- =========================================================

alter table public.emergency_events
  enable row level security;


drop policy if exists emergency_events_select_own
  on public.emergency_events;

create policy emergency_events_select_own
  on public.emergency_events
  for select
  to authenticated
  using (user_id = auth.uid());


drop policy if exists emergency_events_insert_own
  on public.emergency_events;

create policy emergency_events_insert_own
  on public.emergency_events
  for insert
  to authenticated
  with check (user_id = auth.uid());


drop policy if exists emergency_events_update_own
  on public.emergency_events;

create policy emergency_events_update_own
  on public.emergency_events
  for update
  to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());


drop policy if exists emergency_events_delete_own
  on public.emergency_events;


-- =========================================================
-- PRIVILEGES: EMERGENCY EVENTS
-- =========================================================

revoke all on table public.emergency_events
  from PUBLIC, anon;

revoke update, delete on table public.emergency_events
  from authenticated;

grant select, insert on table public.emergency_events
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


-- =========================================================
-- EMERGENCY EVENT DELIVERIES
-- =========================================================

create table if not exists public.emergency_event_deliveries (
  event_id text not null
    references public.emergency_events(id)
    on delete cascade,

  contacto_id text not null,
  nombre text not null,
  telefono text not null,
  prioritario boolean not null default false,

  canal text,
  estado text not null default 'pendiente',
  detalle text,

  creado_en timestamptz not null default pg_catalog.now(),
  actualizado_en timestamptz not null default pg_catalog.now(),
  cliente_actualizado_en timestamptz not null default pg_catalog.now(),
  sincronizado_en timestamptz,

  primary key (event_id, contacto_id),

  constraint emergency_event_deliveries_contacto_id_valido
    check (char_length(contacto_id) between 1 and 80),

  constraint emergency_event_deliveries_nombre_valido
    check (char_length(btrim(nombre)) between 1 and 80),

  constraint emergency_event_deliveries_telefono_valido
    check (char_length(telefono) between 1 and 40),

  constraint emergency_event_deliveries_canal_valido
    check (
      canal is null
      or canal in ('sms', 'whatsapp', 'compartir', 'llamada')
    ),

  constraint emergency_event_deliveries_estado_valido
    check (
      estado in (
        'pendiente',
        'abiertoEnApp',
        'cancelado',
        'fallido',
        'noDisponible'
      )
    ),

  constraint emergency_event_deliveries_detalle_valido
    check (detalle is null or char_length(detalle) <= 500)
);


create index if not exists emergency_event_deliveries_contacto_idx
  on public.emergency_event_deliveries (contacto_id);


-- =========================================================
-- TRIGGERS: EMERGENCY EVENT DELIVERIES
-- =========================================================

drop trigger if exists emergency_event_deliveries_set_server_timestamps
  on public.emergency_event_deliveries;

create trigger emergency_event_deliveries_set_server_timestamps
  before insert on public.emergency_event_deliveries
  for each row
  execute function public.set_server_timestamps();


drop trigger if exists emergency_event_deliveries_enforce_immutable
  on public.emergency_event_deliveries;

create trigger emergency_event_deliveries_enforce_immutable
  before update on public.emergency_event_deliveries
  for each row
  execute function public.enforce_immutable_columns(
    'event_id',
    'contacto_id',
    'nombre',
    'telefono',
    'prioritario',
    'creado_en',
    'actualizado_en',
    'sincronizado_en'
  );


drop trigger if exists emergency_event_deliveries_touch_actualizado_en
  on public.emergency_event_deliveries;

create trigger emergency_event_deliveries_touch_actualizado_en
  before update on public.emergency_event_deliveries
  for each row
  execute function public.touch_actualizado_en();


-- =========================================================
-- ROW LEVEL SECURITY: EMERGENCY EVENT DELIVERIES
-- =========================================================

alter table public.emergency_event_deliveries
  enable row level security;


drop policy if exists emergency_event_deliveries_select_own
  on public.emergency_event_deliveries;

create policy emergency_event_deliveries_select_own
  on public.emergency_event_deliveries
  for select
  to authenticated
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
  for insert
  to authenticated
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
  for update
  to authenticated
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


drop policy if exists emergency_event_deliveries_delete_own
  on public.emergency_event_deliveries;


-- =========================================================
-- PRIVILEGES: EMERGENCY EVENT DELIVERIES
-- =========================================================

revoke all on table public.emergency_event_deliveries
  from PUBLIC, anon;

revoke update, delete on table public.emergency_event_deliveries
  from authenticated;

grant select, insert on table public.emergency_event_deliveries
  to authenticated;

grant update (
  canal,
  estado,
  detalle,
  cliente_actualizado_en
)
  on table public.emergency_event_deliveries
  to authenticated;
