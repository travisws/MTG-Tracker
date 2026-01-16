import 'package:flutter/material.dart';

import '../../mtg/buckets.dart';
import '../../session/session_scope.dart';
import '../../session/session_store.dart';
import 'widgets/move_to_bucket_sheet.dart';
import 'widgets/timeline_thumbnail.dart';

class TimelineItemDetailScreen extends StatefulWidget {
  const TimelineItemDetailScreen({required this.itemId, super.key});

  final String itemId;

  static Future<void> open(BuildContext context, {required String itemId}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => TimelineItemDetailScreen(itemId: itemId),
      ),
    );
  }

  @override
  State<TimelineItemDetailScreen> createState() =>
      _TimelineItemDetailScreenState();
}

class _TimelineItemDetailScreenState extends State<TimelineItemDetailScreen> {
  final TextEditingController _labelController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  SessionStore? _store;
  bool _itemWasDeleted = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_store != null) return;
    final store = SessionScope.of(context);
    _store = store;
    final item = store.itemById(widget.itemId);
    _labelController.text = item?.label ?? '';
    _noteController.text = item?.note ?? '';
    store.addListener(_onStoreChanged);
  }

  void _onStoreChanged() {
    if (_itemWasDeleted) return;
    final item = _store?.itemById(widget.itemId);
    if (item == null && mounted) {
      _itemWasDeleted = true;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card was deleted')),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _store?.removeListener(_onStoreChanged);
    _labelController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final item = store.itemById(widget.itemId);
    final theme = Theme.of(context);

    if (item == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Card details')),
        body: const Center(child: Text('Card not found.')),
      );
    }

    final bucketLabel = MtgBuckets.ordered
        .firstWhere(
          (bucket) => bucket.id == item.bucketId,
          orElse: () => MtgBuckets.staticEffects,
        )
        .label;
    final ocrText = item.ocrText.trim().isEmpty
        ? 'No rules text yet.'
        : item.ocrText;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Card details'),
        actions: [
          IconButton(
            tooltip: 'Save',
            icon: const Icon(Icons.check),
            onPressed: () => _saveAndPop(context),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: TimelineThumbnail(
                  item: item,
                  size: 140,
                  heroTag: timelineItemHeroTag(item.id),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _labelController,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Label'),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                minLines: 2,
                maxLines: 5,
                decoration: const InputDecoration(labelText: 'Note'),
              ),
              const SizedBox(height: 20),
              Text('Step', style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      bucketLabel,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => _moveToStep(context),
                    icon: const Icon(Icons.drive_file_move_outlined),
                    label: const Text('Move'),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Rules text', style: theme.textTheme.labelMedium),
              const SizedBox(height: 6),
              SelectableText(ocrText),
            ],
          ),
        ),
      ),
    );
  }

  void _saveAndPop(BuildContext context) {
    final store = SessionScope.of(context);
    final item = store.itemById(widget.itemId);
    if (item == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Card was deleted')),
      );
      Navigator.of(context).pop();
      return;
    }
    final label = _labelController.text.trim();
    final noteText = _noteController.text.trim();
    store.updateItemDetails(
      widget.itemId,
      label: label,
      note: noteText.isEmpty ? null : noteText,
    );
    Navigator.of(context).pop();
  }

  Future<void> _moveToStep(BuildContext context) async {
    final store = SessionScope.of(context);
    final item = store.itemById(widget.itemId);
    if (item == null) return;

    final selectedBucketId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) =>
          MoveToBucketSheet(currentBucketId: item.bucketId),
    );
    if (!mounted || selectedBucketId == null) return;
    store.moveItem(item.id, selectedBucketId);
  }
}
