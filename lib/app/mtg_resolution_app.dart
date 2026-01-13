import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:io';

import '../app/routes.dart';
import '../decks/deck_library_scope.dart';
import '../decks/deck_library_store.dart';
import '../features/timeline/timeline_screen.dart';
import '../features/decks/decks_screen.dart';
import '../models/timeline_item.dart';
import '../mtg/buckets.dart';
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
          initialItems: _debugSeedItems(),
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

  List<TimelineItem> _debugSeedItems() {
    if (!kDebugMode) return const [];

    return [
      TimelineItem(
        id: 'debug-1',
        bucketId: MtgBuckets.upkeep.id,
        label: 'Rhystic Study',
        ocrText:
            'Whenever an opponent casts a spell, you may draw a card unless that player pays {1}.',
      ),
      TimelineItem(
        id: 'debug-2',
        bucketId: MtgBuckets.declareAttackers.id,
        label: 'Bident of Thassa',
        ocrText:
            'Whenever a creature you control deals combat damage to a player, you may draw a card.',
      ),
      TimelineItem(
        id: 'debug-3',
        bucketId: MtgBuckets.responseWindow.id,
        label: 'Swords to Plowshares',
        ocrText:
            'Exile target creature. Its controller gains life equal to its power.',
      ),
      TimelineItem(
        id: 'debug-4',
        bucketId: MtgBuckets.staticEffects.id,
        label: 'Static Reminder',
        ocrText: 'Static effects apply continuously.',
      ),
    ];
  }
}
