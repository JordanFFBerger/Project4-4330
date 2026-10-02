import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../ar/station_store.dart';
import '../ar/station_ar_screen.dart';
import '../gallery/gallery_screen.dart';
import 'gps_calibration.dart';
import 'gps_calibration_screen.dart';
import 'location_access.dart';
import 'pft_map_data.dart';
import 'pft_map_screen.dart';

class ExplorerScreen extends StatefulWidget {
  const ExplorerScreen({super.key, this.onOpenCamera});
  final VoidCallback? onOpenCamera;
  @override
  State<ExplorerScreen> createState() => _ExplorerScreenState();
}

class _ExplorerScreenState extends State<ExplorerScreen>
    with WidgetsBindingObserver {
  List<PokemonStation> _stations = [];
  int _floor = 1;
  GpsCalibration? _calibration;
  Position? _fix;
  StreamSubscription<Position>? _subscription;
  Timer? _clock;
  bool _tracking = false, _busy = false;
  int _generation = 0;
  String _status = 'GPS off • select your floor manually';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
    _clock = Timer.periodic(const Duration(seconds: 5), (_) {
      if (mounted && _tracking) setState(() {});
    });
  }

  Future<void> _load() async {
    try {
      final stations = await StationStore.load();
      if (mounted) setState(() => _stations = stations);
      await _loadCalibration();
    } catch (_) {
      if (mounted) {
        setState(() => _status = 'Saved map settings could not be loaded.');
      }
    }
  }

  Future<void> _loadCalibration() async {
    final floor = _floor;
    try {
      final calibration = await GpsCalibration.load(floor);
      if (mounted && floor == _floor) {
        setState(() => _calibration = calibration);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _status = 'Could not load calibration. Please retry.');
      }
    }
  }

  Future<void> _start() async {
    final generation = ++_generation;
    setState(() {
      _tracking = true;
      _status = 'Waiting for GPS…';
    });
    try {
      await ensureLocationAccess();
      if (!mounted || !_tracking || generation != _generation) return;
      await _subscription?.cancel();
      _subscription =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 1,
            ),
          ).listen(
            (fix) {
              if (mounted && _tracking && generation == _generation) {
                setState(() => _fix = fix);
              }
            },
            onError: (Object error) {
              if (mounted && generation == _generation) {
                _stop();
                setState(
                  () => _status = 'GPS unavailable. Check location permissions/settings and retry.',
                );
              }
            },
          );
    } catch (e) {
      if (mounted && generation == _generation) {
        _stop();
        setState(() => _status = '$e');
      }
    }
  }

  void _stop() {
    _generation++;
    _subscription?.cancel();
    _subscription = null;
    setState(() {
      _tracking = false;
      _fix = null;
      _status = 'GPS off • select your floor manually';
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if ((state == AppLifecycleState.paused ||
            state == AppLifecycleState.hidden ||
            state == AppLifecycleState.detached) &&
        _tracking) {
      _stop();
    }
  }

  @override
  void dispose() {
    _generation++;
    _subscription?.cancel();
    _clock?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _calibrate() async {
    _stop();
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => GpsCalibrationScreen(floor: _floor)),
    );
    if (mounted) await _loadCalibration();
  }

  Future<void> _shuffle() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Shuffle all Pokémon?'),
        content: const Text(
          'Replace saved placements with random map landmarks for all 13 Pokémon. Calibrate each floor to use these points in GPS AR. Landmark access must be checked on site.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Shuffle'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final catalog = await StationStore.catalog();
      final data = await PftMapData.load();
      final stations = StationStore.randomize(
        catalog,
        data.landmarks,
        Random(),
      );
      await StationStore.save(stations);
      if (mounted) setState(() => _stations = stations);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save shuffled placements. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pokemon(PftEncounter encounter) async {
    final catalog = await StationStore.catalog();
    final model = catalog.firstWhere(
      (m) => 'marker-${m['id']}' == encounter.id,
    );
    if (mounted) {
      await Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => PokemonPreviewScreen(model: model),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    PftMapPosition? position;
    var status = _status;
    if (_tracking) {
      if (_calibration == null) {
        status = 'Calibrate floor $_floor to place GPS on this map.';
      } else if (_fix == null) {
        status = 'Waiting for GPS…';
      } else if (DateTime.now().difference(_fix!.timestamp).abs() >
          const Duration(seconds: 30)) {
        status = 'GPS fix is stale • waiting for a fresh location';
      } else if (!_fix!.accuracy.isFinite ||
          _fix!.accuracy < 0 ||
          _fix!.accuracy > 50) {
        status = 'GPS accuracy too low for this floor plan';
      } else {
        position = _calibration!.project(_fix!.latitude, _fix!.longitude);
        status = position == null
            ? 'GPS is outside the calibrated map • check floor/calibration'
            : 'Approximate GPS ±${_fix!.accuracy.toStringAsFixed(0)} m • floor $_floor selected manually';
      }
    }
    return PftMapScreen(
      allowManualPositioning: !_tracking,
      onOpenCamera: widget.onOpenCamera,
      playerPosition: position,
      positionLabel: status,
      statusText: status,
      onFloorChanged: (floor) {
        setState(() {
          _floor = floor;
          _calibration = null;
        });
        _loadCalibration();
      },
      encounters: _stations
          .map(
            (s) =>
                PftEncounter(id: s.marker, name: s.name, position: s.position),
          )
          .toList(),
      onEncounterSelected: _pokemon,
      extraActions: [
        if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android)
          IconButton(
            tooltip: 'Find Pokémon in GPS AR',
            icon: const Icon(Icons.view_in_ar),
            onPressed: _stations.isEmpty
                ? null
                : () {
                    _stop();
                    Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) => StationArScreen(
                          stations: List.of(_stations),
                          initialFloor: _floor,
                        ),
                      ),
                    );
                  },
          ),
        IconButton(
          tooltip: 'Shuffle Pokémon',
          onPressed: _busy ? null : _shuffle,
          icon: const Icon(Icons.shuffle),
        ),
        PopupMenuButton<String>(
          tooltip: 'GPS options',
          icon: const Icon(Icons.my_location),
          onSelected: (value) async {
            switch (value) {
              case 'toggle':
                _tracking ? _stop() : await _start();
              case 'calibrate':
                await _calibrate();
              case 'location':
                await Geolocator.openLocationSettings();
              case 'app':
                await Geolocator.openAppSettings();
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'toggle',
              child: Text(_tracking ? 'Stop GPS' : 'Start GPS'),
            ),
            PopupMenuItem(
              value: 'calibrate',
              child: Text('Calibrate floor $_floor'),
            ),
            const PopupMenuItem(
              value: 'location',
              child: Text('Location settings'),
            ),
            const PopupMenuItem(value: 'app', child: Text('App permissions')),
          ],
        ),
      ],
    );
  }
}
