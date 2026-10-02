import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:project4/gallery/media_store.dart';

void main() {
  late Directory directory;
  late MediaStore store;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('pft-gallery-test-');
    store = MediaStore(directoryPath: () async => directory.path);
  });
  tearDown(() async {
    await directory.delete(recursive: true);
  });
  test(
    'photo saves survive reopening and delete only the selected item',
    () async {
      final original = await store.savePhoto(Uint8List.fromList([1, 2, 3]));
      await Future<void>.delayed(const Duration(milliseconds: 1));
      final edited = await store.savePhoto(Uint8List.fromList([4, 5, 6]));
      final reopened = MediaStore(directoryPath: () async => directory.path);
      expect((await reopened.list()).map((i) => i.id), [
        edited.id,
        original.id,
      ]);
      expect(await reopened.read(original), [1, 2, 3]);
      await reopened.delete(edited);
      expect((await reopened.list()).single.id, original.id);
    },
  );
  test(
    'video capture is copied intact and its temporary original removed',
    () async {
      final source = File('${directory.path}/capture.mp4');
      await source.writeAsBytes([7, 8, 9]);
      final item = await store.importCapture(source.path, video: true);
      expect(item.isVideo, isTrue);
      expect(await store.read(item), [7, 8, 9]);
      expect(await source.exists(), isFalse);
    },
  );
  test(
    'incomplete writes and invalid identifiers cannot appear in gallery',
    () async {
      await Directory('${directory.path}/pft-gallery').create();
      await File('${directory.path}/pft-gallery/123.png.partial')
          .writeAsBytes([1]);
      expect(await store.list(), isEmpty);
      await expectLater(
        store.read(
          MediaItem(
            id: '../outside.png',
            createdAt: DateTime.now(),
            isVideo: false,
          ),
        ),
        throwsArgumentError,
      );
      await expectLater(store.savePhoto(Uint8List(0)), throwsArgumentError);
    },
  );
}
