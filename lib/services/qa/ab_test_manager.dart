import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';

/// Evento de A/B test
class ABTestEvent {
  final String userId;
  final String variant; // 'control' or 'test'
  final String event;
  final Map<String, dynamic>? metadata;
  final DateTime timestamp;

  ABTestEvent({
    required this.userId,
    required this.variant,
    required this.event,
    this.metadata,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'variant': variant,
      'event': event,
      'metadata': metadata,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}

/// Resultados de A/B test
class ABTestResults {
  final String testName;
  final int controlUsers;
  final int testUsers;
  final double controlConversion;
  final double testConversion;
  final double conversionLift; // (test - control) / control * 100
  final bool isSignificant; // Statistical significance
  final String? winner; // 'control', 'test', or null
  final DateTime testedAt;

  ABTestResults({
    required this.testName,
    required this.controlUsers,
    required this.testUsers,
    required this.controlConversion,
    required this.testConversion,
    required this.conversionLift,
    required this.isSignificant,
    this.winner,
    required this.testedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'testName': testName,
      'controlUsers': controlUsers,
      'testUsers': testUsers,
      'controlConversion': controlConversion,
      'testConversion': testConversion,
      'conversionLift': conversionLift,
      'isSignificant': isSignificant,
      'winner': winner,
      'testedAt': testedAt.toIso8601String(),
    };
  }
}

/// Manager de A/B tests
class ABTestManager {
  final Map<String, ABTestEvent> _events = {};
  final Random _random = Random();

  /// Asigna un usuario a una variante
  String randomizeUserToVariant(String userId, {double testRatio = 0.5}) {
    // Generar variante pseudoaleatoria basada en userId
    final hash = userId.hashCode;
    final variant = (hash.abs() % 100) < (testRatio * 100) ? 'test' : 'control';

    debugPrint('ABTestManager: User $userId assigned to $variant variant');
    return variant;
  }

  /// Tracks un evento
  void trackEvent(
    String userId,
    String variant,
    String event, {
    Map<String, dynamic>? metadata,
  }) {
    final eventId = '${userId}_${event}_${ DateTime.now().millisecondsSinceEpoch}';

    _events[eventId] = ABTestEvent(
      userId: userId,
      variant: variant,
      event: event,
      metadata: metadata,
    );

    debugPrint(
      'ABTestManager: Tracked event "$event" for user $userId ($variant)',
    );
  }

  /// Obtiene el ganador del test
  Future<ABTestResults> getWinner({
    required String testName,
    required String conversionEvent,
  }) async {
    debugPrint('ABTestManager: Analyzing test "$testName"...');

    // Contar usuarios por variante
    final controlEvents = _events.values
        .where((e) => e.variant == 'control' && e.event == conversionEvent)
        .toList();

    final testEvents = _events.values
        .where((e) => e.variant == 'test' && e.event == conversionEvent)
        .toList();

    // Contar usuarios únicos por variante
    final controlUsers =
        _events.values.where((e) => e.variant == 'control').map((e) => e.userId).toSet().length;

    final testUsers =
        _events.values.where((e) => e.variant == 'test').map((e) => e.userId).toSet().length;

    // Calcular conversión
    final controlConversion = controlUsers > 0 ? controlEvents.length / controlUsers : 0;
    final testConversion = testUsers > 0 ? testEvents.length / testUsers : 0;

    // Calcular lift
    final conversionLift = controlConversion > 0
        ? (testConversion - controlConversion) / controlConversion * 100
        : (testConversion > 0 ? 100 : 0);

    // Determinar significancia estadística (simulada)
    final isSignificant = (controlEvents.length > 30 && testEvents.length > 30) &&
        (conversionLift.abs() > 5); // Arbitrary threshold

    // Determinar ganador
    String? winner;
    if (isSignificant) {
      winner = testConversion > controlConversion ? 'test' : 'control';
    }

    debugPrint(
      'ABTestManager: Test "$testName" - Control: ${controlConversion.toStringAsFixed(3)} (n=$controlUsers), Test: ${testConversion.toStringAsFixed(3)} (n=$testUsers), Lift: ${conversionLift.toStringAsFixed(1)}%',
    );

    return ABTestResults(
      testName: testName,
      controlUsers: controlUsers,
      testUsers: testUsers,
      controlConversion: controlConversion.toDouble(),
      testConversion: testConversion.toDouble(),
      conversionLift: conversionLift.toDouble(),
      isSignificant: isSignificant,
      winner: winner,
      testedAt: DateTime.now(),
    );
  }

  /// Obtiene eventos de un usuario
  List<ABTestEvent> getUserEvents(String userId) {
    return _events.values.where((e) => e.userId == userId).toList();
  }

  /// Exporta eventos para análisis
  List<Map<String, dynamic>> exportEvents() {
    return _events.values.map((e) => e.toJson()).toList();
  }

  /// Limpia eventos
  void clear() {
    _events.clear();
    debugPrint('ABTestManager: Events cleared');
  }

  /// Obtiene estadísticas de eventos
  Map<String, dynamic> getEventStatistics() {
    final byVariant = <String, int>{};
    final byEvent = <String, int>{};

    for (final event in _events.values) {
      byVariant[event.variant] = (byVariant[event.variant] ?? 0) + 1;
      byEvent[event.event] = (byEvent[event.event] ?? 0) + 1;
    }

    return {
      'totalEvents': _events.length,
      'byVariant': byVariant,
      'byEvent': byEvent,
      'uniqueUsers': _events.values.map((e) => e.userId).toSet().length,
    };
  }
}
