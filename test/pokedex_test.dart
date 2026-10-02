import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project4/pokedex/pokedex_service.dart';
import 'package:project4/pokedex/pokedex_panel.dart';

final pokemon = {
  'id': 25,
  'height': 4,
  'weight': 60,
  'types': [
    {
      'type': {'name': 'electric'},
    },
  ],
  'abilities': [
    {
      'ability': {'name': 'lightning-rod'},
      'is_hidden': true,
    },
  ],
  'stats': [
    {
      'stat': {'name': 'special-attack'},
      'base_stat': 50,
    },
  ],
};
final species = {
  'genera': [
    {
      'language': {'name': 'en'},
      'genus': 'Mouse Pokémon',
    },
  ],
  'flavor_text_entries': [
    {
      'language': {'name': 'fr'},
      'flavor_text': 'French',
    },
    {
      'language': {'name': 'en'},
      'flavor_text': 'Electric\ncheeks.\fHello.',
    },
  ],
};
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('REST data is converted and persisted for offline reuse', () async {
    final urls = <Uri>[];
    final service = PokedexService(
      client: MockClient((request) async {
        urls.add(request.url);
        return http.Response(
          jsonEncode(
            request.url.path.contains('pokemon-species') ? species : pokemon,
          ),
          200,
        );
      }),
    );
    final entry = await service.load(25);
    expect(
      urls.map((url) => url.toString()),
      unorderedEquals([
        'https://pokeapi.co/api/v2/pokemon/25/',
        'https://pokeapi.co/api/v2/pokemon-species/25/',
      ]),
    );
    expect(entry.height, 0.4);
    expect(entry.weight, 6);
    expect(entry.description, 'Electric cheeks. Hello.');
    expect(entry.types, ['Electric']);
    expect(entry.abilities, ['Lightning Rod (hidden)']);
    expect(entry.stats['Special Attack'], 50);
    final offline = PokedexService(
      client: MockClient((_) async => throw StateError('Offline')),
    );
    expect((await offline.load(25)).category, 'Mouse Pokémon');
  });
  test('bad cache is replaced and failures are not cached', () async {
    SharedPreferences.setMockInitialValues({'pft.pokedex.v1.25': 'broken'});
    var fail = true;
    final service = PokedexService(
      client: MockClient((request) async {
        if (fail) return http.Response('Unavailable', 503);
        return http.Response(
          jsonEncode(
            request.url.path.contains('pokemon-species') ? species : pokemon,
          ),
          200,
        );
      }),
    );
    await expectLater(service.load(25), throwsA(isA<http.ClientException>()));
    fail = false;
    expect((await service.load(25)).id, 25);
  });
  testWidgets('Pokédex shows retry then recovered details', (tester) async {
    var fail = true;
    final service = PokedexService(
      client: MockClient((request) async {
        if (fail) return http.Response('Unavailable', 503);
        return http.Response(
          jsonEncode(
            request.url.path.contains('pokemon-species') ? species : pokemon,
          ),
          200,
        );
      }),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: PokedexPanel(id: 25, service: service)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Retry'), findsOneWidget);
    fail = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('#025 • Mouse Pokémon'), findsOneWidget);
    expect(find.text('Height: 0.4 m'), findsOneWidget);
    expect(find.text('Electric'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
