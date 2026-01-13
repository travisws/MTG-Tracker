import 'package:flutter/material.dart';

import '../../app/app_drawer.dart';
import '../../app/routes.dart';
import '../../decks/deck_library_scope.dart';
import '../../mtg/buckets.dart';
import '../../session/session_scope.dart';
import '../../session/session_store.dart';
import 'widgets/bucket_header.dart';
import 'widgets/timeline_item_row.dart';

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);

    return Scaffold(
      drawer: const AppDrawer(currentRoute: AppRoutes.timeline),
      appBar: AppBar(
        title: const Text('Current Turn'),
        actions: [
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
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: null,
        tooltip: 'Capture (coming soon)',
        child: const Icon(Icons.add_a_photo_outlined),
      ),
      body: CustomScrollView(
        primary: false,
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
    if (!deckStore.isLoaded) {
      await deckStore.load();
    }
    if (!context.mounted) return;

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
                      onPressed: () =>
                          Navigator.of(context).pop(controller.text),
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
      if (!context.mounted) return;
      pickedDeckId = await createDeckAndReturnId();
    } else {
      if (!context.mounted) return;
      pickedDeckId = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) =>
            _DeckPickerSheet(createDeckSentinel: createDeckSentinel),
      );
    }

    if (pickedDeckId == null) return;

    final deckId = pickedDeckId == createDeckSentinel
        ? await createDeckAndReturnId()
        : pickedDeckId;
    if (deckId == null) return;

    final defaultBucketId = item.bucketId == MtgBuckets.trash.id
        ? item.previousBucketId
        : item.bucketId;

    await deckStore.addCardToDeck(
      deckId,
      label: item.label,
      ocrText: item.ocrText,
      note: item.note,
      defaultBucketId: defaultBucketId,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Saved to deck')));
  }
}

class _VisibleStepsSheet extends StatelessWidget {
  const _VisibleStepsSheet();

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);

    return SafeArea(
      child: ListView(
        primary: false,
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('Visible steps'),
            trailing: TextButton(
              onPressed: store.showAllBuckets,
              child: const Text('Show all'),
            ),
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
            primary: false,
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
        primary: false,
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
