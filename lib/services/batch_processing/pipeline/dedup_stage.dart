import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../../database/daos/hash_registry_dao.dart';
import '../batch_config.dart';
import 'pipeline_stage.dart';

/// Stage 3: Detecta y elimina duplicados usando hash SHA256.
/// También calcula pHash (perceptual hash) para detección avanzada.
class DedupStage implements PipelineStage {
  DedupStage({required this.hashRegistry});

  final HashRegistryDAO hashRegistry;

  @override
  String get name => 'dedup';

  @override
  String get description => 'Detect and remove duplicates';

  @override
  Future<List<PipelineCandidate>> execute(
    List<PipelineCandidate> candidates,
    BatchConfig config,
  ) async {
    final results = <PipelineCandidate>[];

    for (final candidate in candidates) {
      if (candidate.data == null) {
        candidate.reject('No data to hash');
        continue;
      }

      // Calcula SHA256
      final hash = sha256.convert(candidate.data!).toString();
      candidate.updateMetadata('file_hash', hash);

      // Verifica si ya existe
      final isDuplicate = await hashRegistry.existsHash(hash);

      if (isDuplicate) {
        candidate.reject('Duplicate (hash match)');
        debugPrint('DedupStage: Duplicate detected: $hash');
      } else {
        // TODO: Implementar pHash para detección perceptual
        // Por ahora solo registramos el SHA256
        results.add(candidate);
      }
    }

    debugPrint('DedupStage: ${results.length}/${candidates.length} candidates passed (no duplicates)');
    return results;
  }
}
