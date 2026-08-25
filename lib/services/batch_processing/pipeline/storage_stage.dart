import 'package:flutter/foundation.dart';

import '../../../database/daos/daos.dart';
import '../../../models/wallpaper.dart';
import '../../../models/processing_record.dart';
import '../batch_config.dart';
import 'pipeline_stage.dart';

/// Stage 6 (final): Almacena los wallpapers aceptados en la BD.
/// También registra rechazados para auditoría.
class StorageStage implements PipelineStage {
  StorageStage({
    required this.wallpaperDAO,
    required this.hashRegistryDAO,
    required this.processingRecordDAO,
    required this.rejectedCandidateDAO,
  });

  final WallpaperDAO wallpaperDAO;
  final HashRegistryDAO hashRegistryDAO;
  final ProcessingRecordDAO processingRecordDAO;
  final RejectedCandidateDAO rejectedCandidateDAO;

  @override
  String get name => 'storage';

  @override
  String get description => 'Store wallpapers in database';

  @override
  Future<List<PipelineCandidate>> execute(
    List<PipelineCandidate> candidates,
    BatchConfig config,
  ) async {
    final now = DateTime.now();
    final accepted = <PipelineCandidate>[];

    for (final candidate in candidates) {
      try {
        if (candidate.isRejected) {
          // Registra como rechazado
          await _storeRejected(candidate, now);
        } else {
          // Crea wallpaper y lo almacena
          final wallpaper = _createWallpaper(candidate, now);
          await wallpaperDAO.insert(wallpaper);

          // Registra el hash para deduplicación futura
          final hash = candidate.getMetadata('file_hash') as String?;
          if (hash != null) {
            await hashRegistryDAO.register(
              hash: hash,
              wallpaperId: wallpaper.id,
              source: candidate.source,
              perceptualHash: candidate.getMetadata('perceptual_hash') as String?,
            );
          }

          // Registra como procesado exitosamente
          await _storeProcessingRecord(candidate, wallpaper.id, 'processed', now);

          accepted.add(candidate);
          debugPrint('StorageStage: Stored wallpaper ${wallpaper.id}');
        }
      } catch (e) {
        debugPrint('StorageStage: Error storing candidate: $e');
        await _storeProcessingRecord(candidate, null, 'error', now, error: e.toString());
      }
    }

    debugPrint('StorageStage: Stored ${accepted.length}/${candidates.length} wallpapers');
    return accepted;
  }

  /// Crea un modelo Wallpaper a partir de un candidato procesado
  Wallpaper _createWallpaper(PipelineCandidate candidate, DateTime now) {
    return Wallpaper(
      id: 'wp_${candidate.sourceId}',
      thumbnailUrl: candidate.url, // URL original como thumbnail
      fullUrl: candidate.url,
      author: candidate.getMetadata('author') as String? ?? candidate.source,
      category: candidate.getMetadata('primary_category') as String? ?? 'general',
      aspectRatio: ((candidate.getMetadata('aspect_ratio') as num?) ?? 1.0).toDouble(),
      source: candidate.source,
      sourceId: candidate.sourceId,
      originalUrl: candidate.url,
      fileHash: candidate.getMetadata('file_hash') as String?,
      perceptualHash: candidate.getMetadata('perceptual_hash') as String?,
      nsfwScore: candidate.getMetadata('nsfw_score') as double?,
      qualityScore: candidate.getMetadata('quality_score') as double?,
      primaryCategory: candidate.getMetadata('primary_category') as String?,
      subcategory: candidate.getMetadata('subcategory') as String?,
      tags: candidate.getMetadata('tags') as List<String>?,
      processedAt: now,
      processingStatus: 'accepted',
    );
  }

  /// Registra un candidato rechazado
  Future<void> _storeRejected(PipelineCandidate candidate, DateTime now) async {
    final reasons = candidate.rejectionReasons.join('; ');
    await rejectedCandidateDAO.insert(
      id: 'rej_${candidate.sourceId}_${now.millisecondsSinceEpoch}',
      sourceUrl: candidate.url,
      sourceId: candidate.sourceId,
      rejectionReason: reasons,
      rejectionDetails: {
        'stages': candidate.getMetadata('rejection_stages'),
        'metadata': candidate.metadata,
      },
    );
  }

  /// Registra un processing record
  Future<void> _storeProcessingRecord(
    PipelineCandidate candidate,
    String? wallpaperId,
    String status,
    DateTime now, {
    String? error,
  }) async {
    await processingRecordDAO.insert(
      ProcessingRecord(
        id: 'pr_${candidate.sourceId}_${now.millisecondsSinceEpoch}',
        sourceUrl: candidate.url,
        sourceId: candidate.sourceId,
        wallpaperId: wallpaperId,
        status: status,
        rejectionReason: error,
        metadata: candidate.metadata,
        processedAt: now,
        processingTimeMs: 0, // Calculado por el batch processor
      ),
    );
  }
}
