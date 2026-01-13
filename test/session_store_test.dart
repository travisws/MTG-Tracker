import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_list/models/timeline_item.dart';
import 'package:mtg_list/mtg/buckets.dart';
import 'package:mtg_list/session/session_store.dart';
import 'package:mtg_list/thumbnail/thumbnail_cache.dart';

void main() {
  test('reorderWithinBucket updates ordering', () {
    final store = SessionStore(
      initialItems: const [
        TimelineItem(
          id: '1',
          bucketId: 'beginning.upkeep',
          label: 'A',
          ocrText: 'A text',
        ),
        TimelineItem(
          id: '2',
          bucketId: 'beginning.upkeep',
          label: 'B',
          ocrText: 'B text',
        ),
        TimelineItem(
          id: '3',
          bucketId: 'beginning.upkeep',
          label: 'C',
          ocrText: 'C text',
        ),
      ],
    );

    store.reorderWithinBucket(MtgBuckets.upkeep.id, 0, 3);

    expect(
      store
          .itemsForBucket(MtgBuckets.upkeep.id)
          .map((item) => item.id)
          .toList(),
      ['2', '3', '1'],
    );
  });

  test('trashItem and restoreItem round trip', () {
    final now = DateTime(2026, 1, 1, 12, 0);
    final store = SessionStore(
      now: () => now,
      initialItems: const [
        TimelineItem(
          id: '1',
          bucketId: 'beginning.upkeep',
          label: 'A',
          ocrText: 'A text',
        ),
      ],
    );

    store.trashItem('1');
    final trashed = store.itemById('1');
    expect(trashed, isNotNull);
    expect(trashed!.bucketId, MtgBuckets.trash.id);
    expect(trashed.deletedAt, now);
    expect(trashed.previousBucketId, MtgBuckets.upkeep.id);

    store.restoreItem('1');
    final restored = store.itemById('1');
    expect(restored, isNotNull);
    expect(restored!.bucketId, MtgBuckets.upkeep.id);
    expect(restored.deletedAt, isNull);
    expect(restored.previousBucketId, isNull);
  });

  test('reset clears items and purges thumbnail cache', () async {
    final tempDir = await Directory.systemTemp.createTemp('mtg_list_thumbs_');
    final file = File('${tempDir.path}/thumb.jpg');
    await file.writeAsString('x');

    final store = SessionStore(
      initialItems: const [
        TimelineItem(
          id: '1',
          bucketId: 'beginning.upkeep',
          label: 'A',
          ocrText: 'A text',
        ),
      ],
      thumbnailCache: ThumbnailCache(directory: tempDir),
    );

    await store.reset();

    expect(store.itemCountForBucket(MtgBuckets.upkeep.id), 0);
    expect(await tempDir.exists(), isFalse);
  });
}
