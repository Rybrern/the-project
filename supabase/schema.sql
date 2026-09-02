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
