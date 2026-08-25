import 'package:flutter/foundation.dart';

/// Gestor de experimentos A/B
class ExperimentManager {
  static final ExperimentManager _instance = ExperimentManager._internal();

  final Map<String, Experiment> _experiments = {};
  final Map<String, String> _userVariants = {}; // userId -> variantId

  factory ExperimentManager() => _instance;

  ExperimentManager._internal();

  /// Crea un nuevo experimento
  void createExperiment({
    required String id,
    required String name,
    required List<String> variants,
    required double trafficPercentage,
  }) {
    _experiments[id] = Experiment(
      id: id,
      name: name,
      variants: variants,
      trafficPercentage: trafficPercentage,
      createdAt: DateTime.now(),
      status: 'active',
    );

    debugPrint('ExperimentManager: Created experiment "$id" with ${variants.length} variants');
  }

  /// Asigna variante a usuario
  String assignVariant(String experimentId, String userId) {
    if (!_experiments.containsKey(experimentId)) {
      return 'control';
    }

    final key = '$experimentId:$userId';
    if (_userVariants.containsKey(key)) {
      return _userVariants[key]!;
    }

    final experiment = _experiments[experimentId]!;
    final hash = userId.hashCode % 100;

    String variant = 'control';
    if (hash < (experiment.trafficPercentage * 100).toInt()) {
      variant = experiment.variants[hash % experiment.variants.length];
    }

    _userVariants[key] = variant;
    return variant;
  }

  /// Obtiene experimento
  Experiment? getExperiment(String id) => _experiments[id];

  /// Lista experimentos
  List<Experiment> listExperiments() => _experiments.values.toList();

  /// Finaliza experimento
  void concludeExperiment(String id, {required String winner}) {
    final exp = _experiments[id];
    if (exp != null) {
      _experiments[id] = exp.copyWith(status: 'concluded', winner: winner);
      debugPrint('ExperimentManager: Experiment "$id" concluded. Winner: $winner');
    }
  }
}

class Experiment {
  const Experiment({
    required this.id,
    required this.name,
    required this.variants,
    required this.trafficPercentage,
    required this.createdAt,
    required this.status,
    this.winner,
  });

  final String id;
  final String name;
  final List<String> variants;
  final double trafficPercentage;
  final DateTime createdAt;
  final String status; // active, paused, concluded
  final String? winner;

  Experiment copyWith({String? status, String? winner}) {
    return Experiment(
      id: id,
      name: name,
      variants: variants,
      trafficPercentage: trafficPercentage,
      createdAt: createdAt,
      status: status ?? this.status,
      winner: winner ?? this.winner,
    );
  }
}
