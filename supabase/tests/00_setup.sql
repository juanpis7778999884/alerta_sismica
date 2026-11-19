
\set ON_ERROR_STOP on

-- ============================================================
-- 00_SETUP.SQL
-- Preparacion del entorno PostgreSQL para pruebas locales
-- Proyecto: Alerta Sísmica
--
-- IMPORTANTE:
-- Este archivo es exclusivamente para una base de datos
-- de pruebas. No debe ejecutarse en el proyecto Supabase
-- de produccion.
-- ============================================================


-- ============================================================
-- 01. ESQUEMA AUTH DE PRUEBAS
-- ============================================================

create schema if not exists auth;


-- ============================================================
-- 02. TABLA SIMULADA AUTH.USERS
-- ============================================================

create table if not exists auth.users (
  id uuid primary key,
  email text not null,
  created_at timestamptz not null default pg_catalog.now()
);


-- Asegurar que created_at exista si la tabla ya estaba creada
-- por una version anterior de este archivo.

alter table auth.users
  add column if not exists created_at timestamptz
  not null default pg_catalog.now();


-- ============================================================
-- 03. FUNCION AUTH.UID()
-- ============================================================

create or replace function auth.uid()
returns uuid
language sql
stable
set search_path = ''
as $$
  select nullif(
    pg_catalog.current_setting('request.jwt.claim.sub', true),
    ''
  )::uuid;
$$;


-- ============================================================
-- 04. ROLES DE PRUEBA
-- ============================================================

do $$
begin

  if not exists (
    select 1
    from pg_catalog.pg_roles
    where rolname = 'anon'
  ) then
    create role anon nologin;
  end if;


  if not exists (
    select 1
    from pg_catalog.pg_roles
    where rolname = 'authenticated'
  ) then
    create role authenticated nologin;
  end if;

end;
$$;


-- ============================================================
-- 05. PERMISOS DEL ENTORNO DE PRUEBAS
-- ============================================================

grant usage on schema public to authenticated, anon;

grant usage on schema auth to authenticated, anon;

grant execute on function auth.uid()
to authenticated, anon;


-- Permitir que los roles consulten los usuarios simulados.
-- Las migraciones y las pruebas pueden necesitar esta lectura.

grant select on table auth.users to authenticated, anon;


-- ============================================================
-- 06. USUARIOS DE PRUEBA
-- ============================================================

insert into auth.users (
  id,
  email
)
values
  (
    '11111111-1111-4111-8111-111111111111',
    'usuario-a@example.test'
  ),
  (
    '22222222-2222-4222-8222-222222222222',
    'usuario-b@example.test'
  )
on conflict (id)
do update
set
  email = excluded.email;


-- ============================================================
-- 07. VERIFICACION DEL ENTORNO
-- ============================================================

do $$
begin

  if not exists (
    select 1
    from auth.users
    where id = '11111111-1111-4111-8111-111111111111'
      and email = 'usuario-a@example.test'
  ) then
    raise exception 'No se pudo preparar el usuario de prueba A';
  end if;


  if not exists (
    select 1
    from auth.users
    where id = '22222222-2222-4222-8222-222222222222'
      and email = 'usuario-b@example.test'
  ) then
    raise exception 'No se pudo preparar el usuario de prueba B';
  end if;


  if auth.uid() is not null then
    raise exception
      'La sesion JWT deberia estar vacia al preparar el entorno';
  end if;

end;
$$;


\echo 'ENTORNO DE PRUEBAS PREPARADO CORRECTAMENTE'
