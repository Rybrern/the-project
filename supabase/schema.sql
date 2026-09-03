-- Supabase schema para Fondos HD — catálogo remoto sin actualizar APK
-- Ejecutar en Supabase Dashboard > SQL Editor

-- Tabla principal: wallpapers curados por vos
create table if not exists public.wallpapers (
  id text primary key, -- ej: 'manual_001' o uuid
  full_url text not null, -- https link directo (Storage o externo)
  thumbnail_url text not null,
  preview_url text,
  category text not null default 'manual' check (category in ('naturaleza','abstracto','espacio','minimalista','arquitectura','animales','oscuro','arte','tablets','manual','general')),
  author text not null default 'Manual',
  tags text[] not null default '{}', -- ej: '{"nature","4k"}'
  width int,
  height int,
  file_size int,
  file_type text default 'image/jpeg',
  quality_score double precision,
  is_published boolean not null default true,
  created_at timestamptz not null default now()
);

-- Índices para filtros y búsqueda por tags
create index if not exists wallpapers_published_idx on public.wallpapers (is_published, created_at desc);
create index if not exists wallpapers_category_idx on public.wallpapers (category);
create index if not exists wallpapers_tags_gin on public.wallpapers using gin (tags);

-- RLS: lectura pública, escritura solo con service_role (tu panel admin)
alter table public.wallpapers enable row level security;

drop policy if exists "public can read published" on public.wallpapers;
create policy "public can read published"
  on public.wallpapers for select
  using (is_published = true);

-- Inserción/actualización solo con service_role key (no anon). No crear policy para anon insert.

-- Bucket Storage para subir imágenes directamente a Supabase (opcional, recomendado)
-- Dashboard > Storage > Create bucket: 'wallpapers' (public)
-- Luego subir via panel o via admin web. URL pública: https://xxx.supabase.co/storage/v1/object/public/wallpapers/...

-- Ejemplo insert:
-- insert into public.wallpapers (id, full_url, thumbnail_url, category, tags, width, height)
-- values ('manual_002', 'https://xxx.supabase.co/storage/v1/object/public/wallpapers/4k_01.jpg', 'https://xxx.supabase.co/storage/v1/object/public/wallpapers/4k_01_thumb.jpg', 'naturaleza', '{"nature","4k"}', 3840, 2160);

-- Vista para app: solo publicados, ordenados por creados
create or replace view public.published_wallpapers as
  select * from public.wallpapers where is_published = true order by created_at desc;

-- ============================================================
-- Subida de usuarios + moderación (correr después de lo de arriba)
-- ============================================================

-- Distingue origen (panel admin vs. subido por un usuario de la app) y
-- habilita el límite de abuso por dispositivo más abajo.
alter table public.wallpapers add column if not exists source text not null default 'admin' check (source in ('admin', 'user'));
alter table public.wallpapers add column if not exists device_id text;

-- Defensa en profundidad a nivel DB — no depender solo de la validación
-- del cliente (Flutter/Next), que un atacante puede saltarse pegándole
-- directo a la API de Supabase con la anon key.
alter table public.wallpapers add constraint wallpapers_full_url_https check (full_url like 'https://%');
alter table public.wallpapers add constraint wallpapers_thumb_url_https check (thumbnail_url like 'https://%');
alter table public.wallpapers add constraint wallpapers_tags_len check (array_length(tags, 1) is null or array_length(tags, 1) <= 15);

-- La app solo puede insertar fondos propios pendientes de moderación, nunca
-- publicados directamente. No hay policy de update/select/delete: el
-- default-deny de RLS ya impide ver u operar sobre filas ajenas o no
-- publicadas (la policy de SELECT de arriba sigue acotada a is_published).
--
-- Requiere sesión anónima de Supabase Auth (Dashboard > Authentication >
-- Sign In / Providers > Anonymous sign-ins). El insert va contra el rol
-- 'authenticated', no 'anon', y `device_id` queda atado a `auth.uid()`:
-- el identificador lo emite el servidor dentro del JWT, así que el cliente
-- ya no puede inventarlo. Sin eso, bastaba con mandar un device_id nuevo en
-- cada request para saltarse el tope de pendientes de más abajo (auditoría
-- 2026-09-02: se demostró insertando 3 filas seguidas con ids inventados).
drop policy if exists "anon can submit pending" on public.wallpapers;
drop policy if exists "authenticated can submit pending" on public.wallpapers;
create policy "authenticated can submit pending"
  on public.wallpapers for insert
  to authenticated
  with check (
    is_published = false
    and source = 'user'
    and device_id = auth.uid()::text
  );

-- Tope de envíos pendientes simultáneos por dispositivo: mitiga spam sin
-- necesitar un sistema de autenticación de usuarios completo. Una vez que
-- un admin aprueba o rechaza un pendiente, el cupo se libera solo.
create or replace function public.enforce_pending_limit() returns trigger as $$
begin
  if (select count(*) from public.wallpapers where device_id = new.device_id and is_published = false) >= 5 then
    raise exception 'Demasiados fondos pendientes de moderación para este dispositivo';
  end if;
  return new;
end;
$$ language plpgsql security definer;

drop trigger if exists trg_enforce_pending_limit on public.wallpapers;
create trigger trg_enforce_pending_limit
  before insert on public.wallpapers
  for each row when (new.source = 'user')
  execute function public.enforce_pending_limit();

-- Storage: el bucket 'wallpapers' necesita su propia policy (las policies de
-- Storage viven en storage.objects, NO en esta tabla). Acota la escritura a
-- la carpeta del propio usuario: user-submitted/<auth.uid()>/archivo.jpg.
-- Sin el segundo segmento atado a auth.uid(), cualquiera con la clave
-- pública podía escribir en carpetas arbitrarias (auditoría 2026-09-02).
drop policy if exists "anon can upload user-submitted" on storage.objects;
drop policy if exists "authenticated can upload own folder" on storage.objects;
create policy "authenticated can upload own folder"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'wallpapers'
    and (storage.foldername(name))[1] = 'user-submitted'
    and (storage.foldername(name))[2] = auth.uid()::text
  );

-- Complemento fuera de SQL (Dashboard > Storage > wallpapers > Settings),
-- ya aplicado por API el 2026-09-02: límite de 25MB por archivo y MIME types
-- restringidos a image/jpeg, image/png, image/webp. Sin eso el bucket
-- aceptaba archivos de cualquier tipo y tamaño.
