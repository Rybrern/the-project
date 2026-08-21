class WallpaperCategory {
  const WallpaperCategory({
    required this.id,
    required this.name,
    required this.emoji,
    required this.query,
    this.ratios,
    this.forcePortraitCrop = true,
  });

  final String id;
  final String name;
  final String emoji;

  /// Search term used to fetch wallpapers for this category from the API.
  final String query;

  /// Optional aspect-ratio filter passed straight to the API (Wallhaven's
  /// `ratios` search param), e.g. `'16x9,16x10'` for landscape categories.
  final String? ratios;

  /// Whether "usar como fondo de pantalla" should center-crop the image to
  /// match the phone's screen. Landscape/tablet categories opt out of this
  /// since forcing a portrait crop would ruin the composition.
  final bool forcePortraitCrop;
}
