import 'package:google_mobile_ads/google_mobile_ads.dart';

import '../config/ads_config.dart';

/// Punto único para inicializar el SDK de AdMob y precargar el anuncio
/// recompensado (se muestra antes de descargar o aplicar un fondo).
class AdsService {
  AdsService._();

  static final AdsService instance = AdsService._();

  RewardedAd? _rewardedAd;
  bool _loadingRewardedAd = false;

  InterstitialAd? _interstitialAd;
  bool _loadingInterstitialAd = false;

  Future<void> initialize() async {
    await MobileAds.instance.initialize();
    _loadRewardedAd();
    _loadInterstitialAd();
  }

  void _loadRewardedAd() {
    if (_loadingRewardedAd || _rewardedAd != null) return;
    _loadingRewardedAd = true;
    RewardedAd.load(
      adUnitId: AdsConfig.rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingRewardedAd = false;
          _rewardedAd = ad;
        },
        onAdFailedToLoad: (_) {
          _loadingRewardedAd = false;
          _rewardedAd = null;
        },
      ),
    );
  }

  /// Muestra el anuncio recompensado si hay uno disponible y espera a que el
  /// usuario lo complete. Devuelve `true` si se ganó la recompensa (o si no
  /// había anuncio disponible, para no bloquear la funcionalidad principal
  /// de la app por una falla de red o de relleno de inventario).
  Future<bool> showRewardedAd() async {
    final ad = _rewardedAd;
    if (ad == null) {
      _loadRewardedAd();
      return true;
    }

    _rewardedAd = null;
    var earnedReward = false;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _loadRewardedAd();
      },
    );

    await ad.show(onUserEarnedReward: (_, _) => earnedReward = true);
    return earnedReward;
  }

  void _loadInterstitialAd() {
    if (_loadingInterstitialAd || _interstitialAd != null) return;
    _loadingInterstitialAd = true;
    InterstitialAd.load(
      adUnitId: AdsConfig.interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          _loadingInterstitialAd = false;
          _interstitialAd = ad;
        },
        onAdFailedToLoad: (_) {
          _loadingInterstitialAd = false;
          _interstitialAd = null;
        },
      ),
    );
  }

  /// Muestra el anuncio intersticial si hay uno disponible. No bloquea nada
  /// si no hay anuncio cargado: simplemente no se muestra.
  Future<void> showInterstitialAd() async {
    final ad = _interstitialAd;
    if (ad == null) {
      _loadInterstitialAd();
      return;
    }

    _interstitialAd = null;

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _loadInterstitialAd();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        _loadInterstitialAd();
      },
    );

    await ad.show();
  }
}
