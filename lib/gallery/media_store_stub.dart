import 'dart:typed_data';

import 'package:video_player/video_player.dart';

import 'media_item.dart';

class MediaStore {
  MediaStore({Future<String> Function()? directoryPath});
  bool get supported => false;
  Future<List<MediaItem>> list() async => [];
  Future<MediaItem> savePhoto(Uint8List bytes) async =>
      throw UnsupportedError('Use the Android app to save photos');
  Future<MediaItem> importCapture(String path, {required bool video}) async =>
      throw UnsupportedError('Use the Android app to capture media');
  Future<Uint8List> read(MediaItem item) async =>
      throw UnsupportedError('Local media unavailable');
  Future<void> delete(MediaItem item) async =>
      throw UnsupportedError('Local media unavailable');
  Future<VideoPlayerController> videoController(MediaItem item) async =>
      throw UnsupportedError('Local media unavailable');
}
