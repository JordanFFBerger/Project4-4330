import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';

import 'media_item.dart';

class MediaStore {
  MediaStore({Future<String> Function()? directoryPath})
    : _directoryPath = directoryPath ?? _defaultPath;
  final Future<String> Function() _directoryPath;
  static Future<String> _defaultPath() async =>
      (await getApplicationDocumentsDirectory()).path;
  bool get supported => true;
  Future<Directory> _folder() async =>
      Directory('${await _directoryPath()}/pft-gallery')
          .create(recursive: true);
  Future<File> _file(String id) async {
    if (!RegExp(r'^\d+\.(png|jpg|mp4)$').hasMatch(id)) {
      throw ArgumentError('Invalid media identifier');
    }
    return File('${(await _folder()).path}/$id');
  }

  Future<List<MediaItem>> list() async {
    final entries = <MediaItem>[];
    await for (final entry in (await _folder()).list()) {
      final id = entry.uri.pathSegments.last;
      if (entry is File && RegExp(r'^\d+\.(png|jpg|mp4)$').hasMatch(id)) {
        entries.add(
          MediaItem(
            id: id,
            createdAt: DateTime.fromMicrosecondsSinceEpoch(
              int.parse(id.split('.').first),
            ),
            isVideo: id.endsWith('.mp4'),
          ),
        );
      }
    }
    return entries..sort((a, b) => b.id.compareTo(a.id));
  }

  Future<MediaItem> savePhoto(Uint8List bytes) async {
    if (bytes.isEmpty) throw ArgumentError('Empty photo');
    final now = DateTime.now();
    final id = '${now.microsecondsSinceEpoch}.png';
    final file = await _file(id);
    final temp = File('${file.path}.partial');
    try {
      await temp.writeAsBytes(bytes, flush: true);
      await temp.rename(file.path);
    } catch (_) {
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
    return MediaItem(id: id, createdAt: now, isVideo: false);
  }

  Future<MediaItem> importCapture(String path, {required bool video}) async {
    final now = DateTime.now();
    final id = '${now.microsecondsSinceEpoch}.${video ? 'mp4' : 'jpg'}';
    final source = File(path);
    if (await source.length() == 0) throw ArgumentError('Empty capture');
    final file = await _file(id);
    final temp = File('${file.path}.partial');
    try {
      await source.copy(temp.path);
      await temp.rename(file.path);
    } catch (_) {
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
    // The camera's temporary original is disposable only after successful import.
    try {
      await source.delete();
    } catch (_) {}
    return MediaItem(id: id, createdAt: now, isVideo: video);
  }

  Future<Uint8List> read(MediaItem item) async =>
      (await _file(item.id)).readAsBytes();
  Future<String> sharePath(MediaItem item) async {
    final file = await _file(item.id);
    if (!await file.exists() || await file.length() == 0) {
      throw StateError('This capture is no longer available.');
    }
    return file.path;
  }

  Future<void> delete(MediaItem item) async => (await _file(item.id)).delete();
  Future<VideoPlayerController> videoController(MediaItem item) async =>
      VideoPlayerController.file(await _file(item.id));
}
