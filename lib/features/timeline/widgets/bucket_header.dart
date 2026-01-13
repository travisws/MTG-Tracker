import 'dart:ui';

import 'package:flutter/material.dart';

class BucketHeader extends StatelessWidget {
  const BucketHeader({
    required this.bucketId,
    required this.label,
    required this.count,
    required this.isExpanded,
    required this.onToggleExpanded,
    this.onLongPress,
    super.key,
  });

  final String bucketId;
  final String label;
  final int count;
  final bool isExpanded;
  final VoidCallback onToggleExpanded;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: theme.colorScheme.surface,
      child: InkWell(
        onLongPress: onLongPress,
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (count > 0) _CountBadge(count: count),
              IconButton(
                key: Key('bucket-toggle-$bucketId'),
                tooltip: isExpanded ? 'Collapse $label' : 'Expand $label',
                onPressed: onToggleExpanded,
                icon: AnimatedRotation(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  turns: isExpanded ? 0.5 : 0,
                  child: const Icon(Icons.expand_more),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CountBadge extends StatelessWidget {
  const _CountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        style: theme.textTheme.labelMedium?.copyWith(
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}
