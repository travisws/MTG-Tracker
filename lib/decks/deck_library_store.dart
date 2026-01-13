import 'dart:collection';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../models/deck.dart';
import 'deck_library_storage.dart';

class DeckLibraryStore extends ChangeNotifier {
  DeckLibraryStore({DeckLibraryStorage? storage, DateTime Function()? now})
    : _storage = storage,
      _now = now ?? DateTime.now {
    _isLoaded = storage == null;
  }

  final DeckLibraryStorage? _storage;
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
    await addCardsToDeck(
      deckId,
      [
        DeckCardInput(
          label: label,
          ocrText: ocrText,
          note: note,
          defaultBucketId: defaultBucketId,
          thumbnailBytes: thumbnailBytes,
        ),
      ],
    );
  }

  Future<void> addCardsToDeck(
    String deckId,
    List<DeckCardInput> cards,
  ) async {
    if (cards.isEmpty) return;
    final deckIndex = _decks.indexWhere((deck) => deck.id == deckId);
    if (deckIndex == -1) return;

    final now = _now();
    final deck = _decks[deckIndex];
    final newCards = cards
        .map((input) => _buildCard(input, now))
        .toList();
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
    await _persist();
    notifyListeners();
  }

  Future<void> deleteAll() async {
    _decks.clear();
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

  DeckCard _buildCard(DeckCardInput input, DateTime now) {
    final thumbnailBytes = input.thumbnailBytes == null
        ? null
        : Uint8List.fromList(input.thumbnailBytes!);
    return DeckCard(
      id: _newId(),
      label: input.label.trim(),
      ocrText: input.ocrText.trim(),
      note: input.note?.trim().isEmpty ?? true ? null : input.note!.trim(),
      defaultBucketId: input.defaultBucketId,
      thumbnailBytes: thumbnailBytes,
      createdAt: now,
      updatedAt: now,
    );
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
