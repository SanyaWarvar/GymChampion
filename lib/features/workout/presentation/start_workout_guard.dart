import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../application/rest_timer_controller.dart';
import '../data/local_workout_store.dart';
import '../domain/workout_template.dart';

/// Старт новой тренировки с защитой от потери незавершённого черновика.
Future<void> startWorkoutGuarded(
  BuildContext context, {
  WorkoutTemplate? template,
  LocalWorkoutDraft? restore,
}) async {
  if (restore != null) {
    await context.push('/workout/active', extra: restore);
    return;
  }

  final store = LocalWorkoutStore();
  final existing = await store.load();
  if (existing != null) {
    if (!context.mounted) return;
    final action = await showDialog<_StartConflictAction>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Тренировка уже идёт'),
        content: Text(
          'Есть черновик (${existing.exercises.length} упр.). '
          'Новая тренировка сотрёт его.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, _StartConflictAction.cancel),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, _StartConflictAction.continueDraft),
            child: const Text(
              'Продолжить',
              style: TextStyle(color: AppColors.amber),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, _StartConflictAction.replace),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: AppColors.background,
            ),
            child: const Text('Начать новую'),
          ),
        ],
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case null:
      case _StartConflictAction.cancel:
        return;
      case _StartConflictAction.continueDraft:
        await context.push('/workout/active', extra: existing);
        return;
      case _StartConflictAction.replace:
        RestTimerController.instance.dismissRest();
        await store.clear();
    }
  }

  if (!context.mounted) return;
  await context.push('/workout/active', extra: template);
}

enum _StartConflictAction { cancel, continueDraft, replace }
