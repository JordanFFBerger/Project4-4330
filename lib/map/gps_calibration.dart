import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

import 'pft_map_data.dart';

class GpsAnchor {
  const GpsAnchor(this.position, this.latitude, this.longitude, this.accuracy);
  final PftMapPosition position;
  final double latitude, longitude, accuracy;
  Map<String, dynamic> toJson() => {
    'position': position.toJson(),
    'lat': latitude,
    'lon': longitude,
    'accuracy': accuracy,
  };
  factory GpsAnchor.fromJson(Map<String, dynamic> json) => GpsAnchor(
    PftMapPosition.fromJson(json['position'] as Map<String, dynamic>),
    (json['lat'] as num).toDouble(),
    (json['lon'] as num).toDouble(),
    (json['accuracy'] as num).toDouble(),
  );
}

class GpsCalibration {
  GpsCalibration(List<GpsAnchor> points) : anchors = List.unmodifiable(points) {
    if (anchors.length != 3 ||
        anchors.any(
          (a) =>
              a.position.floor != anchors.first.position.floor ||
              !a.latitude.isFinite ||
              a.latitude.abs() > 85 ||
              !a.longitude.isFinite ||
              a.longitude.abs() > 180 ||
              !a.accuracy.isFinite ||
              a.accuracy < 0 ||
              a.accuracy > 25,
        )) {
      throw const FormatException(
        'Use three points on the same floor with GPS accuracy within 25 m.',
      );
    }
    final b = _meters(anchors[1].latitude, anchors[1].longitude);
    final c = _meters(anchors[2].latitude, anchors[2].longitude);
    final area = (b.$1 * c.$2 - b.$2 * c.$1).abs();
    final a = anchors[0].position;
    final p = anchors[1].position;
    final q = anchors[2].position;
    final mapArea = ((p.x - a.x) * (q.y - a.y) - (p.y - a.y) * (q.x - a.x))
        .abs();
    if (area < 100 || mapArea < 0.002) {
      throw const FormatException(
        'Choose widely spaced points forming a triangle, not a line.',
      );
    }
    for (var i = 0; i < 3; i++) {
      for (var j = i + 1; j < 3; j++) {
        final u = _meters(anchors[i].latitude, anchors[i].longitude);
        final v = _meters(anchors[j].latitude, anchors[j].longitude);
        final distance = math.sqrt(
          math.pow(u.$1 - v.$1, 2) + math.pow(u.$2 - v.$2, 2),
        );
        if (distance <
            math.max(20, anchors[i].accuracy + anchors[j].accuracy)) {
          throw const FormatException(
            'Calibration points are too close for this GPS accuracy. Move farther apart.',
          );
        }
      }
    }
  }
  final List<GpsAnchor> anchors;
  int get floor => anchors.first.position.floor;

  /// Inverse of project: preserves the user's saved floor-plan placements.
  (double latitude, double longitude) gpsFor(PftMapPosition position) {
    if (position.floor != floor) throw ArgumentError('Wrong calibrated floor');
    final a = anchors[0].position;
    final b = anchors[1].position;
    final c = anchors[2].position;
    final determinant = (b.x - a.x) * (c.y - a.y) - (b.y - a.y) * (c.x - a.x);
    final u =
        ((position.x - a.x) * (c.y - a.y) - (position.y - a.y) * (c.x - a.x)) /
        determinant;
    final v =
        ((b.x - a.x) * (position.y - a.y) - (b.y - a.y) * (position.x - a.x)) /
        determinant;
    return (
      anchors[0].latitude +
          u * (anchors[1].latitude - anchors[0].latitude) +
          v * (anchors[2].latitude - anchors[0].latitude),
      anchors[0].longitude +
          u * (anchors[1].longitude - anchors[0].longitude) +
          v * (anchors[2].longitude - anchors[0].longitude),
    );
  }

  (double, double) _meters(double lat, double lon) => (
    (lon - anchors.first.longitude) *
        111320 *
        math.cos(anchors.first.latitude * math.pi / 180),
    (lat - anchors.first.latitude) * 111320,
  );
  PftMapPosition? project(double latitude, double longitude) {
    if (!latitude.isFinite || !longitude.isFinite) return null;
    final b = _meters(anchors[1].latitude, anchors[1].longitude);
    final c = _meters(anchors[2].latitude, anchors[2].longitude);
    final p = _meters(latitude, longitude);
    final determinant = b.$1 * c.$2 - b.$2 * c.$1;
    final u = (p.$1 * c.$2 - p.$2 * c.$1) / determinant;
    final v = (b.$1 * p.$2 - b.$2 * p.$1) / determinant;
    final a = anchors[0].position;
    final x =
        a.x +
        u * (anchors[1].position.x - a.x) +
        v * (anchors[2].position.x - a.x);
    final y =
        a.y +
        u * (anchors[1].position.y - a.y) +
        v * (anchors[2].position.y - a.y);
    if (!x.isFinite || !y.isFinite || x < 0 || x > 1 || y < 0 || y > 1) {
      return null;
    }
    return PftMapPosition(floor: floor, x: x, y: y);
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      'pft.gps.v1.$floor',
      jsonEncode(anchors.map((a) => a.toJson()).toList()),
    )) {
      throw StateError('Could not save calibration');
    }
  }

  static Future<GpsCalibration?> load(int floor) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('pft.gps.v1.$floor');
    if (raw == null) return null;
    try {
      final result = GpsCalibration(
        (jsonDecode(raw) as List)
            .map((a) => GpsAnchor.fromJson(a as Map<String, dynamic>))
            .toList(),
      );
      return result.floor == floor ? result : null;
    } catch (_) {
      return null;
    }
  }
}
