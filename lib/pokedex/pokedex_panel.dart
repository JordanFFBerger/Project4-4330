import 'package:flutter/material.dart';

import 'pokedex_service.dart';

class PokedexPanel extends StatefulWidget {
  const PokedexPanel({super.key, required this.id, this.service});
  final int id;
  final PokedexService? service;
  @override
  State<PokedexPanel> createState() => _PokedexPanelState();
}

class _PokedexPanelState extends State<PokedexPanel> {
  late Future<PokedexEntry> _entry = _load();
  Future<PokedexEntry> _load() =>
      (widget.service ?? PokedexService()).load(widget.id);
  @override
  Widget build(BuildContext context) => FutureBuilder<PokedexEntry>(
    future: _entry,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Pokédex details could not be loaded. Connect to the internet and try again.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => setState(() {
                    _entry = _load();
                  }),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        );
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      final entry = snapshot.data!;
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '#${entry.id.toString().padLeft(3, '0')} • ${entry.category}',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: entry.types
                .map((type) => Chip(label: Text(type)))
                .toList(),
          ),
          const SizedBox(height: 12),
          Text(entry.description, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 20),
          Wrap(
            spacing: 24,
            runSpacing: 8,
            children: [
              Text('Height: ${entry.height.toStringAsFixed(1)} m'),
              Text('Weight: ${entry.weight.toStringAsFixed(1)} kg'),
            ],
          ),
          const SizedBox(height: 20),
          Text('Abilities', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(entry.abilities.join(', ')),
          const SizedBox(height: 20),
          Text('Base stats', style: Theme.of(context).textTheme.titleMedium),
          for (final stat in entry.stats.entries)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Expanded(child: Text(stat.key)),
                  Text('${stat.value}'),
                ],
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            'Data from PokéAPI • pokeapi.co\nLoaded details are saved on this device for offline viewing.',
          ),
        ],
      );
    },
  );
}
