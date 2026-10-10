import 'package:flutter/foundation.dart';

import 'quest_def.dart';

@immutable
class QuestProgress {
  const QuestProgress({
    required this.questId,
    required this.current,
    required this.target,
    required this.completed,
    this.rewardClaimed = false,
  });

  final String questId;
  final double current;
  final double target;
  final bool completed;
  final bool rewardClaimed;

  double get ratio => target <= 0 ? 0 : (current / target).clamp(0.0, 1.0);

  QuestProgress copyWith({
    double? current,
    double? target,
    bool? completed,
    bool? rewardClaimed,
  }) {
    return QuestProgress(
      questId: questId,
      current: current ?? this.current,
      target: target ?? this.target,
      completed: completed ?? this.completed,
      rewardClaimed: rewardClaimed ?? this.rewardClaimed,
    );
  }

  Map<String, dynamic> toMap() => {
        'current': current,
        'target': target,
        'completed': completed,
        'rewardClaimed': rewardClaimed,
      };

  factory QuestProgress.fromMap(String questId, Map<String, dynamic> data) {
    return QuestProgress(
      questId: questId,
      current: (data['current'] as num?)?.toDouble() ?? 0,
      target: (data['target'] as num?)?.toDouble() ?? 1,
      completed: data['completed'] as bool? ?? false,
      rewardClaimed: data['rewardClaimed'] as bool? ?? false,
    );
  }

  factory QuestProgress.initial(QuestDef def) => QuestProgress(
        questId: def.id,
        current: 0,
        target: def.target,
        completed: false,
      );
}

@immutable
class QuestBoard {
  const QuestBoard({
    required this.periodKey,
    required this.period,
    required this.startsAt,
    required this.endsAt,
    required this.items,
  });

  final String periodKey;
  final QuestPeriod period;
  final DateTime startsAt;
  final DateTime endsAt;
  final List<QuestProgress> items;

  Map<String, dynamic> toMap() => {
        'period': period.name,
        'startsAt': startsAt.toIso8601String(),
        'endsAt': endsAt.toIso8601String(),
        'items': {
          for (final i in items) i.questId: i.toMap(),
        },
      };

  factory QuestBoard.fromMap(
    String periodKey,
    Map<String, dynamic> data,
    List<QuestDef> defs,
  ) {
    final raw = data['items'];
    final map = <String, dynamic>{};
    if (raw is Map) {
      raw.forEach((k, v) {
        if (k is String && v is Map) {
          map[k] = Map<String, dynamic>.from(v);
        }
      });
    }
    return QuestBoard(
      periodKey: periodKey,
      period: QuestPeriod.values.firstWhere(
        (p) => p.name == data['period'],
        orElse: () => QuestPeriod.daily,
      ),
      startsAt: DateTime.tryParse(data['startsAt'] as String? ?? '') ??
          DateTime.now(),
      endsAt: DateTime.tryParse(data['endsAt'] as String? ?? '') ??
          DateTime.now(),
      items: defs
          .map(
            (d) => map.containsKey(d.id)
                ? QuestProgress.fromMap(d.id, map[d.id] as Map<String, dynamic>)
                : QuestProgress.initial(d),
          )
          .toList(),
    );
  }
}
