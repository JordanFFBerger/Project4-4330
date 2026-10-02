import 'package:flutter/material.dart';

void showArTutorial(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (context) =>
        const FractionallySizedBox(heightFactor: 0.9, child: ArTutorial()),
  );
}

class ArTutorial extends StatelessWidget {
  const ArTutorial({super.key});
  static const steps = [
    (
      'Choose a Pokémon',
      'Open Set up Pokémon AR and tap a Pokémon. Pick the floor, tap Test position, then tap where you will put its marker. Save the placement after checking the spot.',
    ),
    (
      'Print its marker',
      'Use the matching image from the printable marker pack. Print the marker image exactly 20 cm wide, without stretching it. Each Pokémon has its own marker.',
    ),
    (
      'Put the marker in place',
      'Lay the printed marker flat at your saved location. Keep the full image uncovered and well lit. If you used Shuffle, move the markers to the new map locations.',
    ),
    (
      'Open the AR scanner',
      'Go back to Set up Pokémon AR and tap Scan placed markers. Allow camera access. Use an Android phone that supports ARCore; install or update Google Play Services for AR if prompted.',
    ),
    (
      'Point, pause, and meet your Pokémon',
      'Point the rear camera at the whole marker. Move slowly and hold steady while it scans. The Pokémon appears on the marker and animates. Tap the camera icon to save an AR photo to Gallery.',
    ),
  ];
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
    children: [
      Row(
        children: [
          Expanded(
            child: Text(
              'Make Pokémon appear',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
          ),
          IconButton(
            tooltip: 'Close tutorial',
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      const SizedBox(height: 8),
      const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'A printed marker brings the Pokémon into AR. GPS and map pins help you find the spot; they do not make it appear. Open Camera takes regular photos and videos.',
          ),
        ),
      ),
      for (var i = 0; i < steps.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(radius: 17, child: Text('${i + 1}')),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      steps[i].$1,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(steps[i].$2),
                  ],
                ),
              ),
            ],
          ),
        ),
      const Divider(),
      Text(
        'Nothing appearing?',
        style: Theme.of(context).textTheme.titleMedium,
      ),
      const SizedBox(height: 8),
      const Text(
        'Check that this Pokémon has a saved placement and that you printed its matching marker. Avoid glare, shadows, folds, and motion. Back up until the whole marker fits in view, then move closer slowly. If tracking pauses, point at the marker again.',
      ),
      const SizedBox(height: 16),
      const Text(
        'Want a quick preview? Gallery → Pokémon shows animated models without a printed marker or GPS.',
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Got it'),
      ),
    ],
  );
}
