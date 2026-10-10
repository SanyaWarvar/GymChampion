import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/exercise_icon.dart';
import '../../rank/domain/mastery_boards.dart';
import '../../workout/domain/exercise_catalog.dart';
import '../data/stats_repository.dart';
import '../domain/stats_models.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  final _repo = StatsRepository();
  late Future<StatsSnapshot> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.buildSnapshot();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Статистика')),
      body: RefreshIndicator(
        onRefresh: () async {
          setState(() => _future = _repo.buildSnapshot());
          await _future;
        },
        child: FutureBuilder<StatsSnapshot>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: CircularProgressIndicator()),
                ],
              );
            }
            final s = snapshot.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text(
                  'Обзор',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Неделя',
                        value: '${s.weekVolumeKg.round()} кг',
                        sub: '${s.weekWorkouts} трен.',
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        label: 'Месяц',
                        value: '${s.monthVolumeKg.round()} кг',
                        sub: '${s.monthWorkouts} трен.',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Активность (12 недель)',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                _Heatmap(days: s.heatmap),
                const SizedBox(height: 24),
                Text(
                  'Нагрузка по мышцам',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                if (s.muscleLoads.isEmpty)
                  const Text(
                    'Пока нет данных',
                    style: TextStyle(color: AppColors.muted),
                  )
                else
                  ...s.muscleLoads.map((m) {
                    final maxSets = s.muscleLoads.first.sets.toDouble();
                    final ratio = maxSets == 0 ? 0.0 : m.sets / maxSets;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(m.muscle.label)),
                              Text(
                                '${m.sets} подх.',
                                style: const TextStyle(color: AppColors.muted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: LinearProgressIndicator(
                              value: ratio.clamp(0.0, 1.0),
                              minHeight: 8,
                              backgroundColor: AppColors.surface,
                              color: AppColors.amber,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 24),
                Text(
                  'Личные рекорды',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                if (s.records.isEmpty)
                  const Text(
                    'Рекорды появятся после тренировок',
                    style: TextStyle(color: AppColors.muted),
                  )
                else
                  ...s.records.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Material(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => context.push(
                            '/stats/exercise/${Uri.encodeComponent(r.exerciseKey)}',
                            extra: r.exerciseName,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Row(
                              children: [
                                ExerciseIcon(
                                  exerciseId: r.exerciseKey,
                                  name: r.exerciseName,
                                  size: 36,
                                  radius: 8,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    r.exerciseName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  _prLabel(r),
                                  style: const TextStyle(
                                    color: AppColors.amber,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.chevron_right,
                                  color: AppColors.muted,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}

String _prLabel(PersonalRecord r) {
  final board = MasteryBoards.byExerciseId(r.exerciseKey);
  if (ExerciseCatalog.isRun(
        exerciseId: r.exerciseKey,
        name: r.exerciseName,
      )) {
    return ExerciseCatalog.formatKm(r.maxWeightKg);
  }
  if (ExerciseCatalog.isHold(
        exerciseId: r.exerciseKey,
        name: r.exerciseName,
      )) {
    return '${r.maxReps} сек';
  }
  if (board?.metric == MasteryMetric.maxReps ||
      (r.maxWeightKg < 1 && r.maxReps > 0)) {
    return '${r.maxReps} ${board?.unit ?? 'раз'}';
  }
  return '${r.maxWeightKg.round()} кг';
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.sub,
  });

  final String label;
  final String value;
  final String sub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18),
          ),
          Text(sub, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ],
      ),
    );
  }
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.days});

  final List<DayActivity> days;

  Color _color(int count) {
    if (count <= 0) return AppColors.surface;
    if (count == 1) return AppColors.amber.withValues(alpha: 0.35);
    if (count == 2) return AppColors.amber.withValues(alpha: 0.65);
    return AppColors.amber;
  }

  @override
  Widget build(BuildContext context) {
    // 12 weeks × 7 days grid, columns = weeks
    final cells = days;
    return SizedBox(
      height: 92,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(12, (week) {
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Column(
                children: List.generate(7, (dow) {
                  final index = week * 7 + dow;
                  final count =
                      index < cells.length ? cells[index].workoutCount : 0;
                  return Expanded(
                    child: Container(
                      margin: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        color: _color(count),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  );
                }),
              ),
            ),
          );
        }),
      ),
    );
  }
}
