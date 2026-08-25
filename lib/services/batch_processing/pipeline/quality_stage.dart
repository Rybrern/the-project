import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

import '../batch_config.dart';
import 'pipeline_stage.dart';

/// Stage 4: Valida la calidad de las imágenes.
/// Verifica: resolución, formato, tamaño de archivo, etc.
class QualityStage implements PipelineStage {
  @override
  String get name => 'quality';

  @override
  String get description => 'Validate image quality';

  @override
  Future<List<PipelineCandidate>> execute(
    List<PipelineCandidate> candidates,
    BatchConfig config,
  ) async {
    final results = <PipelineCandidate>[];

    for (final candidate in candidates) {
      if (candidate.data == null) {
        candidate.reject('No image data');
        continue;
      }

      try {
        // Decodifica la imagen
        final image = img.decodeImage(candidate.data!);

        if (image == null) {
          candidate.reject('Invalid image format');
          continue;
        }

        // Valida dimensiones
        if (image.width < config.minImageWidth || image.height < config.minImageHeight) {
          candidate.reject(
            'Resolution too low: ${image.width}x${image.height} < ${config.minImageWidth}x${config.minImageHeight}',
          );
          continue;
        }

        // Almacena metadatos
        candidate.updateMetadata('image_width', image.width);
        candidate.updateMetadata('image_height', image.height);
        candidate.updateMetadata('aspect_ratio', image.width / image.height);

        // Calcula quality score basado en resolución
        final qualityScore = _calculateQualityScore(image.width, image.height);
        candidate.updateMetadata('quality_score', qualityScore);

        if (qualityScore < config.minQualityScore) {
          candidate.reject('Quality score too low: $qualityScore < ${config.minQualityScore}');
          continue;
        }

        results.add(candidate);
        debugPrint('QualityStage: Passed quality check: ${image.width}x${image.height}');
      } catch (e) {
        candidate.reject('Error analyzing image: $e');
        debugPrint('QualityStage: Error: $e');
      }
    }

    debugPrint('QualityStage: ${results.length}/${candidates.length} candidates passed quality validation');
    return results;
  }

  /// Calcula un score de calidad basado en resolución
  /// Score máximo en 4K+ (0.0 - 1.0)
  double _calculateQualityScore(int width, int height) {
    const int fullHD = 1920 * 1080;
    const int quad = 3840 * 2160;

    final pixels = width * height;

    if (pixels >= quad) return 1.0;
    if (pixels >= fullHD) return 0.8 + (0.2 * (pixels - fullHD) / (quad - fullHD));
    return 0.5; // Resoluciones menores a Full HD
  }
}
