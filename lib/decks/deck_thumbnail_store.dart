import 'dart:io';
import 'dart:typed_data';

class DeckThumbnailStore {
  DeckThumbnailStore({required this.rootDirectory});

  final Directory rootDirectory;

  String thumbnailPathFor({required String deckId, required String cardId}) {
    return '${rootDirectory.path}/$deckId/$cardId.jpg';
  }

  Future<String?> writeBytes({
    required String deckId,
    required String cardId,
    required Uint8List bytes,
  }) async {
    if (bytes.isEmpty) return null;
    final directory = Directory('${rootDirectory.path}/$deckId');
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final file = File('${directory.path}/$cardId.jpg');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  }

  Future<Uint8List?> readBytes({
    required String deckId,
    required String cardId,
  }) async {
    final file = File(thumbnailPathFor(deckId: deckId, cardId: cardId));
    if (!await file.exists()) return null;
    try {
      return await file.readAsBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> deleteCard({
    required String deckId,
    required String cardId,
  }) async {
    final file = File(thumbnailPathFor(deckId: deckId, cardId: cardId));
    if (!await file.exists()) return;
    try {
      await file.delete();
    } catch (_) {}
  }

  Future<void> deleteDeck(String deckId) async {
    final directory = Directory('${rootDirectory.path}/$deckId');
    if (!await directory.exists()) return;
    try {
      await directory.delete(recursive: true);
    } catch (_) {}
  }

  Future<void> deleteAll() async {
    if (!await rootDirectory.exists()) return;
    try {
      await rootDirectory.delete(recursive: true);
    } catch (_) {}
  }
}
