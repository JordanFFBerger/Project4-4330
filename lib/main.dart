import 'package:flutter/material.dart';

import 'camera_screen.dart';
import 'gallery/gallery_screen.dart';
import 'login_page.dart';
import 'map/explorer_screen.dart';
import 'ar/station_setup_screen.dart';
import 'ar/ar_tutorial.dart';
import 'photobook_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'PFT Fieldnotes',
    theme: photobookTheme(),
    home: LoginPage(onLoginSuccess: (_) => const HomeScreen()),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  void _open(BuildContext context, Widget screen) =>
      Navigator.of(context)
          .push(MaterialPageRoute<void>(builder: (_) => screen));
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('PFT Fieldnotes'),
      actions: const [
        Padding(
          padding: EdgeInsets.only(right: 20),
          child: Icon(Icons.auto_stories_outlined),
        ),
      ],
    ),
    body: Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            const Text(
              'A POKÉMON PHOTO JOURNAL',
              style: TextStyle(
                letterSpacing: 2,
                fontSize: 11,
                color: moss,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Little encounters.\nLasting memories.',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 12),
            const Text(
              'Follow the map, meet a Pokémon, and keep a little piece of the adventure.',
            ),
            const SizedBox(height: 22),
            SizedBox(
              height: 208,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.rotate(
                    angle: -.07,
                    child: Container(
                      width: 240,
                      height: 188,
                      color: const Color(0xFFE4D3B7),
                    ),
                  ),
                  Transform.rotate(
                    angle: .035,
                    child: SizedBox(
                      width: 240,
                      child: Card(
                        child: PhotoMount(
                          caption: 'A familiar face',
                          note: 'FIELD STUDY  /  No. 025',
                          child: Image.asset(
                            'assets/pokemon/thumbnails/25.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Open Camera'),
              onPressed: () => _open(context, const CameraScreen()),
            ),
            const SizedBox(height: 10),
            _JournalLink(
              icon: Icons.map_outlined,
              title: 'Open PFT Map',
              subtitle: 'Find your next encounter',
              onTap: () => _open(
                context,
                ExplorerScreen(
                  onOpenCamera: () => _open(context, const CameraScreen()),
                ),
              ),
            ),
            _JournalLink(
              icon: Icons.view_in_ar_outlined,
              title: 'Set up Pokémon AR',
              subtitle: 'Place Pokémon in your world',
              onTap: () => _open(context, const StationSetupScreen()),
            ),
            const GallerySection(),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              icon: const Icon(Icons.help_outline),
              label: const Text('Pokémon AR tutorial'),
              onPressed: () => showArTutorial(context),
            ),
            const SizedBox(height: 14),
            const Center(
              child: Text(
                'EXPLORE  ·  CAPTURE  ·  KEEP',
                style: TextStyle(fontSize: 10, letterSpacing: 2, color: moss),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _JournalLink extends StatelessWidget {
  const _JournalLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      leading: Icon(icon, color: moss),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.arrow_forward, size: 18),
      onTap: onTap,
    ),
  );
}
