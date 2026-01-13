import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../app/app_drawer.dart';
import '../../app/routes.dart';
import '../../decks/deck_library_scope.dart';
import '../../decks/deck_library_store.dart';
import '../../mtg/buckets.dart';
import '../../models/timeline_item.dart';
import '../../models/deck.dart';
import '../../session/session_scope.dart';
import '../../session/session_store.dart';
import '../../session/session_item_id.dart';
import 'widgets/bucket_header.dart';
import 'widgets/timeline_item_row.dart';

const int _maxThumbnailBytes = 256 * 1024;

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
        onPressed: null,
        tooltip: 'Capture (coming soon)',
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
                  onLongPress:
                      bucket.id == MtgBuckets.trash.id
                          ? null
                          : () => _addFromActiveDeck(
                            context,
                            bucketId: bucket.id,
                          ),
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
            trailingActions: [
              IconButton(
                tooltip: 'Restore',
                onPressed: () => store.restoreItem(item.id),
                icon: const Icon(Icons.restore_from_trash),
              ),
              _ItemMenu(
                onSelected: (action) => _handleItemMenuAction(
                  context,
                  store: store,
                  itemId: item.id,
                  action: action,
                  allowTrash: false,
                ),
                allowTrash: false,
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
            onLongPress:
                () => _handleItemMenuAction(
                  context,
                  store: store,
                  itemId: item.id,
                  action: _ItemMenuAction.move,
                  allowTrash: true,
                ),
            trailingActions: [
              _ItemMenu(
                onSelected: (action) => _handleItemMenuAction(
                  context,
                  store: store,
                  itemId: item.id,
                  action: action,
                  allowTrash: true,
                ),
                allowTrash: true,
              ),
            ],
          ),
        );
      }, childCount: items.length),
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
    builder: (context) => _DeckCardPickerSheet(deck: deck),
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

  final thumbnailPath = await store.cacheThumbnailBytes(
    pickedCard.thumbnailBytes,
  );

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
  if (length > _maxThumbnailBytes) {
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
    final visibleCount =
        MtgBuckets.ordered
            .where((bucket) => store.isBucketVisible(bucket.id))
            .length;
    final hiddenCount = totalBuckets - visibleCount;

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('Visible steps'),
            trailing:
                visibleCount == totalBuckets
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

class _ItemMenu extends StatelessWidget {
  const _ItemMenu({required this.onSelected, required this.allowTrash});

  final ValueChanged<_ItemMenuAction> onSelected;
  final bool allowTrash;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ItemMenuAction>(
      tooltip: 'Item actions',
      icon: const Icon(Icons.more_horiz),
      onSelected: onSelected,
      itemBuilder: (context) {
        return [
          const PopupMenuItem(
            value: _ItemMenuAction.move,
            child: Text('Move to…'),
          ),
          const PopupMenuItem(
            value: _ItemMenuAction.saveToDeck,
            child: Text('Save to deck…'),
          ),
          if (allowTrash)
            const PopupMenuItem(
              value: _ItemMenuAction.trash,
              child: Text('Move to Trash'),
            ),
        ];
      },
    );
  }
}

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
  const _DeckCardPickerSheet({required this.deck});

  final Deck deck;

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
              leading: _DeckCardThumbnail(bytes: card.thumbnailBytes),
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
  const _DeckCardThumbnail({this.bytes});

  final Uint8List? bytes;

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

    if (bytes == null || bytes!.isEmpty) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.memory(
        bytes!,
        width: 44,
        height: 44,
        fit: BoxFit.cover,
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
