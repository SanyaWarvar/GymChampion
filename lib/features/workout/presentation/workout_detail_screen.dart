import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/exercise_icon.dart';
import '../data/workout_repository.dart';
import '../domain/exercise_catalog.dart';
import '../domain/saved_workout.dart';

class WorkoutDetailScreen extends StatefulWidget {
  const WorkoutDetailScreen({super.key, required this.workoutId});

  final String workoutId;

  @override
  State<WorkoutDetailScreen> createState() => _WorkoutDetailScreenState();
}

class _WorkoutDetailScreenState extends State<WorkoutDetailScreen> {
  final _repo = WorkoutRepository();
  late Future<SavedWorkout?> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.fetchWorkout(widget.workoutId);
  }

  Future<void> _togglePrivate(SavedWorkout workout) async {
    final next = !workout.isPrivate;
    await _repo.setWorkoutPrivate(
      workoutId: workout.id,
      isPrivate: next,
    );
    setState(() {
      _future = _repo.fetchWorkout(widget.workoutId);
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(next ? 'Тренировка скрыта' : 'Тренировка видна друзьям'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMMM yyyy, HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Тренировка')),
      body: FutureBuilder<SavedWorkout?>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData &&
              snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final workout = snapshot.data;
          if (workout == null) {
            return const Center(child: Text('Тренировка не найдена'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                dateFormat.format(workout.finishedAt.toLocal()),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                [
                  workout.durationLabel,
                  if (workout.loadLabel.isNotEmpty) workout.loadLabel,
                  '+${workout.xpEarned} XP',
                ].join(' · '),
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Скрыть тренировку'),
                subtitle: const Text('Друзья не увидят её в ленте (позже)'),
                value: workout.isPrivate,
                onChanged: (_) => _togglePrivate(workout),
              ),
              const SizedBox(height: 8),
              ...workout.exercises.map((exercise) {
                final doneSets = exercise.sets.where((s) => s.done).toList();
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ExerciseIcon(
                            exerciseId: exercise.exerciseId,
                            name: exercise.name,
                            size: 36,
                            radius: 8,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              exercise.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...doneSets.asMap().entries.map((entry) {
                        final i = entry.key + 1;
                        final set = entry.value;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Text(
                            '$i. ${ExerciseCatalog.formatSet(
                              weightKg: set.weightKg,
                              qty: set.reps,
                              exerciseId: exercise.exerciseId,
                              name: exercise.name,
                            )}',
                            style: const TextStyle(color: AppColors.muted),
                          ),
                        );
                      }),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
