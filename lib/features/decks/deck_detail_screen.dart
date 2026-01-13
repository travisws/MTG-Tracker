import 'package:flutter/material.dart';

import '../../decks/deck_library_scope.dart';
import '../../decks/deck_library_store.dart';
import '../../models/deck.dart';
import '../../models/timeline_item.dart';
import '../../mtg/buckets.dart';
import '../../session/session_scope.dart';
import '../../session/session_store.dart';

class DeckDetailScreen extends StatelessWidget {
  const DeckDetailScreen({required this.deckId, super.key});

  final String deckId;

  @override
  Widget build(BuildContext context) {
    final deckStore = DeckLibraryScope.of(context);
    final sessionStore = SessionScope.of(context);

    return AnimatedBuilder(
      animation: deckStore,
      builder: (context, _) {
        final deck = deckStore.deckById(deckId);
        if (deck == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Deck')),
            body: const Center(child: Text('Deck not found.')),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(deck.name),
            actions: [
              IconButton(
                tooltip: 'Add all to timeline',
                onPressed: () => _addAllToTimeline(
                  context,
                  sessionStore: sessionStore,
                  deck: deck,
                ),
                icon: const Icon(Icons.playlist_add),
              ),
              IconButton(
                tooltip: 'Rename deck',
                onPressed: () => _renameDeck(context, deckStore, deck),
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: 'Delete deck',
                onPressed: () => _deleteDeck(context, deckStore, deck),
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: 'Add saved card',
            onPressed: () => _showAddCardDialog(context, deckStore, deck),
            child: const Icon(Icons.add),
          ),
          body: deck.cards.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'No saved cards yet.\n\nAdd cards manually now, or later save OCR text from scans into this deck.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: deck.cards.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final card = deck.cards[index];
                    return _DeckCardTile(
                      deckId: deck.id,
                      card: card,
                      onAddToTimeline: () => _addCardToTimeline(
                        context,
                        sessionStore: sessionStore,
                        card: card,
                      ),
                    );
                  },
                ),
        );
      },
    );
  }

  Future<void> _renameDeck(
    BuildContext context,
    DeckLibraryStore deckStore,
    Deck deck,
  ) async {
    final controller = TextEditingController(text: deck.name);
    final name =
        await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Rename deck'),
            content: TextField(
              controller: controller,
              autofocus: true,
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
                child: const Text('Save'),
              ),
            ],
          ),
        ) ??
        '';

    if (name.trim().isEmpty || name.trim() == deck.name) return;
    await deckStore.renameDeck(deck.id, name);
  }

  Future<void> _deleteDeck(
    BuildContext context,
    DeckLibraryStore deckStore,
    Deck deck,
  ) async {
    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete deck?'),
            content: Text('Delete "${deck.name}" and all saved cards in it?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) return;
    await deckStore.deleteDeck(deck.id);
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _showAddCardDialog(
    BuildContext context,
    DeckLibraryStore deckStore,
    Deck deck,
  ) async {
    final draft = await showDialog<_DeckCardDraft>(
      context: context,
      builder: (context) => const _DeckCardEditorDialog(),
    );
    if (draft == null) return;

    await deckStore.addCardToDeck(
      deck.id,
      label: draft.label,
      ocrText: draft.ocrText,
      note: draft.note,
      defaultBucketId: draft.defaultBucketId,
    );
  }

  void _addAllToTimeline(
    BuildContext context, {
    required SessionStore sessionStore,
    required Deck deck,
  }) {
    if (deck.cards.isEmpty) return;

    final allowedBucketIds = <String>{
      for (final bucket in MtgBuckets.ordered)
        if (bucket.id != MtgBuckets.trash.id) bucket.id,
    };

    var added = 0;
    for (final card in deck.cards) {
      final bucketId =
          card.defaultBucketId != null &&
              allowedBucketIds.contains(card.defaultBucketId)
          ? card.defaultBucketId!
          : MtgBuckets.staticEffects.id;
      sessionStore.addItem(
        TimelineItem(
          id: _newSessionItemId(),
          bucketId: bucketId,
          label: card.label,
          ocrText: card.ocrText,
          note: card.note,
        ),
      );
      added += 1;
    }

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text('Added $added card${added == 1 ? '' : 's'}')),
      );
  }

  Future<void> _addCardToTimeline(
    BuildContext context, {
    required SessionStore sessionStore,
    required DeckCard card,
  }) async {
    final selectedBucketId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) =>
          _BucketPickerSheet(initialBucketId: card.defaultBucketId),
    );
    if (selectedBucketId == null) return;

    sessionStore.addItem(
      TimelineItem(
        id: _newSessionItemId(),
        bucketId: selectedBucketId,
        label: card.label,
        ocrText: card.ocrText,
        note: card.note,
      ),
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Added to timeline')));
  }

  static int _sequence = 0;
  static String _newSessionItemId() {
    _sequence = (_sequence + 1) % 1000000;
    return '${DateTime.now().microsecondsSinceEpoch}-$_sequence';
  }
}

class _DeckCardTile extends StatelessWidget {
  const _DeckCardTile({
    required this.deckId,
    required this.card,
    required this.onAddToTimeline,
  });

  final String deckId;
  final DeckCard card;
  final VoidCallback onAddToTimeline;

  @override
  Widget build(BuildContext context) {
    final deckStore = DeckLibraryScope.of(context);

    return ListTile(
      title: Text(card.label.isEmpty ? '(Untitled)' : card.label),
      subtitle: Text(
        card.ocrText,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Add to timeline',
            onPressed: onAddToTimeline,
            icon: const Icon(Icons.playlist_add),
          ),
          PopupMenuButton<_DeckCardAction>(
            tooltip: 'Card actions',
            onSelected: (action) => _handleAction(context, deckStore, action),
            itemBuilder: (context) {
              return const [
                PopupMenuItem(value: _DeckCardAction.edit, child: Text('Edit')),
                PopupMenuItem(
                  value: _DeckCardAction.delete,
                  child: Text('Delete'),
                ),
              ];
            },
          ),
        ],
      ),
      onTap: () => _editCard(context, deckStore),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    DeckLibraryStore deckStore,
    _DeckCardAction action,
  ) async {
    switch (action) {
      case _DeckCardAction.edit:
        await _editCard(context, deckStore);
        break;
      case _DeckCardAction.delete:
        await _deleteCard(context, deckStore);
        break;
    }
  }

  Future<void> _editCard(
    BuildContext context,
    DeckLibraryStore deckStore,
  ) async {
    final draft = await showDialog<_DeckCardDraft>(
      context: context,
      builder: (context) => _DeckCardEditorDialog(
        initialLabel: card.label,
        initialText: card.ocrText,
        initialNote: card.note,
        initialBucketId: card.defaultBucketId,
      ),
    );
    if (draft == null) return;

    await deckStore.updateCard(
      deckId,
      card,
      label: draft.label,
      ocrText: draft.ocrText,
      note: draft.note,
      defaultBucketId: draft.defaultBucketId,
    );
  }

  Future<void> _deleteCard(
    BuildContext context,
    DeckLibraryStore deckStore,
  ) async {
    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete saved card?'),
            content: Text('Delete "${card.label}" from this deck?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!shouldDelete) return;
    await deckStore.deleteCard(deckId, card.id);
  }
}

enum _DeckCardAction { edit, delete }

class _DeckCardDraft {
  const _DeckCardDraft({
    required this.label,
    required this.ocrText,
    required this.note,
    required this.defaultBucketId,
  });

  final String label;
  final String ocrText;
  final String? note;
  final String? defaultBucketId;
}

class _DeckCardEditorDialog extends StatefulWidget {
  const _DeckCardEditorDialog({
    this.initialLabel = '',
    this.initialText = '',
    this.initialNote,
    this.initialBucketId,
  });

  final String initialLabel;
  final String initialText;
  final String? initialNote;
  final String? initialBucketId;

  @override
  State<_DeckCardEditorDialog> createState() => _DeckCardEditorDialogState();
}

class _DeckCardEditorDialogState extends State<_DeckCardEditorDialog> {
  late final TextEditingController _labelController;
  late final TextEditingController _textController;
  late final TextEditingController _noteController;
  String? _bucketId;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.initialLabel);
    _textController = TextEditingController(text: widget.initialText);
    _noteController = TextEditingController(text: widget.initialNote ?? '');
    _bucketId = widget.initialBucketId;
  }

  @override
  void dispose() {
    _labelController.dispose();
    _textController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Saved card'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _labelController,
              textInputAction: TextInputAction.next,
              decoration: const InputDecoration(labelText: 'Label'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _textController,
              minLines: 3,
              maxLines: 6,
              decoration: const InputDecoration(labelText: 'Rules text'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              minLines: 1,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Default step (optional)',
                contentPadding: EdgeInsets.zero,
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String?>(
                  isExpanded: true,
                  value: _bucketId,
                  items: [
                    const DropdownMenuItem(value: null, child: Text('None')),
                    for (final bucket in MtgBuckets.ordered)
                      if (bucket.id != MtgBuckets.trash.id)
                        DropdownMenuItem(
                          value: bucket.id,
                          child: Text(bucket.label),
                        ),
                  ],
                  onChanged: (value) => setState(() => _bucketId = value),
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () {
            final text = _textController.text.trim();
            if (text.isEmpty) return;

            Navigator.of(context).pop(
              _DeckCardDraft(
                label: _labelController.text.trim(),
                ocrText: text,
                note: _noteController.text.trim().isEmpty
                    ? null
                    : _noteController.text.trim(),
                defaultBucketId: _bucketId,
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

class _BucketPickerSheet extends StatelessWidget {
  const _BucketPickerSheet({this.initialBucketId});

  final String? initialBucketId;

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
                trailing: bucket.id == initialBucketId
                    ? const Icon(Icons.check)
                    : null,
                onTap: () => Navigator.of(context).pop(bucket.id),
              ),
        ],
      ),
    );
  }
}
