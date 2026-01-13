import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app/mtg_resolution_app.dart';
import 'decks/deck_library_store.dart';
import 'decks/file_deck_library_storage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final deckStore = await _loadDeckStore();
  runApp(MtgResolutionApp(deckStore: deckStore));
}

Future<DeckLibraryStore> _loadDeckStore() async {
  try {
    final dir = await getApplicationDocumentsDirectory();
    final file = File('${dir.path}/decks.json');
    final store = DeckLibraryStore(storage: FileDeckLibraryStorage(file: file));
    await store.load();
    return store;
  } catch (_) {
    return DeckLibraryStore();
  }
}
