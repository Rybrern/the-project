-- Tabla de ratings de usuarios
CREATE TABLE wallpaper_ratings (
  id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
  wallpaper_id TEXT NOT NULL,
  user_id TEXT,
  rating INTEGER NOT NULL CHECK(rating >= 1 AND rating <= 5),
  comment TEXT,
  created_at INTEGER NOT NULL,
  FOREIGN KEY(wallpaper_id) REFERENCES wallpapers(id),
  UNIQUE(wallpaper_id, user_id)
);

CREATE INDEX idx_wallpaper_ratings_wallpaper ON wallpaper_ratings(wallpaper_id);
CREATE INDEX idx_wallpaper_ratings_user ON wallpaper_ratings(user_id);
CREATE INDEX idx_wallpaper_ratings_created ON wallpaper_ratings(created_at);

-- Tabla de reportes de usuarios
CREATE TABLE wallpaper_reports (
  id TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
  wallpaper_id TEXT NOT NULL,
  reason TEXT NOT NULL, -- 'nsfw', 'quality', 'duplicate', 'offensive', 'broken_link'
  description TEXT,
  user_id TEXT,
  status TEXT DEFAULT 'open', -- 'open', 'closed'
  resolution TEXT,
  created_at INTEGER NOT NULL,
  closed_at INTEGER,
  FOREIGN KEY(wallpaper_id) REFERENCES wallpapers(id)
);

CREATE INDEX idx_wallpaper_reports_status ON wallpaper_reports(status);
CREATE INDEX idx_wallpaper_reports_reason ON wallpaper_reports(reason);
CREATE INDEX idx_wallpaper_reports_wallpaper ON wallpaper_reports(wallpaper_id);
CREATE INDEX idx_wallpaper_reports_created ON wallpaper_reports(created_at);
