import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project4/ar/ar_tutorial.dart';
import 'package:project4/main.dart';

void main() {
  testWidgets(
    'tutorial opens from home, scrolls through five steps and closes',
    (tester) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
      await tester.scrollUntilVisible(find.text('Pokémon AR tutorial'), 300);
      await tester.tap(find.text('Pokémon AR tutorial'));
      await tester.pumpAndSettle();
      expect(find.text('Make Pokémon appear'), findsOneWidget);
      expect(find.textContaining('Your GPS and map pins'), findsOneWidget);
      for (final step in ArTutorial.steps) {
        await tester.scrollUntilVisible(
          find.text(step.$1),
          250,
          scrollable: find.descendant(
            of: find.byType(ArTutorial),
            matching: find.byType(Scrollable),
          ),
        );
        expect(find.text(step.$1), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      await tester.scrollUntilVisible(
        find.text('Got it'),
        250,
        scrollable: find.descendant(
          of: find.byType(ArTutorial),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Got it'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Got it'));
      await tester.pumpAndSettle();
      expect(find.byType(ArTutorial), findsNothing);
    },
  );
  test('Charizard retains animation and uses colored light-independent flame materials', () {
    final bytes = File('assets/pokemon/6.glb').readAsBytesSync();
    final header = ByteData.sublistView(bytes);
    expect(header.getUint32(0, Endian.little), 0x46546c67);
    expect(header.getUint32(8, Endian.little), bytes.length);
    final jsonLength = header.getUint32(12, Endian.little);
    final model = jsonDecode(
      utf8.decode(bytes.sublist(20, 20 + jsonLength)),
    ) as Map<String, dynamic>;
    expect(model['animations'], isNotEmpty);
    expect(model['skins'], isNotEmpty);
    final materials = model['materials'] as List;
    for (final index in [0, 1]) {
      final material = materials[index];
      expect(material['extensions']['KHR_materials_unlit'], isNotNull);
      expect(material['pbrMetallicRoughness']['baseColorTexture'], isNull);
      expect(material['pbrMetallicRoughness']['baseColorFactor'][0], 1);
    }
    expect(materials[1]['alphaMode'], 'BLEND');
    for (final index in [2, 3, 4]) {
      expect(
        materials[index]['pbrMetallicRoughness']['baseColorTexture'],
        isNotNull,
      );
    }
    final manifest = jsonDecode(
      File('assets/pokemon/manifest.json').readAsStringSync(),
    );
    expect(
      (manifest['models'] as List).firstWhere((m) => m['id'] == 6)['bytes'],
      bytes.length,
    );
  });
}
