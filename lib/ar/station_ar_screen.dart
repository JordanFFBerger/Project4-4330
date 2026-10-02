import 'package:ar_flutter_plugin_plus/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_plus/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_plus/models/ar_node.dart';
import 'package:ar_flutter_plugin_plus/widgets/ar_view.dart';
import 'package:flutter/material.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import 'station_store.dart';
import '../gallery/media_store.dart';
import 'ar_tutorial.dart';

class StationArScreen extends StatefulWidget {
  const StationArScreen({super.key, required this.stations});
  final List<PokemonStation> stations;
  @override
  State<StationArScreen> createState() => _StationArScreenState();
}

class _StationArScreenState extends State<StationArScreen> {
  ARSessionManager? _session;
  ARObjectManager? _objects;
  ARNode? _node;
  bool _busy = false;
  bool _savingPhoto = false;
  Future<void> _takePhoto() async {
    if (_session == null || _savingPhoto) return;
    setState(() => _savingPhoto = true);
    try {
      final image = await _session!.snapshot();
      if (image is! MemoryImage) throw StateError('Snapshot unavailable');
      await MediaStore().savePhoto(image.bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('AR photo saved to Gallery')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not save AR photo. Check available space and retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _savingPhoto = false);
    }
  }

  String _status = 'Starting AR. Allow camera access when prompted.';
  void _message(String text) {
    if (mounted) setState(() => _status = text);
  }

  void _created(
    ARSessionManager session,
    ARObjectManager objects,
    ARAnchorManager anchors,
    ARLocationManager location,
  ) async {
    _session = session;
    _objects = objects;
    session.onImageTrackingConfigured = (ok) => _message(
      ok
          ? 'Scan a placed marker. Move slowly and keep it well lit.'
          : 'Marker setup failed. Close this screen and retry.',
    );
    session.onTrackingStateChanged = (state, reason) {
      if (state != 'TRACKING') {
        _message('Tracking paused: $reason. Point at the marker again.');
      }
    };
    session.onImageDetected = _detected;
    try {
      objects.onInitialize(androidScaleFactor: 1.0);
      await session.onInitialize(
        showPlanes: false,
        showFeaturePoints: false,
        handleTaps: false,
        trackingImagePaths: widget.stations
            .map((s) => 'assets/markers/${s.marker}.png')
            .toList(),
        continuousImageTracking: true,
        imageTrackingUpdateIntervalMs: 500,
      );
    } catch (_) {
      _message(
        'AR could not start. Check camera permission and ARCore support.',
      );
    }
  }

  Future<void> _detected(String imageName, vm.Matrix4 pose) async {
    if (_busy || !mounted) return;
    final matches = widget.stations.where((s) => s.marker == imageName);
    if (matches.isEmpty) return;
    final station = matches.first;
    final transform = pose.clone();
    // Converted models have a 60 cm maximum rest-pose dimension.
    if (_node?.name == imageName) {
      _node!.transform = transform;
      _message(
        '${station.name} · Floor ${station.position.floor} · Marker aligned',
      );
      return;
    }
    _busy = true;
    try {
      if (_node != null) {
        _objects?.removeNode(_node!);
        _node = null;
      }
      final node = ARNode(
        type: NodeType.localGLB,
        uri: 'assets/pokemon/${station.id}.glb',
        name: imageName,
        transformation: transform,
      );
      final added = await _objects?.addNode(node);
      if (!mounted) return;
      if (added == true) {
        _node = node;
        _message(
          '${station.name} · Floor ${station.position.floor} · Marker aligned',
        );
      } else {
        _message('Could not load ${station.name}. Rescan to retry.');
      }
    } catch (_) {
      _message('Placement failed. Rescan the marker to retry.');
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Pokémon AR'),
      actions: [
        IconButton(
          tooltip: 'Pokémon AR tutorial',
          onPressed: () => showArTutorial(context),
          icon: const Icon(Icons.help_outline),
        ),
        IconButton(
          tooltip: 'Save AR photo',
          onPressed: _savingPhoto || _node == null ? null : _takePhoto,
          icon: const Icon(Icons.camera_alt),
        ),
      ],
    ),
    body: Stack(
      children: [
        ARView(
          onARViewCreated: _created,
          planeDetectionConfig: PlaneDetectionConfig.none,
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(_status),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
