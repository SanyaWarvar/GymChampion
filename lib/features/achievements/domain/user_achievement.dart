import 'package:flutter/material.dart';

import '../../workout/domain/workout_models.dart';

@immutable
class UserAchievement {
  const UserAchievement({
    required this.id,
    required this.level,
    required this.value,
    required this.updatedAt,
    this.unlockedAt,
  });

  final String id;
  /// Текущий достигнутый уровень (0 = ещё не открыто).
  final int level;
  /// Лучшее/текущее значение метрики (вес, объём, счётчик…).
  final double value;
  final DateTime updatedAt;
  final DateTime? unlockedAt;

  bool get isUnlocked => level > 0;

  Map<String, dynamic> toMap() => {
        'level': level,
        'value': value,
        'updatedAt': updatedAt.toIso8601String(),
        if (unlockedAt != null) 'unlockedAt': unlockedAt!.toIso8601String(),
        'progress': level,
      };

  factory UserAchievement.fromMap(String id, Map<String, dynamic> data) {
    final hasLegacyUnlock =
        data.containsKey('unlockedAt') && !data.containsKey('level');
    final level = (data['level'] as num?)?.toInt() ??
        ((data['progress'] as num?)?.toInt() ?? 0);
    // Старые одноразовые ачивки без level считаем уровнем 1.
    final migratedLevel = level == 0 && hasLegacyUnlock ? 1 : level;
    return UserAchievement(
      id: id,
      level: migratedLevel,
      value: (data['value'] as num?)?.toDouble() ??
          (migratedLevel > 0 ? 1 : 0),
      updatedAt: DateTime.tryParse(data['updatedAt'] as String? ?? '') ??
          DateTime.tryParse(data['unlockedAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      unlockedAt: DateTime.tryParse(data['unlockedAt'] as String? ?? ''),
    );
  }
}

/// Событие повышения уровня — для тоста/summary.
@immutable
class AchievementLevelUp {
  const AchievementLevelUp({
    required this.achievementId,
    required this.title,
    required this.level,
    required this.levelDescription,
    required this.maxLevel,
    required this.icon,
  });

  final String achievementId;
  final String title;
  final int level;
  final String levelDescription;
  final int maxLevel;
  final IconData icon;

  String get headline => '$title · Ур.$level';

  String get stars =>
      List.generate(maxLevel, (i) => i < level ? '★' : '☆').join();
}

/// Контекст для проверки достижений после сохранения тренировки.
@immutable
class AchievementEvalContext {
  const AchievementEvalContext({
    required this.workoutCount,
    required this.totalVolumeKg,
    required this.totalDoneSets,
    required this.sessionVolumeKg,
    required this.sessionDoneSets,
    required this.sessionDurationSec,
    required this.sessionExerciseCount,
    required this.finishedAt,
    required this.rankId,
    required this.fromTemplate,
    this.sessionXp = 0,
    this.sessionExercises = const [],
  });

  final int workoutCount;
  final double totalVolumeKg;
  final int totalDoneSets;
  final double sessionVolumeKg;
  final int sessionDoneSets;
  final int sessionDurationSec;
  final int sessionExerciseCount;
  final int sessionXp;
  final DateTime finishedAt;
  final String rankId;
  final bool fromTemplate;
  final List<WorkoutExercise> sessionExercises;

  /// Макс. вес по exerciseId / имени из этой сессии.
  Map<String, double> get sessionMaxWeights {
    final out = <String, double>{};
    for (final ex in sessionExercises) {
      final key = ex.exerciseId ?? ex.name.toLowerCase();
      for (final set in ex.sets) {
        if (!set.done || set.reps <= 0) continue;
        final prev = out[key] ?? 0;
        if (set.weightKg > prev) out[key] = set.weightKg;
      }
    }
    return out;
  }
}
