class Wallpaper {
  const Wallpaper({
    required this.id,
    required this.thumbnailUrl,
    required this.fullUrl,
    required this.author,
    required this.category,
    required this.aspectRatio,
    this.forcePortraitCrop = true,
  });

  final String id;
  final String thumbnailUrl;
  final String fullUrl;
  final String author;
  final String category;
  final double aspectRatio;

  /// Copiado desde [WallpaperCategory.forcePortraitCrop] al momento de crear
  /// el fondo, para que la pantalla de detalle sepa si debe recortarlo al
  /// aplicarlo o dejarlo tal cual (categorías tipo "Tablets").
  final bool forcePortraitCrop;
}
