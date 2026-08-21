class WallpaperCategory {
  const WallpaperCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.query,
  });

  final String id;
  final String name;
  final String emoji;

  /// Search term used to fetch wallpapers for this category from the API.
  final String query;
}
