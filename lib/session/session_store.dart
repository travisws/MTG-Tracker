import 'dart:collection';

import 'package:flutter/foundation.dart';

import '../models/timeline_item.dart';
import '../mtg/buckets.dart';
import '../thumbnail/thumbnail_cache.dart';

class SessionStore extends ChangeNotifier {
  SessionStore({
    List<TimelineItem> initialItems = const [],
    Set<String>? expandedBucketIds,
    Set<String>? visibleBucketIds,
    ThumbnailCache? thumbnailCache,
    DateTime Function()? now,
  }) : _thumbnailCache = thumbnailCache,
       _now = now ?? DateTime.now {
    for (final bucket in MtgBuckets.ordered) {
      _itemsByBucketId[bucket.id] = <TimelineItem>[];
      _expandedByBucketId[bucket.id] = false;
      _visibleByBucketId[bucket.id] =
          visibleBucketIds?.contains(bucket.id) ?? true;
    }

    for (final item in initialItems) {
      final bucketId = _itemsByBucketId.containsKey(item.bucketId)
          ? item.bucketId
          : MtgBuckets.staticEffects.id;
      _itemsByBucketId[bucketId]!.add(item.copyWith(bucketId: bucketId));
    }

    for (final bucket in MtgBuckets.ordered) {
      _expandedByBucketId[bucket.id] =
          expandedBucketIds?.contains(bucket.id) ??
          (_itemsByBucketId[bucket.id]?.isNotEmpty ?? false);
    }
  }

  final ThumbnailCache? _thumbnailCache;
  final DateTime Function() _now;

  final Map<String, List<TimelineItem>> _itemsByBucketId = {};
  final Map<String, bool> _expandedByBucketId = {};
  final Map<String, bool> _visibleByBucketId = {};

  final Map<String, int> _restoreIndexByItemId = {};

  UnmodifiableListView<TimelineItem> itemsForBucket(String bucketId) {
    return UnmodifiableListView<TimelineItem>(
      _itemsByBucketId[bucketId] ?? const [],
    );
  }

  int itemCountForBucket(String bucketId) {
    return _itemsByBucketId[bucketId]?.length ?? 0;
  }

  TimelineItem? itemById(String itemId) {
    final location = _locateItem(itemId);
    if (location == null) return null;
    return _itemsByBucketId[location.bucketId]![location.index];
  }

  bool isBucketExpanded(String bucketId) {
    return _expandedByBucketId[bucketId] ?? false;
  }

  void toggleBucketExpanded(String bucketId) {
    _expandedByBucketId[bucketId] = !isBucketExpanded(bucketId);
    notifyListeners();
  }

  bool isBucketVisible(String bucketId) {
    return _visibleByBucketId[bucketId] ?? true;
  }

  void setBucketVisible(String bucketId, bool isVisible) {
    _visibleByBucketId[bucketId] = isVisible;
    notifyListeners();
  }

  void showAllBuckets() {
    for (final bucket in MtgBuckets.ordered) {
      _visibleByBucketId[bucket.id] = true;
    }
    notifyListeners();
  }

  void addItem(TimelineItem item) {
    final bucketId = _itemsByBucketId.containsKey(item.bucketId)
        ? item.bucketId
        : MtgBuckets.staticEffects.id;
    _itemsByBucketId[bucketId]!.add(item.copyWith(bucketId: bucketId));
    _expandedByBucketId[bucketId] = true;
    _visibleByBucketId[bucketId] = true;
    notifyListeners();
  }

  void reorderWithinBucket(String bucketId, int oldIndex, int newIndex) {
    final bucketItems = _itemsByBucketId[bucketId];
    if (bucketItems == null) return;
    if (oldIndex < 0 || oldIndex >= bucketItems.length) return;

    var targetIndex = newIndex;
    if (targetIndex > bucketItems.length) targetIndex = bucketItems.length;
    if (oldIndex < targetIndex) targetIndex -= 1;
    if (targetIndex < 0 || targetIndex >= bucketItems.length) return;

    final item = bucketItems.removeAt(oldIndex);
    bucketItems.insert(targetIndex, item);
    notifyListeners();
  }

  void moveItem(String itemId, String toBucketId, {int? toIndex}) {
    if (!_itemsByBucketId.containsKey(toBucketId)) return;

    final location = _locateItem(itemId);
    if (location == null) return;

    final fromList = _itemsByBucketId[location.bucketId]!;
    final item = fromList
        .removeAt(location.index)
        .copyWith(
          bucketId: toBucketId,
          deletedAt: null,
          previousBucketId: null,
        );

    final toList = _itemsByBucketId[toBucketId]!;
    final insertIndex = toIndex == null
        ? toList.length
        : toIndex.clamp(0, toList.length);
    toList.insert(insertIndex, item);

    _restoreIndexByItemId.remove(itemId);
    _expandedByBucketId[toBucketId] = true;
    _visibleByBucketId[toBucketId] = true;
    notifyListeners();
  }

  void trashItem(String itemId) {
    final location = _locateItem(itemId);
    if (location == null) return;
    if (location.bucketId == MtgBuckets.trash.id) return;

    final fromList = _itemsByBucketId[location.bucketId]!;
    final item = fromList
        .removeAt(location.index)
        .copyWith(
          bucketId: MtgBuckets.trash.id,
          deletedAt: _now(),
          previousBucketId: location.bucketId,
        );

    _restoreIndexByItemId[itemId] = location.index;
    _itemsByBucketId[MtgBuckets.trash.id]!.add(item);
    _expandedByBucketId[MtgBuckets.trash.id] = true;
    _visibleByBucketId[MtgBuckets.trash.id] = true;
    notifyListeners();
  }

  void restoreItem(String itemId) {
    final location = _locateItem(itemId);
    if (location == null) return;
    if (location.bucketId != MtgBuckets.trash.id) return;

    final trashList = _itemsByBucketId[MtgBuckets.trash.id]!;
    final item = trashList.removeAt(location.index);
    final restoreBucketId = item.previousBucketId ?? MtgBuckets.upkeep.id;
    if (!_itemsByBucketId.containsKey(restoreBucketId)) return;

    final restoreList = _itemsByBucketId[restoreBucketId]!;
    final restoreIndex =
        _restoreIndexByItemId.remove(itemId) ?? restoreList.length;

    restoreList.insert(
      restoreIndex.clamp(0, restoreList.length),
      item.copyWith(
        bucketId: restoreBucketId,
        deletedAt: null,
        previousBucketId: null,
      ),
    );

    _expandedByBucketId[restoreBucketId] = true;
    _visibleByBucketId[restoreBucketId] = true;
    notifyListeners();
  }

  Future<void> reset() async {
    for (final bucket in MtgBuckets.ordered) {
      _itemsByBucketId[bucket.id]!.clear();
      _expandedByBucketId[bucket.id] = false;
      _visibleByBucketId[bucket.id] = true;
    }
    _restoreIndexByItemId.clear();
    notifyListeners();
    await _thumbnailCache?.purge();
  }

  _ItemLocation? _locateItem(String itemId) {
    for (final entry in _itemsByBucketId.entries) {
      final index = entry.value.indexWhere((item) => item.id == itemId);
      if (index != -1) return _ItemLocation(bucketId: entry.key, index: index);
    }
    return null;
  }
}

@immutable
class _ItemLocation {
  const _ItemLocation({required this.bucketId, required this.index});

  final String bucketId;
  final int index;
}
