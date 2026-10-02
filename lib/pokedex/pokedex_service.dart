import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

String displayName(String value) => value
    .split('-')
    .map(
      (word) =>
          word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}',
    )
    .join(' ');

class PokedexEntry {
  PokedexEntry(this.pokemon, this.species) {
    // Validate required fields before accepting network or cached data.
    id;
    height;
    weight;
    types;
    abilities;
    stats;
  }
  final Map<String, dynamic> pokemon;
  final Map<String, dynamic> species;
  int get id => pokemon['id'] as int;
  double get height => (pokemon['height'] as num) / 10;
  double get weight => (pokemon['weight'] as num) / 10;
  List<String> get types => (pokemon['types'] as List)
      .map((v) => displayName(v['type']['name'] as String))
      .toList();
  List<String> get abilities => (pokemon['abilities'] as List)
      .map(
        (v) =>
            '${displayName(v['ability']['name'] as String)}${v['is_hidden'] == true ? ' (hidden)' : ''}',
      )
      .toList();
  Map<String, int> get stats => {
    for (final stat in pokemon['stats'] as List)
      displayName(stat['stat']['name'] as String): stat['base_stat'] as int,
  };
  String _english(String list, String field, String fallback) {
    for (final entry in (species[list] as List? ?? [])) {
      if (entry['language']['name'] == 'en') {
        return (entry[field] as String).replaceAll(RegExp(r'\s+'), ' ').trim();
      }
    }
    return fallback;
  }

  String get category => _english('genera', 'genus', 'Pokémon');
  String get description => _english(
    'flavor_text_entries',
    'flavor_text',
    'No English description is available.',
  );
}

class PokedexService {
  PokedexService({this.client});
  final http.Client? client;

  Future<PokedexEntry> load(int id) async {
    if (id < 1) throw ArgumentError.value(id);
    SharedPreferences? prefs;
    final key = 'pft.pokedex.v1.$id';
    try {
      prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(key);
      if (raw != null) {
        final cached = jsonDecode(raw) as Map<String, dynamic>;
        final entry = PokedexEntry(
          cached['pokemon'] as Map<String, dynamic>,
          cached['species'] as Map<String, dynamic>,
        );
        if (entry.id == id) return entry;
      }
    } catch (_) {
      // An unavailable or damaged cache must not prevent a fresh request.
    }
    final requestClient = client ?? http.Client();
    try {
      Future<Map<String, dynamic>> get(String resource) async {
        final response = await requestClient
            .get(Uri.https('pokeapi.co', '/api/v2/$resource/$id/'))
            .timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) {
          throw http.ClientException('PokéAPI returned ${response.statusCode}');
        }
        return jsonDecode(response.body) as Map<String, dynamic>;
      }

      final data = await Future.wait([get('pokemon'), get('pokemon-species')]);
      final entry = PokedexEntry(data[0], data[1]);
      if (entry.id != id) throw const FormatException('Unexpected Pokémon');
      try {
        await prefs?.setString(
          key,
          jsonEncode({'pokemon': data[0], 'species': data[1]}),
        );
      } catch (_) {
        // Still show successfully fetched information if storage is full.
      }
      return entry;
    } finally {
      if (client == null) requestClient.close();
    }
  }
}
