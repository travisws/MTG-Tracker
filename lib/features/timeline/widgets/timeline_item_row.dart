import 'dart:io';

import 'package:flutter/material.dart';

import '../../../models/timeline_item.dart';

class TimelineItemRow extends StatelessWidget {
  const TimelineItemRow({
    required this.item,
    this.onTap,
    this.onLongPress,
    this.trailingActions = const [],
    super.key,
  });

  final TimelineItem item;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final List<Widget> trailingActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = item.label.trim().isEmpty ? 'Untitled card' : item.label;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 56,
                  height: 56,
                  child: _buildThumbnail(context, theme),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (trailingActions.isNotEmpty) const SizedBox(width: 8),
              ...trailingActions,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThumbnail(BuildContext context, ThemeData theme) {
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
    final cacheSize = (56 * pixelRatio).round();
    return Image.file(
      File(path),
      fit: BoxFit.cover,
      cacheWidth: cacheSize,
      cacheHeight: cacheSize,
      errorBuilder: (context, error, stackTrace) => placeholder,
    );
  }
}
