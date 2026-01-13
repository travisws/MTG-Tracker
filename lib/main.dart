import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import 'app/mtg_resolution_app.dart';
import 'decks/deck_library_store.dart';
import 'decks/deck_thumbnail_store.dart';
import 'decks/file_deck_library_storage.dart';
import 'session/session_store.dart';
import 'thumbnail/thumbnail_cache.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final deckStore = await _loadDeckStore();
  final sessionStore = await _loadSessionStore();
  runApp(MtgResolutionApp(store: sessionStore, deckStore: deckStore));
}

Future<DeckLibraryStore> _loadDeckStore() async {
  try {
    final dir = await getApplicationSupportDirectory();
    final deckRoot = Directory('${dir.path}/mtg_resolution_decks');
    final file = File('${deckRoot.path}/decks.json');
    final thumbnailStore = DeckThumbnailStore(
      rootDirectory: Directory('${deckRoot.path}/thumbnails'),
    );
    final store = DeckLibraryStore(
      storage: FileDeckLibraryStorage(file: file),
      thumbnailStore: thumbnailStore,
    );
    await store.load();
    return store;
  } catch (_) {
    return DeckLibraryStore();
  }
}

Future<SessionStore> _loadSessionStore() async {
  try {
    final dir = await getTemporaryDirectory();
    final cache = ThumbnailCache(
      directory: Directory('${dir.path}/mtg_resolution_timeline_thumbnails'),
    );
    await cache.purge();
    return SessionStore(thumbnailCache: cache);
  } catch (_) {
    return SessionStore();
  }
}
