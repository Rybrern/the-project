import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/wallhaven_config.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'services/ads_service.dart';
import 'services/hybrid_wallpaper_service.dart';
import 'services/wallhaven_wallpaper_service.dart';
import 'state/favorites_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  AdsService.instance.initialize();
  runApp(const WallpaperApp());
}

class WallpaperApp extends StatelessWidget {
  const WallpaperApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => FavoritesController(),
      child: MaterialApp(
        title: 'Fondos HD',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
          useMaterial3: true,
        ),
        home: const _StartupGate(),
      ),
    );
  }
}

/// Muestra el onboarding solo la primera vez que se abre la app.
class _StartupGate extends StatefulWidget {
  const _StartupGate();

  @override
  State<_StartupGate> createState() => _StartupGateState();
}

class _StartupGateState extends State<_StartupGate> {
  bool? _onboardingComplete;

  @override
  void initState() {
    super.initState();
    _loadOnboardingStatus();
  }

  Future<void> _loadOnboardingStatus() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _onboardingComplete = prefs.getBool('onboarding_complete') ?? false);
  }

  @override
  Widget build(BuildContext context) {
    if (_onboardingComplete == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_onboardingComplete == true) {
      return HomeShell(
        wallpaperService: HybridWallpaperService(
          wallhavenService: WallhavenWallpaperService(apiKey: wallhavenApiKey),
        ),
      );
    }
    return OnboardingScreen(onFinished: () => setState(() => _onboardingComplete = true));
  }
}
