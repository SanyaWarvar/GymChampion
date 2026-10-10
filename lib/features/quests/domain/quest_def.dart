import 'package:flutter/material.dart';

enum QuestPeriod { daily, weekly }

enum QuestMetric {
  workouts,
  sets,
  volumeKg,
  distinctExercises,
  durationMin,
  runKm,
}

@immutable
class QuestDef {
  const QuestDef({
    required this.id,
    required this.title,
    required this.description,
    required this.period,
    required this.metric,
    required this.target,
    required this.xpReward,
    required this.icon,
    this.assetId,
  });

  final String id;
  final String title;
  final String description;
  final QuestPeriod period;
  final QuestMetric metric;
  final double target;
  final int xpReward;
  final IconData icon;
  final String? assetId;

  String get iconAsset => 'assets/icons/quests/${assetId ?? id}.jpg';
}

abstract final class QuestCatalog {
  static const daily = <QuestDef>[
    QuestDef(
      id: 'daily_workout',
      title: 'Зал сегодня',
      description: 'Заверши 1 тренировку',
      period: QuestPeriod.daily,
      metric: QuestMetric.workouts,
      target: 1,
      xpReward: 15,
      icon: Icons.fitness_center,
    ),
    QuestDef(
      id: 'daily_sets',
      title: '16 подходов',
      description: 'Сделай 16 рабочих подходов за день',
      period: QuestPeriod.daily,
      metric: QuestMetric.sets,
      target: 16,
      xpReward: 15,
      icon: Icons.repeat,
    ),
    QuestDef(
      id: 'daily_volume',
      title: 'Четыре тонны',
      description: 'Набери 4 000 кг объёма за день',
      period: QuestPeriod.daily,
      metric: QuestMetric.volumeKg,
      target: 4000,
      xpReward: 20,
      icon: Icons.monitor_weight_outlined,
    ),
    QuestDef(
      id: 'daily_long',
      title: 'Час в зале',
      description: 'Тренируйся суммарно 50 минут за день',
      period: QuestPeriod.daily,
      metric: QuestMetric.durationMin,
      target: 50,
      xpReward: 15,
      icon: Icons.timer_outlined,
      assetId: 'daily_workout',
    ),
    QuestDef(
      id: 'daily_variety',
      title: 'Пять движений',
      description: 'Сделай 5 разных упражнений за день',
      period: QuestPeriod.daily,
      metric: QuestMetric.distinctExercises,
      target: 5,
      xpReward: 15,
      icon: Icons.grid_view_outlined,
      assetId: 'weekly_variety',
    ),
    QuestDef(
      id: 'daily_grind',
      title: '24 подхода',
      description: 'Закрой 24 рабочих подхода за день',
      period: QuestPeriod.daily,
      metric: QuestMetric.sets,
      target: 24,
      xpReward: 25,
      icon: Icons.whatshot_outlined,
      assetId: 'daily_sets',
    ),
    QuestDef(
      id: 'daily_run',
      title: 'Пробежка',
      description: 'Набеги 5 км за день',
      period: QuestPeriod.daily,
      metric: QuestMetric.runKm,
      target: 5,
      xpReward: 20,
      icon: Icons.directions_run,
      assetId: 'daily_workout',
    ),
  ];

  static const weekly = <QuestDef>[
    QuestDef(
      id: 'weekly_workouts',
      title: 'Четыре дня в зале',
      description: '4 тренировки за неделю',
      period: QuestPeriod.weekly,
      metric: QuestMetric.workouts,
      target: 4,
      xpReward: 40,
      icon: Icons.calendar_view_week,
    ),
    QuestDef(
      id: 'weekly_volume',
      title: 'Недельный тоннаж',
      description: '25 000 кг объёма за неделю',
      period: QuestPeriod.weekly,
      metric: QuestMetric.volumeKg,
      target: 25000,
      xpReward: 50,
      icon: Icons.local_shipping_outlined,
    ),
    QuestDef(
      id: 'weekly_variety',
      title: 'Разнообразие недели',
      description: '10 разных упражнений за неделю',
      period: QuestPeriod.weekly,
      metric: QuestMetric.distinctExercises,
      target: 10,
      xpReward: 35,
      icon: Icons.grid_view_outlined,
    ),
    QuestDef(
      id: 'weekly_five',
      title: 'Шесть выходов',
      description: '6 тренировок за неделю',
      period: QuestPeriod.weekly,
      metric: QuestMetric.workouts,
      target: 6,
      xpReward: 60,
      icon: Icons.event_available_outlined,
      assetId: 'weekly_workouts',
    ),
    QuestDef(
      id: 'weekly_sets',
      title: '70 подходов',
      description: '70 рабочих подходов за неделю',
      period: QuestPeriod.weekly,
      metric: QuestMetric.sets,
      target: 70,
      xpReward: 45,
      icon: Icons.repeat,
      assetId: 'daily_sets',
    ),
    QuestDef(
      id: 'weekly_hours',
      title: '4 часа в зале',
      description: '240 минут тренировок за неделю',
      period: QuestPeriod.weekly,
      metric: QuestMetric.durationMin,
      target: 240,
      xpReward: 55,
      icon: Icons.hourglass_bottom,
      assetId: 'daily_workout',
    ),
    QuestDef(
      id: 'weekly_beast',
      title: 'Зверь недели',
      description: '40 000 кг объёма за неделю',
      period: QuestPeriod.weekly,
      metric: QuestMetric.volumeKg,
      target: 40000,
      xpReward: 70,
      icon: Icons.local_fire_department,
      assetId: 'weekly_volume',
    ),
    QuestDef(
      id: 'weekly_run',
      title: 'Километраж недели',
      description: '25 км бега за неделю',
      period: QuestPeriod.weekly,
      metric: QuestMetric.runKm,
      target: 25,
      xpReward: 45,
      icon: Icons.directions_run,
      assetId: 'weekly_workouts',
    ),
  ];

  static List<QuestDef> get all => [...daily, ...weekly];

  static QuestDef? byId(String id) {
    for (final q in all) {
      if (q.id == id) return q;
    }
    return null;
  }
}
