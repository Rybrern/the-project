class Wallpaper {
  const Wallpaper({
    required this.id,
    required this.thumbnailUrl,
    required this.fullUrl,
    required this.author,
    required this.category,
    required this.aspectRatio,
    this.forcePortraitCrop = true,
    this.source,
    this.sourceId,
    this.originalUrl,
    this.tags,
    this.width,
    this.height,
    this.fileSize,
    this.fileType,
    this.qualityScore,
    this.previewUrl,
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

  // --- Metadatos de Wallhaven / catálogo manual ---
  final String? source; // 'wallhaven' | 'manual'
  final String? sourceId;
  final String? originalUrl; // https://wallhaven.cc/w/<id>
  final List<String>? tags; // tags oficiales de Wallhaven
  final int? width;
  final int? height;
  final int? fileSize; // bytes
  final String? fileType; // 'image/jpeg', 'image/png'
  final double? qualityScore; // 0.0 - 1.0 basado en resolución
  final String? previewUrl; // url intermedia entre thumb y full

  /// Tokens normalizados para búsqueda local (lowercase, sin duplicados)
  List<String> get searchTokens {
    final set = <String>{};
    for (final t in tags ?? const <String>[]) {
      set.add(t.toLowerCase().trim());
    }
    set.add(category.toLowerCase());
    return set.where((s) => s.isNotEmpty).toList();
  }

  Wallpaper copyWith({
    String? id,
    String? thumbnailUrl,
    String? fullUrl,
    String? author,
    String? category,
    double? aspectRatio,
    bool? forcePortraitCrop,
    String? source,
    String? sourceId,
    String? originalUrl,
    List<String>? tags,
    int? width,
    int? height,
    int? fileSize,
    String? fileType,
    double? qualityScore,
    String? previewUrl,
  }) {
    return Wallpaper(
      id: id ?? this.id,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      fullUrl: fullUrl ?? this.fullUrl,
      author: author ?? this.author,
      category: category ?? this.category,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      forcePortraitCrop: forcePortraitCrop ?? this.forcePortraitCrop,
      source: source ?? this.source,
      sourceId: sourceId ?? this.sourceId,
      originalUrl: originalUrl ?? this.originalUrl,
      tags: tags ?? this.tags,
      width: width ?? this.width,
      height: height ?? this.height,
      fileSize: fileSize ?? this.fileSize,
      fileType: fileType ?? this.fileType,
      qualityScore: qualityScore ?? this.qualityScore,
      previewUrl: previewUrl ?? this.previewUrl,
    );
  }
}
