import 'package:flutter/material.dart';

import '../../../models/timeline_item.dart';
import 'timeline_thumbnail.dart';

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
              TimelineThumbnail(
                item: item,
                size: 56,
                heroTag: timelineItemHeroTag(item.id),
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

}
