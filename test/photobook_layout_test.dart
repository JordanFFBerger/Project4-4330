import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project4/main.dart';
import 'package:project4/photobook_theme.dart';

void main() {
  testWidgets(
    'photobook home fits small portrait and landscape with large text',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      for (final size in [const Size(320, 640), const Size(740, 360)]) {
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            theme: photobookTheme(),
            home: MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(1.3),
              ),
              child: const HomeScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(find.text('Pokémon AR tutorial'), 250);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
