import 'package:flutter/foundation.dart';

@immutable
class StreakState {
  const StreakState({
    this.days = 0,
    this.best = 0,
    this.freezes = 0,
    this.freezeXp = 0,
    this.lastDate,
  });

  final int days;
  final int best;
  final int freezes;

  /// XP accumulated toward the next freeze (0 .. [freezeXpCost] - 1 when under cap).
  final int freezeXp;
  final DateTime? lastDate;

  static const freezeXpCost = 1000;
  static const freezeCap = 2;

  bool get isAlive => days > 0;

  StreakState copyWith({
    int? days,
    int? best,
    int? freezes,
    int? freezeXp,
    DateTime? lastDate,
    bool clearLastDate = false,
  }) {
    return StreakState(
      days: days ?? this.days,
      best: best ?? this.best,
      freezes: freezes ?? this.freezes,
      freezeXp: freezeXp ?? this.freezeXp,
      lastDate: clearLastDate ? null : (lastDate ?? this.lastDate),
    );
  }

  factory StreakState.fromUserData(Map<String, dynamic> data) {
    return StreakState(
      days: (data['streakDays'] as num?)?.toInt() ?? 0,
      best: (data['streakBest'] as num?)?.toInt() ?? 0,
      freezes: (data['streakFreezes'] as num?)?.toInt() ?? 0,
      freezeXp: (data['streakFreezeXp'] as num?)?.toInt() ?? 0,
      lastDate: StreakRules.parseDate(data['streakLastDate'] as String?),
    );
  }

  Map<String, dynamic> toUserFields() {
    return {
      'streakDays': days,
      'streakBest': best,
      'streakFreezes': freezes,
      'streakFreezeXp': freezeXp,
      'streakLastDate':
          lastDate == null ? '' : StreakRules.formatDate(lastDate!),
    };
  }
}

@immutable
class StreakClockResult {
  const StreakClockResult({
    required this.state,
    this.penalizedDays = 0,
    this.freezeDaysUsed = 0,
  });

  final StreakState state;
  final int penalizedDays;
  final int freezeDaysUsed;
}

abstract final class StreakRules {
  static DateTime dateOnly(DateTime value) {
    final local = value.toLocal();
    return DateTime(local.year, local.month, local.day);
  }

  static String formatDate(DateTime value) {
    final d = dateOnly(value);
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '${d.year}-$m-$day';
  }

  static DateTime? parseDate(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return null;
    return dateOnly(parsed);
  }

  /// Spends banked XP toward freezes up to [StreakState.freezeCap].
  static ({int freezes, int freezeXp}) awardFreezes({
    required int freezes,
    required int freezeXp,
    int xpEarned = 0,
  }) {
    var f = freezes.clamp(0, StreakState.freezeCap);
    var xp = freezeXp + xpEarned;
    if (xp < 0) xp = 0;
    while (xp >= StreakState.freezeXpCost && f < StreakState.freezeCap) {
      xp -= StreakState.freezeXpCost;
      f += 1;
    }
    return (freezes: f, freezeXp: xp);
  }

  /// Advances the clock through fully missed days before [now].
  /// Freeze covers a missed day without XP loss and adds that day to the
  /// streak. Unprotected misses break the streak and are counted for XP decay.
  static StreakClockResult applyClock(StreakState state, DateTime now) {
    final today = dateOnly(now);
    if (state.lastDate == null) {
      return StreakClockResult(state: state);
    }
    var last = dateOnly(state.lastDate!);
    if (!last.isBefore(today)) {
      return StreakClockResult(state: state);
    }

    var days = state.days;
    var freezes = state.freezes;
    var freezeXp = state.freezeXp;
    var best = state.best;
    var penalized = 0;
    var freezeUsed = 0;
    var cursor = last;

    while (true) {
      final next = cursor.add(const Duration(days: 1));
      if (!next.isBefore(today)) break;
      if (freezes > 0 && days > 0) {
        freezes -= 1;
        freezeUsed += 1;
        days += 1;
        if (days > best) best = days;
        cursor = next;
      } else {
        penalized += 1;
        days = 0;
        freezes = 0;
        cursor = next;
      }
    }

    if (freezeUsed > 0) {
      final awarded = awardFreezes(freezes: freezes, freezeXp: freezeXp);
      freezes = awarded.freezes;
      freezeXp = awarded.freezeXp;
    }

    return StreakClockResult(
      state: StreakState(
        days: days,
        best: best,
        freezes: freezes,
        freezeXp: freezeXp,
        lastDate: cursor,
      ),
      penalizedDays: penalized,
      freezeDaysUsed: freezeUsed,
    );
  }

  static StreakState applyWorkout(
    StreakState state,
    DateTime at, {
    int xpEarned = 0,
  }) {
    final day = dateOnly(at);
    var cur = applyClock(state, day).state;
    if (cur.lastDate != null && dateOnly(cur.lastDate!) == day) {
      // Same calendar day: still bank XP toward freezes.
      final awarded = awardFreezes(
        freezes: cur.freezes,
        freezeXp: cur.freezeXp,
        xpEarned: xpEarned,
      );
      return cur.copyWith(
        freezes: awarded.freezes,
        freezeXp: awarded.freezeXp,
      );
    }

    final yesterday = day.subtract(const Duration(days: 1));
    final continued =
        cur.lastDate != null && dateOnly(cur.lastDate!) == yesterday && cur.days > 0;

    final awarded = awardFreezes(
      freezes: continued ? cur.freezes : 0,
      freezeXp: cur.freezeXp,
      xpEarned: xpEarned,
    );

    if (!continued) {
      const days = 1;
      final best = state.best > days ? state.best : days;
      return StreakState(
        days: days,
        best: best,
        freezes: awarded.freezes,
        freezeXp: awarded.freezeXp,
        lastDate: day,
      );
    }

    final days = cur.days + 1;
    final best = days > cur.best ? days : cur.best;
    return cur.copyWith(
      days: days,
      best: best,
      freezes: awarded.freezes,
      freezeXp: awarded.freezeXp,
      lastDate: day,
    );
  }

  static StreakState fromWorkoutDates(
    Iterable<DateTime> dates, {
    DateTime? now,
    Iterable<int>? xpPerDate,
  }) {
    final unique = dates.map(dateOnly).toSet().toList()..sort();
    final xpList = xpPerDate?.toList();
    var state = const StreakState();
    for (var i = 0; i < unique.length; i++) {
      final xp = xpList != null && i < xpList.length ? xpList[i] : 0;
      state = applyWorkout(state, unique[i], xpEarned: xp);
    }
    return applyClock(state, now ?? DateTime.now()).state;
  }
}
