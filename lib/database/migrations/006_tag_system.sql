-- Migration 006: Sistema completo de tags con identidad propia, aliases y relaciones
-- Reemplaza el sistema anterior de tags de texto libre con una arquitectura de tags estructurados

-- Tabla principal de tags: cada tag tiene identidad única, tipo y nombre canónico
CREATE TABLE tags (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  canonical_name TEXT UNIQUE NOT NULL,
  display_name TEXT NOT NULL,
  tag_type TEXT NOT NULL,
  description TEXT,
  parent_tag_id INTEGER,
  confidence REAL DEFAULT 0.95,
  created_at INTEGER DEFAULT (strftime('%s', 'now')),
  FOREIGN KEY(parent_tag_id) REFERENCES tags(id) ON DELETE SET NULL
);

-- Índices para búsqueda rápida de tags
CREATE INDEX idx_tags_canonical_name ON tags(canonical_name);
CREATE INDEX idx_tags_tag_type ON tags(tag_type);
CREATE INDEX idx_tags_parent_tag_id ON tags(parent_tag_id);

-- Tabla de aliases: múltiples formas de escribir un mismo tag
-- Ejemplo: "messi", "leo messi", "lionel messi" → todos apuntan al tag ID 10001
CREATE TABLE tag_aliases (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tag_id INTEGER NOT NULL,
  alias_text TEXT NOT NULL,
  normalized_alias TEXT NOT NULL,
  source TEXT,
  confidence REAL DEFAULT 0.8,
  created_at INTEGER DEFAULT (strftime('%s', 'now')),
  FOREIGN KEY(tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

-- Índices para búsqueda de aliases (normalizado para búsqueda rápida)
CREATE INDEX idx_tag_aliases_tag_id ON tag_aliases(tag_id);
CREATE INDEX idx_tag_aliases_normalized ON tag_aliases(normalized_alias);
CREATE INDEX idx_tag_aliases_alias_text ON tag_aliases(alias_text);

-- Tabla de relaciones entre tags: define cómo se relacionan conceptos
-- Ejemplo: Lionel Messi → "player_of_team" → Inter Miami
CREATE TABLE tag_relations (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  source_tag_id INTEGER NOT NULL,
  target_tag_id INTEGER NOT NULL,
  relation_type TEXT NOT NULL,
  created_at INTEGER DEFAULT (strftime('%s', 'now')),
  FOREIGN KEY(source_tag_id) REFERENCES tags(id) ON DELETE CASCADE,
  FOREIGN KEY(target_tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

-- Índices para expansión de relaciones durante búsqueda
CREATE INDEX idx_tag_relations_source ON tag_relations(source_tag_id);
CREATE INDEX idx_tag_relations_target ON tag_relations(target_tag_id);
CREATE INDEX idx_tag_relations_type ON tag_relations(relation_type);

-- Tabla de asociación imagen-tag: relación muchos-a-muchos entre wallpapers y tags
CREATE TABLE image_tags (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  wallpaper_id TEXT NOT NULL,
  tag_id INTEGER NOT NULL,
  confidence REAL DEFAULT 0.95,
  source TEXT,
  created_at INTEGER DEFAULT (strftime('%s', 'now')),
  FOREIGN KEY(wallpaper_id) REFERENCES wallpapers(id) ON DELETE CASCADE,
  FOREIGN KEY(tag_id) REFERENCES tags(id) ON DELETE CASCADE
);

-- Índices para búsqueda rápida por imagen o por tag
CREATE INDEX idx_image_tags_wallpaper_id ON image_tags(wallpaper_id);
CREATE INDEX idx_image_tags_tag_id ON image_tags(tag_id);
CREATE INDEX idx_image_tags_confidence ON image_tags(confidence DESC);

-- Tabla de tipos de tags (para mantener lista de tipos válidos)
-- Esto permite validación y documentación de tipos disponibles
CREATE TABLE tag_types (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  type_name TEXT UNIQUE NOT NULL,
  description TEXT,
  created_at INTEGER DEFAULT (strftime('%s', 'now'))
);

-- Índices para tipos
CREATE INDEX idx_tag_types_name ON tag_types(type_name);

-- Insertar tipos de tags válidos
INSERT INTO tag_types (type_name, description) VALUES
  ('PERSON', 'Personas famosas, deportistas, actores'),
  ('TEAM', 'Equipos, clubes, organizaciones'),
  ('SPORT', 'Deportes y disciplinas'),
  ('COMPETITION', 'Torneos y competiciones'),
  ('FRANCHISE', 'Franquicias, universos, sagas'),
  ('CHARACTER', 'Personajes ficticios'),
  ('GAME', 'Videojuegos específicos'),
  ('MOVIE', 'Películas específicas'),
  ('TV_SHOW', 'Series de TV'),
  ('ANIME', 'Anime y manga específicos'),
  ('COUNTRY', 'Países y regiones'),
  ('CITY', 'Ciudades específicas'),
  ('PLACE', 'Lugares, monumentos, atracciones'),
  ('VEHICLE', 'Vehículos específicos'),
  ('BRAND', 'Marcas y fabricantes'),
  ('ANIMAL', 'Animales específicos'),
  ('GENRE', 'Géneros artísticos'),
  ('STYLE', 'Estilos visuales'),
  ('COLOR', 'Colores dominantes'),
  ('THEME', 'Temas conceptuales'),
  ('CONCEPT', 'Conceptos generales');

-- Migración: Mantener compatibilidad hacia atrás
-- Los campos tags antiguos en wallpapers se migrarán gradualmente
-- Por ahora conviven ambos sistemas durante transición
