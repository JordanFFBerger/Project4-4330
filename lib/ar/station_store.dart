import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../map/pft_map_data.dart';

class PokemonStation {
  const PokemonStation({
    required this.id,
    required this.name,
    required this.position,
  });
  final int id;
  final String name;
  final PftMapPosition position;
  String get marker => 'marker-$id';
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'position': position.toJson(),
  };
  factory PokemonStation.fromJson(Map<String, dynamic> json) {
    final position = PftMapPosition.fromJson(
      json['position'] as Map<String, dynamic>,
    );
    if (position.floor < 1 || position.floor > 3) {
      throw const FormatException('Invalid floor');
    }
    return PokemonStation(
      id: json['id'] as int,
      name: json['name'] as String,
      position: position,
    );
  }
}

class StationStore {
  static List<PokemonStation> randomize(
    List<Map<String, dynamic>> catalog,
    List<PftLandmark> landmarks,
    Random random,
  ) {
    final spots = List<PftLandmark>.of(landmarks)..shuffle(random);
    if (spots.length < catalog.length) {
      throw StateError('Not enough distinct landmarks');
    }
    return [
      for (var i = 0; i < catalog.length; i++)
        PokemonStation(
          id: catalog[i]['id'] as int,
          name: catalog[i]['name'] as String,
          position: spots[i].position,
        ),
    ];
  }

  static const key = 'pft.markerStations.v1';
  static Future<List<PokemonStation>> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(key);
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((v) => PokemonStation.fromJson(v as Map<String, dynamic>))
        .toList();
  }

  static Future<void> save(List<PokemonStation> stations) async {
    final prefs = await SharedPreferences.getInstance();
    if (!await prefs.setString(
      key,
      jsonEncode(stations.map((s) => s.toJson()).toList()),
    )) {
      throw StateError('Could not save placements');
    }
  }

  static Future<List<Map<String, dynamic>>> catalog() async {
    final data = jsonDecode(
      await rootBundle.loadString('assets/pokemon/manifest.json'),
    ) as Map<String, dynamic>;
    return (data['models'] as List).cast<Map<String, dynamic>>();
  }
}
