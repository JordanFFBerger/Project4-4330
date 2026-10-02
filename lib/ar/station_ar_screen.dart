import 'dart:async';

import 'package:ar_flutter_plugin_plus/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_plus/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_plus/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_plus/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_plus/models/ar_node.dart';
import 'package:ar_flutter_plugin_plus/widgets/ar_view.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:vector_math/vector_math_64.dart' as vm;

import '../gallery/media_store.dart';
import '../map/gps_calibration.dart';
import '../map/gps_calibration_screen.dart';
import '../map/location_access.dart';
import 'ar_tutorial.dart';
import 'gps_placement.dart';
import 'station_store.dart';

class StationArScreen extends StatefulWidget {
  const StationArScreen({
    super.key,
    required this.stations,
    this.initialFloor = 1,
  });
  final List<PokemonStation> stations;
  final int initialFloor;
  @override
  State<StationArScreen> createState() => _StationArScreenState();
}

class _PlacedPokemon {
  const _PlacedPokemon(this.node, this.anchor);
  final ARNode node;
  final ARPlaneAnchor anchor;
}

class _StationArScreenState extends State<StationArScreen>
    with WidgetsBindingObserver {
  ARSessionManager? _session;
  ARObjectManager? _objects;
  ARAnchorManager? _anchors;
  final Map<int, _PlacedPokemon> _placed = {};
  GpsCalibration? _calibration;
  Position? _fix;
  StreamSubscription<Position>? _gps;
  Timer? _timer;
  late int _floor = widget.initialFloor;
  int _epoch = 0;
  bool _busy = false,
      _savingPhoto = false,
      _active = true,
      _calibrating = false,
      _ready = false,
      _gpsStarting = false;
  String _status = 'Starting GPS and AR. Allow location and camera access.';
  String? _gpsError;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _loadCalibration();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _update());
  }

  void _message(String text) {
    if (mounted && _status != text) setState(() => _status = text);
  }

  Future<void> _loadCalibration() async {
    final floor = _floor;
    try {
      final calibration = await GpsCalibration.load(floor);
      if (mounted && floor == _floor) {
        setState(() => _calibration = calibration);
      }
    } catch (_) {
      _message('Could not load calibration. Retry or calibrate this floor.');
    }
  }

  Future<void> _startGps() async {
    if (_gpsStarting || !_active || !_ready) return;
    _gpsStarting = true;
    _gpsError = null;
    try {
      await ensureLocationAccess();
      if (!mounted || !_active) return;
      await _gps?.cancel();
      _gps =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 0,
            ),
          ).listen(
            (fix) {
              if (mounted && _active) _fix = fix;
            },
            onError: (Object error) {
              _fix = null;
              _gpsError = 'GPS unavailable. Check Location settings and retry.';
              _message(_gpsError!);
            },
          );
    } catch (e) {
      _gpsError = '$e';
      _message(_gpsError!);
    } finally {
      _gpsStarting = false;
    }
  }

  Future<void> _created(
    ARSessionManager session,
    ARObjectManager objects,
    ARAnchorManager anchors,
    ARLocationManager location,
  ) async {
    _session = session;
    _objects = objects;
    _anchors = anchors;
    try {
      objects.onInitialize(androidScaleFactor: 1.0);
      await session.onInitialize(
        showPlanes: false,
        showFeaturePoints: false,
        handleTaps: false,
      );
      if (mounted) _ready = true;
      await _startGps();
    } catch (_) {
      _message(
        'AR could not start. Check camera permission and ARCore support.',
      );
    }
  }

  void _remove(int id) {
    final placed = _placed.remove(id);
    if (placed != null) {
      _objects?.removeNode(placed.node);
      _anchors?.removeAnchor(placed.anchor);
    }
  }

  void _reset() {
    _epoch++;
    for (final id in _placed.keys.toList()) {
      _remove(id);
    }
    if (mounted) setState(() {});
  }

  Future<void> _update() async {
    if (_busy || !_active || !_ready || !mounted) return;
    if (_calibration == null) {
      _message(
        'Calibrate floor $_floor to convert your saved placements to GPS.',
      );
      return;
    }
    final stations = widget.stations
        .where((s) => s.position.floor == _floor)
        .toList();
    if (stations.isEmpty) {
      _message(
        'No Pokémon saved on floor $_floor. Choose another floor or add placements.',
      );
      return;
    }
    final fix = _fix;
    if (fix == null) {
      _message(_gpsError ?? 'Waiting for a GPS location…');
      return;
    }
    if (!usableGpsFix(
      accuracy: fix.accuracy,
      timestamp: fix.timestamp,
      now: DateTime.now(),
    )) {
      _message(
        'Waiting for a fresh GPS fix within ±20 m. Current accuracy: ±${fix.accuracy.toStringAsFixed(0)} m.',
      );
      return;
    }
    final offsets = <int, GpsOffset>{};
    for (final station in stations) {
      final target = _calibration!.gpsFor(station.position);
      offsets[station.id] = GpsOffset.between(
        fix.latitude,
        fix.longitude,
        target.$1,
        target.$2,
      );
    }
    for (final id in _placed.keys.toList()) {
      if ((offsets[id]?.distance ?? double.infinity) > 35) _remove(id);
    }
    final nearby = stations.where((s) => offsets[s.id]!.distance <= 20).toList()
      ..sort(
        (a, b) => offsets[a.id]!.distance.compareTo(offsets[b.id]!.distance),
      );
    if (nearby.isEmpty) {
      final nearest = stations.reduce(
        (a, b) => offsets[a.id]!.distance < offsets[b.id]!.distance ? a : b,
      );
      _message(
        '${nearest.name} is about ${offsets[nearest.id]!.distance.toStringAsFixed(0)} m away. Walk within 20 m of its saved point.',
      );
      return;
    }
    _busy = true;
    final epoch = _epoch;
    try {
      final frame = await _session!
          .getGpsPlacementFrame(fix.latitude, fix.longitude, fix.altitude)
          .timeout(const Duration(seconds: 3));
      if (!mounted || !_active || epoch != _epoch) return;
      if (frame['status'] != 'ready') {
        _message(frame['status'] as String);
        return;
      }
      final camera = vm.Matrix4.fromList(
        (frame['camera'] as List).map((v) => (v as num).toDouble()).toList(),
      );
      final heading = (frame['heading'] as num).toDouble(),
          floorY = (frame['floorY'] as num).toDouble();
      for (final station in nearby) {
        if (_placed.containsKey(station.id)) continue;
        if (!mounted || !_active || epoch != _epoch) return;
        final pose = gpsWorldPose(
          camera,
          heading,
          floorY,
          offsets[station.id]!,
        );
        final anchor = ARPlaneAnchor(
          transformation: pose,
          name: 'gps-${station.id}-$epoch',
        );
        if (await _anchors!.addAnchor(anchor) != true) {
          _message('AR tracking is settling. Keep scanning the floor.');
          return;
        }
        if (!mounted || !_active || epoch != _epoch) {
          _anchors?.removeAnchor(anchor);
          return;
        }
        final node = ARNode(
          type: NodeType.localGLB,
          uri: 'assets/pokemon/${station.id}.glb',
          name: 'pokemon-${station.id}-$epoch',
          transformation: vm.Matrix4.identity(),
        );
        final added = await _objects!.addNode(node, planeAnchor: anchor);
        if (!mounted || !_active || epoch != _epoch || added != true) {
          _objects?.removeNode(node);
          _anchors?.removeAnchor(anchor);
          if (added != true) {
            _message('Could not load ${station.name}. Retrying…');
          }
          return;
        }
        _placed[station.id] = _PlacedPokemon(node, anchor);
      }
      _message(
        '${_placed.length} Pokémon at saved GPS points • ±${fix.accuracy.toStringAsFixed(0)} m GPS accuracy. Look around. Placement is approximate.',
      );
    } catch (_) {
      _message(
        'Waiting for GPS/compass and AR floor tracking. Keep the camera moving slowly.',
      );
    } finally {
      _busy = false;
      if (mounted) setState(() {});
    }
  }

  Future<void> _calibrate() async {
    _calibrating = true;
    _active = false;
    _reset();
    await _gps?.cancel();
    _gps = null;
    _fix = null;
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => GpsCalibrationScreen(floor: _floor),
      ),
    );
    if (!mounted) return;
    _calibrating = false;
    _active = true;
    await _loadCalibration();
    await _startGps();
  }

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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _active = false;
      _epoch++;
      _fix = null;
      _gps?.cancel();
      _gps = null;
    } else if (state == AppLifecycleState.resumed) {
      _active = !_calibrating;
      _reset();
      _startGps();
    }
  }

  @override
  void dispose() {
    _active = false;
    _epoch++;
    _timer?.cancel();
    _gps?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('GPS Pokémon AR'),
      actions: [
        IconButton(
          tooltip: 'Pokémon AR tutorial',
          onPressed: () => showArTutorial(context),
          icon: const Icon(Icons.help_outline),
        ),
        IconButton(
          tooltip: 'Save AR photo',
          onPressed: _savingPhoto || _placed.isEmpty ? null : _takePhoto,
          icon: const Icon(Icons.camera_alt),
        ),
      ],
    ),
    body: Stack(
      children: [
        ARView(
          onARViewCreated: _created,
          planeDetectionConfig: PlaneDetectionConfig.horizontal,
        ),
        Align(
          alignment: Alignment.topCenter,
          child: SafeArea(
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: [
                    const Text('Your floor: '),
                    Expanded(
                      child: SegmentedButton<int>(
                        segments: [
                          for (final floor in [1, 2, 3])
                            ButtonSegment(value: floor, label: Text('$floor')),
                        ],
                        selected: {_floor},
                        onSelectionChanged: (selection) {
                          _reset();
                          setState(() {
                            _floor = selection.single;
                            _calibration = null;
                          });
                          _loadCalibration();
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: SafeArea(
            child: Card(
              margin: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_status),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      children: [
                        TextButton(
                          onPressed: _calibrate,
                          child: Text('Calibrate floor $_floor'),
                        ),
                        TextButton(
                          onPressed: () {
                            _reset();
                            _startGps();
                          },
                          child: const Text('Realign / retry'),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Location settings',
                          onSelected: (v) async {
                            if (v == 'gps') {
                              await Geolocator.openLocationSettings();
                            } else {
                              await Geolocator.openAppSettings();
                            }
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                              value: 'gps',
                              child: Text('Location settings'),
                            ),
                            PopupMenuItem(
                              value: 'app',
                              child: Text('App permissions'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
