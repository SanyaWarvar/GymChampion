import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../workout/data/workout_repository.dart';
import '../domain/rank_check_rules.dart';
import '../domain/xp_rules.dart';

class RankCheckRepository {
  RankCheckRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    WorkoutRepository? workouts,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _workouts = workouts ?? WorkoutRepository();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final WorkoutRepository _workouts;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Нет авторизованного пользователя');
    return user.uid;
  }

  DocumentReference<Map<String, dynamic>> get _userDoc =>
      _firestore.collection('users').doc(_uid);

  CollectionReference<Map<String, dynamic>> get _checks =>
      _userDoc.collection('rankChecks');

  Future<DateTime?> lastCheckAt() async {
    final snap = await _userDoc.get();
    final raw = snap.data()?['lastRankCheckAt'] as String?;
    return DateTime.tryParse(raw ?? '');
  }

  Future<RankCheckResult> runCheck() async {
    final userSnap = await _userDoc.get();
    final data = userSnap.data() ?? {};
    final last = DateTime.tryParse(data['lastRankCheckAt'] as String? ?? '');
    if (!RankCheckRules.canAttempt(lastCheckAt: last)) {
      throw StateError('Rank Check ещё рано');
    }

    final xp = (data['xp'] as num?)?.toInt() ?? 0;
    final rankId = XpRules.rankForXp(xp);
    final norm = RankCheckRules.normForRank(rankId);

    final since = DateTime.now().subtract(
      const Duration(days: RankCheckRules.periodDays),
    );
    final workouts = await _workouts.fetchMyWorkouts(limit: 40);
    final recent = workouts.where((w) => !w.finishedAt.isBefore(since)).toList();
    final volume = recent.fold<double>(0, (s, w) => s + w.volumeKg);
    final passed =
        recent.length >= norm.minWorkouts && volume >= norm.minVolumeKg;
    final bonus = passed ? norm.xpBonus : 0;
    final checkedAt = DateTime.now();

    await _firestore.runTransaction((tx) async {
      final fresh = await tx.get(_userDoc);
      final currentXp = (fresh.data()?['xp'] as num?)?.toInt() ?? xp;
      final newXp = currentXp + bonus;
      final newRank = XpRules.rankForXp(newXp);
      final checkRef = _checks.doc();
      tx.set(checkRef, {
        'passed': passed,
        'workouts': recent.length,
        'volumeKg': volume,
        'minWorkouts': norm.minWorkouts,
        'minVolumeKg': norm.minVolumeKg,
        'xpBonus': bonus,
        'rankBefore': rankId,
        'rankAfter': newRank,
        'checkedAt': checkedAt.toIso8601String(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(
        _userDoc,
        {
          'xp': newXp,
          'rank': newRank,
          'lastRankCheckAt': checkedAt.toIso8601String(),
          'lastRankCheckPassed': passed,
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    });

    return RankCheckResult(
      passed: passed,
      workouts: recent.length,
      volumeKg: volume,
      norm: norm,
      xpBonus: bonus,
      checkedAt: checkedAt,
    );
  }
}
