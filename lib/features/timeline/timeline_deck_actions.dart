import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../decks/deck_library_scope.dart';
import '../../decks/deck_library_store.dart';
import '../../models/deck.dart';
import '../../models/timeline_item.dart';
import '../../mtg/buckets.dart';
import '../../session/session_item_id.dart';
import '../../session/session_scope.dart';
import '../../session/session_store.dart';
import 'widgets/deck_card_picker_sheet.dart';
import 'widgets/deck_picker_sheet.dart';

Future<void> saveToDeck(
  BuildContext context, {
  required SessionStore store,
  required String itemId,
}) async {
  final item = store.itemById(itemId);
  if (item == null) return;

  final deckStore = DeckLibraryScope.of(context);
  final deckId = await pickDeckId(context, deckStore);
  if (deckId == null) return;

  final defaultBucketId = item.bucketId == MtgBuckets.trash.id
      ? item.previousBucketId
      : item.bucketId;

  final thumbnailResult = await loadThumbnail(item.thumbnailPath);

  await deckStore.addCardToDeck(
    deckId,
    label: item.label,
    ocrText: item.ocrText,
    note: item.note,
    defaultBucketId: defaultBucketId,
    thumbnailBytes: thumbnailResult.bytes,
  );

  if (!context.mounted) return;
  final message = thumbnailWarningMessage(
    base: 'Saved to deck',
    missingCount: thumbnailResult.wasMissing ? 1 : 0,
    tooLargeCount: thumbnailResult.wasTooLarge ? 1 : 0,
  );
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<void> saveSessionToDeck(BuildContext context) async {
  final store = SessionScope.of(context);
  final deckStore = DeckLibraryScope.of(context);
  final items = <TimelineItem>[];
  for (final bucket in MtgBuckets.ordered) {
    if (bucket.id == MtgBuckets.trash.id) continue;
    items.addAll(store.itemsForBucket(bucket.id));
  }

  if (items.isEmpty) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('No cards to save yet')));
    return;
  }

  final deckId = await pickDeckId(context, deckStore);
  if (deckId == null) return;

  final inputs = <DeckCardInput>[];
  var missingCount = 0;
  var tooLargeCount = 0;
  for (final item in items) {
    final thumbnailResult = await loadThumbnail(item.thumbnailPath);
    if (thumbnailResult.wasMissing) {
      missingCount += 1;
    }
    if (thumbnailResult.wasTooLarge) {
      tooLargeCount += 1;
    }
    inputs.add(
      DeckCardInput(
        label: item.label,
        ocrText: item.ocrText,
        note: item.note,
        defaultBucketId: item.bucketId,
        thumbnailBytes: thumbnailResult.bytes,
      ),
    );
  }
  await deckStore.addCardsToDeck(deckId, inputs);

  if (!context.mounted) return;
  final deckName = deckStore.deckById(deckId)?.name ?? 'deck';
  final message = thumbnailWarningMessage(
    base: 'Saved ${items.length} cards to $deckName',
    missingCount: missingCount,
    tooLargeCount: tooLargeCount,
  );
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<String?> pickDeckId(
  BuildContext context,
  DeckLibraryStore deckStore,
) async {
  if (!deckStore.isLoaded) {
    await deckStore.load();
  }
  if (!context.mounted) return null;

  const createDeckSentinel = '__create_deck__';

  Future<String?> createDeckAndReturnId() async {
    final controller = TextEditingController();
    try {
      final name =
          await showDialog<String>(
            context: context,
            builder: (context) {
              return AlertDialog(
                title: const Text('New deck'),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(labelText: 'Deck name'),
                  onSubmitted: (value) => Navigator.of(context).pop(value),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(controller.text),
                    child: const Text('Create'),
                  ),
                ],
              );
            },
          ) ??
          '';

      if (name.trim().isEmpty) return null;
      final before = deckStore.decks.length;
      await deckStore.createDeck(name);
      if (deckStore.decks.length <= before) return null;
      return deckStore.decks.last.id;
    } finally {
      controller.dispose();
    }
  }

  String? pickedDeckId;
  if (deckStore.decks.isEmpty) {
    pickedDeckId = await createDeckAndReturnId();
  } else {
    pickedDeckId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) =>
          DeckPickerSheet(createDeckSentinel: createDeckSentinel),
    );
  }

  if (pickedDeckId == null) return null;
  return pickedDeckId == createDeckSentinel
      ? await createDeckAndReturnId()
      : pickedDeckId;
}

Future<void> addFromActiveDeck(
  BuildContext context, {
  required String bucketId,
}) async {
  final store = SessionScope.of(context);
  final deckStore = DeckLibraryScope.of(context);
  final activeDeckId = store.activeDeckId;

  if (activeDeckId == null) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        const SnackBar(
          content: Text('No active deck. Long-press a deck to use it.'),
        ),
      );
    return;
  }

  if (!deckStore.isLoaded) {
    await deckStore.load();
  }
  if (!context.mounted) return;

  final deck = deckStore.deckById(activeDeckId);
  if (deck == null) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Active deck not found')));
    return;
  }

  if (deck.cards.isEmpty) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text('"${deck.name}" has no saved cards')),
      );
    return;
  }

  final cardId = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    builder: (context) => DeckCardPickerSheet(deck: deck, deckStore: deckStore),
  );
  if (cardId == null) return;

  DeckCard? pickedCard;
  for (final card in deck.cards) {
    if (card.id == cardId) {
      pickedCard = card;
      break;
    }
  }
  if (pickedCard == null) return;

  final deckThumbPath = deckStore.thumbnailPathFor(
    deckId: deck.id,
    card: pickedCard,
  );
  final thumbnailPath = await store.cacheThumbnailFromFile(deckThumbPath);

  store.addItem(
    TimelineItem(
      id: newSessionItemId(),
      bucketId: bucketId,
      label: pickedCard.label,
      ocrText: pickedCard.ocrText,
      note: pickedCard.note,
      thumbnailPath: thumbnailPath,
    ),
  );

  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(const SnackBar(content: Text('Added from deck')));
}

Future<ThumbnailLoadResult> loadThumbnail(String? path) async {
  if (path == null || path.isEmpty) {
    return const ThumbnailLoadResult(wasMissing: true);
  }
  final file = File(path);
  if (!await file.exists()) {
    return const ThumbnailLoadResult(wasMissing: true);
  }
  final length = await file.length();
  if (length > DeckLibraryStore.maxThumbnailBytes) {
    return const ThumbnailLoadResult(wasTooLarge: true);
  }
  try {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      return const ThumbnailLoadResult(wasMissing: true);
    }
    return ThumbnailLoadResult(bytes: bytes);
  } catch (_) {
    return const ThumbnailLoadResult(wasMissing: true);
  }
}

String thumbnailWarningMessage({
  required String base,
  required int missingCount,
  required int tooLargeCount,
}) {
  if (missingCount == 0 && tooLargeCount == 0) {
    return base;
  }
  final details = <String>[];
  if (missingCount > 0) {
    details.add('$missingCount without thumbnails');
  }
  if (tooLargeCount > 0) {
    details.add('$tooLargeCount too large');
  }
  return '$base (${details.join(', ')})';
}

class ThumbnailLoadResult {
  const ThumbnailLoadResult({
    this.bytes,
    this.wasMissing = false,
    this.wasTooLarge = false,
  });

  final Uint8List? bytes;
  final bool wasMissing;
  final bool wasTooLarge;
}
