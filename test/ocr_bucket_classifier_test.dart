import 'package:flutter_test/flutter_test.dart';
import 'package:mtg_list/mtg/buckets.dart';
import 'package:mtg_list/mtg/ocr_bucket_classifier.dart';

void main() {
  test('returns null for empty text', () {
    expect(OcrBucketClassifier.suggestBucketId(''), isNull);
    expect(OcrBucketClassifier.suggestBucketId('  '), isNull);
  });

  test('suggests buckets from common rules text patterns', () {
    expect(
      OcrBucketClassifier.suggestBucketId(
        'At the beginning of your upkeep, scry 1.',
      ),
      MtgBuckets.upkeep.id,
    );
    expect(
      OcrBucketClassifier.suggestBucketId(
        'At the beginning of your draw step, draw an additional card.',
      ),
      MtgBuckets.draw.id,
    );
    expect(
      OcrBucketClassifier.suggestBucketId(
        'At the beginning of combat on your turn, create a 1/1 token.',
      ),
      MtgBuckets.beginCombat.id,
    );
    expect(
      OcrBucketClassifier.suggestBucketId(
        'Whenever this creature attacks, ...',
      ),
      MtgBuckets.declareAttackers.id,
    );
    expect(
      OcrBucketClassifier.suggestBucketId('Whenever it blocks, ...'),
      MtgBuckets.declareBlockers.id,
    );
    expect(
      OcrBucketClassifier.suggestBucketId('It becomes blocked by two or more.'),
      MtgBuckets.declareBlockers.id,
    );
    expect(
      OcrBucketClassifier.suggestBucketId('Whenever it deals combat damage...'),
      MtgBuckets.combatDamage.id,
    );
    expect(
      OcrBucketClassifier.suggestBucketId('At end of combat, draw a card.'),
      MtgBuckets.endCombat.id,
    );
    expect(
      OcrBucketClassifier.suggestBucketId(
        'At the beginning of the end step, return it.',
      ),
      MtgBuckets.endStep.id,
    );
    expect(
      OcrBucketClassifier.suggestBucketId('At end of turn, discard a card.'),
      MtgBuckets.endStep.id,
    );
    expect(
      OcrBucketClassifier.suggestBucketId(
        'Target creature gets +2/+0 until end of turn.',
      ),
      MtgBuckets.cleanup.id,
    );
    expect(
      OcrBucketClassifier.suggestBucketId(
        'Exile it. It gains haste this turn.',
      ),
      MtgBuckets.cleanup.id,
    );
    expect(
      OcrBucketClassifier.suggestBucketId('Flash'),
      MtgBuckets.responseWindow.id,
    );
    expect(
      OcrBucketClassifier.suggestBucketId(
        'You may cast this any time you could cast an instant.',
      ),
      MtgBuckets.responseWindow.id,
    );
  });
}
