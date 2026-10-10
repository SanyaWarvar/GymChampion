import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../data/challenge_repository.dart';
import '../domain/challenge.dart';

class ChallengeDetailScreen extends StatelessWidget {
  const ChallengeDetailScreen({
    super.key,
    required this.auth,
    required this.challengeId,
  });

  final AuthController auth;
  final String challengeId;

  @override
  Widget build(BuildContext context) {
    final repo = ChallengeRepository();
    final dateFormat = DateFormat('d MMM HH:mm');
    final myUid = auth.profile?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Вызов')),
      body: StreamBuilder<Challenge?>(
        stream: repo.watchChallenge(challengeId),
        builder: (context, snapshot) {
          if (!snapshot.hasData &&
              snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final c = snapshot.data;
          if (c == null) {
            return const Center(child: Text('Вызов не найден'));
          }

          final amOpponent = myUid == c.opponentId;
          final myScore =
              myUid == c.challengerId ? c.challengerScore : c.opponentScore;
          final theirScore =
              myUid == c.challengerId ? c.opponentScore : c.challengerScore;
          final theirName =
              myUid == c.challengerId ? c.opponentName : c.challengerName;

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                c.titleFor(myUid),
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                '${c.metric.label} · до ${dateFormat.format(c.endsAt.toLocal())}',
                style: const TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _ScoreBox(
                      label: 'Ты',
                      value: myScore.round().toString(),
                      highlight: myScore >= theirScore,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 12),
                    child: Text(':', style: TextStyle(fontSize: 28)),
                  ),
                  Expanded(
                    child: _ScoreBox(
                      label: theirName,
                      value: theirScore.round().toString(),
                      highlight: theirScore > myScore,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Статус: ${c.status.name}',
                style: const TextStyle(color: AppColors.muted),
              ),
              if (c.status == ChallengeStatus.pending && amOpponent) ...[
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => repo.accept(c.id),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: AppColors.background,
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Принять'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => repo.decline(c.id),
                  child: const Text('Отклонить'),
                ),
              ],
              if (c.status == ChallengeStatus.pending &&
                  myUid == c.challengerId) ...[
                const SizedBox(height: 16),
                const Text(
                  'Ждём ответа соперника',
                  style: TextStyle(color: AppColors.muted),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  const _ScoreBox({
    required this.label,
    required this.value,
    required this.highlight,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: highlight
            ? AppColors.amber.withValues(alpha: 0.14)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: highlight
            ? Border.all(color: AppColors.amber.withValues(alpha: 0.5))
            : null,
      ),
      child: Column(
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
          ),
        ],
      ),
    );
  }
}
