import 'package:flutter/material.dart';

import '../../rank/domain/xp_rules.dart';
import 'achievement_catalog.dart';
import 'achievement_def.dart';
import 'user_achievement.dart';

abstract final class AchievementEvaluator {
  static const _medalOrder = [
    'novice',
    'intern',
    'athlete',
    'gladiator',
    'champion',
    'master',
    'colossus',
    'titan',
  ];

  /// Возвращает апдейты: новый level / value. [levelUps] — только повышения.
  static AchievementEvaluation evaluate(
    AchievementEvalContext ctx, {
    required Map<String, UserAchievement> existing,
  }) {
    final updates = <UserAchievement>[];
    final levelUps = <AchievementLevelUp>[];
    final now = DateTime.now();
    final sessionWeights = ctx.sessionMaxWeights;
    final medalIndex =
        _medalOrder.indexOf(XpRules.medalForId(ctx.rankId).medalKey);

    for (final def in AchievementCatalog.all) {
      final prev = existing[def.id];
      final prevLevel = prev?.level ?? 0;
      final prevValue = prev?.value ?? 0;

      final raw = _metricValue(def, ctx, sessionWeights, medalIndex);
      if (raw == null) continue;

      // Для maxWeight / session* берём max(prev, raw); для счётчиков — raw как абсолют.
      final value = switch (def.metric) {
        AchievementMetric.maxWeightKg ||
        AchievementMetric.sessionVolumeKg ||
        AchievementMetric.sessionDurationSec ||
        AchievementMetric.sessionExerciseCount ||
        AchievementMetric.sessionXp ||
        AchievementMetric.flag =>
          raw > prevValue ? raw : prevValue,
        _ => raw,
      };

      final newLevel = def.levelForValue(value);
      final level = newLevel > prevLevel ? newLevel : prevLevel;
      final valueImproved = value > prevValue + 1e-9;
      final leveledUp = newLevel > prevLevel && newLevel > 0;
      if (!leveledUp && !valueImproved && prev != null) continue;

      final unlockedAt =
          prev?.unlockedAt ?? (level > 0 ? now : null);
      updates.add(
        UserAchievement(
          id: def.id,
          level: level,
          value: value,
          updatedAt: now,
          unlockedAt: unlockedAt,
        ),
      );

      if (leveledUp) {
        // Если прыгнули через несколько уровней — показываем каждый.
        for (var lv = prevLevel + 1; lv <= newLevel; lv++) {
          final levelDef = def.levelDef(lv);
          levelUps.add(
            AchievementLevelUp(
              achievementId: def.id,
              title: def.title,
              level: lv,
              levelDescription: levelDef?.description ?? 'Уровень $lv',
              maxLevel: def.maxLevel,
              icon: def.icon,
            ),
          );
        }
      }
    }

    return AchievementEvaluation(updates: updates, levelUps: levelUps);
  }

  static double? _metricValue(
    AchievementDef def,
    AchievementEvalContext ctx,
    Map<String, double> sessionWeights,
    int medalIndex,
  ) {
    return switch (def.metric) {
      AchievementMetric.workoutCount => ctx.workoutCount.toDouble(),
      AchievementMetric.totalVolumeKg => ctx.totalVolumeKg,
      AchievementMetric.totalDoneSets => ctx.totalDoneSets.toDouble(),
      AchievementMetric.sessionVolumeKg => ctx.sessionVolumeKg,
      AchievementMetric.sessionDurationSec =>
        ctx.sessionDurationSec.toDouble(),
      AchievementMetric.sessionExerciseCount =>
        ctx.sessionExerciseCount.toDouble(),
      AchievementMetric.sessionXp => ctx.sessionXp.toDouble(),
      AchievementMetric.maxWeightKg => () {
          final key = def.exerciseId;
          if (key == null) return null;
          return sessionWeights[key];
        }(),
      AchievementMetric.flag => () {
          final hour = ctx.finishedAt.hour;
          return switch (def.id) {
            'early_bird' => hour < 8 ? 1.0 : null,
            'night_owl' => hour >= 22 ? 1.0 : null,
            'template_start' => ctx.fromTemplate ? 1.0 : null,
            _ => null,
          };
        }(),
      AchievementMetric.medalIndex =>
        medalIndex >= 0 ? medalIndex.toDouble() : null,
    };
  }
}

@immutable
class AchievementEvaluation {
  const AchievementEvaluation({
    required this.updates,
    required this.levelUps,
  });

  final List<UserAchievement> updates;
  final List<AchievementLevelUp> levelUps;
}
