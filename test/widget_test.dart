import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wallpaper_app/main.dart';

void main() {
  testWidgets('Home shell shows the catalog tab title', (WidgetTester tester) async {
    // Salteamos el onboarding: en este test nos interesa el catálogo, no la
    // primera experiencia de usuario.
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});

    await tester.pumpWidget(const WallpaperApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Fondos de pantalla'), findsOneWidget);
  });
}
