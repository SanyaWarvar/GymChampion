import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../rank/domain/xp_rules.dart';
import '../data/workout_repository.dart';
import '../domain/exercise_catalog.dart';
import '../domain/saved_workout.dart';

class WorkoutSummaryScreen extends StatefulWidget {
  const WorkoutSummaryScreen({super.key, required this.draft});

  final WorkoutDraft draft;

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen> {
  final _repo = WorkoutRepository();
  bool _saving = true;
  String? _error;
  WorkoutSaveResult? _result;

  @override
  void initState() {
    super.initState();
    _save();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await _repo.saveWorkout(widget.draft);
      if (!mounted) return;
      setState(() {
        _result = result;
        _saving = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось сохранить. Проверь интернет и попробуй ещё раз.';
        _saving = false;
      });
    }
  }

  void _done() {
    context.go('/workout');
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final volume = draft.volumeKg.round();
    final duration = _formatDuration(draft.duration);

    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Итог'),
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _saving
                      ? 'Сохраняем…'
                      : _error != null
                          ? 'Ошибка'
                          : 'Красава!',
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  _saving
                      ? 'Сохраняем… Firestore подхватит и оффлайн'
                      : _error ?? 'Сохранено · черновик очищен',
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppColors.muted),
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: ListView(
                    children: [
                      if (volume > 0)
                        _StatTile(label: 'Объём', value: '$volume кг'),
                      if (draft.runKm > 0)
                        _StatTile(
                          label: 'Бег',
                          value: ExerciseCatalog.formatKm(draft.runKm),
                        ),
                      _StatTile(label: 'Время', value: duration),
                      _StatTile(label: 'Подходы', value: '${draft.doneSets}'),
                      _StatTile(
                        label: 'Упражнения',
                        value: '${draft.exerciseCount}',
                      ),
                      if (_result != null) ...[
                        const SizedBox(height: 8),
                        _StatTile(
                          label: 'XP за тренировку',
                          value: '+${_result!.xpEarned}',
                          highlight: true,
                        ),
                        ...XpRules.xpBreakdown(
                          doneSets: draft.doneSets,
                          volumeKg: draft.volumeKg,
                          durationSec: draft.duration.inSeconds,
                          exerciseCount: draft.exerciseCount,
                          runKm: draft.runKm,
                        ).entries.where((e) => e.value > 0).map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(
                              left: 4,
                              bottom: 4,
                            ),
                            child: Text(
                              '${e.key}  +${e.value}',
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        _StatTile(
                          label: 'Всего XP / медаль',
                          value:
                              '${_result!.totalXp} · ${XpRules.titleForRank(_result!.rank)}',
                          highlight: true,
                        ),
                        if (_result!.completedQuests.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Задания выполнены',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          ..._result!.completedQuests.map(
                            (q) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.amber.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color:
                                      AppColors.amber.withValues(alpha: 0.45),
                                ),
                              ),
                              child: Row(
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.asset(
                                      q.quest.iconAsset,
                                      width: 36,
                                      height: 36,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, _, _) => Icon(
                                        q.quest.icon,
                                        color: AppColors.amber,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      q.quest.title,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '+${q.xpReward} XP',
                                    style: const TextStyle(
                                      color: AppColors.amber,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                        if (_result!.newlyUnlocked.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Text(
                            'Новые уровни',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 8),
                          ..._result!.newlyUnlocked.map(
                            (a) => Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.amber.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.amber.withValues(alpha: 0.45),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(a.icon, color: AppColors.amber),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          a.headline,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        Text(
                                          '${a.levelDescription} · ${a.stars}',
                                          style: const TextStyle(
                                            color: AppColors.muted,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                      if (_saving)
                        const Padding(
                          padding: EdgeInsets.only(top: 24),
                          child: Center(child: CircularProgressIndicator()),
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _save,
                          child: const Text('Повторить'),
                        ),
                      ],
                    ],
                  ),
                ),
                FilledButton(
                  onPressed: _saving ? null : _done,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: AppColors.background,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('На главную'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: highlight
            ? Border.all(color: AppColors.amber.withValues(alpha: 0.5))
            : null,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: highlight ? AppColors.amber : null,
                ),
          ),
        ],
      ),
    );
  }
}
