import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'media_store.dart';

enum ShareDestination { instagram, twitter, other }

class MediaShare {
  static const channel = MethodChannel('pft/media');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;
  static Future<void> send(
    MediaItem item,
    ShareDestination destination, {
    MediaStore? store,
  }) async {
    if (!supported) {
      throw UnsupportedError('Sharing is available in the Android app.');
    }
    final path = await (store ?? MediaStore()).sharePath(item);
    await channel.invokeMethod<void>('shareMedia', {
      'path': path,
      'destination': destination.name,
    });
  }
}
