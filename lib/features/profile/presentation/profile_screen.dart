import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_version_label.dart';
import '../../../shared/widgets/streak_flame.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/app_user.dart';
import '../../rank/domain/streak_rules.dart';
import '../../rank/domain/xp_rules.dart';
import '../../rank/presentation/rank_badge.dart';
import '../../updates/app_update_prompt.dart';
import '../../workout/data/workout_repository.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _repo = WorkoutRepository();
  late Future<MonthSummary> _monthFuture;

  @override
  void initState() {
    super.initState();
    _monthFuture = _repo.fetchMonthSummary();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.auth,
      builder: (context, _) {
        final profile = widget.auth.profile;
        final xp = profile?.xp ?? 0;
        final rank = XpRules.rankForXp(xp);
        final toNext = XpRules.xpToNextRank(xp);
        final nextLabel = XpRules.nextRankLabel(xp);

        return Scaffold(
          appBar: AppBar(title: const Text('Профиль')),
          body: RefreshIndicator(
            onRefresh: () async {
              setState(() {
                _monthFuture = _repo.fetchMonthSummary();
              });
              await _monthFuture;
            },
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    UserAvatar(
                      photoUrl: profile?.photoUrl,
                      name: profile?.displayName,
                      rankId: rank,
                      size: 72,
                      previewOnTap: true,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => context.push('/profile/edit'),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile?.displayName ?? 'Без имени',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              profile?.email ?? '',
                              style: const TextStyle(color: AppColors.muted),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              profile?.photoUrl == null ||
                                      profile!.photoUrl!.trim().isEmpty
                                  ? 'Нажми имя, чтобы сменить фото'
                                  : 'Фото — увеличить · имя — изменить',
                              style: const TextStyle(
                                color: AppColors.amber,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.amber.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      RankBadge(rankId: rank, size: 52, showLabel: true),
                      const SizedBox(height: 10),
                      Text(
                        '$xp XP',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 10),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: XpRules.progressToNextRank(xp),
                          minHeight: 8,
                          backgroundColor: AppColors.background,
                          color: XpRules.colorForRank(rank),
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (toNext > 0 && nextLabel != null)
                        Text(
                          'До $nextLabel: $toNext XP',
                          style: const TextStyle(color: AppColors.muted),
                        )
                      else
                        const Text(
                          'Максимум — Титан',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          StreakFlame(
                            days: profile?.streakDays ?? 0,
                            freezes: profile?.streakFreezes ?? 0,
                            lastDate: profile?.streakLastDate,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _freezeHint(profile),
                              style: const TextStyle(color: AppColors.muted),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _FreezeXpBar(profile: profile),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => context.push('/rank/ladder'),
                        child: const Text('Все медали'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                FutureBuilder<MonthSummary>(
                  future: _monthFuture,
                  builder: (context, snapshot) {
                    final month = snapshot.data;
                    return Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Этот месяц',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 12),
                          _row(
                            'Тренировок',
                            '${month?.workoutCount ?? '—'}',
                          ),
                          _row(
                            'Объём',
                            month == null
                                ? '—'
                                : '${month.totalVolumeKg.round()} кг',
                          ),
                          _row(
                            'Средняя нагрузка',
                            month == null
                                ? '—'
                                : '${month.averageVolumeKg.round()} кг',
                          ),
                          _row(
                            'Всего тренировок',
                            '${profile?.workoutCount ?? 0}',
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),
                _navTile(
                  icon: Icons.edit_outlined,
                  title: 'Имя и аватар',
                  onTap: () => context.push('/profile/edit'),
                ),
                _navTile(
                  icon: Icons.auto_awesome_outlined,
                  title: 'Оформление',
                  onTap: () => context.push('/profile/appearance'),
                ),
                _navTile(
                  icon: Icons.insights_outlined,
                  title: 'Статистика',
                  onTap: () => context.push('/stats'),
                ),
                _navTile(
                  icon: Icons.emoji_events_outlined,
                  title: 'Достижения',
                  onTap: () => context.push('/achievements'),
                ),
                _navTile(
                  icon: Icons.task_alt_outlined,
                  title: 'Задания',
                  onTap: () => context.push('/quests'),
                ),
                _navTile(
                  icon: Icons.sports_kabaddi_outlined,
                  title: 'Вызовы',
                  onTap: () => context.push('/challenges'),
                ),
                _navTile(
                  icon: Icons.verified_outlined,
                  title: 'Rank Check',
                  onTap: () => context.push('/rank/check'),
                ),
                _navTile(
                  icon: Icons.history,
                  title: 'История тренировок',
                  onTap: () => context.push('/workout/history'),
                ),
                _navTile(
                  icon: Icons.lock_outline,
                  title: 'Приватность',
                  onTap: () => context.push('/profile/privacy'),
                ),
                _navTile(
                  icon: Icons.notifications_outlined,
                  title: 'Лента уведомлений',
                  onTap: () => context.push('/notifications'),
                ),
                _navTile(
                  icon: Icons.tune_outlined,
                  title: 'Настройки уведомлений',
                  onTap: () => context.push('/profile/notifications'),
                ),
                const SizedBox(height: 24),
                OutlinedButton(
                  onPressed: () => widget.auth.signOut(),
                  child: const Text('Выйти'),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () => AppUpdatePrompt.check(silent: false),
                  behavior: HitTestBehavior.opaque,
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8),
                    child: AppVersionLabel(),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: AppColors.muted)),
          ),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _navTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        tileColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        leading: Icon(icon),
        title: Text(title),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

String _freezeHint(AppUser? profile) {
  final freezes = profile?.streakFreezes ?? 0;
  final days = profile?.streakDays ?? 0;
  final word = _freezeWord(freezes);
  final last = profile?.streakLastDate;
  final litToday = days > 0 &&
      last != null &&
      StreakRules.dateOnly(last) == StreakRules.dateOnly(DateTime.now());
  if (!litToday) {
    return '$word в запасе · зажги огонёк сегодня';
  }
  return '$word в запасе';
}

String _freezeWord(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return '$n заморозка';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return '$n заморозки';
  }
  return '$n заморозок';
}

class _FreezeXpBar extends StatelessWidget {
  const _FreezeXpBar({required this.profile});

  static const _freezeColor = Color(0xFF5AD4FF);

  final AppUser? profile;

  @override
  Widget build(BuildContext context) {
    final freezes = profile?.streakFreezes ?? 0;
    final freezeXp = profile?.streakFreezeXp ?? 0;
    final cost = StreakState.freezeXpCost;
    final atCap = freezes >= StreakState.freezeCap;
    final barValue =
        atCap ? 1.0 : (freezeXp.clamp(0, cost) / cost).toDouble();
    final label = atCap
        ? freezeXp > 0
            ? 'Запас полный · $freezeXp XP в банке'
            : 'Запас заморозок полный'
        : 'До заморозки: $freezeXp / $cost XP';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.muted, fontSize: 12),
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
    );
  }
}
