/// Fondo animado (video en loop) traído de Pixabay Video. Se maneja aparte
/// de [Wallpaper] porque su flujo de vista previa y de aplicado es distinto:
/// no hay recorte de imagen, sino un video que se reproduce en bucle mudo
/// tanto en la previsualización como en el fondo de pantalla real.
class AnimatedWallpaper {
  const AnimatedWallpaper({
    required this.id,
    required this.previewImageUrl,
    required this.videoUrl,
    required this.width,
    required this.height,
    // Nuevos campos para feature parity con Wallpaper
    this.previewVideoUrl,
    this.externalId,
    this.source,
    this.sourceId,
    this.nsfwScore,
    this.qualityScore,
    this.primaryCategory,
    this.subcategory,
    this.tags,
    this.searchTokens,
    this.entityMetadata,
    this.processedAt,
    this.processingStatus,
  });

  final String id;
  final String previewImageUrl;
  final String videoUrl;
  final int width;
  final int height;

  /// URL del video comprimido para preview rápido (pre-aplicación)
  final String? previewVideoUrl;
  /// ID único externo de la fuente original
  final String? externalId;
  /// Fuente del fondo animado ('pixabay' | 'custom' | etc)
  final String? source;
  /// ID en la fuente original
  final String? sourceId;
  /// Puntuación NSFW (0.0 - 1.0)
  final double? nsfwScore;
  /// Puntuación de calidad (0.0 - 1.0)
  final double? qualityScore;
  /// Categoría principal ('deportes', 'naturaleza', etc)
  final String? primaryCategory;
  /// Subcategoría ('fútbol', 'paisajes', etc)
  final String? subcategory;
  /// Tags asociados
  final List<String>? tags;
  /// Tokens normalizados para búsqueda
  final List<String>? searchTokens;
  /// Metadatos de entidades (jugadores, equipos, etc.)
  final Map<String, dynamic>? entityMetadata;
  /// Fecha de procesamiento
  final DateTime? processedAt;
  /// Estado del procesamiento ('accepted' | 'rejected' | etc)
  final String? processingStatus;

  double get aspectRatio => width / height;

  AnimatedWallpaper copyWith({
    String? id,
    String? previewImageUrl,
    String? videoUrl,
    int? width,
    int? height,
    String? previewVideoUrl,
    String? externalId,
    String? source,
    String? sourceId,
    double? nsfwScore,
    double? qualityScore,
    String? primaryCategory,
    String? subcategory,
    List<String>? tags,
    List<String>? searchTokens,
    Map<String, dynamic>? entityMetadata,
    DateTime? processedAt,
    String? processingStatus,
  }) {
    return AnimatedWallpaper(
      id: id ?? this.id,
      previewImageUrl: previewImageUrl ?? this.previewImageUrl,
      videoUrl: videoUrl ?? this.videoUrl,
      width: width ?? this.width,
      height: height ?? this.height,
      previewVideoUrl: previewVideoUrl ?? this.previewVideoUrl,
      externalId: externalId ?? this.externalId,
      source: source ?? this.source,
      sourceId: sourceId ?? this.sourceId,
      nsfwScore: nsfwScore ?? this.nsfwScore,
      qualityScore: qualityScore ?? this.qualityScore,
      primaryCategory: primaryCategory ?? this.primaryCategory,
      subcategory: subcategory ?? this.subcategory,
      tags: tags ?? this.tags,
      searchTokens: searchTokens ?? this.searchTokens,
      entityMetadata: entityMetadata ?? this.entityMetadata,
      processedAt: processedAt ?? this.processedAt,
      processingStatus: processingStatus ?? this.processingStatus,
    );
  }
}
