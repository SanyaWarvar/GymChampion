import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../data/workout_repository.dart';
import '../domain/saved_workout.dart';

class WorkoutHistoryScreen extends StatelessWidget {
  const WorkoutHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = WorkoutRepository();
    final dateFormat = DateFormat('d MMM yyyy, HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('История')),
      body: StreamBuilder<List<SavedWorkout>>(
        stream: repo.watchMyWorkouts(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Не удалось загрузить историю.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final workouts = snapshot.data!;
          if (workouts.isEmpty) {
            return const Center(
              child: Text(
                'Пока пусто — сходи на первую тренировку',
                style: TextStyle(color: AppColors.muted),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: workouts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final w = workouts[index];
              return ListTile(
                tileColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(
                  dateFormat.format(w.finishedAt.toLocal()),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  [
                    '${w.exerciseCount} упр.',
                    '${w.doneSets} подх.',
                    if (w.loadLabel.isNotEmpty) w.loadLabel,
                    '+${w.xpEarned} XP',
                  ].join(' · '),
                  style: const TextStyle(color: AppColors.muted),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/workout/history/${w.id}'),
              );
            },
          );
        },
      ),
    );
  }
}
