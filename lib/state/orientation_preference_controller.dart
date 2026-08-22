import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Si el usuario eligió ver fondos que no calzan con la orientación de su
/// pantalla (por ejemplo, horizontales en un celular angosto) a pesar de la
/// advertencia. Se persiste para no volver a preguntar en cada sesión.
class OrientationPreferenceController extends ChangeNotifier {
  static const _prefsKey = 'wallpaper_show_mismatched_orientation';

  bool _showMismatched = false;
  bool get showMismatched => _showMismatched;

  OrientationPreferenceController() {
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    _showMismatched = prefs.getBool(_prefsKey) ?? false;
    notifyListeners();
  }

  Future<void> setShowMismatched(bool value) async {
    _showMismatched = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }
}
