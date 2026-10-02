import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import 'gps_calibration.dart';
import 'location_access.dart';
import 'pft_map_data.dart';
import 'pft_map_screen.dart';

class GpsCalibrationScreen extends StatefulWidget {
  const GpsCalibrationScreen({super.key, required this.floor});
  final int floor;
  @override
  State<GpsCalibrationScreen> createState() => _GpsCalibrationScreenState();
}

class _GpsCalibrationScreenState extends State<GpsCalibrationScreen> {
  final List<GpsAnchor> _anchors = [];
  bool _busy = false;
  String? _error;
  Future<void> _record() async {
    final point = await Navigator.push<PftMapPosition>(
      context,
      MaterialPageRoute(
        builder: (routeContext) => PftMapScreen(
          initialFloor: widget.floor,
          onManualPositionChanged: (p) => Navigator.pop(routeContext, p),
        ),
      ),
    );
    if (point == null || !mounted) return;
    if (point.floor != widget.floor) {
      setState(() => _error = 'Select a point on floor ${widget.floor}.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ensureLocationAccess();
      final fix = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 25),
        ),
      );
      if (!fix.accuracy.isFinite ||
          fix.accuracy > 25 ||
          fix.accuracy < 0 ||
          DateTime.now().difference(fix.timestamp).abs() >
              const Duration(seconds: 30)) {
        throw StateError(
          'GPS is not accurate or fresh enough. Try a spot with a clearer view of the sky.',
        );
      }
      if (mounted) {
        setState(
          () => _anchors.add(
            GpsAnchor(point, fix.latitude, fix.longitude, fix.accuracy),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not record point: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final calibration = GpsCalibration(_anchors);
      await calibration.save();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Scaffold(
      appBar: AppBar(title: Text('Calibrate floor ${widget.floor}')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Stand at a known spot, tap Add point, then use Test position to mark where you are. Stay still while GPS is recorded. Repeat at three widely spaced spots forming a triangle on this floor.',
          ),
          const SizedBox(height: 12),
          const Text(
            'Choose positions at least 20 m apart with clear sky reception where possible. GPS is approximate indoors; a saved calibration cannot remove GPS drift. Saving replaces this floor’s previous calibration.',
          ),
          for (var i = 0; i < _anchors.length; i++)
            ListTile(
              title: Text(
                'Point ${i + 1} • ±${_anchors[i].accuracy.toStringAsFixed(0)} m',
              ),
              subtitle: Text(
                '${_anchors[i].latitude.toStringAsFixed(6)}, ${_anchors[i].longitude.toStringAsFixed(6)}',
              ),
              trailing: IconButton(
                tooltip: 'Remove point',
                onPressed: _busy
                    ? null
                    : () => setState(() => _anchors.removeAt(i)),
                icon: const Icon(Icons.delete_outline),
              ),
            ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          if (_busy) const LinearProgressIndicator(),
          FilledButton.icon(
            onPressed: _busy || _anchors.length == 3 ? null : _record,
            icon: const Icon(Icons.add_location_alt),
            label: Text('Add point (${_anchors.length}/3)'),
          ),
          OutlinedButton(
            onPressed: _busy || _anchors.length != 3 ? null : _save,
            child: const Text('Save calibration'),
          ),
        ],
      ),
    ),
  );
}
