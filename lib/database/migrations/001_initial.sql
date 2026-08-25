-- Tabla de wallpapers (extendida con metadatos de ingesta)
CREATE TABLE wallpapers (
  id TEXT PRIMARY KEY,
  thumbnail_url TEXT NOT NULL,
  full_url TEXT NOT NULL,
  author TEXT NOT NULL,
  category TEXT NOT NULL,
  aspect_ratio REAL NOT NULL,
  force_portrait_crop INTEGER NOT NULL DEFAULT 1,

  -- Metadatos de procesamiento
  source TEXT,
  source_id TEXT,
  original_url TEXT,
  file_hash TEXT UNIQUE,
  perceptual_hash TEXT,
  nsfw_score REAL,
  quality_score REAL,
  primary_category TEXT,
  subcategory TEXT,
  tags TEXT, -- JSON array

  processed_at INTEGER,
  processing_status TEXT DEFAULT 'accepted',
  rejection_reason TEXT,

  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

-- Índices para búsquedas frecuentes
CREATE INDEX idx_wallpapers_source ON wallpapers(source);
CREATE INDEX idx_wallpapers_primary_category ON wallpapers(primary_category);
CREATE INDEX idx_wallpapers_subcategory ON wallpapers(subcategory);
CREATE INDEX idx_wallpapers_nsfw_score ON wallpapers(nsfw_score);
CREATE INDEX idx_wallpapers_file_hash ON wallpapers(file_hash);
CREATE INDEX idx_wallpapers_perceptual_hash ON wallpapers(perceptual_hash);
