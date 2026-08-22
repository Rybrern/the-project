import 'package:flutter/widgets.dart';

import '../models/wallpaper.dart';

/// Un celular angosto (como el Redmi Note 11, ~1080x2400) da una relación
/// lado corto/lado largo baja, alrededor de 0.45. Tablets, plegables
/// abiertos u otros equipos con pantalla menos alargada dan un valor bastante
/// mayor y pueden mostrar fondos horizontales sin que se vean forzados.
bool deviceFitsWideWallpapers(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  final shortSide = size.width < size.height ? size.width : size.height;
  final longSide = size.width < size.height ? size.height : size.width;
  if (longSide == 0) return false;
  return shortSide / longSide > 0.6;
}

/// Filtra los fondos horizontales cuando el dispositivo no da para
/// mostrarlos bien, salvo que el usuario haya confirmado que los quiere ver
/// igual ([showMismatched]).
List<Wallpaper> filterByOrientation(
  List<Wallpaper> wallpapers, {
  required bool deviceFitsWide,
  required bool showMismatched,
}) {
  if (showMismatched || deviceFitsWide) return wallpapers;
  return wallpapers.where((w) => w.aspectRatio <= 1).toList(growable: false);
}
