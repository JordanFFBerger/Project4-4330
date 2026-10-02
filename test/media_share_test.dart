import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project4/gallery/media_share.dart';
import 'package:project4/gallery/media_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('shares actual saved media paths to each target and propagates destination errors', () async {
    final dir = await Directory.systemTemp.createTemp('photobook-share-test');
    final store = MediaStore(directoryPath: () async => dir.path);
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    addTearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      await dir.delete(recursive: true);
    });
    final calls = <MethodCall>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(MediaShare.channel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(MediaShare.channel, null),
    );
    final photo = await store.savePhoto(Uint8List.fromList([1, 2, 3]));
    final capture = File('${dir.path}/capture.mp4');
    await capture.writeAsBytes([4, 5, 6]);
    final video = await store.importCapture(capture.path, video: true);
    for (final target in ShareDestination.values) {
      await MediaShare.send(photo, target, store: store);
      expect(calls.last.arguments['destination'], target.name);
      expect(await File(calls.last.arguments['path'] as String).readAsBytes(), [
        1,
        2,
        3,
      ]);
    }
    await MediaShare.send(video, ShareDestination.twitter, store: store);
    expect(calls.last.arguments['path'], endsWith('.mp4'));
    messenger.setMockMethodCallHandler(
      MediaShare.channel,
      (_) async => throw PlatformException(code: 'app_unavailable'),
    );
    await expectLater(
      MediaShare.send(photo, ShareDestination.instagram, store: store),
      throwsA(isA<PlatformException>()),
    );
    await store.delete(photo);
    await expectLater(
      MediaShare.send(photo, ShareDestination.other, store: store),
      throwsStateError,
    );
  });
}
