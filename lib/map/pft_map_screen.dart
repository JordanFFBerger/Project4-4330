import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'pft_map_data.dart';

const _purple = Color(0xFF461D7C);
const _gold = Color(0xFFFDD023);

/// Offline floor map. Game code owns encounters and the positioning provider.
class PftMapScreen extends StatefulWidget {
  const PftMapScreen({
    super.key,
    this.encounters = const [],
    this.playerPosition,
    this.onEncounterSelected,
    this.onManualPositionChanged,
    this.onOpenCamera,
    this.allowManualPositioning = true,
    this.initialFloor = 1,
    this.onFloorChanged,
    this.positionLabel = 'Player position',
    this.extraActions = const [],
    this.statusText,
  });

  final List<PftEncounter> encounters;
  final PftMapPosition? playerPosition;
  final ValueChanged<PftEncounter>? onEncounterSelected;
  final ValueChanged<PftMapPosition>? onManualPositionChanged;
  final VoidCallback? onOpenCamera;
  final bool allowManualPositioning;
  final int initialFloor;
  final ValueChanged<int>? onFloorChanged;
  final String positionLabel;
  final List<Widget> extraActions;
  final String? statusText;

  @override
  State<PftMapScreen> createState() => _PftMapScreenState();
}

class _PftMapScreenState extends State<PftMapScreen> {
  late Future<PftMapData> _data = PftMapData.load();
  final _canvasKey = GlobalKey<_PftMapCanvasState>();
  late int _floorId = widget.initialFloor;
  PftLandmark? _selected;
  PftMapPosition? _manualPosition;
  PftEncounter? _selectedEncounter;
  bool _placingPosition = false;

  @override
  void didUpdateWidget(covariant PftMapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.allowManualPositioning) _placingPosition = false;
  }

  void _selectLandmark(PftLandmark landmark) {
    widget.onFloorChanged?.call(landmark.position.floor);
    setState(() {
      _floorId = landmark.position.floor;
      _selected = landmark;
      _selectedEncounter = null;
      _placingPosition = false;
    });
    // Also focus when the already-selected marker is tapped again.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _canvasKey.currentState?.focus(landmark.position);
    });
  }

  Future<void> _showPlaces(PftMapData data) async {
    var query = '';
    final selected = await showModalBottomSheet<PftLandmark>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          final matches = data.landmarks.where((landmark) {
            final terms = '${landmark.name} ${landmark.room ?? ''}';
            return terms.toLowerCase().contains(query.toLowerCase());
          }).toList();
          return FractionallySizedBox(
            heightFactor: 0.8,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                16 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Find a place',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: const InputDecoration(
                      labelText: 'Place name or room number',
                      prefixIcon: Icon(Icons.search),
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (value) => update(() => query = value.trim()),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: matches.isEmpty
                        ? const Center(child: Text('No matching places.'))
                        : ListView.builder(
                            itemCount: matches.length,
                            itemBuilder: (context, index) {
                              final place = matches[index];
                              return ListTile(
                                leading: Icon(
                                  _landmarkIcon(place.kind),
                                  color: _purple,
                                ),
                                title: Text(place.name),
                                subtitle: Text(_placeSubtitle(place)),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.pop(context, place),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (mounted && selected != null) _selectLandmark(selected);
  }

  void _showSource() {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About this map'),
        content: const SingleChildScrollView(
          child: Text(
            'Floor plans: LSU College of Engineering, Patrick F. Taylor Hall '
            'Building Guide (2021). Landmark pins are approximate.\n\n'
            'Room names and access may have changed. Lab and office markers '
            'identify places, and do not indicate public access.\n\n'
            'GPS is approximate and requires three-point calibration for each floor. '
            'Select your floor manually; indoor GPS can drift.\n\n'
            'lsu.edu/eng/images/pft_floorplan_guide2_webupdated2021.pdf',
          ),
        ),
        actions: [
          ...widget.extraActions,
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F3F8),
      appBar: AppBar(
        title: const Text('PFT Explorer'),
        backgroundColor: const Color(0xFFF5F3F8),
        actions: [
          if (widget.onOpenCamera != null)
            IconButton(
              tooltip: 'Open Camera',
              onPressed: widget.onOpenCamera,
              icon: const Icon(Icons.camera_alt_outlined),
            ),
          IconButton(
            tooltip: 'Map source',
            onPressed: _showSource,
            icon: const Icon(Icons.info_outline),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: FutureBuilder<PftMapData>(
          future: _data,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not load the PFT map.'),
                    TextButton(
                      onPressed: () => setState(() {
                        _data = PftMapData.load();
                      }),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              );
            }
            final data = snapshot.data;
            if (data == null) {
              return const Center(child: CircularProgressIndicator());
            }
            final floor = data.floors.firstWhere((item) => item.id == _floorId);
            final position =
                widget.playerPosition ??
                (widget.allowManualPositioning ? _manualPosition : null);
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Patrick F. Taylor Hall',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      SizedBox(width: 8),
                      _OfflineBadge(),
                    ],
                  ),
                  const SizedBox(height: 16),
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: data.floors
                        .map(
                          (item) => ButtonSegment(
                            value: item.id,
                            label: Text(item.label),
                          ),
                        )
                        .toList(),
                    selected: {_floorId},
                    onSelectionChanged: (selection) => setState(() {
                      _floorId = selection.single;
                      widget.onFloorChanged?.call(_floorId);
                      _selected = null;
                      _selectedEncounter = null;
                      _placingPosition = false;
                    }),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      widget.statusText ?? floor.description,
                      style: const TextStyle(
                        color: Color(0xFF6D647B),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: _PftMapCanvas(
                        key: _canvasKey,
                        floor: floor,
                        landmarks: data.landmarks
                            .where((item) => item.position.floor == _floorId)
                            .toList(),
                        encounters: widget.encounters
                            .where((item) => item.position.floor == _floorId)
                            .toList(),
                        selectedId: _selected?.id,
                        playerPosition: position?.floor == _floorId
                            ? position
                            : null,
                        placingPosition: _placingPosition,
                        onLandmarkSelected: _selectLandmark,
                        onEncounterSelected: (encounter) {
                          setState(() {
                            _selected = null;
                            _selectedEncounter = encounter;
                          });
                          widget.onEncounterSelected?.call(encounter);
                        },
                        onPositionPlaced: (newPosition) {
                          setState(() {
                            _manualPosition = newPosition;
                            _placingPosition = false;
                          });
                          widget.onManualPositionChanged?.call(newPosition);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _DetailsCard(
                    title: _placingPosition
                        ? 'Tap the map to set a test position'
                        : _selected?.name ??
                              _selectedEncounter?.name ??
                              'Explore the building',
                    subtitle: _placingPosition
                        ? 'The blue marker is placed manually.'
                        : _selected != null
                        ? '${_placeSubtitle(_selected!)} · ${_selected!.description}'
                        : _selectedEncounter != null
                        ? 'Encounter on floor $_floorId'
                        : 'Pinch to zoom. Tap a pin to see a place.',
                    onClose: _selected != null || _selectedEncounter != null
                        ? () => setState(() {
                            _selected = null;
                            _selectedEncounter = null;
                          })
                        : null,
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => _showPlaces(data),
                          icon: const Icon(Icons.search),
                          label: const Text('Find a place'),
                        ),
                      ),
                      if (widget.allowManualPositioning) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => setState(() {
                              _placingPosition = !_placingPosition;
                              _selected = null;
                              _selectedEncounter = null;
                            }),
                            icon: Icon(
                              _placingPosition
                                  ? Icons.close
                                  : Icons.my_location,
                            ),
                            label: Text(
                              _placingPosition ? 'Cancel' : 'Test position',
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (position?.floor == _floorId)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        widget.playerPosition != null
                            ? widget.positionLabel
                            : 'Manual test position',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6D647B),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

String _placeSubtitle(PftLandmark place) =>
    'Floor ${place.position.floor}${place.room == null ? '' : ' · Room ${place.room}'}';

IconData _landmarkIcon(String kind) => switch (kind) {
  'elevator' => Icons.elevator_outlined,
  'entrance' => Icons.login,
  'lab' => Icons.science_outlined,
  'office' => Icons.business_outlined,
  _ => Icons.place_outlined,
};

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: const Color(0xFFE9E2F3),
      borderRadius: BorderRadius.circular(20),
    ),
    child: const Text(
      'OFFLINE MAP',
      style: TextStyle(
        fontSize: 9,
        fontWeight: FontWeight.w800,
        color: _purple,
        letterSpacing: 0.7,
      ),
    ),
  );
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.title,
    required this.subtitle,
    this.onClose,
  });

  final String title;
  final String subtitle;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: _purple,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6D647B)),
              ),
            ],
          ),
        ),
        if (onClose != null)
          IconButton(
            tooltip: 'Clear selection',
            onPressed: onClose,
            icon: const Icon(Icons.close, size: 18),
          ),
      ],
    ),
  );
}

class _PftMapCanvas extends StatefulWidget {
  const _PftMapCanvas({
    super.key,
    required this.floor,
    required this.landmarks,
    required this.encounters,
    required this.selectedId,
    required this.playerPosition,
    required this.placingPosition,
    required this.onLandmarkSelected,
    required this.onEncounterSelected,
    required this.onPositionPlaced,
  });

  final PftFloor floor;
  final List<PftLandmark> landmarks;
  final List<PftEncounter> encounters;
  final String? selectedId;
  final PftMapPosition? playerPosition;
  final bool placingPosition;
  final ValueChanged<PftLandmark> onLandmarkSelected;
  final ValueChanged<PftEncounter> onEncounterSelected;
  final ValueChanged<PftMapPosition> onPositionPlaced;

  @override
  State<_PftMapCanvas> createState() => _PftMapCanvasState();
}

class _PftMapCanvasState extends State<_PftMapCanvas> {
  final _transform = TransformationController();
  Size _viewport = Size.zero;
  static const _sceneWidth = 1000.0;
  double get _sceneHeight =>
      _sceneWidth * widget.floor.height / widget.floor.width;
  double get _fitScale => math.min(
    (_viewport.width - 24) / _sceneWidth,
    (_viewport.height - 24) / _sceneHeight,
  );

  Matrix4 _matrix(double scale, Offset translation) =>
      Matrix4.diagonal3Values(scale, scale, scale)
        ..setTranslationRaw(translation.dx, translation.dy, 0);

  void fit() {
    if (_viewport.isEmpty) return;
    final scale = _fitScale;
    _transform.value = _matrix(
      scale,
      Offset(
        (_viewport.width - _sceneWidth * scale) / 2,
        (_viewport.height - _sceneHeight * scale) / 2,
      ),
    );
  }

  void focus(PftMapPosition position) {
    if (_viewport.isEmpty) return;
    final scale = _fitScale * 3;
    _transform.value = _matrix(
      scale,
      Offset(
        _viewport.width / 2 - position.x * _sceneWidth * scale,
        _viewport.height / 2 - position.y * _sceneHeight * scale,
      ),
    );
  }

  void _zoom(double factor) {
    final center = _viewport.center(Offset.zero);
    final sceneCenter = _transform.toScene(center);
    final scale = (_transform.value.getMaxScaleOnAxis() * factor).clamp(
      _fitScale,
      _fitScale * 8,
    );
    _transform.value = _matrix(scale, center - sceneCenter * scale);
  }

  @override
  void didUpdateWidget(covariant _PftMapCanvas oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.floor.id != oldWidget.floor.id) fit();
  }

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  Widget _pin({
    required String id,
    required String label,
    required PftMapPosition position,
    required IconData icon,
    required double scale,
    required VoidCallback? onTap,
    Color color = _purple,
    bool selected = false,
  }) {
    return Positioned(
      left: position.x * _sceneWidth - 22,
      top: position.y * _sceneHeight - 22,
      width: 44,
      height: 44,
      child: Transform.scale(
        scale: 1 / scale,
        child: Semantics(
          label: label,
          button: onTap != null,
          child: Tooltip(
            message: label,
            child: GestureDetector(
              key: ValueKey(id),
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Center(
                child: Container(
                  width: selected ? 34 : 28,
                  height: selected ? 34 : 28,
                  decoration: BoxDecoration(
                    color: selected ? _gold : color,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x33000000),
                        blurRadius: 5,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: selected ? _purple : Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      if (size != _viewport) {
        _viewport = size;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            final selected = widget.landmarks
                .where((place) => place.id == widget.selectedId)
                .firstOrNull;
            if (selected == null) {
              fit();
            } else {
              focus(selected.position);
            }
          }
        });
      }
      return ColoredBox(
        color: const Color(0xFFFEFDFC),
        child: Stack(
          children: [
            Positioned.fill(
              child: GestureDetector(
                key: const ValueKey('pft-map-viewport'),
                onTapUp: widget.placingPosition
                    ? (details) {
                        final point = _transform.toScene(details.localPosition);
                        final x = point.dx / _sceneWidth;
                        final y = point.dy / _sceneHeight;
                        if (x >= 0 && x <= 1 && y >= 0 && y <= 1) {
                          widget.onPositionPlaced(
                            PftMapPosition(floor: widget.floor.id, x: x, y: y),
                          );
                        }
                      }
                    : null,
                child: InteractiveViewer(
                  transformationController: _transform,
                  constrained: false,
                  alignment: Alignment.topLeft,
                  minScale: math.max(0.01, _fitScale),
                  maxScale: math.max(0.08, _fitScale * 8),
                  boundaryMargin: const EdgeInsets.all(1200),
                  child: ValueListenableBuilder<Matrix4>(
                    valueListenable: _transform,
                    builder: (context, matrix, _) {
                      final scale = matrix.getMaxScaleOnAxis();
                      return SizedBox(
                        width: _sceneWidth,
                        height: _sceneHeight,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Positioned.fill(
                              child: Image.asset(
                                widget.floor.asset,
                                key: ValueKey('floor-plan-${widget.floor.id}'),
                                fit: BoxFit.fill,
                                filterQuality: FilterQuality.high,
                                errorBuilder: (context, error, stack) =>
                                    const Center(
                                      child: Text(
                                        'Floor plan image unavailable.',
                                      ),
                                    ),
                              ),
                            ),
                            // Hide the brochure legend outside the building crop.
                            if (widget.floor.id == 1)
                              Positioned(
                                left: 0,
                                top: _sceneHeight * 0.69,
                                width: _sceneWidth * 0.10,
                                height: _sceneHeight * 0.31,
                                child: const ColoredBox(color: Colors.white),
                              ),
                            for (final landmark in widget.landmarks)
                              _pin(
                                id: 'landmark-${landmark.id}',
                                label: landmark.name,
                                position: landmark.position,
                                icon: _landmarkIcon(landmark.kind),
                                scale: scale,
                                onTap: widget.placingPosition
                                    ? null
                                    : () => widget.onLandmarkSelected(landmark),
                                selected: widget.selectedId == landmark.id,
                              ),
                            for (final encounter in widget.encounters)
                              _pin(
                                id: 'encounter-${encounter.id}',
                                label: encounter.name,
                                position: encounter.position,
                                icon: Icons.catching_pokemon,
                                scale: scale,
                                color: const Color(0xFFD64257),
                                onTap: widget.placingPosition
                                    ? null
                                    : () =>
                                          widget.onEncounterSelected(encounter),
                              ),
                            if (widget.playerPosition case final position?)
                              _pin(
                                id: 'player-position',
                                label: 'Player position',
                                position: position,
                                icon: Icons.person,
                                scale: scale,
                                color: const Color(0xFF1769C2),
                                onTap: null,
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
            const Positioned(
              left: 12,
              top: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.all(Radius.circular(10)),
                ),
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.west, size: 14, color: _purple),
                      SizedBox(width: 4),
                      Text(
                        'N',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: _purple,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              right: 10,
              bottom: 10,
              child: Material(
                color: Colors.white,
                elevation: 2,
                borderRadius: BorderRadius.circular(14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'Zoom in',
                      onPressed: () => _zoom(1.5),
                      icon: const Icon(Icons.add),
                    ),
                    IconButton(
                      tooltip: 'Zoom out',
                      onPressed: () => _zoom(1 / 1.5),
                      icon: const Icon(Icons.remove),
                    ),
                    IconButton(
                      tooltip: 'Fit map',
                      onPressed: fit,
                      icon: const Icon(Icons.fit_screen),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
