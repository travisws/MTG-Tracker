import 'package:flutter/widgets.dart';

import 'deck_library_store.dart';

class DeckLibraryScope extends InheritedNotifier<DeckLibraryStore> {
  const DeckLibraryScope({
    required DeckLibraryStore store,
    required super.child,
    super.key,
  }) : super(notifier: store);

  static DeckLibraryStore of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<DeckLibraryScope>();
    assert(scope != null, 'No DeckLibraryScope found in context');
    return scope!.notifier!;
  }
}
