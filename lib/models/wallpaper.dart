class Wallpaper {
  const Wallpaper({
    required this.id,
    required this.thumbnailUrl,
    required this.fullUrl,
    required this.author,
    required this.category,
    required this.aspectRatio,
  });

  final String id;
  final String thumbnailUrl;
  final String fullUrl;
  final String author;
  final String category;
  final double aspectRatio;
}
