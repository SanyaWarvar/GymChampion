import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/exercise_icon.dart';
import '../data/achievement_repository.dart';
import '../domain/achievement_catalog.dart';
import '../domain/achievement_def.dart';
import '../domain/user_achievement.dart';

class AchievementsScreen extends StatelessWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = AchievementRepository();

    return Scaffold(
      appBar: AppBar(title: const Text('Достижения')),
      body: StreamBuilder<List<UserAchievement>>(
        stream: repo.watchUnlocked(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Не удалось загрузить достижения',
                style: TextStyle(color: AppColors.muted),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final progress = {
            for (final u in snapshot.data!) u.id: u,
          };

          var stars = 0;
          var maxStars = 0;
          for (final def in AchievementCatalog.all) {
            maxStars += def.maxLevel;
            stars += (progress[def.id]?.level ?? 0).clamp(0, def.maxLevel);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(
                '$stars / $maxStars ★',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.amber,
                    ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Многоуровневые ачивки: качай вес и открывай следующие ★',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 16),
              ...AchievementCategory.values.map((category) {
                final items = AchievementCatalog.byCategory(category);
                if (items.isEmpty) return const SizedBox.shrink();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Row(
                        children: [
                          Icon(category.icon, size: 18, color: AppColors.muted),
                          const SizedBox(width: 8),
                          Text(
                            category.label,
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ...items.map((def) {
                      final state = progress[def.id];
                      return _AchievementTile(
                        def: def,
                        level: state?.level ?? 0,
                        value: state?.value ?? 0,
                      );
                    }),
                  ],
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({
    required this.def,
    required this.level,
    required this.value,
  });

  final AchievementDef def;
  final int level;
  final double value;

  @override
  Widget build(BuildContext context) {
    final unlocked = level > 0;
    final maxed = level >= def.maxLevel;
    final next = maxed
        ? null
        : def.levels.firstWhere((l) => l.level == level + 1);
    final nextThreshold = next?.threshold ?? 1;
    final prevThreshold = level == 0
        ? 0.0
        : (def.levelDef(level)?.threshold ?? 0);
    final span = (nextThreshold - prevThreshold).clamp(1e-6, double.infinity);
    final barValue = maxed
        ? 1.0
        : ((value - prevThreshold) / span).clamp(0.0, 1.0);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: unlocked
            ? AppColors.amber.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: unlocked
            ? Border.all(color: AppColors.amber.withValues(alpha: 0.4))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (def.exerciseId != null)
                ExerciseIcon(
                  exerciseId: def.exerciseId,
                  size: 44,
                  radius: 22,
                )
              else
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: unlocked
                        ? AppColors.amber.withValues(alpha: 0.25)
                        : AppColors.background,
                  ),
                  child: Icon(
                    def.icon,
                    color: unlocked ? AppColors.amber : AppColors.muted,
                  ),
                ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      def.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: unlocked ? AppColors.onDark : AppColors.muted,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      level > 0
                          ? 'Ур.$level · ${def.starsLabel(level)}'
                          : 'Ещё не открыто',
                      style: TextStyle(
                        color: unlocked ? AppColors.amber : AppColors.muted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$level/${def.maxLevel}',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.muted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            def.progressHint(currentLevel: level, value: value),
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          if (!maxed && def.metric != AchievementMetric.flag) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: barValue,
                minHeight: 6,
                backgroundColor: AppColors.background,
                color: AppColors.amber,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              _valueLabel(value, nextThreshold),
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
          if (def.levels.length > 1) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: def.levels.map((l) {
                final done = level >= l.level;
                return Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: done
                        ? AppColors.amber.withValues(alpha: 0.2)
                        : AppColors.background,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Ур.${l.level}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: done ? AppColors.amber : AppColors.muted,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _valueLabel(double value, double next) {
    if (def.metric == AchievementMetric.maxWeightKg ||
        def.metric == AchievementMetric.totalVolumeKg ||
        def.metric == AchievementMetric.sessionVolumeKg) {
      return '${value.round()} / ${next.round()} кг';
    }
    if (def.metric == AchievementMetric.sessionDurationSec) {
      return '${(value / 60).round()} / ${(next / 60).round()} мин';
    }
    if (def.metric == AchievementMetric.sessionXp) {
      return '${value.round()} / ${next.round()} XP';
    }
    return '${value.round()} / ${next.round()}';
  }
}
