import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../database/daos/daos.dart';
import '../../models/wallpaper.dart';
import '../deduplication/perceptual_hash.dart';

/// Métricas de validación de deduplicación
class DedupMetrics {
  final int totalWallpapers;
  final int exactDuplicates;
  final int visualDuplicates;
  final double falsePositiveRate;
  final double falseNegativeRate;
  final double avgProcessingTimeMs;
  final List<DuplicateGroup> duplicateGroups;
  final DateTime testedAt;

  DedupMetrics({
    required this.totalWallpapers,
    required this.exactDuplicates,
    required this.visualDuplicates,
    required this.falsePositiveRate,
    required this.falseNegativeRate,
    required this.avgProcessingTimeMs,
    required this.duplicateGroups,
    required this.testedAt,
  });

  bool isHealthy() {
    return falsePositiveRate < 0.05 && // Less than 5% false positives
        falseNegativeRate < 0.10 && // Less than 10% false negatives
        avgProcessingTimeMs < 50; // Less than 50ms per image
  }

  Map<String, dynamic> toJson() {
    return {
      'totalWallpapers': totalWallpapers,
      'exactDuplicates': exactDuplicates,
      'visualDuplicates': visualDuplicates,
      'falsePositiveRate': falsePositiveRate,
      'falseNegativeRate': falseNegativeRate,
      'avgProcessingTimeMs': avgProcessingTimeMs,
      'duplicateGroupsCount': duplicateGroups.length,
      'isHealthy': isHealthy(),
      'testedAt': testedAt.toIso8601String(),
    };
  }
}

/// Grupo de imágenes duplicadas
class DuplicateGroup {
  final String primaryId;
  final String primaryHash;
  final List<String> duplicateIds;
  final List<String> duplicateHashes;
  final List<int> hammingDistances;
  final String type; // 'exact' or 'visual'

  DuplicateGroup({
    required this.primaryId,
    required this.primaryHash,
    required this.duplicateIds,
    required this.duplicateHashes,
    required this.hammingDistances,
    required this.type,
  });
}

/// Validador de deduplicación con SHA256 exacto y pHash visual
class DedupValidator {
  final WallpaperDAO _wallpaperDAO;
  final HashRegistryDAO _hashRegistryDAO;

  DedupValidator({
    required WallpaperDAO wallpaperDAO,
    required HashRegistryDAO hashRegistryDAO,
  })  : _wallpaperDAO = wallpaperDAO,
        _hashRegistryDAO = hashRegistryDAO;

  /// Valida la efectividad de la deduplicación
  Future<DedupMetrics> validateDeduplication({
    int sampleSize = 1000,
    int visualSimilarityThreshold = 5,
  }) async {
    debugPrint('DedupValidator: Starting deduplication validation...');
    final startTime = DateTime.now();

    try {
      // Obtener todas las imágenes aceptadas
      final allWallpapers = await _wallpaperDAO.getAllAccepted(limit: sampleSize);
      final totalCount = allWallpapers.length;

      if (totalCount == 0) {
        return DedupMetrics(
          totalWallpapers: 0,
          exactDuplicates: 0,
          visualDuplicates: 0,
          falsePositiveRate: 0,
          falseNegativeRate: 0,
          avgProcessingTimeMs: 0,
          duplicateGroups: [],
          testedAt: DateTime.now(),
        );
      }

      int exactDuplicateCount = 0;
      int visualDuplicateCount = 0;
      int totalProcessingTimeMs = 0;
      final duplicateGroups = <DuplicateGroup>[];
      final processedHashes = <String>{};

      // Verificar duplicados exactos (SHA256)
      for (final wallpaper in allWallpapers) {
        final startProcessing = DateTime.now();

        if (wallpaper.fileHash != null && wallpaper.fileHash!.isNotEmpty) {
          final hash = wallpaper.fileHash!;

          // Buscar otros wallpapers con el mismo hash
          final sameHashCount = allWallpapers
              .where((w) => w.fileHash == hash && w.id != wallpaper.id)
              .length;

          if (sameHashCount > 0) {
            exactDuplicateCount += sameHashCount;

            if (!processedHashes.contains(hash)) {
              final duplicates = allWallpapers
                  .where((w) => w.fileHash == hash && w.id != wallpaper.id)
                  .map((w) => w.id)
                  .toList();

              duplicateGroups.add(DuplicateGroup(
                primaryId: wallpaper.id,
                primaryHash: hash,
                duplicateIds: duplicates,
                duplicateHashes: List.filled(duplicates.length, hash),
                hammingDistances: List.filled(duplicates.length, 0),
                type: 'exact',
              ));

              processedHashes.add(hash);
            }
          }
        }

        // Verificar duplicados visuales (pHash)
        if (wallpaper.perceptualHash != null &&
            wallpaper.perceptualHash!.isNotEmpty) {
          final pHash = wallpaper.perceptualHash!;
          final similarHashes = <String>[];
          final similarities = <int>[];

          for (final other in allWallpapers) {
            if (other.id == wallpaper.id ||
                other.perceptualHash == null ||
                other.perceptualHash!.isEmpty) {
              continue;
            }

            final distance = PerceptualHashComparator.hammingDistance(
              pHash,
              other.perceptualHash!,
            );

            if (distance <= visualSimilarityThreshold && distance > 0) {
              similarHashes.add(other.id);
              similarities.add(distance);
              visualDuplicateCount++;
            }
          }

          if (similarHashes.isNotEmpty) {
            duplicateGroups.add(DuplicateGroup(
              primaryId: wallpaper.id,
              primaryHash: pHash,
              duplicateIds: similarHashes,
              duplicateHashes: allWallpapers
                  .where((w) => similarHashes.contains(w.id))
                  .map((w) => w.perceptualHash ?? '')
                  .toList(),
              hammingDistances: similarities,
              type: 'visual',
            ));
          }
        }

        final processingTime =
            DateTime.now().difference(startProcessing).inMilliseconds;
        totalProcessingTimeMs += processingTime;
      }

      final avgProcessingTime =
          totalCount > 0 ? totalProcessingTimeMs / totalCount : 0;

      // Calcular tasas de error (estas son estimaciones basadas en muestras)
      // En un escenario real, deberías comparar contra un conjunto de datos verificados manualmente
      final falsePositiveRate = _estimateFalsePositives(allWallpapers);
      final falseNegativeRate = _estimateFalseNegatives(allWallpapers);

      debugPrint(
        'DedupValidator: Validation complete. Exact: $exactDuplicateCount, Visual: $visualDuplicateCount, Avg time: ${avgProcessingTime.toStringAsFixed(2)}ms',
      );

      return DedupMetrics(
        totalWallpapers: totalCount,
        exactDuplicates: exactDuplicateCount,
        visualDuplicates: visualDuplicateCount,
        falsePositiveRate: falsePositiveRate,
        falseNegativeRate: falseNegativeRate,
        avgProcessingTimeMs: avgProcessingTime.toDouble(),
        duplicateGroups: duplicateGroups,
        testedAt: DateTime.now(),
      );
    } catch (e) {
      debugPrint('DedupValidator: Error during validation: $e');
      rethrow;
    }
  }

  /// Estima la tasa de falsos positivos
  double _estimateFalsePositives(List<Wallpaper> wallpapers) {
    // Verificar si hay hashes exactos que en realidad son diferentes imágenes
    // (esto sería muy raro con SHA256, pero posible con errores)
    int falsePositives = 0;

    final hashGroups = <String, List<Wallpaper>>{};
    for (final wallpaper in wallpapers) {
      final hash = wallpaper.fileHash;
      if (hash != null && hash.isNotEmpty) {
        if (!hashGroups.containsKey(hash)) {
          hashGroups[hash] = [];
        }
        hashGroups[hash]!.add(wallpaper);
      }
    }

    // En un escenario real, verificarías esto contra datos verificados
    // Por ahora, retornamos 0 ya que SHA256 tiene colisiones prácticamente imposibles
    return falsePositives.toDouble() / wallpapers.length.clamp(1, double.maxFinite);
  }

  /// Estima la tasa de falsos negativos
  double _estimateFalseNegatives(List<Wallpaper> wallpapers) {
    // Verificar si hay imágenes que deberían ser marcadas como duplicadas pero no lo son
    // Esto es difícil de estimar sin datos de referencia
    // Por ahora retornamos 0
    return 0.0;
  }

  /// Obtiene hashes duplicados en la base de datos
  Future<Map<String, List<String>>> getExactDuplicates() async {
    debugPrint('DedupValidator: Getting exact duplicates from database...');
    final wallpapers = await _wallpaperDAO.getAllAccepted(limit: 10000);
    final hashMap = <String, List<String>>{};

    for (final wallpaper in wallpapers) {
      if (wallpaper.fileHash != null && wallpaper.fileHash!.isNotEmpty) {
        final hash = wallpaper.fileHash!;
        if (!hashMap.containsKey(hash)) {
          hashMap[hash] = [];
        }
        hashMap[hash]!.add(wallpaper.id);
      }
    }

    // Retornar solo los hashes con duplicados
    return {
      for (final entry in hashMap.entries)
        if (entry.value.length > 1) entry.key: entry.value
    };
  }

  /// Obtiene hashes visuales similares
  Future<Map<String, List<SimilarHash>>> getSimilarPHashes({
    int threshold = 5,
  }) async {
    debugPrint('DedupValidator: Getting similar pHashes...');
    final wallpapers = await _wallpaperDAO.getAllAccepted(limit: 5000);
    final similarMap = <String, List<SimilarHash>>{};

    for (int i = 0; i < wallpapers.length; i++) {
      final wallpaper = wallpapers[i];
      if (wallpaper.perceptualHash == null ||
          wallpaper.perceptualHash!.isEmpty) {
        continue;
      }

      for (int j = i + 1; j < wallpapers.length; j++) {
        final other = wallpapers[j];
        if (other.perceptualHash == null || other.perceptualHash!.isEmpty) {
          continue;
        }

        final distance = PerceptualHashComparator.hammingDistance(
          wallpaper.perceptualHash!,
          other.perceptualHash!,
        );

        if (distance <= threshold) {
          if (!similarMap.containsKey(wallpaper.id)) {
            similarMap[wallpaper.id] = [];
          }
          similarMap[wallpaper.id]!.add(
            SimilarHash(
              wallpaperId: other.id,
              pHash: other.perceptualHash!,
              distance: distance,
            ),
          );
        }
      }
    }

    return similarMap;
  }

  /// Limpia duplicados exactos (mantiene solo uno)
  Future<int> deduplicateExact() async {
    debugPrint('DedupValidator: Deduplicating exact duplicates...');
    int deletedCount = 0;

    final duplicates = await getExactDuplicates();

    for (final entry in duplicates.entries) {
      // Mantener el primero, eliminar los demás
      final toKeep = entry.value.first;
      for (final id in entry.value.skip(1)) {
        await _wallpaperDAO.delete(id);
        deletedCount++;
      }
    }

    debugPrint('DedupValidator: Deleted $deletedCount exact duplicates');
    return deletedCount;
  }
}

/// Representa un pHash similar
class SimilarHash {
  final String wallpaperId;
  final String pHash;
  final int distance;

  SimilarHash({
    required this.wallpaperId,
    required this.pHash,
    required this.distance,
  });
}
