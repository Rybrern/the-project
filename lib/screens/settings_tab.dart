import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/quality_settings_controller.dart';
import 'upload_wallpaper_screen.dart';

class SettingsTab extends StatelessWidget {
  const SettingsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<QualitySettingsController>();

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: ListView(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
            child: Text(
              'Calidad de imagen',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          RadioGroup<ImageQuality>(
            groupValue: controller.quality,
            onChanged: (value) {
              if (value != null) controller.setQuality(value);
            },
            child: Column(
              children: [
                for (final quality in ImageQuality.values)
                  RadioListTile<ImageQuality>(
                    value: quality,
                    title: Text(quality.label),
                    subtitle: Text(quality.description),
                  ),
              ],
            ),
          ),
          const Divider(height: 32),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Contenido',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.add_photo_alternate_outlined),
            title: const Text('Subir un fondo'),
            subtitle: const Text('Se revisa antes de aparecer en el catálogo'),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const UploadWallpaperScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
