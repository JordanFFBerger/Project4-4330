import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project4/map/pft_map_data.dart';
import 'package:project4/map/pft_map_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late PftMapData map;
  setUpAll(() async => map = await PftMapData.load());

  test('Every landmark belongs to a floor and each floor image matches its dimensions', () {
    expect(map.floors.map((floor) => floor.id), [1, 2, 3]);
    for (final floor in map.floors) {
      final png = File(floor.asset).readAsBytesSync();
      final header = png.buffer.asByteData();
      expect(header.getUint32(16), floor.width);
      expect(header.getUint32(20), floor.height);
      expect(
        map.landmarks.where((place) => place.position.floor == floor.id),
        isNotEmpty,
      );
    }
  });

  test('Invalid or non-finite normalized coordinates are rejected', () {
    for (final coordinate in [-0.01, 1.01, double.nan, double.infinity]) {
      expect(
        () => PftMapPosition(floor: 1, x: coordinate, y: 0.5),
        throwsArgumentError,
      );
      expect(
        () => PftMapPosition(floor: 1, x: 0.5, y: coordinate),
        throwsArgumentError,
      );
    }
    final position = PftMapPosition(floor: 2, x: 0.2, y: 0.8);
    expect(
      PftMapPosition.fromJson(position.toJson()).toJson(),
      position.toJson(),
    );
  });

  test('Map data rejects landmarks pointing to nonexistent floors', () {
    final json = jsonDecode(
      File('assets/maps/pft-map.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    (json['landmarks'] as List).first['floor'] = 99;
    expect(() => PftMapData.fromJson(json), throwsFormatException);
  });

  Future<void> openMap(
    WidgetTester tester, {
    PftMapScreen screen = const PftMapScreen(),
  }) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(MaterialApp(home: screen));
      await PftMapData.load();
    });
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('pft-map-viewport')), findsOneWidget);
  }

  testWidgets(
    'Switching floors updates the plan and hides other-floor landmarks',
    (tester) async {
      await openMap(tester);
      expect(find.byKey(const ValueKey('floor-plan-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('landmark-f1-commons')), findsOneWidget);
      await tester.tap(find.text('2nd floor'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('floor-plan-2')), findsOneWidget);
      expect(find.byKey(const ValueKey('landmark-f1-commons')), findsNothing);
      expect(
        find.byKey(const ValueKey('landmark-f2-student-services')),
        findsOneWidget,
      );
      await tester.tap(find.text('3rd floor'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('floor-plan-3')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Room search selects a place on another floor and focuses its marker',
    (tester) async {
      await openMap(tester);
      await tester.tap(find.text('Find a place'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '3325');
      await tester.pumpAndSettle();
      await tester.tap(find.text('ECE & Computer Science'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('floor-plan-3')), findsOneWidget);
      expect(find.text('ECE & Computer Science'), findsOneWidget);
      final viewport = tester.getRect(
        find.byKey(const ValueKey('pft-map-viewport')),
      );
      final markerCenter = tester.getCenter(
        find.byKey(const ValueKey('landmark-f3-ece-cs')),
      );
      expect((markerCenter - viewport.center).distance, lessThan(1));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Position placement stays aligned after zoom and pan and keeps its floor',
    (tester) async {
      PftMapPosition? placed;
      await openMap(
        tester,
        screen: PftMapScreen(
          onManualPositionChanged: (point) => placed = point,
        ),
      );
      await tester.tap(find.byTooltip('Zoom in'));
      await tester.pumpAndSettle();
      final viewport = tester.getRect(
        find.byKey(const ValueKey('pft-map-viewport')),
      );
      await tester.dragFrom(viewport.center, const Offset(35, -25));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test position'));
      await tester.pumpAndSettle();
      final currentViewport = tester.getRect(
        find.byKey(const ValueKey('pft-map-viewport')),
      );
      final tap = currentViewport.center + const Offset(-20, 15);
      final viewer = tester.widget<InteractiveViewer>(
        find.byType(InteractiveViewer),
      );
      final scenePoint = viewer.transformationController!.toScene(
        tap - currentViewport.topLeft,
      );
      await tester.tapAt(tap);
      await tester.pumpAndSettle();
      expect(placed, isNotNull);
      expect(placed!.x, closeTo(scenePoint.dx / 1000, 0.00001));
      expect(placed!.y, closeTo(scenePoint.dy / (1000 * 2300 / 2520), 0.00001));
      expect(placed!.floor, 1);
      expect(find.byKey(const ValueKey('player-position')), findsOneWidget);
      await tester.tap(find.text('2nd floor'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('player-position')), findsNothing);
      await tester.tap(find.text('1st floor'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('player-position')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Only encounters on the selected floor appear and taps reach game code',
    (tester) async {
      final first = PftEncounter(
        id: 'one',
        name: 'Bulbasaur',
        position: PftMapPosition(floor: 1, x: 0.37, y: 0.77),
      );
      final second = PftEncounter(
        id: 'two',
        name: 'Pikachu',
        position: PftMapPosition(floor: 2, x: 0.75, y: 0.39),
      );
      PftEncounter? tapped;
      await openMap(
        tester,
        screen: PftMapScreen(
          encounters: [first, second],
          onEncounterSelected: (encounter) => tapped = encounter,
        ),
      );
      expect(find.byKey(const ValueKey('encounter-one')), findsOneWidget);
      expect(find.byKey(const ValueKey('encounter-two')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('encounter-one')));
      await tester.pumpAndSettle();
      expect(tapped, same(first));
      await tester.tap(find.text('2nd floor'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('encounter-one')), findsNothing);
      expect(find.byKey(const ValueKey('encounter-two')), findsOneWidget);
    },
  );

  testWidgets('Small portrait and landscape layouts do not overflow', (
    tester,
  ) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    tester.view.devicePixelRatio = 1;
    for (final size in [const Size(360, 740), const Size(740, 360)]) {
      tester.view.physicalSize = size;
      await openMap(tester);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
    'GPS status and controls fit phone layouts and hide on other floors',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      tester.view.devicePixelRatio = 1;
      for (final size in [const Size(360, 740), const Size(740, 360)]) {
        tester.view.physicalSize = size;
        await openMap(
          tester,
          screen: PftMapScreen(
            allowManualPositioning: false,
            playerPosition: PftMapPosition(floor: 1, x: .5, y: .5),
            statusText: 'Approximate GPS ±15 m • floor 1 selected manually',
            positionLabel: 'Approximate GPS ±15 m',
            extraActions: [
              IconButton(onPressed: () {}, icon: const Icon(Icons.shuffle)),
              IconButton(onPressed: () {}, icon: const Icon(Icons.my_location)),
            ],
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byKey(const ValueKey('player-position')), findsOneWidget);
        await tester.tap(find.text('2nd floor'));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('player-position')), findsNothing);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
