import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project4/map/gps_calibration.dart';
import 'package:project4/map/pft_map_data.dart';
import 'package:project4/ar/station_store.dart';

GpsAnchor point(double x, double y, double lat, double lon) =>
    GpsAnchor(PftMapPosition(floor: 2, x: x, y: y), lat, lon, 3);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  final points = [
    point(.1, .2, 30, -91),
    point(.8, .3, 30, -90.999),
    point(.2, .9, 30.001, -91),
  ];
  test(
    'calibration maps anchors and interior points, persists per floor',
    () async {
      final calibration = GpsCalibration(points);
      for (final anchor in points) {
        final projected = calibration.project(
          anchor.latitude,
          anchor.longitude,
        )!;
        expect(projected.x, closeTo(anchor.position.x, 1e-8));
        expect(projected.y, closeTo(anchor.position.y, 1e-8));
      }
      final center = calibration.project(30.00025, -90.99975)!;
      expect(center.x, closeTo(.3, 1e-6));
      expect(center.y, closeTo(.4, 1e-6));
      expect(calibration.project(31, -90), isNull);
      await calibration.save();
      expect(
        (await GpsCalibration.load(2))!.project(30, -91)!.x,
        closeTo(.1, 1e-8),
      );
      expect(await GpsCalibration.load(1), isNull);
    },
  );
  test('rejects collinear, inaccurate and insufficient calibration points', () {
    expect(
      () => GpsCalibration(points.take(2).toList()),
      throwsFormatException,
    );
    expect(
      () => GpsCalibration([points[0], points[1], point(.4, .4, 30, -90.998)]),
      throwsFormatException,
    );
    expect(
      () => GpsCalibration([
        points[0],
        points[1],
        GpsAnchor(points[2].position, 30.001, -91, 100),
      ]),
      throwsFormatException,
    );
  });
  test(
    'shuffle assigns every bundled Pokemon to a unique landmark and saves',
    () async {
      final catalog = await StationStore.catalog();
      final data = await PftMapData.load();
      final shuffled = StationStore.randomize(
        catalog,
        data.landmarks,
        Random(7),
      );
      expect(shuffled.length, 13);
      expect(
        shuffled.map((s) => s.id).toSet(),
        catalog.map((m) => m['id']).toSet(),
      );
      expect(shuffled.map((s) => s.position).toSet().length, 13);
      for (final station in shuffled) {
        expect(
          data.landmarks.any((l) => identical(l.position, station.position)),
          isTrue,
        );
      }
      await StationStore.save(shuffled);
      expect(
        (await StationStore.load()).map((s) => s.toJson()),
        shuffled.map((s) => s.toJson()),
      );
      expect(
        () => StationStore.randomize(catalog, [], Random(1)),
        throwsStateError,
      );
    },
  );
}
