import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project4/gallery/gallery_screen.dart';
import 'package:project4/gallery/media_store.dart';

class EmptyMediaStore extends MediaStore {
  @override
  Future<List<MediaItem>> list() async => [];
}

void main() {
  testWidgets(
    'gallery offers Pokemon previews and an empty media capture action',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: GalleryScreen(mediaStore: EmptyMediaStore())),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 300));
      });
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 10),
      );
      expect(find.text('Bulbasaur'), findsOneWidget);
      expect(find.text('Charizard'), findsOneWidget);
      await tester.tap(find.text('Photos & videos'));
      await tester.pumpAndSettle();
      expect(
        find.text('Your photos and videos will appear here.'),
        findsOneWidget,
      );
      expect(find.text('Open camera'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
