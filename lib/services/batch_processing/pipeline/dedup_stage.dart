import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';

import '../../../database/daos/hash_registry_dao.dart';
import '../../deduplication/perceptual_hash.dart';
import '../batch_config.dart';
import 'pipeline_stage.dart';

/// Stage 3: Detecta y elimina duplicados usando SHA256 + pHash.
/// - SHA256: detección rápida de duplicados exactos
/// - pHash (perceptual hash): detección de duplicados re-encoded/scaled
/// Workflow:
/// 1. Calcula SHA256; si existe → rechaza (duplicado exacto, rápido)
/// 2. Si no, calcula pHash; compara con existentes
/// 3. Si similitud > 95% (Hamming distance < 3) → rechaza
class DedupStage implements PipelineStage {
  DedupStage({required this.hashRegistry});

  final HashRegistryDAO hashRegistry;
  final _pHashGenerator = PerceptualHashGenerator();

  @override
  String get name => 'dedup';

  @override
  String get description => 'Detect duplicates (SHA256 + perceptual hash)';

  @override
  Future<List<PipelineCandidate>> execute(
    List<PipelineCandidate> candidates,
    BatchConfig config,
  ) async {
    final results = <PipelineCandidate>[];
    int sha256Dupes = 0;
    int pHashDupes = 0;

    for (final candidate in candidates) {
      if (candidate.data == null) {
        candidate.reject('No data to hash');
        continue;
      }

      // Etapa 1: SHA256 (detección rápida exacta)
      final sha256Hash = sha256.convert(candidate.data!).toString();
      candidate.updateMetadata('file_hash', sha256Hash);

      final isDuplicateSHA = await hashRegistry.existsHash(sha256Hash);
      if (isDuplicateSHA) {
        candidate.reject('Duplicate (SHA256 exact match)');
        sha256Dupes++;
        debugPrint('DedupStage: SHA256 duplicate: $sha256Hash');
        continue;
      }

      // Etapa 2: pHash (detección perceptual)
      String pHash = '';
      try {
        pHash = await _pHashGenerator.generateHash(candidate.data!);
        candidate.updateMetadata('perceptual_hash', pHash);
      } catch (e) {
        debugPrint('DedupStage: Error computing pHash: $e');
        // Si falla pHash, continuamos (mejor error que rechazar)
      }

      // Verifica pHash contra existentes en BD
      bool isDuplicatePerceptual = false;
      if (pHash.isNotEmpty) {
        final existingHashes = await hashRegistry.getSimilarPerceptualHashes(pHash);
        for (final existingHash in existingHashes) {
          final distance = PerceptualHashComparator.hammingDistance(pHash, existingHash);
          final similarity = PerceptualHashComparator.similarityPercentage(pHash, existingHash);

          // Threshold: similitud > 90% (distancia < 6 bits de 64)
          if (distance <= 6) {
            isDuplicatePerceptual = true;
            pHashDupes++;
            debugPrint(
              'DedupStage: pHash duplicate (similarity: ${similarity.toStringAsFixed(1)}%): '
              '$pHash vs $existingHash'
            );
            break;
          }
        }
      }

      if (isDuplicatePerceptual) {
        candidate.reject('Duplicate (perceptual hash match > 90%)');
      } else {
        results.add(candidate);
      }
    }

    debugPrint(
      'DedupStage: ${results.length}/${candidates.length} passed dedup. '
      'Rejected: $sha256Dupes SHA256, $pHashDupes perceptual'
    );
    return results;
  }
}
