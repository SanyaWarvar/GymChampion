import 'package:flutter/foundation.dart';

import 'challenge.dart';

enum GroupChallengeStatus { active, completed }

@immutable
class GroupChallenge {
  const GroupChallenge({
    required this.id,
    required this.title,
    required this.creatorId,
    required this.metric,
    required this.target,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    required this.participantIds,
    required this.names,
    required this.scores,
    this.totalScore = 0,
  });

  final String id;
  final String title;
  final String creatorId;
  final ChallengeMetric metric;
  final double target;
  final GroupChallengeStatus status;
  final DateTime startsAt;
  final DateTime endsAt;
  final List<String> participantIds;
  final Map<String, String> names;
  final Map<String, double> scores;
  final double totalScore;

  bool get reached => totalScore >= target;

  double get ratio => target <= 0 ? 0 : (totalScore / target).clamp(0.0, 1.0);

  String formatScore(double value) {
    return switch (metric) {
      ChallengeMetric.xp => '${value.round()} XP',
      ChallengeMetric.workouts => '${value.round()} трен.',
      ChallengeMetric.volume => '${value.round()} кг',
      ChallengeMetric.run => '${value == value.roundToDouble() ? value.round() : value.toStringAsFixed(1)} км',
    };
  }

  Map<String, dynamic> toMap() => {
        'kind': 'group',
        'title': title,
        'creatorId': creatorId,
        'metric': metric.name,
        'target': target,
        'status': status.name,
        'startsAt': startsAt.toIso8601String(),
        'endsAt': endsAt.toIso8601String(),
        'participantIds': participantIds,
        'names': names,
        'scores': scores,
        'totalScore': totalScore,
      };

  factory GroupChallenge.fromMap(String id, Map<String, dynamic> data) {
    final namesRaw = data['names'];
    final scoresRaw = data['scores'];
    final names = <String, String>{};
    final scores = <String, double>{};
    if (namesRaw is Map) {
      namesRaw.forEach((k, v) {
        if (k is String) names[k] = v?.toString() ?? '';
      });
    }
    if (scoresRaw is Map) {
      scoresRaw.forEach((k, v) {
        if (k is String) scores[k] = (v as num?)?.toDouble() ?? 0;
      });
    }
    return GroupChallenge(
      id: id,
      title: data['title'] as String? ?? 'Общая цель',
      creatorId: data['creatorId'] as String? ?? '',
      metric: ChallengeMetric.values.firstWhere(
        (m) => m.name == data['metric'],
        orElse: () => ChallengeMetric.xp,
      ),
      target: (data['target'] as num?)?.toDouble() ?? 500,
      status: GroupChallengeStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => GroupChallengeStatus.active,
      ),
      startsAt: DateTime.tryParse(data['startsAt'] as String? ?? '') ??
          DateTime.now(),
      endsAt: DateTime.tryParse(data['endsAt'] as String? ?? '') ??
          DateTime.now().add(const Duration(days: 30)),
      participantIds: (data['participantIds'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .toList(),
      names: names,
      scores: scores,
      totalScore: (data['totalScore'] as num?)?.toDouble() ??
          scores.values.fold(0, (a, b) => a + b),
    );
  }
}
