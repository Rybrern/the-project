import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ImageQuality { media, alta, ultra }

extension ImageQualityX on ImageQuality {
  /// Piso mínimo de `Wallpaper.qualityScore` para este nivel. `0.0` no
  /// agrega ningún piso extra: "Media" ya es la base de todo el catálogo,
  /// los 3 servicios de fondos rechazan de entrada cualquier cosa por
  /// debajo de Full HD.
  double get minScore => switch (this) {
        ImageQuality.media => 0.0,
        ImageQuality.alta => 0.9,
        ImageQuality.ultra => 1.0,
      };

  String get label => switch (this) {
        ImageQuality.media => 'Media (Full HD)',
        ImageQuality.alta => 'Alta (2K / QHD)',
        ImageQuality.ultra => 'Ultra (4K)',
      };

  String get description => switch (this) {
        ImageQuality.media => 'Muestra todos los fondos del catálogo (1080p o mejor).',
        ImageQuality.alta => 'Solo fondos 2K/QHD o mejor.',
        ImageQuality.ultra => 'Solo fondos 4K.',
      };
}

/// Preferencia de calidad mínima del usuario, persistida entre sesiones.
class QualitySettingsController extends ChangeNotifier {
  QualitySettingsController() {
    _load();
  }

  static const _prefsKey = 'image_quality';

  ImageQuality _quality = ImageQuality.media;
  ImageQuality get quality => _quality;

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    if (saved == null) return;
    _quality = ImageQuality.values.firstWhere(
      (q) => q.name == saved,
      orElse: () => ImageQuality.media,
    );
    notifyListeners();
  }

  Future<void> setQuality(ImageQuality quality) async {
    if (quality == _quality) return;
    _quality = quality;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, quality.name);
  }
}
