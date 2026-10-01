import 'dart:convert';

import 'package:flutter/services.dart';

/// Coordinates relative to a floor image, with (0, 0) at its top-left corner.
/// These are image coordinates, not latitude/longitude or distances in meters.
class PftMapPosition {
  PftMapPosition({required this.floor, required this.x, required this.y}) {
    if (!x.isFinite || !y.isFinite || x < 0 || x > 1 || y < 0 || y > 1) {
      throw ArgumentError(
        'Map coordinates must be finite and between 0 and 1.',
      );
    }
  }

  final int floor;
  final double x;
  final double y;

  factory PftMapPosition.fromJson(Map<String, dynamic> json) => PftMapPosition(
    floor: json['floor'] as int,
    x: (json['x'] as num).toDouble(),
    y: (json['y'] as num).toDouble(),
  );

  Map<String, dynamic> toJson() => {'floor': floor, 'x': x, 'y': y};
}

class PftFloor {
  const PftFloor({
    required this.id,
    required this.label,
    required this.description,
    required this.asset,
    required this.width,
    required this.height,
  });

  final int id;
  final String label;
  final String description;
  final String asset;
  final double width;
  final double height;

  factory PftFloor.fromJson(Map<String, dynamic> json) => PftFloor(
    id: json['id'] as int,
    label: json['label'] as String,
    description: json['description'] as String,
    asset: json['asset'] as String,
    width: (json['width'] as num).toDouble(),
    height: (json['height'] as num).toDouble(),
  );
}

class PftLandmark {
  const PftLandmark({
    required this.id,
    required this.name,
    required this.kind,
    required this.description,
    required this.position,
    this.room,
  });

  final String id;
  final String name;
  final String kind;
  final String description;
  final String? room;
  final PftMapPosition position;

  factory PftLandmark.fromJson(Map<String, dynamic> json) => PftLandmark(
    id: json['id'] as String,
    name: json['name'] as String,
    kind: json['kind'] as String,
    description: json['description'] as String,
    room: json['room'] as String?,
    position: PftMapPosition.fromJson(json),
  );
}

/// Game-owned encounter data. The map does not create or collect Pokemon.
class PftEncounter {
  const PftEncounter({
    required this.id,
    required this.name,
    required this.position,
  });

  final String id;
  final String name;
  final PftMapPosition position;
}

class PftMapData {
  const PftMapData({required this.floors, required this.landmarks});

  final List<PftFloor> floors;
  final List<PftLandmark> landmarks;

  static Future<PftMapData> load() async => PftMapData.fromJson(
    jsonDecode(await rootBundle.loadString('assets/maps/pft-map.json'))
        as Map<String, dynamic>,
  );

  factory PftMapData.fromJson(Map<String, dynamic> json) {
    if (json['coordinateSystem'] != 'image-normalized-top-left') {
      throw const FormatException('Unsupported map coordinate system.');
    }
    final floors = (json['floors'] as List)
        .map((item) => PftFloor.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    final landmarks = (json['landmarks'] as List)
        .map((item) => PftLandmark.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
    final floorIds = floors.map((floor) => floor.id).toSet();
    if (floors.isEmpty || floorIds.length != floors.length) {
      throw const FormatException('Map needs unique floors.');
    }
    for (final floor in floors) {
      if (!floor.width.isFinite ||
          !floor.height.isFinite ||
          floor.width <= 0 ||
          floor.height <= 0) {
        throw const FormatException('Floor image dimensions must be positive.');
      }
    }
    if (landmarks.map((item) => item.id).toSet().length != landmarks.length ||
        landmarks.any((item) => !floorIds.contains(item.position.floor))) {
      throw const FormatException('Invalid landmark ID or floor.');
    }
    return PftMapData(
      floors: List.unmodifiable(floors),
      landmarks: List.unmodifiable(landmarks),
    );
  }
}
