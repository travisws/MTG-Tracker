import '../models/deck.dart';

abstract class DeckLibraryStorage {
  Future<List<Deck>> loadDecks();
  Future<void> saveDecks(List<Deck> decks);
}
