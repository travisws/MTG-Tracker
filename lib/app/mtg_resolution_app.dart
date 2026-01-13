import 'package:flutter/material.dart';
import 'dart:io';

import '../app/routes.dart';
import '../decks/deck_library_scope.dart';
import '../decks/deck_library_store.dart';
import '../features/timeline/timeline_screen.dart';
import '../features/decks/decks_screen.dart';
import '../session/session_scope.dart';
import '../session/session_store.dart';
import '../thumbnail/thumbnail_cache.dart';

class MtgResolutionApp extends StatelessWidget {
  const MtgResolutionApp({super.key, this.store, this.deckStore});

  final SessionStore? store;
  final DeckLibraryStore? deckStore;

  @override
  Widget build(BuildContext context) {
    final sessionStore =
        store ??
        SessionStore(
          thumbnailCache: ThumbnailCache(
            directory: Directory(
              '${Directory.systemTemp.path}/mtg_resolution_timeline_thumbnails',
            ),
          ),
        );
    final decks = deckStore ?? DeckLibraryStore();

    return DeckLibraryScope(
      store: decks,
      child: SessionScope(
        store: sessionStore,
        child: MaterialApp(
          title: 'MTG Resolution Timeline',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.indigo,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          themeMode: ThemeMode.dark,
          initialRoute: AppRoutes.timeline,
          routes: {
            AppRoutes.timeline: (context) => const TimelineScreen(),
            AppRoutes.decks: (context) => const DecksScreen(),
          },
        ),
      ),
    );
  }
}
