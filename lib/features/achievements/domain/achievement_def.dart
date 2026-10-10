import 'package:flutter/material.dart';

enum AchievementCategory {
  milestones,
  lifts,
  volume,
  intensity,
  habits,
  ranks,
}

extension AchievementCategoryX on AchievementCategory {
  String get label => switch (this) {
        AchievementCategory.milestones => 'Вехи',
        AchievementCategory.lifts => 'Жимовые',
        AchievementCategory.volume => 'Объём',
        AchievementCategory.intensity => 'Интенсивность',
        AchievementCategory.habits => 'Привычки',
        AchievementCategory.ranks => 'Медали',
      };

  IconData get icon => switch (this) {
        AchievementCategory.milestones => Icons.flag_outlined,
        AchievementCategory.lifts => Icons.fitness_center,
        AchievementCategory.volume => Icons.monitor_weight_outlined,
        AchievementCategory.intensity => Icons.local_fire_department_outlined,
        AchievementCategory.habits => Icons.schedule,
        AchievementCategory.ranks => Icons.military_tech_outlined,
      };
}

/// Что меряем для прогресса уровней.
enum AchievementMetric {
  workoutCount,
  totalVolumeKg,
  totalDoneSets,
  sessionVolumeKg,
  sessionDurationSec,
  sessionExerciseCount,
  sessionXp,
  /// Лучший вес в упражнении (кг). Нужен [exerciseId].
  maxWeightKg,
  /// 1 если условие выполнено (привычки).
  flag,
  /// Индекс медали 0..7 (Новичок…Титан).
  medalIndex,
}

@immutable
class AchievementLevel {
  const AchievementLevel({
    required this.level,
    required this.threshold,
    required this.description,
  });

  final int level;
  final double threshold;
  final String description;
}

@immutable
class AchievementDef {
  const AchievementDef({
    required this.id,
    required this.title,
    required this.category,
    required this.icon,
    required this.metric,
    required this.levels,
    this.exerciseId,
    this.description,
  });

  final String id;
  final String title;
  final String? description;
  final AchievementCategory category;
  final IconData icon;
  final AchievementMetric metric;
  final List<AchievementLevel> levels;
  final String? exerciseId;

  int get maxLevel => levels.isEmpty ? 0 : levels.last.level;

  AchievementLevel? levelDef(int level) {
    for (final l in levels) {
      if (l.level == level) return l;
    }
    return null;
  }

  /// Наивысший уровень, чей порог уже достигнут.
  int levelForValue(double value) {
    var reached = 0;
    for (final l in levels) {
      if (value + 1e-9 >= l.threshold) {
        reached = l.level;
      }
    }
    return reached;
  }

  String starsLabel(int level) {
    if (levels.isEmpty) return '';
    return List.generate(maxLevel, (i) => i < level ? '★' : '☆').join();
  }

  String progressHint({required int currentLevel, required double value}) {
    if (currentLevel >= maxLevel) {
      return 'Максимум · ${levelDef(maxLevel)?.description ?? ''}';
    }
    final next = levels.firstWhere((l) => l.level == currentLevel + 1);
    return 'Ур.${next.level}: ${next.description}';
  }
}
