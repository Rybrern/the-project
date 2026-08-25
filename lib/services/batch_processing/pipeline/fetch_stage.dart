import 'package:flutter/foundation.dart';
import '../batch_config.dart';
import 'pipeline_stage.dart';

/// Stage 1: Obtiene candidatos de los discovery engines.
/// No hace procesamiento, solo obtiene URLs de las fuentes.
class FetchStage implements PipelineStage {
  @override
  String get name => 'fetch';

  @override
  String get description => 'Fetch candidates from discovery engines';

  @override
  Future<List<PipelineCandidate>> execute(
    List<PipelineCandidate> candidates,
    BatchConfig config,
  ) async {
    // En esta etapa, los candidatos ya vienen de discovery engine
    // Solo validamos que tengan URLs válidas
    final validCandidates = <PipelineCandidate>[];

    for (final candidate in candidates) {
      if (candidate.url.isNotEmpty) {
        validCandidates.add(candidate);
        debugPrint('FetchStage: Fetched candidate from ${candidate.source}');
      } else {
        candidate.reject('Invalid URL');
      }
    }

    debugPrint('FetchStage: Fetched ${validCandidates.length} candidates');
    return validCandidates;
  }
}
