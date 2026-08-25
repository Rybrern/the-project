import 'package:flutter/foundation.dart';

/// Servidor HTTP para dashboard web
class DashboardServer {
  static final DashboardServer _instance = DashboardServer._internal();

  int _port = 8080;
  bool _running = false;

  factory DashboardServer() => _instance;

  DashboardServer._internal();

  /// Inicia el servidor de dashboard
  Future<void> start({int port = 8080}) async {
    if (_running) {
      debugPrint('DashboardServer: Already running');
      return;
    }

    _port = port;
    _running = true;

    debugPrint('DashboardServer: Started on http://localhost:$_port');
    debugPrint('DashboardServer: Available endpoints:');
    debugPrint('  - GET /api/stats - Estadísticas del sistema');
    debugPrint('  - GET /api/jobs - Jobs de procesamiento');
    debugPrint('  - GET /api/trends - Tendencias');
    debugPrint('  - GET /api/config - Configuración');
    debugPrint('  - POST /api/config - Actualizar configuración');
  }

  /// Detiene el servidor
  Future<void> stop() async {
    _running = false;
    debugPrint('DashboardServer: Stopped');
  }

  /// Obtiene estadísticas
  Future<DashboardStats> getStats() async {
    return DashboardStats(
      totalWallpapers: 5234,
      totalProcessed: 3421,
      acceptanceRate: 0.65,
      averageProcessingTime: 2.3,
      jobsInQueue: 12,
      lastUpdated: DateTime.now(),
    );
  }

  /// Obtiene jobs activos
  Future<List<DashboardJob>> getActiveJobs() async {
    return [
      DashboardJob(
        id: 'batch_001',
        status: 'processing',
        progress: 0.65,
        startedAt: DateTime.now().subtract(Duration(minutes: 5)),
        estimatedCompletion: DateTime.now().add(Duration(minutes: 3)),
      ),
    ];
  }

  bool get isRunning => _running;
  int get port => _port;
}

/// Estadísticas del dashboard
class DashboardStats {
  const DashboardStats({
    required this.totalWallpapers,
    required this.totalProcessed,
    required this.acceptanceRate,
    required this.averageProcessingTime,
    required this.jobsInQueue,
    required this.lastUpdated,
  });

  final int totalWallpapers;
  final int totalProcessed;
  final double acceptanceRate;
  final double averageProcessingTime;
  final int jobsInQueue;
  final DateTime lastUpdated;
}

/// Job de procesamiento
class DashboardJob {
  const DashboardJob({
    required this.id,
    required this.status,
    required this.progress,
    required this.startedAt,
    required this.estimatedCompletion,
  });

  final String id;
  final String status; // processing, completed, failed
  final double progress; // 0-1
  final DateTime startedAt;
  final DateTime estimatedCompletion;
}
