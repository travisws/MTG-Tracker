import 'dart:io';

import 'package:flutter/material.dart';

import '../../../decks/deck_library_store.dart';
import '../../../models/deck.dart';

class DeckCardPickerSheet extends StatelessWidget {
  const DeckCardPickerSheet({
    required this.deck,
    required this.deckStore,
    super.key,
  });

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
              leading: DeckCardThumbnail(
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

class DeckCardThumbnail extends StatelessWidget {
  const DeckCardThumbnail({this.path, super.key});

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
        errorBuilder: (context, error, stackTrace) => placeholder,
      ),
    );
  }
}
