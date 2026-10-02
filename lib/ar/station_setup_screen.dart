import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../map/pft_map_data.dart';
import '../map/pft_map_screen.dart';
import 'station_store.dart';
import 'station_ar_screen.dart';
import 'ar_tutorial.dart';

class StationSetupScreen extends StatefulWidget {
  const StationSetupScreen({super.key});
  @override
  State<StationSetupScreen> createState() => _StationSetupScreenState();
}

class _StationSetupScreenState extends State<StationSetupScreen> {
  List<PokemonStation> _stations = [];
  List<Map<String, dynamic>> _catalog = [];
  String? _error;
  bool _loading = true;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final catalog = await StationStore.catalog();
      final stations = await StationStore.load();
      if (!mounted) return;
      setState(() {
        _catalog = catalog;
        _stations = stations;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Placements could not be loaded. Close and retry.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _place(Map<String, dynamic> model) async {
    final position = await Navigator.of(context).push<PftMapPosition>(
      MaterialPageRoute(
        builder: (routeContext) => PftMapScreen(
          onManualPositionChanged: (position) =>
              Navigator.of(routeContext).pop(position),
        ),
      ),
    );
    if (position == null || !mounted) return;
    final station = PokemonStation(
      id: model['id'] as int,
      name: model['name'] as String,
      position: position,
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Place ${station.name} on floor ${position.floor}?'),
        content: const Text(
          'This map point becomes a GPS target using this floor’s calibration. Pokémon appear automatically nearby in GPS AR. Check that the location is accessible.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Save placement'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _save([..._stations.where((s) => s.id != station.id), station]);
  }

  Future<void> _save(List<PokemonStation> stations) async {
    try {
      await StationStore.save(stations);
      if (mounted) setState(() => _stations = stations);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Please retry.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Pokémon GPS setup'),
      actions: [
        IconButton(
          tooltip: 'Pokémon AR tutorial',
          onPressed: () => showArTutorial(context),
          icon: const Icon(Icons.help_outline),
        ),
      ],
    ),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
        ? Center(child: Text(_error!))
        : ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Choose a Pokémon, select the floor, turn on Test position, and tap its location. Your saved floor calibration converts the point to GPS. No printed markers are needed.',
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                icon: const Icon(Icons.view_in_ar),
                label: const Text('Find Pokémon in GPS AR'),
                onPressed:
                    _stations.isEmpty ||
                        kIsWeb ||
                        defaultTargetPlatform != TargetPlatform.android
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => StationArScreen(
                            stations: List.of(_stations),
                            initialFloor: _stations.first.position.floor,
                          ),
                        ),
                      ),
              ),
              if (kIsWeb || defaultTargetPlatform != TargetPlatform.android)
                const Text('GPS AR is currently enabled on Android only.'),
              OutlinedButton(
                onPressed: _stations.isEmpty
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => PftMapScreen(
                            allowManualPositioning: false,
                            encounters: _stations
                                .map(
                                  (s) => PftEncounter(
                                    id: s.marker,
                                    name: s.name,
                                    position: s.position,
                                  ),
                                )
                                .toList(),
                          ),
                        ),
                      ),
                child: Text('View ${_stations.length} placements on map'),
              ),
              for (final model in _catalog)
                Builder(
                  builder: (context) {
                    final matches = _stations.where((s) => s.id == model['id']);
                    final station = matches.isEmpty ? null : matches.first;
                    return Card(
                      child: ListTile(
                        leading: Image.asset(
                          'assets/pokemon/thumbnails/${model['id']}.png',
                          width: 48,
                        ),
                        title: Text(model['name'] as String),
                        subtitle: Text(
                          station == null
                              ? 'Not placed'
                              : 'Floor ${station.position.floor} · tap to move',
                        ),
                        onTap: () => _place(model),
                        trailing: station == null
                            ? const Icon(Icons.add_location_alt)
                            : IconButton(
                                tooltip: 'Remove placement',
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => _save(
                                  _stations
                                      .where((s) => s.id != station.id)
                                      .toList(),
                                ),
                              ),
                      ),
                    );
                  },
                ),
            ],
          ),
  );
}
