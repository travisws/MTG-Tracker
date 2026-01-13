import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_list/decks/deck_library_store.dart';
import 'package:mtg_list/decks/file_deck_library_storage.dart';

void main() {
  test('Deck library persists to file storage', () async {
    final dir = await Directory.systemTemp.createTemp('mtg_list_decks_');
    addTearDown(() => dir.delete(recursive: true));

    final storage = FileDeckLibraryStorage(
      file: File('${dir.path}/decks.json'),
    );
    final now = DateTime(2026, 1, 1, 12, 0);

    final store = DeckLibraryStore(storage: storage, now: () => now);
    await store.load();

    await store.createDeck('My Deck');
    final deckId = store.decks.single.id;

    await store.addCardToDeck(
      deckId,
      label: 'Rhystic Study',
      ocrText:
          'Whenever an opponent casts a spell, you may draw a card unless that player pays {1}.',
      defaultBucketId: 'beginning.upkeep',
    );

    final reloaded = DeckLibraryStore(storage: storage, now: () => now);
    await reloaded.load();

    expect(reloaded.decks, hasLength(1));
    expect(reloaded.decks.single.name, 'My Deck');
    expect(reloaded.decks.single.cards, hasLength(1));
    expect(reloaded.decks.single.cards.single.label, 'Rhystic Study');
    expect(
      reloaded.decks.single.cards.single.defaultBucketId,
      'beginning.upkeep',
    );
  });
}
