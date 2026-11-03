/// Rules for the Momentum medals, kept free of Flutter imports so they can be
/// unit tested with plain `dart test`. Display data (names, icons, colours)
/// lives in `achievement_definition.dart` under the same ids.
library;

import 'package:zerotrust_fitness/features/health/domain/momentum_engine.dart';

class MomentumMedals {
  const MomentumMedals._();

  static const onTarget = 'on_target';
  static const hatTrick = 'target_streak_3';
  static const lockedIn = 'target_streak_7';
  static const comeback = 'comeback';
  static const raisingTheBar = 'target_40';
  static const steady = 'momentum_50';
  static const unstoppable = 'momentum_75';
  static const perpetualMotion = 'momentum_week_75';

  static const all = <String>[
    onTarget,
    hatTrick,
    lockedIn,
    comeback,
    raisingTheBar,
    steady,
    unstoppable,
    perpetualMotion,
  ];

  static const int comebackGapDays = 3;
  static const int raisedTarget = 40;
  static const int perpetualDays = 7;

  /// Medal ids earned anywhere in [days] (oldest first, as returned by
  /// [MomentumEngine.timeline]).
  static Set<String> earned(List<MomentumDay> days) {
    final earned = <String>{};
    var hitStreak = 0;
    var missStreak = 0;
    var highMomentumStreak = 0;

    for (final day in days) {
      // A hit today is final (points only go up), so today counts for hits.
      if (day.targetHit) {
        earned.add(onTarget);
        if (missStreak >= comebackGapDays) earned.add(comeback);
        hitStreak++;
        missStreak = 0;
      } else if (day.isComplete) {
        hitStreak = 0;
        missStreak++;
      }
      if (hitStreak >= 3) earned.add(hatTrick);
      if (hitStreak >= 7) earned.add(lockedIn);

      if (day.target >= raisedTarget) earned.add(raisingTheBar);
      if (day.momentum >= 50) earned.add(steady);
      if (day.momentum >= 75) earned.add(unstoppable);

      // Holding Momentum only counts for finished days; today's live value
      // could still be propped up by yesterday.
      if (day.isComplete) {
        highMomentumStreak = day.momentum >= 75 ? highMomentumStreak + 1 : 0;
        if (highMomentumStreak >= perpetualDays) earned.add(perpetualMotion);
      }
    }
    return earned;
  }
}
