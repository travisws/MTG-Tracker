import 'package:flutter/material.dart';

import '../../../mtg/buckets.dart';
import '../../../session/session_scope.dart';

class VisibleStepsSheet extends StatelessWidget {
  const VisibleStepsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final store = SessionScope.of(context);
    final totalBuckets = MtgBuckets.ordered.length;
    final visibleCount = MtgBuckets.ordered
        .where((bucket) => store.isBucketVisible(bucket.id))
        .length;
    final hiddenCount = totalBuckets - visibleCount;

    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(
            title: const Text('Visible steps'),
            trailing: visibleCount == totalBuckets
                ? TextButton(
                    onPressed: store.hideAllBuckets,
                    child: const Text('Hide all'),
                  )
                : hiddenCount >= 3
                ? TextButton(
                    onPressed: store.showAllBuckets,
                    child: const Text('Show all'),
                  )
                : null,
          ),
          for (final bucket in MtgBuckets.ordered)
            SwitchListTile(
              title: Text(bucket.label),
              value: store.isBucketVisible(bucket.id),
              onChanged: (value) => store.setBucketVisible(bucket.id, value),
            ),
        ],
      ),
    );
  }
}
