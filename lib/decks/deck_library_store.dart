import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/deck.dart';
import 'deck_library_storage.dart';
import 'deck_thumbnail_store.dart';

class DeckLibraryStore extends ChangeNotifier {
  DeckLibraryStore({
    DeckLibraryStorage? storage,
    DeckThumbnailStore? thumbnailStore,
    DateTime Function()? now,
  }) : _storage = storage,
       _thumbnailStore = thumbnailStore,
       _now = now ?? DateTime.now {
    _isLoaded = storage == null;
  }

  static const int maxThumbnailBytes = 256 * 1024;

  final DeckLibraryStorage? _storage;
  final DeckThumbnailStore? _thumbnailStore;
  final DateTime Function() _now;

  final List<Deck> _decks = [];
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  UnmodifiableListView<Deck> get decks => UnmodifiableListView<Deck>(_decks);

  Deck? deckById(String deckId) {
    final index = _decks.indexWhere((deck) => deck.id == deckId);
    if (index == -1) return null;
    return _decks[index];
  }

  String? thumbnailPathFor({required String deckId, required DeckCard card}) {
    if (!card.hasThumbnail) return null;
    if (_thumbnailStore == null) return null;
    return _thumbnailStore!.thumbnailPathFor(deckId: deckId, cardId: card.id);
  }

  Future<void> load() async {
    if (_isLoaded) return;

    final loaded = await _storage?.loadDecks() ?? const <Deck>[];
    _decks
      ..clear()
      ..addAll(loaded);
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> createDeck(String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final now = _now();
    final deck = Deck(
      id: _newId(),
      name: trimmed,
      cards: const [],
      createdAt: now,
      updatedAt: now,
    );
    _decks.add(deck);
    await _persist();
    notifyListeners();
  }

  Future<void> renameDeck(String deckId, String name) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final index = _decks.indexWhere((deck) => deck.id == deckId);
    if (index == -1) return;

    _decks[index] = _decks[index].copyWith(name: trimmed, updatedAt: _now());
    await _persist();
    notifyListeners();
  }

  Future<void> deleteDeck(String deckId) async {
    _decks.removeWhere((deck) => deck.id == deckId);
    await _thumbnailStore?.deleteDeck(deckId);
    await _persist();
    notifyListeners();
  }

  Future<void> addCardToDeck(
    String deckId, {
    required String label,
    required String ocrText,
    String? note,
    String? defaultBucketId,
    Uint8List? thumbnailBytes,
  }) async {
    await addCardsToDeck(deckId, [
      DeckCardInput(
        label: label,
        ocrText: ocrText,
        note: note,
        defaultBucketId: defaultBucketId,
        thumbnailBytes: thumbnailBytes,
      ),
    ]);
  }

  Future<void> addCardsToDeck(String deckId, List<DeckCardInput> cards) async {
    if (cards.isEmpty) return;
    final deckIndex = _decks.indexWhere((deck) => deck.id == deckId);
    if (deckIndex == -1) return;

    final now = _now();
    final deck = _decks[deckIndex];
    final newCards = <DeckCard>[];
    for (final input in cards) {
      final card = await _buildCard(deckId, input, now);
      newCards.add(card);
    }
    _decks[deckIndex] = deck.copyWith(
      cards: [...deck.cards, ...newCards],
      updatedAt: now,
    );
    await _persist();
    notifyListeners();
  }

  Future<void> updateCard(
    String deckId,
    DeckCard card, {
    required String label,
    required String ocrText,
    String? note,
    String? defaultBucketId,
  }) async {
    final deckIndex = _decks.indexWhere((deck) => deck.id == deckId);
    if (deckIndex == -1) return;

    final deck = _decks[deckIndex];
    final cardIndex = deck.cards.indexWhere((c) => c.id == card.id);
    if (cardIndex == -1) return;

    final now = _now();
    final updatedCard = card.copyWith(
      label: label.trim(),
      ocrText: ocrText.trim(),
      note: note?.trim().isEmpty ?? true ? null : note!.trim(),
      defaultBucketId: defaultBucketId,
      updatedAt: now,
    );
    final updatedCards = [...deck.cards]..[cardIndex] = updatedCard;
    _decks[deckIndex] = deck.copyWith(cards: updatedCards, updatedAt: now);
    await _persist();
    notifyListeners();
  }

  Future<void> deleteCard(String deckId, String cardId) async {
    final deckIndex = _decks.indexWhere((deck) => deck.id == deckId);
    if (deckIndex == -1) return;

    final deck = _decks[deckIndex];
    _decks[deckIndex] = deck.copyWith(
      cards: deck.cards.where((card) => card.id != cardId).toList(),
      updatedAt: _now(),
    );
    await _thumbnailStore?.deleteCard(deckId: deckId, cardId: cardId);
    await _persist();
    notifyListeners();
  }

  Future<void> deleteAll() async {
    _decks.clear();
    await _thumbnailStore?.deleteAll();
    await _persist();
    notifyListeners();
  }

  Future<void> _persist() async {
    await _storage?.saveDecks(_decks);
  }

  int _sequence = 0;
  String _newId() {
    _sequence = (_sequence + 1) % 1000000;
    return '${_now().microsecondsSinceEpoch}-$_sequence';
  }

  Future<DeckCard> _buildCard(
    String deckId,
    DeckCardInput input,
    DateTime now,
  ) async {
    final cardId = _newId();
    final thumbnailBytes = _sanitizeThumbnailBytes(input.thumbnailBytes);
    var hasThumbnail = false;
    if (_thumbnailStore != null && thumbnailBytes != null) {
      try {
        await _thumbnailStore!.writeBytes(
          deckId: deckId,
          cardId: cardId,
          bytes: thumbnailBytes,
        );
        hasThumbnail = true;
      } catch (_) {
        hasThumbnail = false;
      }
    }
    return DeckCard(
      id: cardId,
      label: input.label.trim(),
      ocrText: input.ocrText.trim(),
      note: input.note?.trim().isEmpty ?? true ? null : input.note!.trim(),
      defaultBucketId: input.defaultBucketId,
      hasThumbnail: hasThumbnail,
      createdAt: now,
      updatedAt: now,
    );
  }

  Uint8List? _sanitizeThumbnailBytes(Uint8List? bytes) {
    if (bytes == null || bytes.isEmpty) return null;
    if (bytes.lengthInBytes > maxThumbnailBytes) return null;
    return Uint8List.fromList(bytes);
  }
}

@immutable
class DeckCardInput {
  const DeckCardInput({
    required this.label,
    required this.ocrText,
    this.note,
    this.defaultBucketId,
    this.thumbnailBytes,
  });

  final String label;
  final String ocrText;
  final String? note;
  final String? defaultBucketId;
  final Uint8List? thumbnailBytes;
}
