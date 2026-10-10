import 'package:flutter/material.dart';

import 'achievement_def.dart';

/// Каталог уровневых достижений. Один id = цепочка уровней/звёзд.
abstract final class AchievementCatalog {
  static const all = <AchievementDef>[
    // ——— Вехи ———
    AchievementDef(
      id: 'workouts',
      title: 'Регулярность',
      description: 'Число завершённых тренировок',
      category: AchievementCategory.milestones,
      icon: Icons.event_available_outlined,
      metric: AchievementMetric.workoutCount,
      levels: [
        AchievementLevel(level: 1, threshold: 1, description: '1 тренировка'),
        AchievementLevel(level: 2, threshold: 5, description: '5 тренировок'),
        AchievementLevel(level: 3, threshold: 10, description: '10 тренировок'),
        AchievementLevel(level: 4, threshold: 25, description: '25 тренировок'),
        AchievementLevel(level: 5, threshold: 50, description: '50 тренировок'),
        AchievementLevel(level: 6, threshold: 100, description: '100 тренировок'),
      ],
    ),

    // ——— Жимовые / упражнения ———
    AchievementDef(
      id: 'bench_press_master',
      title: 'Мастер жима',
      description: 'Лучший вес в жиме лёжа',
      category: AchievementCategory.lifts,
      icon: Icons.fitness_center,
      metric: AchievementMetric.maxWeightKg,
      exerciseId: 'bench_press',
      levels: [
        AchievementLevel(level: 1, threshold: 40, description: 'Пожать 40 кг'),
        AchievementLevel(level: 2, threshold: 60, description: 'Пожать 60 кг'),
        AchievementLevel(level: 3, threshold: 80, description: 'Пожать 80 кг'),
        AchievementLevel(level: 4, threshold: 100, description: 'Пожать 100 кг'),
        AchievementLevel(level: 5, threshold: 120, description: 'Пожать 120 кг'),
      ],
    ),
    AchievementDef(
      id: 'squat_master',
      title: 'Мастер приседа',
      description: 'Лучший вес в приседе',
      category: AchievementCategory.lifts,
      icon: Icons.accessibility_new,
      metric: AchievementMetric.maxWeightKg,
      exerciseId: 'squat',
      levels: [
        AchievementLevel(level: 1, threshold: 60, description: 'Присесть 60 кг'),
        AchievementLevel(level: 2, threshold: 80, description: 'Присесть 80 кг'),
        AchievementLevel(level: 3, threshold: 100, description: 'Присесть 100 кг'),
        AchievementLevel(level: 4, threshold: 120, description: 'Присесть 120 кг'),
        AchievementLevel(level: 5, threshold: 140, description: 'Присесть 140 кг'),
      ],
    ),
    AchievementDef(
      id: 'deadlift_master',
      title: 'Мастер тяги',
      description: 'Лучший вес в становой',
      category: AchievementCategory.lifts,
      icon: Icons.airline_seat_flat_angled,
      metric: AchievementMetric.maxWeightKg,
      exerciseId: 'deadlift',
      levels: [
        AchievementLevel(level: 1, threshold: 80, description: 'Тяга 80 кг'),
        AchievementLevel(level: 2, threshold: 100, description: 'Тяга 100 кг'),
        AchievementLevel(level: 3, threshold: 120, description: 'Тяга 120 кг'),
        AchievementLevel(level: 4, threshold: 140, description: 'Тяга 140 кг'),
        AchievementLevel(level: 5, threshold: 160, description: 'Тяга 160 кг'),
      ],
    ),
    AchievementDef(
      id: 'ohp_master',
      title: 'Мастер жима стоя',
      description: 'Лучший вес в жиме стоя',
      category: AchievementCategory.lifts,
      icon: Icons.vertical_align_top,
      metric: AchievementMetric.maxWeightKg,
      exerciseId: 'ohp',
      levels: [
        AchievementLevel(level: 1, threshold: 30, description: 'Жим стоя 30 кг'),
        AchievementLevel(level: 2, threshold: 40, description: 'Жим стоя 40 кг'),
        AchievementLevel(level: 3, threshold: 50, description: 'Жим стоя 50 кг'),
        AchievementLevel(level: 4, threshold: 60, description: 'Жим стоя 60 кг'),
        AchievementLevel(level: 5, threshold: 70, description: 'Жим стоя 70 кг'),
      ],
    ),

    // ——— Объём ———
    AchievementDef(
      id: 'volume',
      title: 'Тоннаж',
      description: 'Суммарный объём за всё время',
      category: AchievementCategory.volume,
      icon: Icons.monitor_weight_outlined,
      metric: AchievementMetric.totalVolumeKg,
      levels: [
        AchievementLevel(level: 1, threshold: 10000, description: '10 000 кг'),
        AchievementLevel(level: 2, threshold: 50000, description: '50 000 кг'),
        AchievementLevel(level: 3, threshold: 100000, description: '100 000 кг'),
        AchievementLevel(level: 4, threshold: 250000, description: '250 000 кг'),
        AchievementLevel(level: 5, threshold: 500000, description: '500 000 кг'),
      ],
    ),
    AchievementDef(
      id: 'session_volume',
      title: 'Тяжёлая сессия',
      description: 'Объём одной тренировки',
      category: AchievementCategory.volume,
      icon: Icons.local_fire_department_outlined,
      metric: AchievementMetric.sessionVolumeKg,
      levels: [
        AchievementLevel(level: 1, threshold: 3000, description: '3 000 кг за сессию'),
        AchievementLevel(level: 2, threshold: 5000, description: '5 000 кг за сессию'),
        AchievementLevel(level: 3, threshold: 8000, description: '8 000 кг за сессию'),
        AchievementLevel(level: 4, threshold: 12000, description: '12 000 кг за сессию'),
      ],
    ),
    AchievementDef(
      id: 'session_xp',
      title: 'Жирная тренировка',
      description: 'Максимум XP за одну тренировку',
      category: AchievementCategory.intensity,
      icon: Icons.bolt_outlined,
      metric: AchievementMetric.sessionXp,
      levels: [
        AchievementLevel(level: 1, threshold: 150, description: '150 XP за сессию'),
        AchievementLevel(level: 2, threshold: 250, description: '250 XP за сессию'),
        AchievementLevel(level: 3, threshold: 350, description: '350 XP за сессию'),
        AchievementLevel(level: 4, threshold: 500, description: '500 XP за сессию'),
        AchievementLevel(level: 5, threshold: 700, description: '700 XP за сессию'),
      ],
    ),

    // ——— Интенсивность ———
    AchievementDef(
      id: 'sets',
      title: 'Фабрика подходов',
      description: 'Суммарные завершённые подходы',
      category: AchievementCategory.intensity,
      icon: Icons.repeat,
      metric: AchievementMetric.totalDoneSets,
      levels: [
        AchievementLevel(level: 1, threshold: 50, description: '50 подходов'),
        AchievementLevel(level: 2, threshold: 100, description: '100 подходов'),
        AchievementLevel(level: 3, threshold: 250, description: '250 подходов'),
        AchievementLevel(level: 4, threshold: 500, description: '500 подходов'),
        AchievementLevel(level: 5, threshold: 1000, description: '1000 подходов'),
      ],
    ),
    AchievementDef(
      id: 'long_session',
      title: 'Марафонец зала',
      description: 'Длительность одной тренировки',
      category: AchievementCategory.intensity,
      icon: Icons.timer_outlined,
      metric: AchievementMetric.sessionDurationSec,
      levels: [
        AchievementLevel(level: 1, threshold: 45 * 60, description: '45 минут'),
        AchievementLevel(level: 2, threshold: 60 * 60, description: '60 минут'),
        AchievementLevel(level: 3, threshold: 90 * 60, description: '90 минут'),
      ],
    ),
    AchievementDef(
      id: 'variety',
      title: 'Разнообразие',
      description: 'Упражнений в одной тренировке',
      category: AchievementCategory.intensity,
      icon: Icons.grid_view_outlined,
      metric: AchievementMetric.sessionExerciseCount,
      levels: [
        AchievementLevel(level: 1, threshold: 4, description: '4 упражнения'),
        AchievementLevel(level: 2, threshold: 6, description: '6 упражнений'),
        AchievementLevel(level: 3, threshold: 8, description: '8 упражнений'),
      ],
    ),

    // ——— Привычки (одноуровневые флаги) ———
    AchievementDef(
      id: 'early_bird',
      title: 'Ранняя пташка',
      category: AchievementCategory.habits,
      icon: Icons.wb_sunny_outlined,
      metric: AchievementMetric.flag,
      levels: [
        AchievementLevel(
          level: 1,
          threshold: 1,
          description: 'Заверши тренировку до 08:00',
        ),
      ],
    ),
    AchievementDef(
      id: 'night_owl',
      title: 'Ночная смена',
      category: AchievementCategory.habits,
      icon: Icons.nightlight_outlined,
      metric: AchievementMetric.flag,
      levels: [
        AchievementLevel(
          level: 1,
          threshold: 1,
          description: 'Заверши тренировку после 22:00',
        ),
      ],
    ),
    AchievementDef(
      id: 'template_start',
      title: 'По плану',
      category: AchievementCategory.habits,
      icon: Icons.playlist_play_outlined,
      metric: AchievementMetric.flag,
      levels: [
        AchievementLevel(
          level: 1,
          threshold: 1,
          description: 'Запусти тренировку из шаблона',
        ),
      ],
    ),

    // ——— Медали ———
    AchievementDef(
      id: 'rank_climb',
      title: 'Восхождение',
      description: 'Прогресс по медалям',
      category: AchievementCategory.ranks,
      icon: Icons.military_tech_outlined,
      metric: AchievementMetric.medalIndex,
      levels: [
        AchievementLevel(level: 1, threshold: 1, description: 'Стажёр'),
        AchievementLevel(level: 2, threshold: 3, description: 'Гладиатор'),
        AchievementLevel(level: 3, threshold: 4, description: 'Чемпион'),
        AchievementLevel(level: 4, threshold: 6, description: 'Колосс'),
        AchievementLevel(level: 5, threshold: 7, description: 'Титан'),
      ],
    ),
  ];

  static AchievementDef? byId(String id) {
    for (final a in all) {
      if (a.id == id) return a;
    }
    return null;
  }

  static List<AchievementDef> byCategory(AchievementCategory category) =>
      all.where((a) => a.category == category).toList();
}
