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
          visibleBucketIds?.contains(bucket.id) ??
          MtgBuckets.defaultVisibleBucketIds.contains(bucket.id);
    }

    for (final item in initialItems) {
      final bucketId = _itemsByBucketId.containsKey(item.bucketId)
          ? item.bucketId
          : MtgBuckets.staticEffects.id;
      _itemsByBucketId[bucketId]!.add(item.copyWith(bucketId: bucketId));
      _bucketIdByItemId[item.id] = bucketId;
    }

    for (final bucket in MtgBuckets.ordered) {
      if ((_itemsByBucketId[bucket.id]?.isNotEmpty ?? false)) {
        _visibleByBucketId[bucket.id] = true;
      }
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
  String? _activeDeckId;

  final Map<String, int> _restoreIndexByItemId = {};
  // Cache: itemId -> bucketId for O(1) bucket lookup
  final Map<String, String> _bucketIdByItemId = {};

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

  String? get activeDeckId => _activeDeckId;

  void setActiveDeck(String? deckId) {
    if (_activeDeckId == deckId) return;
    _activeDeckId = deckId;
    notifyListeners();
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

  void hideAllBuckets() {
    for (final bucket in MtgBuckets.ordered) {
      _visibleByBucketId[bucket.id] = false;
    }
    notifyListeners();
  }

  void addItem(TimelineItem item) {
    final bucketId = _itemsByBucketId.containsKey(item.bucketId)
        ? item.bucketId
        : MtgBuckets.staticEffects.id;
    _itemsByBucketId[bucketId]!.add(item.copyWith(bucketId: bucketId));
    _bucketIdByItemId[item.id] = bucketId;
    _expandedByBucketId[bucketId] = true;
    _visibleByBucketId[bucketId] = true;
    notifyListeners();
  }

  void updateItemDetails(String itemId, {required String label, String? note}) {
    final location = _locateItem(itemId);
    if (location == null) return;
    final list = _itemsByBucketId[location.bucketId]!;
    final item = list[location.index];
    list[location.index] = item.copyWith(label: label, note: note);
    notifyListeners();
  }

  Future<String?> cacheThumbnailBytes(List<int>? bytes) async {
    if (bytes == null || bytes.isEmpty) return null;
    if (_thumbnailCache == null) return null;
    final data = Uint8List.fromList(bytes);
    return _thumbnailCache.writeBytes(data);
  }

  Future<String?> cacheThumbnailFromFile(String? path) async {
    if (path == null || path.isEmpty) return null;
    if (_thumbnailCache == null) return null;
    return _thumbnailCache.copyFromFile(path);
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

    _bucketIdByItemId[itemId] = toBucketId;
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
    _bucketIdByItemId[itemId] = MtgBuckets.trash.id;
    _itemsByBucketId[MtgBuckets.trash.id]!.add(item);
    _expandedByBucketId[MtgBuckets.trash.id] = true;
    _visibleByBucketId[MtgBuckets.trash.id] = true;

    // Prune stale restore indices if map is getting large
    if (_restoreIndexByItemId.length > 50) {
      _pruneStaleRestoreIndices();
    }

    notifyListeners();
  }

  void _pruneStaleRestoreIndices() {
    final trashItems = _itemsByBucketId[MtgBuckets.trash.id] ?? const [];
    final trashItemIds = {for (final item in trashItems) item.id};
    _restoreIndexByItemId.removeWhere((id, _) => !trashItemIds.contains(id));
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

    _bucketIdByItemId[itemId] = restoreBucketId;
    _expandedByBucketId[restoreBucketId] = true;
    _visibleByBucketId[restoreBucketId] = true;
    notifyListeners();
  }

  Future<void> reset() async {
    for (final bucket in MtgBuckets.ordered) {
      _itemsByBucketId[bucket.id]!.clear();
      _expandedByBucketId[bucket.id] = false;
      _visibleByBucketId[bucket.id] = MtgBuckets.defaultVisibleBucketIds
          .contains(bucket.id);
    }
    _bucketIdByItemId.clear();
    _restoreIndexByItemId.clear();
    _activeDeckId = null;
    notifyListeners();
    await _thumbnailCache?.purge();
  }

  _ItemLocation? _locateItem(String itemId) {
    // O(1) bucket lookup from cache
    final bucketId = _bucketIdByItemId[itemId];
    if (bucketId == null) return null;

    final items = _itemsByBucketId[bucketId];
    if (items == null) return null;

    // O(b) search within bucket (b is typically small)
    final index = items.indexWhere((item) => item.id == itemId);
    if (index == -1) return null;

    return _ItemLocation(bucketId: bucketId, index: index);
  }
}

@immutable
class _ItemLocation {
  const _ItemLocation({required this.bucketId, required this.index});

  final String bucketId;
  final int index;
}
