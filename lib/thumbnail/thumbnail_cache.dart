import 'dart:io';

class ThumbnailCache {
  ThumbnailCache({required this.directory});

  final Directory directory;

  Future<void> purge() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }
}
