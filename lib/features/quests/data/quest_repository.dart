import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../rank/domain/xp_rules.dart';
import '../../workout/domain/saved_workout.dart';
import '../domain/quest_def.dart';
import '../domain/quest_progress.dart';

class QuestCompletion {
  const QuestCompletion({
    required this.quest,
    required this.xpReward,
  });

  final QuestDef quest;
  final int xpReward;
}

class QuestApplyResult {
  const QuestApplyResult({required this.completed});

  final List<QuestCompletion> completed;
}

class QuestRepository {
  QuestRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Нет авторизованного пользователя');
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> _boards(String uid) =>
      _firestore.collection('users').doc(uid).collection('questBoards');

  static String dailyKey([DateTime? now]) {
    final n = now ?? DateTime.now();
    final d = DateTime(n.year, n.month, n.day);
    return 'daily_${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  static String weeklyKey([DateTime? now]) {
    final n = now ?? DateTime.now();
    final start = DateTime(n.year, n.month, n.day)
        .subtract(Duration(days: n.weekday - 1));
    return 'weekly_${start.year}-${start.month.toString().padLeft(2, '0')}-${start.day.toString().padLeft(2, '0')}';
  }

  static ({DateTime start, DateTime end}) dailyBounds([DateTime? now]) {
    final n = now ?? DateTime.now();
    final start = DateTime(n.year, n.month, n.day);
    return (start: start, end: start.add(const Duration(days: 1)));
  }

  static ({DateTime start, DateTime end}) weeklyBounds([DateTime? now]) {
    final n = now ?? DateTime.now();
    final start = DateTime(n.year, n.month, n.day)
        .subtract(Duration(days: n.weekday - 1));
    return (start: start, end: start.add(const Duration(days: 7)));
  }

  Future<QuestBoard> _ensureBoard({
    required String key,
    required QuestPeriod period,
    required List<QuestDef> defs,
    required DateTime start,
    required DateTime end,
  }) async {
    final ref = _boards(_uid).doc(key);
    final snap = await ref.get();
    if (snap.exists && snap.data() != null) {
      return QuestBoard.fromMap(key, snap.data()!, defs);
    }
    final board = QuestBoard(
      periodKey: key,
      period: period,
      startsAt: start,
      endsAt: end,
      items: defs.map(QuestProgress.initial).toList(),
    );
    await ref.set(board.toMap());
    return board;
  }

  Future<List<QuestBoard>> fetchActiveBoards() async {
    final day = dailyBounds();
    final week = weeklyBounds();
    final daily = await _ensureBoard(
      key: dailyKey(),
      period: QuestPeriod.daily,
      defs: QuestCatalog.daily,
      start: day.start,
      end: day.end,
    );
    final weekly = await _ensureBoard(
      key: weeklyKey(),
      period: QuestPeriod.weekly,
      defs: QuestCatalog.weekly,
      start: week.start,
      end: week.end,
    );
    return [daily, weekly];
  }

  Stream<List<QuestBoard>> watchActiveBoards() async* {
    // Первичный ensure, затем стримы.
    await fetchActiveBoards();
    final uid = _uid;
    yield* _boards(uid)
        .where(FieldPath.documentId, whereIn: [dailyKey(), weeklyKey()])
        .snapshots()
        .map((snap) {
      final byId = {for (final d in snap.docs) d.id: d.data()};
      QuestBoard parse(String key, QuestPeriod period, List<QuestDef> defs) {
        final data = byId[key];
        if (data == null) {
          final bounds =
              period == QuestPeriod.daily ? dailyBounds() : weeklyBounds();
          return QuestBoard(
            periodKey: key,
            period: period,
            startsAt: bounds.start,
            endsAt: bounds.end,
            items: defs.map(QuestProgress.initial).toList(),
          );
        }
        return QuestBoard.fromMap(key, data, defs);
      }

      return [
        parse(dailyKey(), QuestPeriod.daily, QuestCatalog.daily),
        parse(weeklyKey(), QuestPeriod.weekly, QuestCatalog.weekly),
      ];
    });
  }

  /// Обновляет прогресс квестов после тренировки, начисляет XP за новые завершения.
  Future<QuestApplyResult> applyWorkout(SavedWorkout workout) async {
    final uid = _uid;
    final finished = workout.finishedAt;
    final dayKey = dailyKey(finished);
    final weekKey = weeklyKey(finished);
    final dayBounds = dailyBounds(finished);
    final weekBounds = weeklyBounds(finished);

    final daily = await _ensureBoard(
      key: dayKey,
      period: QuestPeriod.daily,
      defs: QuestCatalog.daily,
      start: dayBounds.start,
      end: dayBounds.end,
    );
    final weekly = await _ensureBoard(
      key: weekKey,
      period: QuestPeriod.weekly,
      defs: QuestCatalog.weekly,
      start: weekBounds.start,
      end: weekBounds.end,
    );

    final exerciseKeys = workout.exercises
        .map((e) => e.exerciseId ?? e.name.toLowerCase())
        .toSet();

    final completed = <QuestCompletion>[];
    var xpGain = 0;

    QuestBoard bump(QuestBoard board, List<QuestDef> defs) {
      final nextItems = <QuestProgress>[];
      for (final def in defs) {
        final prev = board.items.firstWhere(
          (i) => i.questId == def.id,
          orElse: () => QuestProgress.initial(def),
        );
        var current = prev.current;
        switch (def.metric) {
          case QuestMetric.workouts:
            current += 1;
          case QuestMetric.sets:
            current += workout.doneSets;
          case QuestMetric.volumeKg:
            current += workout.volumeKg;
          case QuestMetric.distinctExercises:
            current = (current + exerciseKeys.length).clamp(0, def.target * 2);
          case QuestMetric.durationMin:
            current += workout.durationSec / 60;
          case QuestMetric.runKm:
            current += workout.runKm;
        }
        final done = current >= def.target;
        var rewardClaimed = prev.rewardClaimed;
        if (done && !prev.completed && !rewardClaimed) {
          final q = QuestCatalog.byId(def.id);
          if (q != null) {
            completed.add(QuestCompletion(quest: q, xpReward: q.xpReward));
            xpGain += q.xpReward;
            rewardClaimed = true;
          }
        }
        nextItems.add(
          prev.copyWith(
            current: current,
            target: def.target,
            completed: done || prev.completed,
            rewardClaimed: rewardClaimed,
          ),
        );
      }
      return QuestBoard(
        periodKey: board.periodKey,
        period: board.period,
        startsAt: board.startsAt,
        endsAt: board.endsAt,
        items: nextItems,
      );
    }

    final newDaily = bump(daily, QuestCatalog.daily);
    final newWeekly = bump(weekly, QuestCatalog.weekly);

    final batch = _firestore.batch();
    batch.set(_boards(uid).doc(dayKey), newDaily.toMap());
    batch.set(_boards(uid).doc(weekKey), newWeekly.toMap());

    if (xpGain > 0) {
      final userRef = _firestore.collection('users').doc(uid);
      final userSnap = await userRef.get();
      final xp = (userSnap.data()?['xp'] as num?)?.toInt() ?? 0;
      final newXp = xp + xpGain;
      batch.set(
        userRef,
        {
          'xp': newXp,
          'rank': XpRules.rankForXp(newXp),
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
    return QuestApplyResult(completed: completed);
  }
}
