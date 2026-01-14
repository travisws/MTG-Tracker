import 'package:flutter/material.dart';

import '../../app/app_drawer.dart';
import '../../app/routes.dart';
import '../../features/capture/capture_flow.dart';
import '../../mtg/buckets.dart';
import '../../session/session_scope.dart';
import 'timeline_actions.dart';
import 'widgets/bucket_header.dart';
import 'widgets/timeline_item_row.dart';
import 'widgets/trash_swipe_background.dart';

class TimelineScreen extends StatelessWidget {
  const TimelineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);

    return Scaffold(
      drawer: AppDrawer(
        currentRoute: AppRoutes.timeline,
        onSaveSessionToDeck: () => saveSessionToDeck(context),
      ),
      appBar: AppBar(
        title: const Text('Current Turn'),
        actions: [
          IconButton(
            onPressed: () => saveSessionToDeck(context),
            tooltip: 'Save session to deck',
            icon: const Icon(Icons.library_add),
          ),
          IconButton(
            onPressed: () => showVisibleStepsSheet(context),
            tooltip: 'Show/Hide Steps',
            icon: const Icon(Icons.tune),
          ),
          IconButton(
            onPressed: () => confirmAndReset(context),
            tooltip: 'Reset',
            icon: const Icon(Icons.restart_alt),
          ),
          PopupMenuButton<_TimelineMenuAction>(
            tooltip: 'More',
            onSelected: (action) {
              switch (action) {
                case _TimelineMenuAction.saveSessionToDeck:
                  saveSessionToDeck(context);
                  break;
                case _TimelineMenuAction.showHideSteps:
                  showVisibleStepsSheet(context);
                  break;
                case _TimelineMenuAction.reset:
                  confirmAndReset(context);
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
                      : () => addFromActiveDeck(context, bucketId: bucket.id),
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
            onTap: () => openItemDetails(context, item.id),
            onLongPress: () async {
              final action = await showItemActionsSheet(
                context,
                allowTrash: false,
              );
              if (action == null) return;
              if (!context.mounted) return;
              await handleItemMenuAction(
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
          secondaryBackground: const TrashSwipeBackground(),
          onDismissed: (_) => trashWithUndo(context, store, item.id),
          child: TimelineItemRow(
            item: item,
            onTap: () => openItemDetails(context, item.id),
            onLongPress: () async {
              final action = await showItemActionsSheet(
                context,
                allowTrash: true,
              );
              if (action == null) return;
              if (!context.mounted) return;
              await handleItemMenuAction(
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
}

enum _TimelineMenuAction { saveSessionToDeck, showHideSteps, reset }
