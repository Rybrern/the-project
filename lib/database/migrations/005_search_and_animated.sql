-- Migration 005: Add search index and animated wallpapers table
-- Enables intelligent search and improves animated wallpaper support

-- Search index for quick lookup by normalized terms
CREATE TABLE search_index (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  wallpaper_id TEXT NOT NULL,
  query_text TEXT NOT NULL,
  entity_type TEXT,
  relevance REAL DEFAULT 1.0,
  created_at INTEGER DEFAULT (strftime('%s', 'now')),
  FOREIGN KEY(wallpaper_id) REFERENCES wallpapers(id) ON DELETE CASCADE
);

CREATE INDEX idx_search_index_query
  ON search_index(query_text);

CREATE INDEX idx_search_index_entity_type
  ON search_index(entity_type);

CREATE INDEX idx_search_index_wallpaper_id
  ON search_index(wallpaper_id);

-- Dedicated table for animated wallpapers with full metadata
CREATE TABLE animated_wallpapers (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  external_id TEXT UNIQUE NOT NULL,
  preview_image_url TEXT NOT NULL,
  video_url TEXT NOT NULL,
  preview_video_url TEXT,
  width INTEGER,
  height INTEGER,
  source TEXT,
  source_id TEXT,
  nfsw_score REAL,
  quality_score REAL,
  primary_category TEXT,
  subcategory TEXT,
  tags TEXT,
  search_tokens TEXT,
  entity_metadata TEXT,
  processed_at INTEGER,
  processing_status TEXT,
  created_at INTEGER DEFAULT (strftime('%s', 'now'))
);

CREATE INDEX idx_animated_wallpapers_category
  ON animated_wallpapers(primary_category);

CREATE INDEX idx_animated_wallpapers_processed
  ON animated_wallpapers(processing_status);

CREATE INDEX idx_animated_wallpapers_external_id
  ON animated_wallpapers(external_id);

-- Add pagination support fields to wallpapers
ALTER TABLE wallpapers ADD COLUMN pagination_order INTEGER;

CREATE INDEX idx_wallpapers_pagination
  ON wallpapers(pagination_order);
