import 'package:flutter/material.dart';

Future<void> showArTutorial(BuildContext context) async {
  await showModalBottomSheet<void>(
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
      'Open Set up Pokémon AR and tap a Pokémon. Pick the floor, tap Test position, then tap its location and save. You can also use Shuffle on the map to assign all Pokémon to landmarks.',
    ),
    (
      'Calibrate your floor once',
      'Open PFT Map, select your floor, then choose GPS options → Calibrate floor. Record three widely spaced known positions forming a triangle and save. Existing calibrations still work.',
    ),
    (
      'Walk toward a saved point',
      'Use the map to find the location. Pokémon load automatically when your reported GPS position is within 20 m of their saved point. Select your floor manually; GPS cannot identify it.',
    ),
    (
      'Open GPS AR',
      'Tap Find Pokémon in GPS AR in setup, or the AR icon on the map. Allow location and camera access. Use an ARCore-compatible Android phone with a compass. Install or update Google Play Services for AR if prompted.',
    ),
    (
      'Point, pause, and meet your Pokémon',
      'Slowly scan the ground, then hold the phone facing forward. Nearby Pokémon appear automatically at estimated GPS positions and stay anchored while you walk around. No printables or placement tap needed. Tap the camera icon to save an AR photo.',
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
            'Your GPS and map pins now bring Pokémon into AR—no printables. GPS, compass, and calibration errors can shift their appearance, especially indoors. Open Camera still takes regular photos and videos.',
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
        'Check the selected floor, saved placement, and calibration. Move within 20 m and wait for GPS accuracy of ±20 m or better. Scan a well-lit, textured floor. Move the phone in a figure eight if compass alignment is poor. Use Realign / retry after improving reception.',
      ),
      const SizedBox(height: 16),
      const Text(
        'Want a quick preview? Gallery → Pokémon shows animated models without GPS or an AR-compatible phone.',
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Got it'),
      ),
    ],
  );
}
