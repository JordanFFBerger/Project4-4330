import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'media_store.dart';

const photoFilters = <String, List<double>>{
  'Original': [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0],
  'Mono': [
    .2126,
    .7152,
    .0722,
    0,
    0,
    .2126,
    .7152,
    .0722,
    0,
    0,
    .2126,
    .7152,
    .0722,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ],
  'Sepia': [
    .393,
    .769,
    .189,
    0,
    0,
    .349,
    .686,
    .168,
    0,
    0,
    .272,
    .534,
    .131,
    0,
    0,
    0,
    0,
    0,
    1,
    0,
  ],
  'Bright': [1, 0, 0, 0, 25, 0, 1, 0, 0, 25, 0, 0, 1, 0, 25, 0, 0, 0, 1, 0],
};

class PhotoStroke {
  PhotoStroke(this.color, this.width, this.points);
  final Color color;
  final double width;
  final List<Offset> points;
}

void paintPhotoStrokes(Canvas canvas, Size size, List<PhotoStroke> strokes) {
  for (final stroke in strokes) {
    if (stroke.points.isEmpty) continue;
    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.width * size.width
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final points = stroke.points
        .map((p) => Offset(p.dx * size.width, p.dy * size.height))
        .toList();
    if (points.length == 1) {
      canvas.drawCircle(
        points.first,
        paint.strokeWidth / 2,
        Paint()..color = stroke.color,
      );
      continue;
    }
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(path, paint);
  }
}

Future<Uint8List> renderEditedPhoto(
  ui.Image original,
  Rect crop,
  List<double> filter,
  List<PhotoStroke> strokes,
) async {
  final size = Size(original.width.toDouble(), original.height.toDouble());
  final left = (crop.left * size.width).round().clamp(0, original.width - 1);
  final top = (crop.top * size.height).round().clamp(0, original.height - 1);
  final width = (crop.width * size.width).round().clamp(
    1,
    original.width - left,
  );
  final height = (crop.height * size.height).round().clamp(
    1,
    original.height - top,
  );
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder)..translate(-left.toDouble(), -top.toDouble());
  canvas.drawImage(
    original,
    Offset.zero,
    Paint()..colorFilter = ColorFilter.matrix(filter),
  );
  paintPhotoStrokes(canvas, size, strokes);
  final picture = recorder.endRecording();
  final output = await picture.toImage(width, height);
  try {
    final bytes = await output.toByteData(format: ui.ImageByteFormat.png);
    return bytes!.buffer.asUint8List();
  } finally {
    output.dispose();
    picture.dispose();
  }
}

class PhotoEditorScreen extends StatefulWidget {
  const PhotoEditorScreen({super.key, required this.item});
  final MediaItem item;
  @override
  State<PhotoEditorScreen> createState() => _PhotoEditorScreenState();
}

class _PhotoEditorScreenState extends State<PhotoEditorScreen> {
  ui.Image? _image;
  String? _error;
  bool _saving = false, _cropMode = false, _draw = false;
  String _filter = 'Original';
  Color _color = Colors.red;
  double _width = .008;
  Rect _crop = const Rect.fromLTWH(0, 0, 1, 1);
  final _strokes = <PhotoStroke>[];
  Offset? _dragStart;
  Rect? _startRect;
  int? _corner;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final bytes = await MediaStore().read(widget.item);
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      codec.dispose();
      if (!mounted) {
        frame.image.dispose();
        return;
      }
      setState(() => _image = frame.image);
    } catch (_) {
      if (mounted) setState(() => _error = 'This photo could not be opened.');
    }
  }

  @override
  void dispose() {
    _image?.dispose();
    super.dispose();
  }

  bool get _changed =>
      _filter != 'Original' ||
      _strokes.isNotEmpty ||
      _crop != const Rect.fromLTWH(0, 0, 1, 1);
  Future<void> _leave() async {
    if (_saving) return;
    final discard = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard edits?'),
        content: const Text('The original photo will remain in your gallery.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.pop(context);
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final bytes = await renderEditedPhoto(
        _image!,
        _crop,
        photoFilters[_filter]!,
        _strokes,
      );
      await MediaStore().savePhoto(bytes);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save. Free some space and retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Offset _normalize(Offset p, Size size) =>
      Offset((p.dx / size.width).clamp(0, 1), (p.dy / size.height).clamp(0, 1));
  void _start(DragStartDetails details, Size size) {
    final point = _normalize(details.localPosition, size);
    if (_cropMode) {
      _dragStart = point;
      _startRect = _crop;
      final corners = [
        _crop.topLeft,
        _crop.topRight,
        _crop.bottomRight,
        _crop.bottomLeft,
      ];
      _corner = null;
      double distance = 32;
      for (var i = 0; i < 4; i++) {
        final delta = Offset(
          (point.dx - corners[i].dx) * size.width,
          (point.dy - corners[i].dy) * size.height,
        ).distance;
        if (delta < distance) {
          distance = delta;
          _corner = i;
        }
      }
    } else if (_draw) {
      setState(() => _strokes.add(PhotoStroke(_color, _width, [point])));
    }
  }

  void _update(DragUpdateDetails details, Size size) {
    final point = _normalize(details.localPosition, size);
    if (_cropMode && _startRect != null) {
      final r = _startRect!;
      var l = r.left, t = r.top, rr = r.right, b = r.bottom;
      switch (_corner) {
        case 0:
          l = point.dx.clamp(0, rr - .05);
          t = point.dy.clamp(0, b - .05);
        case 1:
          rr = point.dx.clamp(l + .05, 1);
          t = point.dy.clamp(0, b - .05);
        case 2:
          rr = point.dx.clamp(l + .05, 1);
          b = point.dy.clamp(t + .05, 1);
        case 3:
          l = point.dx.clamp(0, rr - .05);
          b = point.dy.clamp(t + .05, 1);
        default:
          final dx = (point.dx - _dragStart!.dx).clamp(-l, 1 - rr);
          final dy = (point.dy - _dragStart!.dy).clamp(-t, 1 - b);
          l += dx;
          rr += dx;
          t += dy;
          b += dy;
      }
      setState(() => _crop = Rect.fromLTRB(l, t, rr, b));
    } else if (_draw && _strokes.isNotEmpty) {
      setState(() => _strokes.last.points.add(point));
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_changed && !_saving,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) _leave();
    },
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Edit photo'),
        actions: [
          TextButton(
            onPressed: _image == null || _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save copy'),
          ),
        ],
      ),
      body: _error != null
          ? Center(child: Text(_error!))
          : _image == null
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final image = _image!;
                      final fit = applyBoxFit(
                        BoxFit.contain,
                        Size(image.width.toDouble(), image.height.toDouble()),
                        constraints.biggest,
                      ).destination;
                      return Center(
                        child: SizedBox(
                          width: fit.width,
                          height: fit.height,
                          child: GestureDetector(
                            onPanStart: _saving ? null : (d) => _start(d, fit),
                            onPanUpdate: _saving
                                ? null
                                : (d) => _update(d, fit),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                ColorFiltered(
                                  colorFilter: ColorFilter.matrix(
                                    photoFilters[_filter]!,
                                  ),
                                  child: RawImage(
                                    image: image,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                CustomPaint(
                                  painter: _EditorPainter(
                                    _strokes,
                                    _crop,
                                    _cropMode,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_cropMode)
                          const Text(
                            'Drag the corner handles to crop; drag inside to move.',
                          ),
                        Wrap(
                          spacing: 8,
                          children: [
                            for (final name in photoFilters.keys)
                              ChoiceChip(
                                label: Text(name),
                                selected: _filter == name,
                                onSelected: _saving
                                    ? null
                                    : (_) => setState(() => _filter = name),
                              ),
                          ],
                        ),
                        Wrap(
                          spacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            FilterChip(
                              label: const Text('Crop'),
                              selected: _cropMode,
                              onSelected: _saving
                                  ? null
                                  : (v) => setState(() {
                                      _cropMode = v;
                                      _draw = false;
                                    }),
                            ),
                            FilterChip(
                              label: const Text('Draw'),
                              selected: _draw,
                              onSelected: _saving
                                  ? null
                                  : (v) => setState(() {
                                      _draw = v;
                                      _cropMode = false;
                                    }),
                            ),
                            IconButton(
                              tooltip: 'Undo drawing',
                              onPressed: _saving || _strokes.isEmpty
                                  ? null
                                  : () => setState(() => _strokes.removeLast()),
                              icon: const Icon(Icons.undo),
                            ),
                            TextButton(
                              onPressed: _saving
                                  ? null
                                  : () => setState(() {
                                      _crop = const Rect.fromLTWH(0, 0, 1, 1);
                                      _strokes.clear();
                                      _filter = 'Original';
                                    }),
                              child: const Text('Reset'),
                            ),
                          ],
                        ),
                        if (_draw)
                          Row(
                            children: [
                              for (final color in [
                                Colors.red,
                                Colors.yellow,
                                Colors.blue,
                                Colors.black,
                                Colors.white,
                              ])
                                IconButton(
                                  tooltip: 'Drawing color ${color.toARGB32()}',
                                  onPressed: _saving
                                      ? null
                                      : () => setState(() => _color = color),
                                  icon: Icon(
                                    _color == color
                                        ? Icons.check_circle
                                        : Icons.circle,
                                    color: color,
                                    shadows: const [
                                      Shadow(color: Colors.grey, blurRadius: 2),
                                    ],
                                  ),
                                ),
                              Expanded(
                                child: Slider(
                                  value: _width,
                                  min: .003,
                                  max: .03,
                                  onChanged: _saving
                                      ? null
                                      : (v) => setState(() => _width = v),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    ),
  );
}

class _EditorPainter extends CustomPainter {
  _EditorPainter(this.strokes, this.crop, this.showCrop);
  final List<PhotoStroke> strokes;
  final Rect crop;
  final bool showCrop;
  @override
  void paint(Canvas canvas, Size size) {
    paintPhotoStrokes(canvas, size, strokes);
    if (crop != const Rect.fromLTWH(0, 0, 1, 1) || showCrop) {
      final rect = Rect.fromLTRB(
        crop.left * size.width,
        crop.top * size.height,
        crop.right * size.width,
        crop.bottom * size.height,
      );
      final shade = Path()
        ..fillType = PathFillType.evenOdd
        ..addRect(Offset.zero & size)
        ..addRect(rect);
      canvas.drawPath(shade, Paint()..color = Colors.black54);
      canvas.drawRect(
        rect,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      if (showCrop) {
        for (final point in [
          rect.topLeft,
          rect.topRight,
          rect.bottomLeft,
          rect.bottomRight,
        ]) {
          canvas.drawCircle(point, 9, Paint()..color = Colors.white);
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EditorPainter oldDelegate) => true;
}
