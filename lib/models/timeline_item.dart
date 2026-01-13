import 'package:flutter/foundation.dart';

@immutable
class TimelineItem {
  const TimelineItem({
    required this.id,
    required this.bucketId,
    required this.label,
    required this.ocrText,
    this.thumbnailPath,
    this.note,
    this.deletedAt,
    this.previousBucketId,
  });

  final String id;
  final String bucketId;
  final String label;
  final String ocrText;
  final String? thumbnailPath;
  final String? note;
  final DateTime? deletedAt;
  final String? previousBucketId;

  bool get isTrashed => deletedAt != null;

  static const Object _unset = Object();

  TimelineItem copyWith({
    String? id,
    String? bucketId,
    String? label,
    String? ocrText,
    Object? thumbnailPath = _unset,
    Object? note = _unset,
    Object? deletedAt = _unset,
    Object? previousBucketId = _unset,
  }) {
    return TimelineItem(
      id: id ?? this.id,
      bucketId: bucketId ?? this.bucketId,
      label: label ?? this.label,
      ocrText: ocrText ?? this.ocrText,
      thumbnailPath: identical(thumbnailPath, _unset)
          ? this.thumbnailPath
          : thumbnailPath as String?,
      note: identical(note, _unset) ? this.note : note as String?,
      deletedAt: identical(deletedAt, _unset)
          ? this.deletedAt
          : deletedAt as DateTime?,
      previousBucketId: identical(previousBucketId, _unset)
          ? this.previousBucketId
          : previousBucketId as String?,
    );
  }
}
