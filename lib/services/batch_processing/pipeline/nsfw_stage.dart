import 'package:flutter/foundation.dart';

import '../../nsfw_detection/nsfw_detection.dart';
import '../batch_config.dart';
import 'pipeline_stage.dart';

/// Stage de detección NSFW (se ejecuta entre Quality y Classification).
/// Filtra contenido inapropiado usando detección multicapa.
class NSFWStage implements PipelineStage {
  NSFWStage({required this.nsfwEngine});

  final NSFWEngine nsfwEngine;

  @override
  String get name => 'nsfw';

  @override
  String get description => 'Detect and filter NSFW content';

  @override
  Future<List<PipelineCandidate>> execute(
    List<PipelineCandidate> candidates,
    BatchConfig config,
  ) async {
    final results = <PipelineCandidate>[];

    for (final candidate in candidates) {
      if (candidate.data == null) {
        candidate.reject('No image data for NSFW check');
        continue;
      }

      try {
        // Ejecuta detección NSFW
        final metadata = {
          ...candidate.metadata,
          'tags': candidate.getMetadata('tags'),
          'author': candidate.getMetadata('author'),
        };

        final detectionResult = await nsfwEngine.detect(
          candidate.data!,
          metadata: metadata,
        );

        // Almacena resultado
        candidate.updateMetadata('nsfw_score', detectionResult.score);
        candidate.updateMetadata('nsfw_confidence', detectionResult.confidence);
        candidate.updateMetadata('nsfw_method', detectionResult.method);
        candidate.updateMetadata('nsfw_details', detectionResult.details);

        debugPrint(
          'NSFWStage: NSFW Score=${detectionResult.score} for ${candidate.url}',
        );

        // Rechaza si excede umbral
        if (detectionResult.score > config.maxNsfwScore) {
          candidate.reject(
            'NSFW detected (score=${detectionResult.score.toStringAsFixed(2)})',
          );
          debugPrint(
            'NSFWStage: Rejected - NSFW score ${detectionResult.score} > ${config.maxNsfwScore}',
          );
        } else {
          results.add(candidate);
        }
      } catch (e) {
        candidate.reject('Error in NSFW detection: $e');
        debugPrint('NSFWStage: Error: $e');
      }
    }

    debugPrint('NSFWStage: ${results.length}/${candidates.length} candidates passed NSFW check');
    return results;
  }
}
