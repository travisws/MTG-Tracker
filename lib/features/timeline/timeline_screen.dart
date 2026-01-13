import 'package:flutter/material.dart';

import '../../mtg/buckets.dart';
import '../../session/session_scope.dart';
import '../../session/session_store.dart';
import 'widgets/bucket_header_delegate.dart';
import 'widgets/timeline_item_row.dart';

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);

    return Scaffold(
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
        slivers: [
          for (final bucket in MtgBuckets.ordered)
            if (store.isBucketVisible(bucket.id)) ...[
              SliverPersistentHeader(
                pinned: true,
                delegate: BucketHeaderDelegate(
                  label: bucket.label,
                  count: store.itemCountForBucket(bucket.id),
                  isExpanded: store.isBucketExpanded(bucket.id),
                  onTap: () => store.toggleBucketExpanded(bucket.id),
                ),
              ),
              if (store.isBucketExpanded(bucket.id))
                _BucketBodySliver(bucketId: bucket.id)
              else
                const SliverToBoxAdapter(child: SizedBox.shrink()),
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

    return SliverReorderableList(
      itemBuilder: (context, index) {
        final item = items[index];
        return Dismissible(
          key: ValueKey(item.id),
          direction: DismissDirection.endToStart,
          background: const SizedBox.shrink(),
          secondaryBackground: _TrashSwipeBackground(),
          onDismissed: (_) => _trashWithUndo(context, store, item.id),
          child: TimelineItemRow(
            item: item,
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
              ReorderableDragStartListener(
                index: index,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: Icon(
                    Icons.drag_handle,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        );
      },
      itemCount: items.length,
      onReorder: (oldIndex, newIndex) {
        store.reorderWithinBucket(bucketId, oldIndex, newIndex);
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
      case _ItemMenuAction.trash:
        if (!allowTrash) return;
        _trashWithUndo(context, store, itemId);
        break;
    }
  }
}

class _VisibleStepsSheet extends StatelessWidget {
  const _VisibleStepsSheet();

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);

    return SafeArea(
      child: ListView(
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

enum _ItemMenuAction { move, trash }

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
