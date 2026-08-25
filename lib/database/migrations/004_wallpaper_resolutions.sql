-- Migration 004: Add wallpaper resolutions table
-- Allows storing multiple resolution versions of the same wallpaper
-- (thumbnail, preview, original)

CREATE TABLE wallpaper_resolutions (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  wallpaper_id TEXT NOT NULL,
  resolution_type TEXT NOT NULL,
  url TEXT NOT NULL UNIQUE,
  width INTEGER,
  height INTEGER,
  file_size_bytes INTEGER,
  created_at INTEGER DEFAULT (strftime('%s', 'now')),
  FOREIGN KEY(wallpaper_id) REFERENCES wallpapers(id) ON DELETE CASCADE
);

CREATE INDEX idx_wallpaper_resolutions_wallpaper_id
  ON wallpaper_resolutions(wallpaper_id, resolution_type);

CREATE INDEX idx_wallpaper_resolutions_type
  ON wallpaper_resolutions(resolution_type);

-- Add preview_url and search_tokens to wallpapers table
ALTER TABLE wallpapers ADD COLUMN preview_url TEXT;
ALTER TABLE wallpapers ADD COLUMN search_tokens TEXT;
ALTER TABLE wallpapers ADD COLUMN entity_metadata TEXT;
