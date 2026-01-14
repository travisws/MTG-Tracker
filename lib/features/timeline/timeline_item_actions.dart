import 'package:flutter/material.dart';

import '../../session/session_scope.dart';
import '../../session/session_store.dart';
import 'timeline_deck_actions.dart';
import 'timeline_item_detail_screen.dart';
import 'widgets/move_to_bucket_sheet.dart';
import 'widgets/visible_steps_sheet.dart';

enum TimelineItemMenuAction { move, saveToDeck, trash }

Future<void> confirmAndReset(BuildContext context) async {
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
  } catch (_) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Reset failed')));
  }
}

void showVisibleStepsSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (context) => const VisibleStepsSheet(),
  );
}

Future<void> openItemDetails(BuildContext context, String itemId) {
  return TimelineItemDetailScreen.open(context, itemId: itemId);
}

Future<TimelineItemMenuAction?> showItemActionsSheet(
  BuildContext context, {
  required bool allowTrash,
}) {
  return showModalBottomSheet<TimelineItemMenuAction>(
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
              onTap: () =>
                  Navigator.of(context).pop(TimelineItemMenuAction.move),
            ),
            ListTile(
              leading: const Icon(Icons.library_add),
              title: const Text('Save to deck...'),
              onTap: () =>
                  Navigator.of(context).pop(TimelineItemMenuAction.saveToDeck),
            ),
            if (allowTrash)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Move to Trash'),
                onTap: () =>
                    Navigator.of(context).pop(TimelineItemMenuAction.trash),
              ),
          ],
        ),
      );
    },
  );
}

void trashWithUndo(BuildContext context, SessionStore store, String itemId) {
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

Future<void> handleItemMenuAction(
  BuildContext context, {
  required SessionStore store,
  required String itemId,
  required TimelineItemMenuAction action,
  required bool allowTrash,
}) async {
  switch (action) {
    case TimelineItemMenuAction.move:
      final item = store.itemById(itemId);
      if (item == null) return;
      final selectedBucketId = await showModalBottomSheet<String>(
        context: context,
        showDragHandle: true,
        builder: (context) => MoveToBucketSheet(currentBucketId: item.bucketId),
      );
      if (selectedBucketId == null) return;
      store.moveItem(itemId, selectedBucketId);
      break;
    case TimelineItemMenuAction.saveToDeck:
      await saveToDeck(context, store: store, itemId: itemId);
      break;
    case TimelineItemMenuAction.trash:
      if (!allowTrash) return;
      trashWithUndo(context, store, itemId);
      break;
  }
}
