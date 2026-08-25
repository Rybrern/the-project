import 'dart:async';

/// Utilidad para aplicar timeouts a Futures y Streams con manejo de errores
class TimeoutHelper {
  /// Envuelve un Future con timeout automático
  ///
  /// Si el Future excede la duración especificada, lanza TimeoutException
  static Future<T> withTimeout<T>(
    Future<T> future, {
    Duration timeout = const Duration(seconds: 15),
    required String operation,
  }) {
    return future.timeout(
      timeout,
      onTimeout: () {
        throw TimeoutException(
          '$operation excedió ${timeout.inSeconds}s',
          timeout,
        );
      },
    );
  }

  /// Envuelve un Stream con timeout automático
  ///
  /// Si el Stream no emite dentro del timeout, lanza TimeoutException
  static Stream<T> streamWithTimeout<T>(
    Stream<T> stream, {
    Duration timeout = const Duration(seconds: 30),
    String operation = 'Stream operation',
  }) {
    return stream.timeout(
      timeout,
      onTimeout: (sink) {
        sink.addError(
          TimeoutException(
            '$operation excedió ${timeout.inSeconds}s',
            timeout,
          ),
        );
      },
    );
  }

  /// Ejecuta Future con reintentos automáticos
  static Future<T> withRetry<T>(
    Future<T> Function() futureFactory, {
    int maxAttempts = 3,
    Duration delay = const Duration(seconds: 2),
    Duration timeout = const Duration(seconds: 15),
  }) async {
    int attempt = 0;
    while (attempt < maxAttempts) {
      attempt++;
      try {
        return await withTimeout(
          futureFactory(),
          timeout: timeout,
          operation: 'Attempt $attempt',
        );
      } catch (e) {
        if (attempt == maxAttempts) rethrow;
        await Future.delayed(delay);
      }
    }
    throw Exception('Max attempts exceeded');
  }
}
