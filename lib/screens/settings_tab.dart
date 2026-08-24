import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/quality_settings_controller.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final quality = context.watch<QualitySettingsController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const _SectionHeader('Calidad de imagen'),
          const _SectionDescription(
            'Afecta la resolución y el peso de los fondos estáticos al '
            'aplicarlos. "Equilibrada" es la opción recomendada.',
          ),
          RadioGroup<ImageQuality>(
            groupValue: quality.imageQuality,
            onChanged: (value) {
              if (value != null) quality.setImageQuality(value);
            },
            child: Column(
              children: [
                for (final level in ImageQuality.values)
                  RadioListTile<ImageQuality>(
                    value: level,
                    title: Text(_imageQualityLabel(level)),
                    subtitle: Text(_imageQualityDetail(level)),
                  ),
              ],
            ),
          ),
          const Divider(height: 32),
          const _SectionHeader('Calidad de fondos animados'),
          const _SectionDescription(
            'Controla qué versión de los videos se descarga. Subir la '
            'calidad pesa más y tarda más en aplicarse.',
          ),
          RadioGroup<AnimatedQuality>(
            groupValue: quality.animatedQuality,
            onChanged: (value) {
              if (value != null) quality.setAnimatedQuality(value);
            },
            child: Column(
              children: [
                for (final level in AnimatedQuality.values)
                  RadioListTile<AnimatedQuality>(
                    value: level,
                    title: Text(_animatedQualityLabel(level)),
                    subtitle: Text(_animatedQualityDetail(level)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _imageQualityLabel(ImageQuality level) => switch (level) {
        ImageQuality.balanced => 'Automática / Equilibrada',
        ImageQuality.high => 'Alta',
        ImageQuality.maximum => 'Máxima',
      };

  String _imageQualityDetail(ImageQuality level) => switch (level) {
        ImageQuality.balanced => 'Buen balance entre nitidez y peso del archivo.',
        ImageQuality.high => 'Más resolución y nitidez, archivos más pesados.',
        ImageQuality.maximum => 'La mejor calidad disponible, mayor uso de datos y almacenamiento.',
      };

  String _animatedQualityLabel(AnimatedQuality level) => switch (level) {
        AnimatedQuality.balanced => 'Equilibrada',
        AnimatedQuality.high => 'Alta',
        AnimatedQuality.maximum => 'Máxima',
      };

  String _animatedQualityDetail(AnimatedQuality level) => switch (level) {
        AnimatedQuality.balanced => 'Descargas rápidas y livianas, calidad de sobra para la mayoría de las pantallas.',
        AnimatedQuality.high => 'Más nitidez, descargas más lentas.',
        AnimatedQuality.maximum => 'La mejor calidad de video disponible, descargas notablemente más pesadas.',
      };
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SectionDescription extends StatelessWidget {
  const _SectionDescription(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
