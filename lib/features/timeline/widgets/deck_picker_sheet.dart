import 'package:flutter/material.dart';

import '../../../decks/deck_library_scope.dart';

class DeckPickerSheet extends StatelessWidget {
  const DeckPickerSheet({required this.createDeckSentinel, super.key});

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
