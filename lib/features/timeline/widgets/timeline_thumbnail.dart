import 'dart:io';

import 'package:flutter/material.dart';

import '../../../models/timeline_item.dart';

String timelineItemHeroTag(String itemId) => 'timeline-thumb-$itemId';

class TimelineThumbnail extends StatelessWidget {
  const TimelineThumbnail({
    required this.item,
    required this.size,
    this.heroTag,
    super.key,
  });

  final TimelineItem item;
  final double size;
  final String? heroTag;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final thumbnail = ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: size,
        height: size,
        child: _buildImage(context, theme),
      ),
    );

    if (heroTag == null) {
      return thumbnail;
    }

    return Hero(tag: heroTag!, child: thumbnail);
  }

  Widget _buildImage(BuildContext context, ThemeData theme) {
    final placeholder = Container(
      color: theme.colorScheme.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_outlined,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );

    final path = item.thumbnailPath;
    if (path == null || path.isEmpty) {
      return placeholder;
    }

    final pixelRatio = MediaQuery.of(context).devicePixelRatio;
    final cacheSize = (size * pixelRatio).round();
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      cacheWidth: cacheSize,
      cacheHeight: cacheSize,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}
