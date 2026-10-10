import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/exercise_icon.dart';
import '../../../shared/widgets/streak_flame.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/app_user.dart';
import '../data/leaderboard_repository.dart';
import '../data/streak_repository.dart';
import '../domain/mastery_boards.dart';
import '../domain/season.dart';
import '../domain/session_records.dart';
import '../domain/xp_rules.dart';

class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  final _repo = LeaderboardRepository();
  final _streaks = StreakRepository();
  LeaderboardSort _sort = LeaderboardSort.seasonXp;
  MasteryBoard _board = MasteryBoards.defaultBoard;
  SessionRecordBoard _session = SessionRecords.defaultBoard;

  @override
  void initState() {
    super.initState();
    unawaited(_streaks.ensureSynced());
  }

  @override
  Widget build(BuildContext context) {
    final season = Season.current();
    final myMastery = widget.auth.profile?.masteryValue(_board) ?? 0;
    final mySession = widget.auth.profile?.sessionRecordValue(_session) ?? 0;
    final myStreak = widget.auth.profile?.streakDays ?? 0;
    final hideWeights = widget.auth.profile?.hideWeights ?? false;
    final sessionBoards = SessionRecords.all
        .where((b) => !b.hideIfWeightsHidden || !hideWeights)
        .toList();
    final headerSub = switch (_sort) {
      LeaderboardSort.mastery when myMastery > 0 =>
        'личный рекорд: ${_board.format(myMastery)}',
      LeaderboardSort.session when mySession > 0 =>
        'личный рекорд: ${_session.format(mySession)}',
      LeaderboardSort.streak => myStreak > 0
          ? 'твоя серия: $myStreak дн.'
          : 'тренируйся, чтобы зажечь огонёк',
      _ => 'ещё ${season.daysLeft} дн. · сезон XP: '
          '${widget.auth.profile?.seasonId == season.id ? widget.auth.profile?.seasonXp ?? 0 : 0}',
    };

    return Scaffold(
      appBar: AppBar(
        title: const Text('Рейтинг'),
        actions: [
          IconButton(
            tooltip: 'Сезон',
            onPressed: () => context.push('/rank/season'),
            icon: const Icon(Icons.calendar_month_outlined),
          ),
          IconButton(
            tooltip: 'Rank Check',
            onPressed: () => context.push('/rank/check'),
            icon: const Icon(Icons.verified_outlined),
          ),
          IconButton(
            tooltip: 'Медали',
            onPressed: () => context.push('/rank/ladder'),
            icon: const Icon(Icons.military_tech_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          season.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          headerSub,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.push('/rank/season'),
                    child: const Text('Правила'),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _chip('Сезон XP', LeaderboardSort.seasonXp),
                _chip('Всего XP', LeaderboardSort.totalXp),
                _chip('Серия', LeaderboardSort.streak),
                _chip('Тренировки', LeaderboardSort.workouts),
                _chip('Мастерство', LeaderboardSort.mastery),
                _chip('Рекорды', LeaderboardSort.session),
              ],
            ),
          ),
          if (_sort == LeaderboardSort.mastery)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                children: MasteryBoards.all.map(_boardChip).toList(),
              ),
            ),
          if (_sort == LeaderboardSort.session)
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                children: sessionBoards.map(_sessionChip).toList(),
              ),
            ),
          Expanded(
            child: StreamBuilder<List<AppUser>>(
              stream: _repo.watch(
                sort: _sort,
                board: _board,
                session: _session,
              ),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Не удалось загрузить рейтинг.\nПроверь интернет.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.muted),
                      ),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final users = snapshot.data!;
                if (users.isEmpty) {
                  return Center(
                    child: Text(
                      _sort == LeaderboardSort.mastery
                          ? 'Пока нет рекордов по «${_board.title}»'
                          : _sort == LeaderboardSort.session
                              ? 'Пока нет рекордов по «${_session.title}»'
                              : _sort == LeaderboardSort.streak
                                  ? 'Пока никто не держит серию'
                                  : 'Пока никого нет в рейтинге',
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  );
                }

                final myUid = widget.auth.profile?.uid;
                final myIndex = users.indexWhere((u) => u.uid == myUid);

                return Column(
                  children: [
                    Expanded(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        itemCount: users.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final user = users[index];
                          return _RankTile(
                            place: index + 1,
                            user: user,
                            sort: _sort,
                            board: _board,
                            session: _session,
                            highlight: user.uid == myUid,
                            onTap: () => context.push('/friends/${user.uid}'),
                          );
                        },
                      ),
                    ),
                    if (myIndex >= 0)
                      Material(
                        color: AppColors.surface,
                        child: SafeArea(
                          top: false,
                          child: _RankTile(
                            place: myIndex + 1,
                            user: users[myIndex],
                            sort: _sort,
                            board: _board,
                            session: _session,
                            highlight: true,
                            pinned: true,
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, LeaderboardSort sort) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: _sort == sort,
        onSelected: (_) {
          setState(() => _sort = sort);
          if (sort == LeaderboardSort.mastery ||
              sort == LeaderboardSort.session) {
            unawaited(_repo.backfillMyMasteryIfNeeded());
          }
        },
      ),
    );
  }

  Widget _boardChip(MasteryBoard board) {
    final selected = _board.id == board.id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        avatar: ExerciseIcon(
          exerciseId: board.exerciseId,
          size: 22,
          radius: 6,
        ),
        label: Text(board.title),
        selected: selected,
        onSelected: (_) => setState(() => _board = board),
      ),
    );
  }

  Widget _sessionChip(SessionRecordBoard board) {
    final selected = _session.id == board.id;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(board.title),
        selected: selected,
        onSelected: (_) => setState(() => _session = board),
      ),
    );
  }
}

class _RankTile extends StatelessWidget {
  const _RankTile({
    required this.place,
    required this.user,
    required this.sort,
    required this.board,
    required this.session,
    this.highlight = false,
    this.pinned = false,
    this.onTap,
  });

  final int place;
  final AppUser user;
  final LeaderboardSort sort;
  final MasteryBoard board;
  final SessionRecordBoard session;
  final bool highlight;
  final bool pinned;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final score = switch (sort) {
      LeaderboardSort.totalXp => '${user.xp} XP',
      LeaderboardSort.seasonXp => '${user.seasonXp} XP',
      LeaderboardSort.workouts => '${user.workoutCount}',
      LeaderboardSort.mastery => board.format(user.masteryValue(board)),
      LeaderboardSort.session =>
        session.format(user.sessionRecordValue(session)),
      LeaderboardSort.streak => '${user.streakDays} дн.',
    };

    return Material(
      color: highlight
          ? AppColors.amber.withValues(alpha: 0.12)
          : AppColors.surface,
      borderRadius: pinned ? null : BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: pinned ? null : BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: pinned ? null : BorderRadius.circular(12),
            border: highlight
                ? Border.all(color: AppColors.amber.withValues(alpha: 0.4))
                : null,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 36,
                child: Text(
                  '$place',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: place <= 3 ? AppColors.amber : AppColors.muted,
                  ),
                ),
              ),
              UserAvatar(
                photoUrl: user.photoUrl,
                name: user.displayName,
                rankId: XpRules.rankForXp(user.xp),
                size: 40,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.displayName ?? 'Без имени',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        StreakFlame(days: user.streakDays, compact: true),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            '${XpRules.shortTitleForRank(XpRules.rankForXp(user.xp))} · '
                            '${user.workoutCount} трен.',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Text(
                score,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  color: AppColors.amber,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
