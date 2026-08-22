import 'dart:io';

import 'package:flutter/foundation.dart';

/// IDs de unidades de anuncio de AdMob.
///
/// Banner, rewarded e interstitial ya tienen ID real para Android, pero en
/// modo debug se sigue forzando el ID de prueba: servir el anuncio real de
/// la cuenta durante el desarrollo cuenta como tráfico inválido para AdMob y
/// puede llevar a que suspendan la cuenta. El ID real solo se usa en builds
/// de release.
///
/// iOS sigue usando IDs de prueba también en release hasta que se cree la
/// app de iOS en AdMob: reemplazarlos ahí (y actualizar
/// GADApplicationIdentifier en ios/Runner/Info.plist) antes de publicar en la
/// App Store.
class AdsConfig {
  const AdsConfig._();

  static String get bannerAdUnitId {
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/2934735716';
    if (kDebugMode) return 'ca-app-pub-3940256099942544/6300978111';
    return 'ca-app-pub-8003573930637347/3135356807';
  }

  static String get rewardedAdUnitId {
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/1712485313';
    if (kDebugMode) return 'ca-app-pub-3940256099942544/5224354917';
    return 'ca-app-pub-8003573930637347/2872622601';
  }

  static String get interstitialAdUnitId {
    if (Platform.isIOS) return 'ca-app-pub-3940256099942544/4411468910';
    if (kDebugMode) return 'ca-app-pub-3940256099942544/1033173712';
    return 'ca-app-pub-8003573930637347/1715830908';
  }
}
