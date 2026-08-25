import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Gestiona descargas concurrentes con reintentos y control de rate limiting.
class DownloadManager {
  DownloadManager({
    required this.maxConcurrent,
    required this.timeoutSeconds,
    required this.retryAttempts,
    required this.retryDelayMs,
  });

  final int maxConcurrent;
  final int timeoutSeconds;
  final int retryAttempts;
  final int retryDelayMs;

  /// Cola de descargas pendientes
  final _queue = <DownloadTask>[];

  /// Descargas actualmente en progreso
  int _activeDownloads = 0;

  /// Procesa una URL y retorna los bytes si es exitoso
  Future<Uint8List?> download(String url) async {
    var lastError = Exception('Unknown error');

    for (var attempt = 0; attempt < retryAttempts; attempt++) {
      try {
        if (attempt > 0) {
          // Espera exponencial
          final delay = retryDelayMs * (1 << (attempt - 1)); // 2^(attempt-1)
          await Future.delayed(Duration(milliseconds: delay));
        }

        final response = await http
            .get(Uri.parse(url))
            .timeout(Duration(seconds: timeoutSeconds));

        if (response.statusCode == 200) {
          return response.bodyBytes;
        } else {
          lastError = Exception('HTTP ${response.statusCode}');
        }
      } on SocketException catch (e) {
        lastError = e;
      } catch (e) {
        lastError = e as Exception;
      }
    }

    debugPrint('DownloadManager: Failed to download $url after $retryAttempts attempts: $lastError');
    return null;
  }

  /// Descarga múltiples URLs con control de concurrencia
  Future<Map<String, Uint8List?>> downloadBatch(List<String> urls) async {
    final results = <String, Uint8List?>{};

    // Procesa en lotes de maxConcurrent
    for (var i = 0; i < urls.length; i += maxConcurrent) {
      final batch = urls.skip(i).take(maxConcurrent);
      final futures = batch.map((url) => download(url));

      final batchResults = await Future.wait(futures);

      for (var j = 0; j < batch.length; j++) {
        results[batch.elementAt(j)] = batchResults[j];
      }
    }

    return results;
  }

  /// Obtiene estadísticas de las descargas
  Map<String, dynamic> getStats() {
    return {
      'active_downloads': _activeDownloads,
      'queue_size': _queue.length,
      'max_concurrent': maxConcurrent,
    };
  }
}

/// Tarea de descarga individual
class DownloadTask {
  DownloadTask({
    required this.url,
    required this.retryCount,
    this.data,
    this.error,
  });

  final String url;
  final int retryCount;
  Uint8List? data;
  Exception? error;

  bool get isSuccess => data != null && error == null;
  bool get isFailed => error != null;
}
