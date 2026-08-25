import '../database/daos/wallpaper_resolution_dao.dart';

class Wallpaper {
  const Wallpaper({
    required this.id,
    required this.thumbnailUrl,
    required this.fullUrl,
    required this.author,
    required this.category,
    required this.aspectRatio,
    this.forcePortraitCrop = true,
    // Metadatos de procesamiento (nuevos)
    this.source,
    this.sourceId,
    this.originalUrl,
    this.fileHash,
    this.perceptualHash,
    this.nsfwScore,
    this.qualityScore,
    this.primaryCategory,
    this.subcategory,
    this.tags,
    this.processedAt,
    this.processingStatus,
    this.rejectionReason,
    // Nuevos campos para búsqueda y carga progresiva
    this.previewUrl,
    this.resolutions,
    this.searchTokens,
    this.entityMetadata,
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

  /// Metadatos de procesamiento y clasificación
  final String? source; // 'wallhaven' | 'pixabay' | 'custom'
  final String? sourceId; // ID en la fuente original
  final String? originalUrl; // URL original
  final String? fileHash; // SHA256
  final String? perceptualHash; // pHash para deduplicación
  final double? nsfwScore; // 0.0 - 1.0
  final double? qualityScore; // 0.0 - 1.0
  final String? primaryCategory; // 'deportes', 'naturaleza', etc
  final String? subcategory; // 'fútbol', 'paisajes', etc
  final List<String>? tags; // Tags adicionales
  final DateTime? processedAt;
  final String? processingStatus; // 'accepted' | 'rejected'
  final String? rejectionReason;

  /// URL intermedia para carga progresiva (entre thumbnail y fullUrl)
  final String? previewUrl;
  /// Múltiples resoluciones almacenadas (thumbnail, preview, original)
  final List<WallpaperResolution>? resolutions;
  /// Tokens normalizados para búsqueda rápida
  final List<String>? searchTokens;
  /// Metadatos de entidades (jugadores, equipos, etc.)
  final Map<String, dynamic>? entityMetadata;

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
    String? fileHash,
    String? perceptualHash,
    double? nsfwScore,
    double? qualityScore,
    String? primaryCategory,
    String? subcategory,
    List<String>? tags,
    DateTime? processedAt,
    String? processingStatus,
    String? rejectionReason,
    String? previewUrl,
    List<WallpaperResolution>? resolutions,
    List<String>? searchTokens,
    Map<String, dynamic>? entityMetadata,
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
      fileHash: fileHash ?? this.fileHash,
      perceptualHash: perceptualHash ?? this.perceptualHash,
      nsfwScore: nsfwScore ?? this.nsfwScore,
      qualityScore: qualityScore ?? this.qualityScore,
      primaryCategory: primaryCategory ?? this.primaryCategory,
      subcategory: subcategory ?? this.subcategory,
      tags: tags ?? this.tags,
      processedAt: processedAt ?? this.processedAt,
      processingStatus: processingStatus ?? this.processingStatus,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      previewUrl: previewUrl ?? this.previewUrl,
      resolutions: resolutions ?? this.resolutions,
      searchTokens: searchTokens ?? this.searchTokens,
      entityMetadata: entityMetadata ?? this.entityMetadata,
    );
  }
}
