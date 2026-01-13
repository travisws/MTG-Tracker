import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_list/app/mtg_resolution_app.dart';
import 'package:mtg_list/models/timeline_item.dart';
import 'package:mtg_list/mtg/buckets.dart';
import 'package:mtg_list/session/session_store.dart';

void main() {
  testWidgets('Swipe to Trash shows Undo and restores', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 2000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final store = SessionStore(
      initialItems: const [
        TimelineItem(
          id: 'test-1',
          bucketId: 'beginning.upkeep',
          label: 'Test Card',
          ocrText: 'Rules text.',
        ),
      ],
    );

    await tester.pumpWidget(MtgResolutionApp(store: store));
    expect(store.itemCountForBucket(MtgBuckets.upkeep.id), 1);

    await tester.drag(find.text('Test Card'), const Offset(-500, 0));
    await tester.pumpAndSettle();

    expect(find.text('Moved to Trash'), findsOneWidget);
    expect(store.itemCountForBucket(MtgBuckets.upkeep.id), 0);
    expect(store.itemCountForBucket(MtgBuckets.trash.id), 1);

    await tester.tap(find.text('Undo'));
    await tester.pumpAndSettle();

    expect(store.itemCountForBucket(MtgBuckets.upkeep.id), 1);
    expect(store.itemCountForBucket(MtgBuckets.trash.id), 0);
  });

  testWidgets('Reset clears the session after confirmation', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 2000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final store = SessionStore(
      initialItems: const [
        TimelineItem(
          id: 'test-1',
          bucketId: 'beginning.upkeep',
          label: 'Test Card',
          ocrText: 'Rules text.',
        ),
      ],
    );

    await tester.pumpWidget(MtgResolutionApp(store: store));
    expect(store.itemCountForBucket(MtgBuckets.upkeep.id), 1);

    await tester.tap(find.byIcon(Icons.restart_alt));
    await tester.pumpAndSettle();

    expect(find.text('Reset session?'), findsOneWidget);
    await tester.tap(find.text('Reset'));
    await tester.pumpAndSettle();

    expect(store.itemCountForBucket(MtgBuckets.upkeep.id), 0);
    expect(find.text('Session reset'), findsOneWidget);
  });
}
