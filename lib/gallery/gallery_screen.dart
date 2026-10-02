import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:video_player/video_player.dart';

import '../ar/station_store.dart';
import '../camera_screen.dart';
import '../pokedex/pokedex_panel.dart';
import 'media_store.dart';
import 'photo_editor.dart';

class GallerySection extends StatelessWidget {
  const GallerySection({super.key});
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const SizedBox(height: 24),
      Text('Gallery', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Card(
        child: Column(
          children: [
            ListTile(
              leading: Image.asset(
                'assets/pokemon/thumbnails/25.png',
                width: 48,
                height: 48,
              ),
              title: const Text('Pokémon'),
              subtitle: const Text('Animated models & Pokédex details'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const GalleryScreen()),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined, size: 40),
              title: const Text('Photos & videos'),
              subtitle: const Text('Your camera and AR captures'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => const GalleryScreen(initialTab: 1),
                ),
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key, this.initialTab = 0, this.mediaStore});
  final int initialTab;
  final MediaStore? mediaStore;
  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  final _catalog = StationStore.catalog();
  late final _store = widget.mediaStore ?? MediaStore();
  Future<List<MediaItem>> _loadMedia() {
    final pending = _store.list();
    // The other tab may not mount its FutureBuilder until selected.
    pending.ignore();
    return pending;
  }

  late Future<List<MediaItem>> _media = _loadMedia();
  void _reload() {
    if (mounted) {
      setState(() {
        _media = _loadMedia();
      });
    }
  }

  Future<void> _camera() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => const CameraScreen()),
    );
    _reload();
  }

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    initialIndex: widget.initialTab,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Gallery'),
        actions: [
          IconButton(
            tooltip: 'Take photo or video',
            onPressed: _store.supported ? _camera : null,
            icon: const Icon(Icons.add_a_photo),
          ),
        ],
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Pokémon'),
            Tab(text: 'Photos & videos'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _catalog,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text('The Pokémon gallery could not be loaded.'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 220,
                  mainAxisExtent: 210,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: snapshot.data!.length,
                itemBuilder: (context, index) {
                  final model = snapshot.data![index];
                  return Card(
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => PokemonPreviewScreen(model: model),
                        ),
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Image.asset(
                                'assets/pokemon/thumbnails/${model['id']}.png',
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              model['name'] as String,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          ),
          !_store.supported
              ? const Center(
                  child: Text(
                    'Photos and videos are available in the Android app.',
                  ),
                )
              : FutureBuilder<List<MediaItem>>(
                  future: _media,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                        child: TextButton(
                          onPressed: _reload,
                          child: const Text('Could not open Gallery. Retry'),
                        ),
                      );
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final items = snapshot.data!;
                    if (items.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.photo_library_outlined,
                                size: 64,
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                'Your photos and videos will appear here.',
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _camera,
                                icon: const Icon(Icons.camera_alt),
                                label: const Text('Open camera'),
                              ),
                            ],
                          ),
                        ),
                      );
                    }
                    return RefreshIndicator(
                      onRefresh: () async {
                        _reload();
                        await _media;
                      },
                      child: GridView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(12),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 200,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: items.length,
                        itemBuilder: (context, index) {
                          final item = items[index];
                          return Card(
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute<void>(
                                    builder: (_) =>
                                        MediaDetailScreen(item: item),
                                  ),
                                );
                                _reload();
                              },
                              child: item.isVideo
                                  ? const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.play_circle_outline,
                                          size: 56,
                                        ),
                                        Text('Video'),
                                      ],
                                    )
                                  : SavedPhotoImage(
                                      key: ValueKey(item.id),
                                      item: item,
                                    ),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ],
      ),
    ),
  );
}

class PokemonPreviewScreen extends StatelessWidget {
  const PokemonPreviewScreen({super.key, required this.model});
  final Map<String, dynamic> model;
  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: Text(model['name'] as String),
        bottom: const TabBar(
          tabs: [
            Tab(text: '3D model'),
            Tab(text: 'Pokédex'),
          ],
        ),
      ),
      body: TabBarView(
        children: [
          Column(
            children: [
              Expanded(
                child: ModelViewer(
                  src: 'assets/pokemon/${model['file']}',
                  alt: 'Animated ${model['name']}',
                  autoPlay: true,
                  autoRotate: true,
                  cameraControls: true,
                  ar: false,
                  backgroundColor: const Color(0xFFF4F0FA),
                  debugLogging: false,
                ),
              ),
              const SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('Drag to rotate • Pinch to zoom'),
                ),
              ),
            ],
          ),
          PokedexPanel(id: model['id'] as int),
        ],
      ),
    ),
  );
}

class SavedPhotoImage extends StatefulWidget {
  const SavedPhotoImage({super.key, required this.item, this.contain = false});
  final MediaItem item;
  final bool contain;
  @override
  State<SavedPhotoImage> createState() => _SavedPhotoImageState();
}

class _SavedPhotoImageState extends State<SavedPhotoImage> {
  late final Future<Uint8List> _bytes = MediaStore().read(widget.item);
  @override
  Widget build(BuildContext context) => FutureBuilder<Uint8List>(
    future: _bytes,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Center(child: Icon(Icons.broken_image_outlined));
      }
      if (!snapshot.hasData) {
        return const Center(child: CircularProgressIndicator());
      }
      return Image.memory(
        snapshot.data!,
        width: double.infinity,
        height: double.infinity,
        fit: widget.contain ? BoxFit.contain : BoxFit.cover,
        cacheWidth: widget.contain ? null : 400,
        errorBuilder: (_, error, stack) =>
            const Icon(Icons.broken_image_outlined),
      );
    },
  );
}

class MediaDetailScreen extends StatefulWidget {
  const MediaDetailScreen({super.key, required this.item});
  final MediaItem item;
  @override
  State<MediaDetailScreen> createState() => _MediaDetailScreenState();
}

class _MediaDetailScreenState extends State<MediaDetailScreen>
    with WidgetsBindingObserver {
  VideoPlayerController? _player;
  String? _error;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.item.isVideo) _openVideo();
  }

  Future<void> _openVideo() async {
    VideoPlayerController? controller;
    try {
      controller = await MediaStore().videoController(widget.item);
      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _player = controller);
    } catch (_) {
      await controller?.dispose();
      if (mounted) setState(() => _error = 'This video could not be played.');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _player?.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player?.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete this capture?'),
        content: const Text('This removes it from the app gallery.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _player?.pause();
      await MediaStore().delete(widget.item);
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not delete this capture.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.item.isVideo ? 'Video' : 'Photo'),
      actions: [
        if (!widget.item.isVideo)
          IconButton(
            tooltip: 'Edit photo',
            onPressed: () async {
              final saved = await Navigator.push<bool>(
                context,
                MaterialPageRoute(
                  builder: (_) => PhotoEditorScreen(item: widget.item),
                ),
              );
              if (saved == true && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Edited copy saved to Gallery')),
                );
              }
            },
            icon: const Icon(Icons.edit),
          ),
        IconButton(
          tooltip: 'Delete capture',
          onPressed: _delete,
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    ),
    body: widget.item.isVideo
        ? (_error != null
              ? Center(child: Text(_error!))
              : _player == null
              ? const Center(child: CircularProgressIndicator())
              : Column(
                  children: [
                    Expanded(
                      child: Center(
                        child: AspectRatio(
                          aspectRatio: _player!.value.aspectRatio,
                          child: VideoPlayer(_player!),
                        ),
                      ),
                    ),
                    VideoProgressIndicator(_player!, allowScrubbing: true),
                    SafeArea(
                      top: false,
                      child: ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: _player!,
                        builder: (context, value, _) => IconButton(
                          tooltip: value.isPlaying ? 'Pause' : 'Play',
                          iconSize: 48,
                          icon: Icon(
                            value.isPlaying
                                ? Icons.pause_circle
                                : Icons.play_circle,
                          ),
                          onPressed: () => value.isPlaying
                              ? _player!.pause()
                              : _player!.play(),
                        ),
                      ),
                    ),
                  ],
                ))
        : InteractiveViewer(
            child: SavedPhotoImage(item: widget.item, contain: true),
          ),
  );
}
