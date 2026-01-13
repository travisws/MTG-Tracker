import 'package:flutter/material.dart';

import '../../app/app_drawer.dart';
import '../../app/routes.dart';
import '../../decks/deck_library_scope.dart';
import '../../decks/deck_library_store.dart';
import '../../models/deck.dart';
import 'deck_detail_screen.dart';

class DecksScreen extends StatelessWidget {
  const DecksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final deckStore = DeckLibraryScope.of(context);

    return Scaffold(
      drawer: const AppDrawer(currentRoute: AppRoutes.decks),
      appBar: AppBar(
        title: const Text('Decks'),
        actions: [
          IconButton(
            tooltip: 'Add deck',
            onPressed: () => _showCreateDeckDialog(context),
            icon: const Icon(Icons.add),
          ),
          IconButton(
            tooltip: 'Delete all decks',
            onPressed: () => _confirmDeleteAllDecks(context),
            icon: const Icon(Icons.delete_sweep_outlined),
          ),
        ],
      ),
      body: AnimatedBuilder(
        animation: deckStore,
        builder: (context, _) {
          if (!deckStore.isLoaded) {
            return const Center(child: CircularProgressIndicator());
          }

          if (deckStore.decks.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No decks yet.\n\nCreate a deck to save card reminders you can quickly add back into a session later.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            physics: const ClampingScrollPhysics(),
            itemCount: deckStore.decks.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final deck = deckStore.decks[index];
              return _DeckTile(deck: deck);
            },
          );
        },
      ),
    );
  }

  Future<void> _showCreateDeckDialog(BuildContext context) async {
    final deckStore = DeckLibraryScope.of(context);
    final controller = TextEditingController();

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

    if (name.trim().isEmpty) return;

    await deckStore.createDeck(name);
  }

  Future<void> _confirmDeleteAllDecks(BuildContext context) async {
    final deckStore = DeckLibraryScope.of(context);
    if (!deckStore.isLoaded || deckStore.decks.isEmpty) return;

    final shouldDelete =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Delete all decks?'),
            content: const Text(
              'This removes every saved deck and saved card reminder.',
            ),
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
    await deckStore.deleteAll();

    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text('Deleted all decks')));
  }
}

class _DeckTile extends StatelessWidget {
  const _DeckTile({required this.deck});

  final Deck deck;

  @override
  Widget build(BuildContext context) {
    final deckStore = DeckLibraryScope.of(context);

    return ListTile(
      title: Text(deck.name),
      subtitle: Text('${deck.cards.length} saved cards'),
      trailing: PopupMenuButton<_DeckAction>(
        tooltip: 'Deck actions',
        onSelected: (action) => _handleAction(context, deckStore, action),
        itemBuilder: (context) {
          return const [
            PopupMenuItem(value: _DeckAction.rename, child: Text('Rename')),
            PopupMenuItem(value: _DeckAction.delete, child: Text('Delete')),
          ];
        },
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (context) => DeckDetailScreen(deckId: deck.id),
          ),
        );
      },
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    DeckLibraryStore deckStore,
    _DeckAction action,
  ) async {
    switch (action) {
      case _DeckAction.rename:
        await _renameDeck(context, deckStore);
        break;
      case _DeckAction.delete:
        await _deleteDeck(context, deckStore);
        break;
    }
  }

  Future<void> _renameDeck(
    BuildContext context,
    DeckLibraryStore deckStore,
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
  }
}

enum _DeckAction { rename, delete }
