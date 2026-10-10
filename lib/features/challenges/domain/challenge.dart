import 'package:flutter/foundation.dart';

enum ChallengeMetric { volume, workouts, xp, run }

enum ChallengeStatus { pending, active, completed, declined }

extension ChallengeMetricX on ChallengeMetric {
  String get label => switch (this) {
        ChallengeMetric.volume => 'Объём (кг)',
        ChallengeMetric.workouts => 'Тренировки',
        ChallengeMetric.xp => 'XP',
        ChallengeMetric.run => 'Бег (км)',
      };

  String formatAmount(double value) => switch (this) {
        ChallengeMetric.xp => '${value.round()} XP',
        ChallengeMetric.workouts =>
          '${value.round()} ${_workoutWord(value.round())}',
        ChallengeMetric.volume => '${value.round()} кг',
        ChallengeMetric.run =>
          '${value == value.roundToDouble() ? value.round() : value.toStringAsFixed(1)} км',
      };

  String progressVerb(double value) => switch (this) {
        ChallengeMetric.run => 'пробежал ${formatAmount(value)}',
        ChallengeMetric.volume => 'набрал ${formatAmount(value)}',
        ChallengeMetric.xp => 'заработал ${formatAmount(value)}',
        ChallengeMetric.workouts => 'закрыл ${formatAmount(value)}',
      };
}

String _workoutWord(int n) {
  final mod10 = n % 10;
  final mod100 = n % 100;
  if (mod10 == 1 && mod100 != 11) return 'тренировку';
  if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
    return 'тренировки';
  }
  return 'тренировок';
}

@immutable
class Challenge {
  const Challenge({
    required this.id,
    required this.challengerId,
    required this.challengerName,
    required this.opponentId,
    required this.opponentName,
    required this.metric,
    required this.status,
    required this.startsAt,
    required this.endsAt,
    this.challengerScore = 0,
    this.opponentScore = 0,
  });

  final String id;
  final String challengerId;
  final String challengerName;
  final String opponentId;
  final String opponentName;
  final ChallengeMetric metric;
  final ChallengeStatus status;
  final DateTime startsAt;
  final DateTime endsAt;
  final double challengerScore;
  final double opponentScore;

  bool involves(String uid) =>
      uid == challengerId || uid == opponentId;

  String titleFor(String myUid) {
    final other =
        myUid == challengerId ? opponentName : challengerName;
    return 'vs $other';
  }

  Map<String, dynamic> toMap() => {
        'challengerId': challengerId,
        'challengerName': challengerName,
        'opponentId': opponentId,
        'opponentName': opponentName,
        'metric': metric.name,
        'status': status.name,
        'startsAt': startsAt.toIso8601String(),
        'endsAt': endsAt.toIso8601String(),
        'challengerScore': challengerScore,
        'opponentScore': opponentScore,
      };

  factory Challenge.fromMap(String id, Map<String, dynamic> data) {
    final metricName = data['metric'] as String? ?? 'volume';
    final statusName = data['status'] as String? ?? 'pending';
    return Challenge(
      id: id,
      challengerId: data['challengerId'] as String? ?? '',
      challengerName: data['challengerName'] as String? ?? '',
      opponentId: data['opponentId'] as String? ?? '',
      opponentName: data['opponentName'] as String? ?? '',
      metric: ChallengeMetric.values.firstWhere(
        (m) => m.name == metricName,
        orElse: () => ChallengeMetric.volume,
      ),
      status: ChallengeStatus.values.firstWhere(
        (s) => s.name == statusName,
        orElse: () => ChallengeStatus.pending,
      ),
      startsAt: DateTime.tryParse(data['startsAt'] as String? ?? '') ??
          DateTime.now(),
      endsAt: DateTime.tryParse(data['endsAt'] as String? ?? '') ??
          DateTime.now().add(const Duration(days: 7)),
      challengerScore: (data['challengerScore'] as num?)?.toDouble() ?? 0,
      opponentScore: (data['opponentScore'] as num?)?.toDouble() ?? 0,
    );
  }
}
