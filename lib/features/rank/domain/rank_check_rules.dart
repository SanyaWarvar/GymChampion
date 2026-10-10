import 'package:flutter/foundation.dart';

import 'xp_rules.dart';

@immutable
class RankCheckNorm {
  const RankCheckNorm({
    required this.minWorkouts,
    required this.minVolumeKg,
    required this.xpBonus,
  });

  final int minWorkouts;
  final double minVolumeKg;
  final int xpBonus;
}

/// Нормативы Rank Check по текущей медали (за последние 14 дней).
abstract final class RankCheckRules {
  static const periodDays = 14;

  static RankCheckNorm normForRank(String rankId) {
    final medal = XpRules.medalForId(rankId).medalKey;
    return switch (medal) {
      'novice' || 'intern' => const RankCheckNorm(
          minWorkouts: 2,
          minVolumeKg: 2000,
          xpBonus: 40,
        ),
      'athlete' || 'gladiator' => const RankCheckNorm(
          minWorkouts: 3,
          minVolumeKg: 5000,
          xpBonus: 60,
        ),
      'champion' || 'master' => const RankCheckNorm(
          minWorkouts: 4,
          minVolumeKg: 9000,
          xpBonus: 80,
        ),
      _ => const RankCheckNorm(
          minWorkouts: 5,
          minVolumeKg: 14000,
          xpBonus: 100,
        ),
    };
  }

  static bool canAttempt({DateTime? lastCheckAt, DateTime? now}) {
    final n = now ?? DateTime.now();
    if (lastCheckAt == null) return true;
    return n.difference(lastCheckAt).inDays >= periodDays;
  }

  static int daysUntilNext(DateTime lastCheckAt, [DateTime? now]) {
    final n = now ?? DateTime.now();
    final left = periodDays - n.difference(lastCheckAt).inDays;
    return left.clamp(0, periodDays);
  }
}

@immutable
class RankCheckResult {
  const RankCheckResult({
    required this.passed,
    required this.workouts,
    required this.volumeKg,
    required this.norm,
    required this.xpBonus,
    required this.checkedAt,
  });

  final bool passed;
  final int workouts;
  final double volumeKg;
  final RankCheckNorm norm;
  final int xpBonus;
  final DateTime checkedAt;
}
