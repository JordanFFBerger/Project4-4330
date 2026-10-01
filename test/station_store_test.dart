import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:project4/ar/station_store.dart';
import 'package:project4/map/pft_map_data.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('placements survive storage and preserve floor coordinates', () async {
    final station = PokemonStation(
      id: 25,
      name: 'Pikachu',
      position: PftMapPosition(floor: 2, x: 0.2, y: 0.7),
    );
    await StationStore.save([station]);
    final restored = (await StationStore.load()).single;
    expect(restored.marker, 'marker-25');
    expect(restored.position.toJson(), station.position.toJson());
    await StationStore.save([]);
    expect(await StationStore.load(), isEmpty);
  });
  test('rejects invalid floor and nonfinite coordinates', () {
    expect(
      () => PokemonStation.fromJson({
        'id': 25,
        'name': 'Pikachu',
        'position': {'floor': 4, 'x': 0.5, 'y': 0.5},
      }),
      throwsFormatException,
    );
    expect(
      () => PftMapPosition(floor: 1, x: double.nan, y: 0),
      throwsArgumentError,
    );
  });
  test('at least ten bundled animated models', () async {
    final catalog = await StationStore.catalog();
    expect(catalog.length, greaterThanOrEqualTo(10));
    expect(catalog.every((m) => (m['animations'] as List).isNotEmpty), isTrue);
  });
}
