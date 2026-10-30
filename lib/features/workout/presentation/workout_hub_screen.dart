import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/exercise_icon.dart';
import '../../../shared/widgets/streak_flame.dart';
import '../../auth/domain/app_user.dart';
import '../../quests/presentation/quest_hub_section.dart';
import '../../rank/data/streak_repository.dart';
import '../../rank/domain/streak_rules.dart';
import '../../rank/domain/xp_rules.dart';
import '../data/local_workout_store.dart';
import '../data/template_repository.dart';
import '../data/workout_repository.dart';
import '../domain/saved_workout.dart';
import '../domain/workout_template.dart';
import 'start_workout_guard.dart';

class WorkoutHubScreen extends StatefulWidget {
  const WorkoutHubScreen({super.key});

  @override
  State<WorkoutHubScreen> createState() => _WorkoutHubScreenState();
}

class _WorkoutHubScreenState extends State<WorkoutHubScreen> {
  final _localStore = LocalWorkoutStore();
  final _streaks = StreakRepository();
  LocalWorkoutDraft? _draft;

  @override
  void initState() {
    super.initState();
    _loadDraft();
    unawaited(_streaks.ensureSynced());
  }

  Future<void> _loadDraft() async {
    final draft = await _localStore.load();
    if (!mounted) return;
    setState(() => _draft = draft);
  }

  Future<void> _startEmpty() async {
    await startWorkoutGuarded(context);
    if (mounted) await _loadDraft();
  }

  Future<void> _startTemplate(WorkoutTemplate t) async {
    await startWorkoutGuarded(context, template: t);
    if (mounted) await _loadDraft();
  }

  Future<void> _continueDraft() async {
    final draft = _draft;
    if (draft == null) return;
    await startWorkoutGuarded(context, restore: draft);
    if (mounted) await _loadDraft();
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final repo = WorkoutRepository();
    final dateFormat = DateFormat('d MMM, HH:mm');

    return Scaffold(
      appBar: AppBar(title: const Text('Тренировка')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Text(
              'Пора в зал',
              style: textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Начни с нуля или выбери шаблон ниже',
              style: textTheme.bodyMedium?.copyWith(color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            _StreakCard(),
            if (_draft != null) ...[
              const SizedBox(height: 16),
              Material(
                color: AppColors.amber.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(12),
                child: ListTile(
                  leading: const Icon(Icons.history_toggle_off,
                      color: AppColors.amber),
                  title: const Text(
                    'Продолжить тренировку',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    'Черновик с ${_draft!.exercises.length} упр. · оффлайн OK',
                    style: const TextStyle(color: AppColors.muted),
                  ),
                  trailing: const Icon(Icons.play_arrow),
                  onTap: _continueDraft,
                ),
              ),
            ],
            const SizedBox(height: 20),
            const QuestHubSection(),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _startEmpty,
              icon: const Icon(Icons.play_arrow_rounded, size: 28),
              label: const Padding(
                padding: EdgeInsets.symmetric(vertical: 14),
                child: Text(
                  'Начать тренировку',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: AppColors.background,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Недавние',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/workout/history'),
                  child: const Text('Вся история'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<SavedWorkout>>(
              stream: repo.watchMyWorkouts(limit: 3),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'История недоступна оффлайн',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final workouts = snapshot.data!;
                if (workouts.isEmpty) {
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Пока нет тренировок — время первой!',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  );
                }
                return Column(
                  children: workouts.map((w) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
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
                            if (w.loadLabel.isNotEmpty) w.loadLabel,
                            '+${w.xpEarned} XP',
                          ].join(' · '),
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => context.push('/workout/history/${w.id}'),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Шаблоны',
                    style: textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => context.push('/workout/templates'),
                  child: const Text('Все'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            StreamBuilder<List<WorkoutTemplate>>(
              stream: TemplateRepository().watchTemplates(),
              builder: (context, snapshot) {
                final templates = snapshot.data ?? const <WorkoutTemplate>[];
                if (templates.isEmpty) {
                  return ListTile(
                    tileColor: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    title: const Text('Создать шаблон'),
                    subtitle: const Text(
                      'Чтобы не набивать упражнения каждый раз',
                      style: TextStyle(color: AppColors.muted),
                    ),
                    trailing: const Icon(Icons.add),
                    onTap: () => context.push('/workout/templates/edit'),
                  );
                }
                final preview = [
                  ...templates.where((t) => t.isProgramDay),
                  ...templates.where((t) => !t.isProgramDay),
                ].take(4);
                return Column(
                  children: preview.map((t) {
                    final first =
                        t.exercises.isNotEmpty ? t.exercises.first : null;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        tileColor: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        leading: first == null
                            ? const Icon(Icons.playlist_play,
                                color: AppColors.amber)
                            : ExerciseIcon(
                                exerciseId: first.exerciseId,
                                name: first.name,
                                size: 40,
                                radius: 10,
                              ),
                        title: Text(
                          t.name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text(
                          t.exercises.isEmpty
                              ? '${t.exercises.length} упражнений'
                              : t.exercises.map((e) => e.name).join(' · '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        trailing: const Icon(Icons.play_arrow),
                        onTap: () => _startTemplate(t),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  static const _freezeColor = Color(0xFF5AD4FF);

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return const SizedBox.shrink();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
      builder: (context, snapshot) {
        final data = snapshot.data?.data();
        final user = data == null ? null : AppUser.fromMap(uid, data);
        final streak =
            data == null ? const StreakState() : StreakState.fromUserData(data);
        final days = user?.streakDays ?? 0;
        final freezes = user?.streakFreezes ?? 0;
        final freezeXp = streak.freezeXp;
        final atCap = freezes >= StreakState.freezeCap;
        final cost = StreakState.freezeXpCost;
        final barValue = atCap
            ? 1.0
            : (freezeXp.clamp(0, cost) / cost).toDouble();
        final penalty = (data?['lastXpPenalty'] as num?)?.toInt() ?? 0;
        final penaltyAt =
            DateTime.tryParse(data?['lastXpPenaltyAt'] as String? ?? '');
        final recentPenalty = penalty > 0 &&
            penaltyAt != null &&
            DateTime.now().difference(penaltyAt).inHours < 36;
        final missHit = XpRules.xpForMissedDayAt(user?.xp ?? 0);
        final subtitle = recentPenalty
            ? '−$penalty XP за пропуск · заморозка XP не тратит'
            : days == 0
                ? 'Пропуск без заморозки: −$missHit XP. Заморозка XP не тратит.'
                : freezes > 0
                    ? '$freezes в запасе · пропуск без неё −$missHit XP'
                    : 'Без заморозки пропуск: −$missHit XP';
        final progressLabel = atCap
            ? freezeXp > 0
                ? 'Запас полный · $freezeXp XP в банке'
                : 'Запас заморозок полный'
            : 'До заморозки: $freezeXp / $cost XP';

        return Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.amber.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  StreakFlame(
                    days: days,
                    freezes: freezes,
                    lastDate: streak.lastDate,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          days > 0 ? '$days дн. подряд' : 'Ударный режим',
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
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
              const SizedBox(height: 12),
              Text(
                progressLabel,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: barValue,
                  minHeight: 8,
                  backgroundColor: AppColors.background,
                  color: _freezeColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
