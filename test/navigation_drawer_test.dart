import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_list/app/mtg_resolution_app.dart';
import 'package:mtg_list/decks/deck_library_store.dart';
import 'package:mtg_list/session/session_store.dart';

void main() {
  testWidgets('Drawer navigates between Timeline and Decks', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 2000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MtgResolutionApp(store: SessionStore(), deckStore: DeckLibraryStore()),
    );

    expect(find.text('Current Turn'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Decks'));
    await tester.pumpAndSettle();

    expect(find.text('Decks'), findsOneWidget);
    expect(find.text('Current Turn'), findsNothing);
  });
}
