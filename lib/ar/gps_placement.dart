import 'dart:math' as math;

import 'package:vector_math/vector_math_64.dart';

class GpsOffset {
  const GpsOffset(this.east, this.north);
  final double east, north;
  double get distance => math.sqrt(east * east + north * north);
  factory GpsOffset.between(
    double latitude,
    double longitude,
    double targetLatitude,
    double targetLongitude,
  ) => GpsOffset(
    (targetLongitude - longitude) * 111320 * math.cos(latitude * math.pi / 180),
    (targetLatitude - latitude) * 111320,
  );
}

/// Align true-north/east offsets with the AR camera's horizontal forward axis.
Matrix4 gpsWorldPose(
  Matrix4 camera,
  double headingRadians,
  double floorY,
  GpsOffset offset,
) {
  final fx = -camera.entry(0, 2), fz = -camera.entry(2, 2);
  final length = math.sqrt(fx * fx + fz * fz);
  if (!length.isFinite ||
      length < .25 ||
      !headingRadians.isFinite ||
      !floorY.isFinite ||
      !offset.east.isFinite ||
      !offset.north.isFinite) {
    throw const FormatException('Hold the phone facing forward to align GPS.');
  }
  final forwardX = fx / length, forwardZ = fz / length;
  final rightX = -forwardZ, rightZ = forwardX;
  final s = math.sin(headingRadians), c = math.cos(headingRadians);
  final x =
      camera.entry(0, 3) +
      offset.north * (c * forwardX - s * rightX) +
      offset.east * (s * forwardX + c * rightX);
  final z =
      camera.entry(2, 3) +
      offset.north * (c * forwardZ - s * rightZ) +
      offset.east * (s * forwardZ + c * rightZ);
  return Matrix4.translationValues(x, floorY, z);
}

bool usableGpsFix({
  required double accuracy,
  required DateTime timestamp,
  required DateTime now,
}) =>
    accuracy.isFinite &&
    accuracy >= 0 &&
    accuracy <= 20 &&
    now.difference(timestamp).abs() <= const Duration(seconds: 10);
