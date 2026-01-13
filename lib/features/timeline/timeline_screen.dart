import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/app_drawer.dart';
import '../../app/routes.dart';
import '../../decks/deck_library_scope.dart';
import '../../decks/deck_library_store.dart';
import '../../features/capture/capture_flow.dart';
import '../../mtg/buckets.dart';
import '../../models/timeline_item.dart';
import '../../models/deck.dart';
import '../../session/session_scope.dart';
import '../../session/session_store.dart';
import '../../session/session_item_id.dart';
import 'widgets/bucket_header.dart';
import 'widgets/timeline_item_row.dart';

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);

    return Scaffold(
      drawer: AppDrawer(
        currentRoute: AppRoutes.timeline,
        onSaveSessionToDeck: () => _saveSessionToDeck(context),
      ),
      appBar: AppBar(
        title: const Text('Current Turn'),
        actions: [
          IconButton(
            onPressed: () => _saveSessionToDeck(context),
            tooltip: 'Save session to deck',
            icon: const Icon(Icons.library_add),
          ),
          IconButton(
            onPressed: () => _showVisibleStepsSheet(context),
            tooltip: 'Show/Hide Steps',
            icon: const Icon(Icons.tune),
          ),
          IconButton(
            onPressed: () => _confirmAndReset(context),
            tooltip: 'Reset',
            icon: const Icon(Icons.restart_alt),
          ),
          PopupMenuButton<_TimelineMenuAction>(
            tooltip: 'More',
            onSelected: (action) {
              switch (action) {
                case _TimelineMenuAction.saveSessionToDeck:
                  _saveSessionToDeck(context);
                  break;
                case _TimelineMenuAction.showHideSteps:
                  _showVisibleStepsSheet(context);
                  break;
                case _TimelineMenuAction.reset:
                  _confirmAndReset(context);
                  break;
              }
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _TimelineMenuAction.saveSessionToDeck,
                child: Text('Save session to deck'),
              ),
              PopupMenuItem(
                value: _TimelineMenuAction.showHideSteps,
                child: Text('Show/Hide steps'),
              ),
              PopupMenuItem(
                value: _TimelineMenuAction.reset,
                child: Text('Reset session'),
              ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => CaptureFlow.start(context),
        tooltip: 'Capture card',
        child: const Icon(Icons.add_a_photo_outlined),
      ),
      body: CustomScrollView(
        slivers: [
          for (final bucket in MtgBuckets.ordered)
            if (store.isBucketVisible(bucket.id)) ...[
              SliverToBoxAdapter(
                child: BucketHeader(
                  bucketId: bucket.id,
                  label: bucket.label,
                  count: store.itemCountForBucket(bucket.id),
                  isExpanded: store.isBucketExpanded(bucket.id),
                  onToggleExpanded: () => store.toggleBucketExpanded(bucket.id),
                  onLongPress: bucket.id == MtgBuckets.trash.id
                      ? null
                      : () => _addFromActiveDeck(context, bucketId: bucket.id),
                ),
              ),
              if (store.isBucketExpanded(bucket.id))
                _BucketBodySliver(bucketId: bucket.id),
            ],
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }

  Future<void> _confirmAndReset(BuildContext context) async {
    final store = SessionScope.of(context);

    final shouldReset =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Reset session?'),
            content: const Text(
              'This removes all items and deletes cached thumbnails. This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Reset'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldReset) return;

    try {
      await store.reset();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Session reset')));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Reset failed')));
    }
  }

  void _showVisibleStepsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => const _VisibleStepsSheet(),
    );
  }
}

class _BucketBodySliver extends StatelessWidget {
  const _BucketBodySliver({required this.bucketId});

  final String bucketId;

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final items = store.itemsForBucket(bucketId);
    if (items.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 20),
          child: Text('No items yet.', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    if (bucketId == MtgBuckets.trash.id) {
      return SliverList(
        delegate: SliverChildBuilderDelegate((context, index) {
          final item = items[index];
          return TimelineItemRow(
            item: item,
            onTap: () => _showItemDetailsDialog(context, item),
            onLongPress: () async {
              final action = await _showItemActionsSheet(
                context,
                allowTrash: false,
              );
              if (action == null) return;
              await _handleItemMenuAction(
                context,
                store: store,
                itemId: item.id,
                action: action,
                allowTrash: false,
              );
            },
            trailingActions: [
              IconButton(
                tooltip: 'Restore',
                onPressed: () => store.restoreItem(item.id),
                icon: const Icon(Icons.restore_from_trash),
              ),
            ],
          );
        }, childCount: items.length),
      );
    }

    return SliverList(
      delegate: SliverChildBuilderDelegate((context, index) {
        final item = items[index];
        return Dismissible(
          key: ValueKey(item.id),
          direction: DismissDirection.endToStart,
          background: const SizedBox.shrink(),
          secondaryBackground: _TrashSwipeBackground(),
          onDismissed: (_) => _trashWithUndo(context, store, item.id),
          child: TimelineItemRow(
            item: item,
            onTap: () => _showItemDetailsDialog(context, item),
            onLongPress: () async {
              final action = await _showItemActionsSheet(
                context,
                allowTrash: true,
              );
              if (action == null) return;
              await _handleItemMenuAction(
                context,
                store: store,
                itemId: item.id,
                action: action,
                allowTrash: true,
              );
            },
          ),
        );
      }, childCount: items.length),
    );
  }

  Future<void> _showItemDetailsDialog(
    BuildContext context,
    TimelineItem item,
  ) async {
    final theme = Theme.of(context);
    final title = item.label.trim().isEmpty ? 'Card details' : item.label;
    final ocrText = item.ocrText.trim().isEmpty
        ? 'No rules text yet.'
        : item.ocrText;
    final note = item.note?.trim();

    await showDialog<void>(
      context: context,
      builder: (context) {
        final maxHeight = MediaQuery.of(context).size.height * 0.6;
        return AlertDialog(
          title: Text(title),
          content: ConstrainedBox(
            constraints: BoxConstraints(maxHeight: maxHeight),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rules text', style: theme.textTheme.labelMedium),
                  const SizedBox(height: 6),
                  SelectableText(ocrText),
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Note', style: theme.textTheme.labelMedium),
                    const SizedBox(height: 6),
                    Text(note),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Future<_ItemMenuAction?> _showItemActionsSheet(
    BuildContext context, {
    required bool allowTrash,
  }) {
    return showModalBottomSheet<_ItemMenuAction>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.drive_file_move_outlined),
                title: const Text('Move to...'),
                onTap: () => Navigator.of(context).pop(_ItemMenuAction.move),
              ),
              ListTile(
                leading: const Icon(Icons.library_add),
                title: const Text('Save to deck...'),
                onTap: () =>
                    Navigator.of(context).pop(_ItemMenuAction.saveToDeck),
              ),
              if (allowTrash)
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const Text('Move to Trash'),
                  onTap: () => Navigator.of(context).pop(_ItemMenuAction.trash),
                ),
            ],
          ),
        );
      },
    );
  }

  void _trashWithUndo(BuildContext context, SessionStore store, String itemId) {
    store.trashItem(itemId);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: const Text('Moved to Trash'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => store.restoreItem(itemId),
          ),
        ),
      );
  }

  Future<void> _handleItemMenuAction(
    BuildContext context, {
    required SessionStore store,
    required String itemId,
    required _ItemMenuAction action,
    required bool allowTrash,
  }) async {
    switch (action) {
      case _ItemMenuAction.move:
        final item = store.itemById(itemId);
        if (item == null) return;
        final selectedBucketId = await showModalBottomSheet<String>(
          context: context,
          showDragHandle: true,
          builder: (context) =>
              _MoveToBucketSheet(currentBucketId: item.bucketId),
        );
        if (selectedBucketId == null) return;
        store.moveItem(itemId, selectedBucketId);
        break;
      case _ItemMenuAction.saveToDeck:
        await _saveToDeck(context, store: store, itemId: itemId);
        break;
      case _ItemMenuAction.trash:
        if (!allowTrash) return;
        _trashWithUndo(context, store, itemId);
        break;
    }
  }

  Future<void> _saveToDeck(
    BuildContext context, {
    required SessionStore store,
    required String itemId,
  }) async {
    final item = store.itemById(itemId);
    if (item == null) return;

    final deckStore = DeckLibraryScope.of(context);
    final deckId = await _pickDeckId(context, deckStore);
    if (deckId == null) return;

    final defaultBucketId = item.bucketId == MtgBuckets.trash.id
        ? item.previousBucketId
        : item.bucketId;

    final thumbnailResult = await _loadThumbnail(item.thumbnailPath);

    await deckStore.addCardToDeck(
      deckId,
      label: item.label,
      ocrText: item.ocrText,
      note: item.note,
      defaultBucketId: defaultBucketId,
      thumbnailBytes: thumbnailResult.bytes,
    );

    if (!context.mounted) return;
    final message = _thumbnailWarningMessage(
      base: 'Saved to deck',
      missingCount: thumbnailResult.wasMissing ? 1 : 0,
      tooLargeCount: thumbnailResult.wasTooLarge ? 1 : 0,
    );
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

Future<void> _saveSessionToDeck(BuildContext context) async {
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

  final deckId = await _pickDeckId(context, deckStore);
  if (deckId == null) return;

  final inputs = <DeckCardInput>[];
  var missingCount = 0;
  var tooLargeCount = 0;
  for (final item in items) {
    final thumbnailResult = await _loadThumbnail(item.thumbnailPath);
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
  final message = _thumbnailWarningMessage(
    base: 'Saved ${items.length} cards to $deckName',
    missingCount: missingCount,
    tooLargeCount: tooLargeCount,
  );
  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<String?> _pickDeckId(
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
          _DeckPickerSheet(createDeckSentinel: createDeckSentinel),
    );
  }

  if (pickedDeckId == null) return null;
  return pickedDeckId == createDeckSentinel
      ? await createDeckAndReturnId()
      : pickedDeckId;
}

Future<void> _addFromActiveDeck(
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
    builder: (context) =>
        _DeckCardPickerSheet(deck: deck, deckStore: deckStore),
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

Future<_ThumbnailLoadResult> _loadThumbnail(String? path) async {
  if (path == null || path.isEmpty) {
    return const _ThumbnailLoadResult(wasMissing: true);
  }
  final file = File(path);
  if (!await file.exists()) {
    return const _ThumbnailLoadResult(wasMissing: true);
  }
  final length = await file.length();
  if (length > DeckLibraryStore.maxThumbnailBytes) {
    return const _ThumbnailLoadResult(wasTooLarge: true);
  }
  try {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      return const _ThumbnailLoadResult(wasMissing: true);
    }
    return _ThumbnailLoadResult(bytes: bytes);
  } catch (_) {
    return const _ThumbnailLoadResult(wasMissing: true);
  }
}

String _thumbnailWarningMessage({
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

class _ThumbnailLoadResult {
  const _ThumbnailLoadResult({
    this.bytes,
    this.wasMissing = false,
    this.wasTooLarge = false,
  });

  final Uint8List? bytes;
  final bool wasMissing;
  final bool wasTooLarge;
}

class _VisibleStepsSheet extends StatelessWidget {
  const _VisibleStepsSheet();

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final totalBuckets = MtgBuckets.ordered.length;
    final visibleCount = MtgBuckets.ordered
        .where((bucket) => store.isBucketVisible(bucket.id))
        .length;
    final hiddenCount = totalBuckets - visibleCount;

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('Visible steps'),
            trailing: visibleCount == totalBuckets
                ? TextButton(
                    onPressed: store.hideAllBuckets,
                    child: const Text('Hide all'),
                  )
                : hiddenCount >= 3
                ? TextButton(
                    onPressed: store.showAllBuckets,
                    child: const Text('Show all'),
                  )
                : null,
          ),
          for (final bucket in MtgBuckets.ordered)
            SwitchListTile(
              title: Text(bucket.label),
              value: store.isBucketVisible(bucket.id),
              onChanged: (value) => store.setBucketVisible(bucket.id, value),
            ),
        ],
      ),
    );
  }
}

enum _ItemMenuAction { move, saveToDeck, trash }

enum _TimelineMenuAction { saveSessionToDeck, showHideSteps, reset }

class _DeckPickerSheet extends StatelessWidget {
  const _DeckPickerSheet({required this.createDeckSentinel});

  final String createDeckSentinel;

  @override
  Widget build(BuildContext context) {
    final deckStore = DeckLibraryScope.of(context);

    return SafeArea(
      child: AnimatedBuilder(
        animation: deckStore,
        builder: (context, _) {
          if (!deckStore.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          return ListView(
            shrinkWrap: true,
            children: [
              const ListTile(title: Text('Save to deck')),
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('New deck…'),
                onTap: () => Navigator.of(context).pop(createDeckSentinel),
              ),
              if (deckStore.decks.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No decks yet. Create one to save this card.'),
                )
              else
                for (final deck in deckStore.decks)
                  ListTile(
                    title: Text(deck.name),
                    subtitle: Text('${deck.cards.length} saved cards'),
                    onTap: () => Navigator.of(context).pop(deck.id),
                  ),
            ],
          );
        },
      ),
    );
  }
}

class _DeckCardPickerSheet extends StatelessWidget {
  const _DeckCardPickerSheet({required this.deck, required this.deckStore});

  final Deck deck;
  final DeckLibraryStore deckStore;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: Text(deck.name),
            subtitle: Text('${deck.cards.length} saved cards'),
          ),
          for (final card in deck.cards)
            ListTile(
              leading: _DeckCardThumbnail(
                path: deckStore.thumbnailPathFor(deckId: deck.id, card: card),
              ),
              title: Text(card.label.isEmpty ? 'Untitled card' : card.label),
              subtitle: Text(
                card.ocrText,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              onTap: () => Navigator.of(context).pop(card.id),
            ),
        ],
      ),
    );
  }
}

class _DeckCardThumbnail extends StatelessWidget {
  const _DeckCardThumbnail({this.path});

  final String? path;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final placeholder = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: theme.colorScheme.onSurfaceVariant,
        size: 18,
      ),
    );

    if (path == null || path!.isEmpty) return placeholder;

    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheSize = (44 * pixelRatio).round();
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.file(
        File(path!),
        width: 44,
        height: 44,
        fit: BoxFit.cover,
        cacheWidth: cacheSize,
        cacheHeight: cacheSize,
        errorBuilder: (_, __, ___) => placeholder,
      ),
    );
  }
}

class _TrashSwipeBackground extends StatelessWidget {
  const _TrashSwipeBackground();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      color: theme.colorScheme.errorContainer,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Icon(
        Icons.delete_outline,
        color: theme.colorScheme.onErrorContainer,
      ),
    );
  }
}

class _MoveToBucketSheet extends StatelessWidget {
  const _MoveToBucketSheet({required this.currentBucketId});

  final String currentBucketId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final bucket in MtgBuckets.ordered)
            if (bucket.id != MtgBuckets.trash.id)
              ListTile(
                title: Text(bucket.label),
                trailing: bucket.id == currentBucketId
                    ? const Icon(Icons.check)
                    : null,
                enabled: bucket.id != currentBucketId,
                onTap: bucket.id == currentBucketId
                    ? null
                    : () => Navigator.of(context).pop(bucket.id),
              ),
        ],
      ),
    );
  }
}
