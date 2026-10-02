import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:vector_math/vector_math_64.dart';
import 'package:project4/ar/gps_placement.dart';
import 'package:project4/map/gps_calibration.dart';
import 'package:project4/map/pft_map_data.dart';

void main() {
  test('saved map placements round-trip through GPS on a rotated floor', () {
    final calibration = GpsCalibration([
      GpsAnchor(PftMapPosition(floor: 2, x: .1, y: .2), 30, -91, 3),
      GpsAnchor(PftMapPosition(floor: 2, x: .8, y: .3), 30, -90.999, 3),
      GpsAnchor(PftMapPosition(floor: 2, x: .2, y: .9), 30.001, -91, 3),
    ]);
    for (final point in [
      PftMapPosition(floor: 2, x: .4, y: .5),
      PftMapPosition(floor: 2, x: .9, y: .1),
    ]) {
      final gps = calibration.gpsFor(point);
      final restored = calibration.project(gps.$1, gps.$2)!;
      expect(restored.x, closeTo(point.x, 1e-8));
      expect(restored.y, closeTo(point.y, 1e-8));
    }
    expect(
      () => calibration.gpsFor(PftMapPosition(floor: 1, x: .5, y: .5)),
      throwsArgumentError,
    );
  });
  test('GPS offsets have correct metric distance and compass direction', () {
    final offset = GpsOffset.between(0, 0, .001, .001);
    expect(offset.north, closeTo(111.32, .01));
    expect(offset.east, closeTo(111.32, .01));
    expect(offset.distance, closeTo(157.43, .02));
    expect(GpsOffset.between(30, -91, 30, -91).distance, 0);
  });
  test('true north and east map correctly for different camera headings', () {
    final camera = Matrix4.translationValues(5, 1.6, 7);
    var pose = gpsWorldPose(camera, 0, 0, const GpsOffset(3, 4));
    expect(pose.getTranslation().storage, orderedEquals([8, 0, 3]));
    pose = gpsWorldPose(camera, math.pi / 2, 0, const GpsOffset(3, 4));
    expect(pose.entry(0, 3), closeTo(1, 1e-8));
    expect(pose.entry(2, 3), closeTo(4, 1e-8));
    final rotated = Matrix4.rotationY(-math.pi / 2)
      ..setTranslation(Vector3(5, 1.6, 7));
    pose = gpsWorldPose(rotated, math.pi / 2, 0, const GpsOffset(3, 4));
    expect(pose.entry(0, 3), closeTo(8, 1e-8));
    expect(pose.entry(2, 3), closeTo(3, 1e-8));
  });
  test('rejects vertical camera and stale or inaccurate GPS fixes', () {
    expect(
      () => gpsWorldPose(
        Matrix4.rotationX(math.pi / 2),
        0,
        0,
        const GpsOffset(1, 1),
      ),
      throwsFormatException,
    );
    final now = DateTime.utc(2026, 10, 2);
    expect(usableGpsFix(accuracy: 10, timestamp: now, now: now), isTrue);
    expect(usableGpsFix(accuracy: 21, timestamp: now, now: now), isFalse);
    expect(
      usableGpsFix(accuracy: double.nan, timestamp: now, now: now),
      isFalse,
    );
    expect(
      usableGpsFix(
        accuracy: 10,
        timestamp: now.subtract(const Duration(seconds: 11)),
        now: now,
      ),
      isFalse,
    );
  });
}
