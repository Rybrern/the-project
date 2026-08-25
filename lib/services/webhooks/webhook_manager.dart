import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Gestiona webhooks para notificaciones de eventos del sistema.
class WebhookManager {
  WebhookManager();

  final List<Webhook> _webhooks = [];

  /// Registra un webhook
  void registerWebhook(Webhook webhook) {
    _webhooks.add(webhook);
    debugPrint('WebhookManager: Registered webhook for ${webhook.event}');
  }

  /// Desregistra un webhook
  void unregisterWebhook(String webhookId) {
    _webhooks.removeWhere((w) => w.id == webhookId);
    debugPrint('WebhookManager: Unregistered webhook $webhookId');
  }

  /// Dispara un evento de webhook
  Future<void> fireEvent(String eventType, Map<String, dynamic> data) async {
    final matchingWebhooks = _webhooks.where((w) => w.event == eventType);

    for (final webhook in matchingWebhooks) {
      try {
        await _sendWebhook(webhook, WebhookPayload(
          event: eventType,
          timestamp: DateTime.now(),
          data: data,
        ));
      } catch (e) {
        debugPrint('WebhookManager: Error sending webhook: $e');
      }
    }
  }

  /// Envía un webhook a la URL configurada
  Future<void> _sendWebhook(Webhook webhook, WebhookPayload payload) async {
    final response = await http.post(
      Uri.parse(webhook.url),
      headers: {
        'Content-Type': 'application/json',
        if (webhook.secret != null) 'X-Webhook-Secret': webhook.secret!,
      },
      body: jsonEncode(payload.toJson()),
    ).timeout(Duration(seconds: 10));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Webhook failed: ${response.statusCode}');
    }
  }

  /// Obtiene todos los webhooks registrados
  List<Webhook> getWebhooks() => List.unmodifiable(_webhooks);

  /// Obtiene webhooks por evento
  List<Webhook> getWebhooksByEvent(String event) {
    return _webhooks.where((w) => w.event == event).toList();
  }
}

/// Modelo de webhook
class Webhook {
  const Webhook({
    required this.id,
    required this.url,
    required this.event,
    this.secret,
    this.active = true,
    this.createdAt,
  });

  final String id;
  final String url; // URL donde se enviarán las notificaciones
  final String event; // 'batch_started', 'batch_completed', 'wallpaper_rated', etc.
  final String? secret; // Para verificar autenticidad
  final bool active;
  final DateTime? createdAt;
}

/// Payload de webhook
class WebhookPayload {
  const WebhookPayload({
    required this.event,
    required this.timestamp,
    required this.data,
  });

  final String event;
  final DateTime timestamp;
  final Map<String, dynamic> data;

  Map<String, dynamic> toJson() => {
    'event': event,
    'timestamp': timestamp.toIso8601String(),
    'data': data,
  };
}

/// Tipos de eventos disponibles
class WebhookEvents {
  static const String batchStarted = 'batch.started';
  static const String batchCompleted = 'batch.completed';
  static const String batchFailed = 'batch.failed';
  static const String wallpaperAdded = 'wallpaper.added';
  static const String wallpaperRemoved = 'wallpaper.removed';
  static const String wallpaperRated = 'wallpaper.rated';
  static const String wallpaperReported = 'wallpaper.reported';
  static const String nsfwDetected = 'nsfw.detected';
  static const String duplicateFound = 'duplicate.found';
  static const String maintenanceCompleted = 'maintenance.completed';
}
