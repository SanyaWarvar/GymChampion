import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../data/challenge_repository.dart';
import '../domain/challenge.dart';
import '../domain/group_challenge.dart';

class ChallengeListScreen extends StatelessWidget {
  const ChallengeListScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Вызовы'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Дуэли'),
              Tab(text: 'Общие цели'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _DuelTab(auth: auth),
            _GroupTab(auth: auth),
          ],
        ),
      ),
    );
  }
}

class _DuelTab extends StatelessWidget {
  const _DuelTab({required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final repo = ChallengeRepository();
    final dateFormat = DateFormat('d MMM');
    final myUid = auth.profile?.uid ?? '';

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/challenges/create'),
        icon: const Icon(Icons.add),
        label: const Text('Дуэль'),
      ),
      body: StreamBuilder<List<Challenge>>(
        stream: repo.watchMyChallenges(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Не удалось загрузить вызовы',
                style: TextStyle(color: AppColors.muted),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Нет дуэлей.\nБрось другу вызов на неделю.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final c = items[index];
              final myScore =
                  myUid == c.challengerId ? c.challengerScore : c.opponentScore;
              final theirScore =
                  myUid == c.challengerId ? c.opponentScore : c.challengerScore;
              return ListTile(
                tileColor: AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(
                  c.titleFor(myUid),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${c.metric.label} · ${c.status.name} · до ${dateFormat.format(c.endsAt)}\n'
                  '${myScore.round()} : ${theirScore.round()}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                isThreeLine: true,
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/challenges/${c.id}'),
              );
            },
          );
        },
      ),
    );
  }
}

class _GroupTab extends StatelessWidget {
  const _GroupTab({required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final repo = ChallengeRepository();
    final dateFormat = DateFormat('d MMM');

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/challenges/group/create'),
        icon: const Icon(Icons.groups_outlined),
        label: const Text('Цель'),
      ),
      body: StreamBuilder<List<GroupChallenge>>(
        stream: repo.watchGroupChallenges(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Не удалось загрузить цели',
                style: TextStyle(color: AppColors.muted),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Нет общих целей.\nСобери всех: например 500 XP за месяц.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final c = items[index];
              return Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => context.push('/challenges/group/${c.id}'),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.title,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${c.metric.label} · ${c.participantIds.length} чел. · '
                          'до ${dateFormat.format(c.endsAt.toLocal())}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 10),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: c.ratio,
                            minHeight: 8,
                            backgroundColor: AppColors.background,
                            color: AppColors.amber,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${c.formatScore(c.totalScore)} / ${c.formatScore(c.target)}'
                          '${c.status == GroupChallengeStatus.completed || c.reached ? ' · цель закрыта' : ''}',
                          style: const TextStyle(
                            color: AppColors.amber,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
