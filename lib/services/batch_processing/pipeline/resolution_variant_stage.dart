import 'dart:typed_data';
import 'package:image/image.dart' as img;
import '../batch_config.dart';
import 'pipeline_stage.dart';

/// Genera variantes de resolución (thumbnail, preview) para cada imagen descargada
/// Almacena las variantes como Base64 en metadatos para transferencia sin necesidad de filesystem
class ResolutionVariantStage implements PipelineStage {
  @override
  String get name => 'resolution_variants';

  @override
  String get description => 'Generating resolution variants (thumbnail, preview)';

  /// Dimensiones objetivo para cada variante
  static const int thumbnailMaxDim = 200;
  static const int previewMaxDim = 800;

  @override
  Future<List<PipelineCandidate>> execute(
    List<PipelineCandidate> candidates,
    BatchConfig config,
  ) async {
    final processed = <PipelineCandidate>[];

    for (final candidate in candidates) {
      try {
        // Solo procesar si no fue rechazado previamente
        if (candidate.isRejected) {
          processed.add(candidate);
          continue;
        }

        // Verificar que tenemos datos de imagen
        if (candidate.data == null || candidate.data!.isEmpty) {
          processed.add(candidate);
          continue;
        }

        // Decodificar imagen
        final image = img.decodeImage(candidate.data!);
        if (image == null) {
          candidate.reject('Unable to decode image');
          processed.add(candidate);
          continue;
        }

        // Generar thumbnail
        final thumbnail = _generateVariant(image, maxDimension: thumbnailMaxDim);
        final thumbnailBytes = Uint8List.fromList(img.encodeJpg(thumbnail, quality: 85));

        // Generar preview
        final preview = _generateVariant(image, maxDimension: previewMaxDim);
        final previewBytes = Uint8List.fromList(img.encodeJpg(preview, quality: 90));

        // Almacenar variantes en metadatos
        candidate.updateMetadata('thumbnail_data', thumbnailBytes);
        candidate.updateMetadata('preview_data', previewBytes);
        candidate.updateMetadata('thumbnail_size', thumbnailBytes.length);
        candidate.updateMetadata('preview_size', previewBytes.length);
        candidate.updateMetadata('original_width', image.width);
        candidate.updateMetadata('original_height', image.height);

        processed.add(candidate);
      } catch (e) {
        candidate.reject('Error generating resolution variants: $e');
        processed.add(candidate);
      }
    }

    return processed;
  }

  /// Redimensiona una imagen manteniendo aspect ratio
  img.Image _generateVariant(
    img.Image original, {
    required int maxDimension,
  }) {
    final width = original.width;
    final height = original.height;

    final scale = maxDimension / (width > height ? width : height);
    final newWidth = (width * scale).toInt();
    final newHeight = (height * scale).toInt();

    return img.copyResize(
      original,
      width: newWidth,
      height: newHeight,
      interpolation: img.Interpolation.linear,
    );
  }
}
