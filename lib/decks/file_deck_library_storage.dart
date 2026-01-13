import 'dart:convert';
import 'dart:io';

import '../models/deck.dart';
import 'deck_library_storage.dart';

class FileDeckLibraryStorage implements DeckLibraryStorage {
  FileDeckLibraryStorage({required File file}) : _file = file;

  final File _file;

  @override
  Future<List<Deck>> loadDecks() async {
    try {
      if (!await _file.exists()) return const [];

      final raw = await _file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return const [];

      final version = decoded['version'];
      if (version != 2) return const [];

      final decksRaw = decoded['decks'];
      if (decksRaw is! List) return const [];

      return decksRaw
          .whereType<Map>()
          .map(
            (rawDeck) => Deck.fromJson(
              rawDeck.map((key, value) => MapEntry(key.toString(), value)),
            ),
          )
          .where((deck) => deck.id.isNotEmpty)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<void> saveDecks(List<Deck> decks) async {
    final directory = _file.parent;
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final payload = <String, Object?>{
      'version': 2,
      'decks': decks.map((deck) => deck.toJson()).toList(),
    };
    await _file.writeAsString(jsonEncode(payload));
  }
}
