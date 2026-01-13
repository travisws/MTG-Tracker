import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_list/mtg/buckets.dart';

void main() {
  test('Bucket IDs and ordering match docs', () {
    expect(MtgBuckets.ordered.map((bucket) => bucket.id).toList(), const [
      'beginning.upkeep',
      'beginning.draw',
      'main.precombat',
      'combat.begin',
      'combat.attackers',
      'combat.blockers',
      'combat.damage',
      'combat.end',
      'main.postcombat',
      'ending.endStep',
      'ending.cleanup',
      'meta.responseWindow',
      'meta.static',
      'meta.trash',
    ]);
  });
}
