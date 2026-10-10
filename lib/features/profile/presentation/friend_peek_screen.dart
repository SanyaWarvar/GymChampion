import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/exercise_icon.dart';
import '../../../shared/widgets/streak_flame.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/domain/app_user.dart';
import '../../rank/domain/mastery_boards.dart';
import '../../rank/domain/xp_rules.dart';
import '../../rank/presentation/rank_badge.dart';

class FriendPeekScreen extends StatelessWidget {
  const FriendPeekScreen({super.key, required this.userId});

  final String userId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Профиль')),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final snap = snapshot.data!;
          if (!snap.exists || snap.data() == null) {
            return const Center(child: Text('Пользователь не найден'));
          }
          final user = AppUser.fromMap(snap.id, snap.data()!);
          final rank = XpRules.rankForXp(user.xp);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: UserAvatar(
                  photoUrl: user.photoUrl,
                  name: user.displayName,
                  rankId: rank,
                  size: 84,
                  previewOnTap: true,
                ),
              ),
              const SizedBox(height: 16),
              RankBadge(rankId: rank, size: 48, showLabel: true),
              const SizedBox(height: 12),
              Text(
                user.displayName ?? 'Без имени',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '${user.xp} XP · ${user.workoutCount} тренировок',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 10),
              StreakFlame(days: user.streakDays, freezes: user.streakFreezes),
              const SizedBox(height: 8),
              Text(
                user.hideWeights
                    ? 'Объём скрыт настройками приватности'
                    : 'Объём: ${user.totalVolume.round()} кг · сезон XP: ${user.seasonXp}',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 24),
              if (_visibleMastery(user).isNotEmpty) ...[
                Text(
                  'Мастерство',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                ..._visibleMastery(user).map(
                  (entry) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      tileColor: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      leading: ExerciseIcon(
                        exerciseId: entry.board.exerciseId,
                        size: 36,
                        radius: 8,
                      ),
                      title: Text(entry.board.title),
                      trailing: Text(
                        entry.board.format(entry.value),
                        style: const TextStyle(
                          color: AppColors.amber,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
              ListTile(
                tileColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                leading: const Icon(Icons.sports_kabaddi_outlined),
                title: const Text('Бросить вызов'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/challenges/create', extra: user),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MasteryEntry {
  const _MasteryEntry({required this.board, required this.value});

  final MasteryBoard board;
  final num value;
}

List<_MasteryEntry> _visibleMastery(AppUser user) {
  return [
    for (final board in MasteryBoards.all)
      if (user.masteryValue(board) > 0 && !(board.isWeight && user.hideWeights))
        _MasteryEntry(board: board, value: user.masteryValue(board)),
  ];
}

