import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Calidad de los fondos estáticos al descargarlos/recortarlos: controla
/// resolución máxima y compresión JPEG (ver `wallpaper_image_processor.dart`).
enum ImageQuality { balanced, high, maximum }

/// Calidad de los fondos animados al descargarlos: controla qué tier de
/// video pide Pixabay (ver `pixabay_video_service.dart`).
enum AnimatedQuality { balanced, high, maximum }

/// Preferencia de calidad/rendimiento del usuario, persistida entre
/// sesiones. "Equilibrada" es el default recomendado en ambos casos: no
/// tiene sentido bajar automáticamente la máxima calidad si el usuario no
/// lo pidió, así que el punto de partida es liviano.
class QualitySettingsController extends ChangeNotifier {
  static const _imageQualityKey = 'quality_image_tier';
  static const _animatedQualityKey = 'quality_animated_tier';

  ImageQuality _imageQuality = ImageQuality.balanced;
  AnimatedQuality _animatedQuality = AnimatedQuality.balanced;

  ImageQuality get imageQuality => _imageQuality;
  AnimatedQuality get animatedQuality => _animatedQuality;

  QualitySettingsController() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final imageIndex = prefs.getInt(_imageQualityKey);
    if (imageIndex != null && imageIndex < ImageQuality.values.length) {
      _imageQuality = ImageQuality.values[imageIndex];
    }
    final animatedIndex = prefs.getInt(_animatedQualityKey);
    if (animatedIndex != null && animatedIndex < AnimatedQuality.values.length) {
      _animatedQuality = AnimatedQuality.values[animatedIndex];
    }
    notifyListeners();
  }

  Future<void> setImageQuality(ImageQuality value) async {
    _imageQuality = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_imageQualityKey, value.index);
  }

  Future<void> setAnimatedQuality(AnimatedQuality value) async {
    _animatedQuality = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_animatedQualityKey, value.index);
  }
}
