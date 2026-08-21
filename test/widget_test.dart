import 'package:flutter_test/flutter_test.dart';

import 'package:wallpaper_app/main.dart';

void main() {
  testWidgets('Home shell shows the catalog tab title', (WidgetTester tester) async {
    await tester.pumpWidget(const WallpaperApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Fondos de pantalla'), findsOneWidget);
  });
}
