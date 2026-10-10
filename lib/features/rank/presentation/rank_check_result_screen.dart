import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/rank_check_rules.dart';

class RankCheckResultScreen extends StatelessWidget {
  const RankCheckResultScreen({super.key, required this.result});

  final RankCheckResult result;

  @override
  Widget build(BuildContext context) {
    final ok = result.passed;
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Результат'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              ok ? Icons.verified : Icons.heart_broken_outlined,
              size: 64,
              color: ok ? AppColors.amber : AppColors.muted,
            ),
            const SizedBox(height: 16),
            Text(
              ok ? 'Прошёл!' : 'Не прошёл',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              ok
                  ? 'Форма в порядке. +${result.xpBonus} XP'
                  : 'Медаль на месте — просто добери объём к следующему check.',
              style: const TextStyle(color: AppColors.muted),
            ),
            const SizedBox(height: 24),
            _row('Тренировок', '${result.workouts} / ${result.norm.minWorkouts}'),
            _row(
              'Объём',
              '${result.volumeKg.round()} / ${result.norm.minVolumeKg.round()} кг',
            ),
            const Spacer(),
            FilledButton(
              onPressed: () => context.go('/rank'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: AppColors.background,
                minimumSize: const Size.fromHeight(48),
              ),
              child: const Text('В рейтинг'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}
