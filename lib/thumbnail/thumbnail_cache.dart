import 'dart:io';
import 'dart:typed_data';

class ThumbnailCache {
  ThumbnailCache({required this.directory});

  final Directory directory;
  int _sequence = 0;

  Future<void> purge() async {
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  Future<String> writeBytes(Uint8List bytes) async {
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    _sequence = (_sequence + 1) % 1000000;
    final filename =
        'thumb_${DateTime.now().microsecondsSinceEpoch}_$_sequence.jpg';
    final file = File('${directory.path}/$filename');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }
}
