import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project4/gallery/photo_editor.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('export applies crop, filter and drawing to the saved pixels', () async {
    final recorder = ui.PictureRecorder();
    Canvas(
      recorder,
    ).drawRect(const Rect.fromLTWH(0, 0, 100, 80), Paint()..color = Colors.red);
    final picture = recorder.endRecording();
    final original = await picture.toImage(100, 80);
    picture.dispose();
    final bytes = await renderEditedPhoto(
      original,
      const Rect.fromLTWH(.2, .25, .5, .5),
      photoFilters['Mono']!,
      [
        PhotoStroke(Colors.blue, .1, [const Offset(.45, .5)]),
      ],
    );
    final codec = await ui.instantiateImageCodec(bytes);
    final edited = (await codec.getNextFrame()).image;
    expect(edited.width, 50);
    expect(edited.height, 40);
    final rgba = await edited.toByteData(format: ui.ImageByteFormat.rawRgba);
    expect((rgba!.getUint8(0) - rgba.getUint8(1)).abs(), lessThanOrEqualTo(1));
    final center = (20 * 50 + 25) * 4;
    expect(rgba.getUint8(center + 2), greaterThan(rgba.getUint8(center)));
    expect(original.width, 100);
    expect(original.height, 80);
    codec.dispose();
    edited.dispose();
    original.dispose();
  });
}
