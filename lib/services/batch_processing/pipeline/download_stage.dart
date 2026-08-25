import 'package:flutter/foundation.dart';
import '../batch_config.dart';
import '../download_manager.dart';
import 'pipeline_stage.dart';

/// Stage 2: Descarga las imágenes de los candidatos.
class DownloadStage implements PipelineStage {
  DownloadStage({required this.downloadManager});

  final DownloadManager downloadManager;

  @override
  String get name => 'download';

  @override
  String get description => 'Download image files';

  @override
  Future<List<PipelineCandidate>> execute(
    List<PipelineCandidate> candidates,
    BatchConfig config,
  ) async {
    final results = <PipelineCandidate>[];

    // Extrae URLs
    final urls = candidates.map((c) => c.url).toList();

    // Descarga todas en paralelo
    final downloaded = await downloadManager.downloadBatch(urls);

    for (final candidate in candidates) {
      final data = downloaded[candidate.url];

      if (data != null) {
        candidate.data = data;
        candidate.updateMetadata('download_size_bytes', data.length);
        debugPrint('DownloadStage: Downloaded ${candidate.url} (${data.length} bytes)');
        results.add(candidate);
      } else {
        candidate.reject('Failed to download');
        debugPrint('DownloadStage: Failed to download ${candidate.url}');
      }
    }

    debugPrint('DownloadStage: Downloaded ${results.length}/${candidates.length} candidates');
    return results;
  }
}
