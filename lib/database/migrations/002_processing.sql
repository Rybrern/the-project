-- Tabla de jerarquía de categorías
CREATE TABLE category_hierarchy (
  id TEXT PRIMARY KEY,
  parent_id TEXT,
  name TEXT NOT NULL,
  emoji TEXT NOT NULL,
  description TEXT,
  priority INTEGER DEFAULT 0,
  force_portrait_crop INTEGER NOT NULL DEFAULT 1,
  discovery_queries TEXT, -- JSON array
  created_at INTEGER NOT NULL,
  FOREIGN KEY(parent_id) REFERENCES category_hierarchy(id)
);

CREATE INDEX idx_category_hierarchy_parent ON category_hierarchy(parent_id);

-- Tabla de registros de procesamiento
CREATE TABLE processing_records (
  id TEXT PRIMARY KEY,
  source_url TEXT NOT NULL,
  source_id TEXT,
  wallpaper_id TEXT,
  status TEXT NOT NULL, -- 'processed' | 'rejected' | 'duplicate' | 'error'
  rejection_reason TEXT,
  metadata TEXT, -- JSON
  processed_at INTEGER NOT NULL,
  processing_time_ms INTEGER NOT NULL,
  created_at INTEGER NOT NULL,
  FOREIGN KEY(wallpaper_id) REFERENCES wallpapers(id)
);

CREATE INDEX idx_processing_records_status ON processing_records(status);
CREATE INDEX idx_processing_records_source_id ON processing_records(source_id);
CREATE INDEX idx_processing_records_wallpaper_id ON processing_records(wallpaper_id);
CREATE INDEX idx_processing_records_processed_at ON processing_records(processed_at);

-- Tabla para deduplicación rápida
CREATE TABLE hash_registry (
  hash TEXT PRIMARY KEY,
  perceptual_hash TEXT,
  wallpaper_id TEXT NOT NULL,
  source TEXT NOT NULL,
  registered_at INTEGER NOT NULL,
  FOREIGN KEY(wallpaper_id) REFERENCES wallpapers(id)
);

CREATE INDEX idx_hash_registry_perceptual ON hash_registry(perceptual_hash);
CREATE INDEX idx_hash_registry_wallpaper ON hash_registry(wallpaper_id);

-- Tabla de candidatos rechazados (para análisis)
CREATE TABLE rejected_candidates (
  id TEXT PRIMARY KEY,
  source_url TEXT NOT NULL,
  source_id TEXT,
  rejection_reason TEXT NOT NULL,
  rejection_details TEXT, -- JSON con detalles del por qué
  processed_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);

CREATE INDEX idx_rejected_candidates_reason ON rejected_candidates(rejection_reason);
CREATE INDEX idx_rejected_candidates_source_id ON rejected_candidates(source_id);
