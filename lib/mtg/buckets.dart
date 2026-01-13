import 'package:flutter/foundation.dart';

@immutable
class MtgBucketDefinition {
  const MtgBucketDefinition({required this.id, required this.label});

  final String id;
  final String label;
}

class MtgBuckets {
  static const upkeep = MtgBucketDefinition(
    id: 'beginning.upkeep',
    label: 'Upkeep',
  );
  static const draw = MtgBucketDefinition(id: 'beginning.draw', label: 'Draw');
  static const precombatMain = MtgBucketDefinition(
    id: 'main.precombat',
    label: 'Precombat Main',
  );
  static const beginCombat = MtgBucketDefinition(
    id: 'combat.begin',
    label: 'Begin Combat',
  );
  static const declareAttackers = MtgBucketDefinition(
    id: 'combat.attackers',
    label: 'Declare Attackers',
  );
  static const declareBlockers = MtgBucketDefinition(
    id: 'combat.blockers',
    label: 'Declare Blockers',
  );
  static const combatDamage = MtgBucketDefinition(
    id: 'combat.damage',
    label: 'Combat Damage',
  );
  static const endCombat = MtgBucketDefinition(
    id: 'combat.end',
    label: 'End Combat',
  );
  static const postcombatMain = MtgBucketDefinition(
    id: 'main.postcombat',
    label: 'Postcombat Main',
  );
  static const endStep = MtgBucketDefinition(
    id: 'ending.endStep',
    label: 'End Step',
  );
  static const cleanup = MtgBucketDefinition(
    id: 'ending.cleanup',
    label: 'Cleanup',
  );
  static const responseWindow = MtgBucketDefinition(
    id: 'meta.responseWindow',
    label: 'Response Window',
  );
  static const staticEffects = MtgBucketDefinition(
    id: 'meta.static',
    label: 'Static',
  );
  static const trash = MtgBucketDefinition(id: 'meta.trash', label: 'Trash');

  static const ordered = <MtgBucketDefinition>[
    upkeep,
    draw,
    precombatMain,
    beginCombat,
    declareAttackers,
    declareBlockers,
    combatDamage,
    endCombat,
    postcombatMain,
    endStep,
    cleanup,
    responseWindow,
    staticEffects,
    trash,
  ];
}
