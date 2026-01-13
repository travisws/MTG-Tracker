import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_list/app/mtg_resolution_app.dart';
import 'package:mtg_list/models/timeline_item.dart';
import 'package:mtg_list/mtg/buckets.dart';
import 'package:mtg_list/session/session_store.dart';

void main() {
  testWidgets('Timeline contains all bucket headers', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 2000);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(tester.view.resetPhysicalSize);

    final store = SessionStore(initialItems: const []);
    await tester.pumpWidget(MtgResolutionApp(store: store));

    double? lastHeaderTop;
    for (final bucket in MtgBuckets.ordered) {
      final finder = find.text(bucket.label);
      expect(finder, findsOneWidget);

      final headerTop = tester.getTopLeft(finder).dy;
      if (lastHeaderTop != null) {
        expect(headerTop, greaterThan(lastHeaderTop));
      }
      lastHeaderTop = headerTop;
    }
  });

  testWidgets('Bucket header toggles collapse/expand', (
    WidgetTester tester,
  ) async {
    final store = SessionStore(
      initialItems: const [
        TimelineItem(
          id: 'test-1',
          bucketId: 'beginning.upkeep',
          label: 'Test Card',
          ocrText: 'Test rules text.',
        ),
      ],
    );
    await tester.pumpWidget(MtgResolutionApp(store: store));

    expect(find.text('Upkeep'), findsOneWidget);
    expect(find.text('Test Card'), findsOneWidget);

    await tester.tap(find.byKey(const Key('bucket-toggle-beginning.upkeep')));
    await tester.pumpAndSettle();
    expect(find.text('Test Card'), findsNothing);

    await tester.tap(find.byKey(const Key('bucket-toggle-beginning.upkeep')));
    await tester.pumpAndSettle();
    expect(find.text('Test Card'), findsOneWidget);
  });

  testWidgets('Visible steps sheet shows Hide all only when all visible', (
    WidgetTester tester,
  ) async {
    final store = SessionStore(initialItems: const []);
    await tester.pumpWidget(MtgResolutionApp(store: store));

    await tester.tap(find.byTooltip('Show/Hide Steps'));
    await tester.pumpAndSettle();

    expect(find.text('Hide all'), findsOneWidget);
    expect(find.text('Show all'), findsNothing);
  });

  testWidgets('Visible steps sheet shows Show all when 3+ are hidden', (
    WidgetTester tester,
  ) async {
    final orderedBucketIds = MtgBuckets.ordered
        .map((bucket) => bucket.id)
        .toList();
    final visibleBucketIds =
        orderedBucketIds.sublist(0, orderedBucketIds.length - 3).toSet();

    final store = SessionStore(
      initialItems: const [],
      visibleBucketIds: visibleBucketIds,
    );
    await tester.pumpWidget(MtgResolutionApp(store: store));

    await tester.tap(find.byTooltip('Show/Hide Steps'));
    await tester.pumpAndSettle();

    expect(find.text('Show all'), findsOneWidget);
    expect(find.text('Hide all'), findsNothing);
  });
}
