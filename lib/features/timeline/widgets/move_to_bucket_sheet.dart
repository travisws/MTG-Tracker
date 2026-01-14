import 'package:flutter/material.dart';

import '../../../mtg/buckets.dart';

class MoveToBucketSheet extends StatelessWidget {
  const MoveToBucketSheet({required this.currentBucketId, super.key});

  final String currentBucketId;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final bucket in MtgBuckets.ordered)
            if (bucket.id != MtgBuckets.trash.id)
              ListTile(
                title: Text(bucket.label),
                trailing: bucket.id == currentBucketId
                    ? const Icon(Icons.check)
                    : null,
                enabled: bucket.id != currentBucketId,
                onTap: bucket.id == currentBucketId
                    ? null
                    : () => Navigator.of(context).pop(bucket.id),
              ),
        ],
      ),
    );
  }
}
