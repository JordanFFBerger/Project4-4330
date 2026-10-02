import 'camera_screen.dart';
import 'gallery/gallery_screen.dart';

import 'package:flutter/material.dart';

import 'login_page.dart';
import 'map/explorer_screen.dart';
import 'ar/station_setup_screen.dart';
import 'ar/ar_tutorial.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Project 4',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF461D7C)),
      ),
      home: LoginPage(onLoginSuccess: (_) => const HomeScreen()),
    );
  }
}

// Chloe Phan: home screen and camera button.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Project 4')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.help_outline),
              label: const Text('Pokémon AR tutorial'),
              onPressed: () => showArTutorial(context),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.view_in_ar),
              label: const Text('Set up Pokémon AR'),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const StationSetupScreen(),
                ),
              ),
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.map_outlined),
              label: const Text('Open PFT Map'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => ExplorerScreen(
                      onOpenCamera: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (context) => const CameraScreen(),
                          ),
                        );
                      },
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              icon: const Icon(Icons.camera_alt),
              label: const Text('Open Camera'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (context) => const CameraScreen(),
                  ),
                );
              },
            ),
            const GallerySection(),
          ],
        ),
      ),
    );
  }
}
