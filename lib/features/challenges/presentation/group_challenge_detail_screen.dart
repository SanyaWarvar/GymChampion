import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../data/challenge_repository.dart';
import '../domain/challenge.dart';
import '../domain/group_challenge.dart';

class GroupChallengeDetailScreen extends StatefulWidget {
  const GroupChallengeDetailScreen({
    super.key,
    required this.auth,
    required this.challengeId,
  });

  final AuthController auth;
  final String challengeId;

  @override
  State<GroupChallengeDetailScreen> createState() =>
      _GroupChallengeDetailScreenState();
}

class _GroupChallengeDetailScreenState
    extends State<GroupChallengeDetailScreen> {
  final _repo = ChallengeRepository();

  @override
  void initState() {
    super.initState();
    final uid = widget.auth.profile?.uid;
    if (uid != null) {
      unawaited(_repo.syncStepsChallenges(userId: uid));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM');
    final me = widget.auth.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Общая цель')),
      body: StreamBuilder<GroupChallenge?>(
        stream: _repo.watchGroupChallenge(widget.challengeId),
        builder: (context, snapshot) {
          if (!snapshot.hasData &&
              snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final c = snapshot.data;
          if (c == null) {
            return const Center(child: Text('Цель не найдена'));
          }
          final inIt = me != null && c.participantIds.contains(me.uid);
          final rows = c.participantIds.map((id) {
            return (
              id: id,
              name: c.names[id] ?? 'Без имени',
              score: c.scores[id] ?? 0,
            );
          }).toList()
            ..sort((a, b) => b.score.compareTo(a.score));

          return RefreshIndicator(
            onRefresh: () async {
              final uid = me?.uid;
              if (uid != null) {
                await _repo.syncStepsChallenges(userId: uid);
              }
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  c.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${c.metric.label} вместе · до ${dateFormat.format(c.endsAt.toLocal())}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: c.ratio,
                    minHeight: 12,
                    backgroundColor: AppColors.surface,
                    color: AppColors.amber,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${c.formatScore(c.totalScore)} из ${c.formatScore(c.target)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.amber,
                  ),
                ),
                if (c.reached || c.status == GroupChallengeStatus.completed) ...[
                  const SizedBox(height: 8),
                  const Text(
                    'Цель закрыта',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
                if (!inIt &&
                    me != null &&
                    c.status == GroupChallengeStatus.active &&
                    !c.reached) ...[
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: () => _repo.joinGroupChallenge(
                      challengeId: c.id,
                      me: me,
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.amber,
                      foregroundColor: AppColors.background,
                    ),
                    child: const Text('Присоединиться'),
                  ),
                ],
                const SizedBox(height: 24),
                Text(
                  'Вклад',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 8),
                ...rows.map(
                  (row) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      tileColor: row.id == me?.uid
                          ? AppColors.amber.withValues(alpha: 0.12)
                          : AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      title: Text(row.name),
                      trailing: Text(
                        c.formatScore(row.score),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
