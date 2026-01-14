import 'buckets.dart';

class OcrBucketClassifier {
  static final List<_OcrRule> _rules = [
    _OcrRule(
      RegExp(r'\bat the beginning of (your|each|the) upkeep\b'),
      MtgBuckets.upkeep.id,
    ),
    _OcrRule(
      RegExp(r'\bat the beginning of (your|each|the) draw step\b'),
      MtgBuckets.draw.id,
    ),
    _OcrRule(
      RegExp(r'\bat the beginning of (the )?combat\b'),
      MtgBuckets.beginCombat.id,
    ),
    _OcrRule(
      RegExp(r'\b(whenever|when)\b.*\battacks\b'),
      MtgBuckets.declareAttackers.id,
    ),
    _OcrRule(
      RegExp(r'\b(whenever|when)\b.*\bblocks\b'),
      MtgBuckets.declareBlockers.id,
    ),
    _OcrRule(RegExp(r'\bbecomes blocked\b'), MtgBuckets.declareBlockers.id),
    _OcrRule(RegExp(r'\bdeals combat damage\b'), MtgBuckets.combatDamage.id),
    _OcrRule(RegExp(r'\bat end of combat\b'), MtgBuckets.endCombat.id),
    _OcrRule(
      RegExp(r'\bat the beginning of the end step\b'),
      MtgBuckets.endStep.id,
    ),
    _OcrRule(RegExp(r'\bat end of turn\b'), MtgBuckets.endStep.id),
    _OcrRule(RegExp(r'\buntil end of turn\b'), MtgBuckets.cleanup.id),
    _OcrRule(
      RegExp(r'\bany time you could cast an instant\b'),
      MtgBuckets.responseWindow.id,
    ),
    _OcrRule(RegExp(r'\bflash\b'), MtgBuckets.responseWindow.id),
    _OcrRule(RegExp(r'\bthis turn\b'), MtgBuckets.cleanup.id),
  ];

  static String? suggestBucketId(String text) {
    final normalized = _normalize(text);
    if (normalized.isEmpty) return null;
    if (normalized.length < 8) return null;
    for (final rule in _rules) {
      if (rule.pattern.hasMatch(normalized)) return rule.bucketId;
    }
    return null;
  }

  static String _normalize(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }
}

class _OcrRule {
  const _OcrRule(this.pattern, this.bucketId);

  final RegExp pattern;
  final String bucketId;
}
