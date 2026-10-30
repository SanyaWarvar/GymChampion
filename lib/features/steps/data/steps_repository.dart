import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../auth/domain/app_user.dart';
import '../../challenges/data/challenge_repository.dart';
import '../../feed/data/feed_repository.dart';
import '../../rank/data/streak_repository.dart';
import '../../rank/domain/season.dart';
import '../../rank/domain/streak_rules.dart';
import '../../rank/domain/xp_rules.dart';
import 'steps_service.dart';

enum StepsClaimStatus {
  claimed,
  alreadyClaimed,
  belowGoal,
  notSignedIn,
  error,
}

class StepsClaimResult {
  const StepsClaimResult({
    required this.status,
    this.xpEarned = 0,
    this.steps = 0,
  });

  final StepsClaimStatus status;
  final int xpEarned;
  final int steps;
}

class StepsRepository {
  StepsRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    StepsService? steps,
    StreakRepository? streaks,
    FeedRepository? feed,
    ChallengeRepository? challenges,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _steps = steps ?? StepsService.instance,
        _streaks = streaks ?? StreakRepository(),
        _feed = feed ?? FeedRepository(),
        _challenges = challenges ?? ChallengeRepository();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final StepsService _steps;
  final StreakRepository _streaks;
  final FeedRepository _feed;
  final ChallengeRepository _challenges;

  DocumentReference<Map<String, dynamic>>? get _userRef {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid);
  }

  Future<int> goalForUser() async {
    final ref = _userRef;
    if (ref == null) return XpRules.defaultStepsGoal;
    final snap = await ref.get();
    return (snap.data()?['stepsGoal'] as num?)?.toInt() ??
        XpRules.defaultStepsGoal;
  }

  Future<String?> lastClaimDate() async {
    final ref = _userRef;
    if (ref == null) return null;
    final snap = await ref.get();
    final raw = snap.data()?['stepsLastClaimDate'] as String?;
    return (raw == null || raw.isEmpty) ? null : raw;
  }

  Future<bool> claimedToday({DateTime? now}) async {
    final today = StreakRules.formatDate(now ?? DateTime.now());
    return (await lastClaimDate()) == today;
  }

  Future<StepsClaimResult> claimTodayIfEligible({
    required int steps,
    DateTime? now,
  }) async {
    final uid = _auth.currentUser?.uid;
    final ref = _userRef;
    if (uid == null || ref == null) {
      return const StepsClaimResult(status: StepsClaimStatus.notSignedIn);
    }

    final at = now ?? DateTime.now();
    final dayKey = StreakRules.formatDate(at);
    final goal = await goalForUser();
    if (steps < goal) {
      return StepsClaimResult(
        status: StepsClaimStatus.belowGoal,
        steps: steps,
      );
    }

    try {
      await _streaks.ensureSynced(now: at);
    } catch (_) {}

    final xpAward = XpRules.xpForStepsDay;
    late final StepsClaimStatus status;
    late final AppUser author;

    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(ref);
        final data = snap.data() ?? {};
        final already = data['stepsLastClaimDate'] as String?;
        if (already == dayKey) {
          status = StepsClaimStatus.alreadyClaimed;
          author = AppUser.fromMap(uid, data);
          return;
        }

        final season = Season.current(at);
        final currentXp = (data['xp'] as num?)?.toInt() ?? 0;
        final storedSeasonId = data['seasonId'] as String?;
        final storedSeasonXp = (data['seasonXp'] as num?)?.toInt() ?? 0;
        final seasonXpBase =
            storedSeasonId == season.id ? storedSeasonXp : 0;
        final newXp = currentXp + xpAward;
        final streak = StreakRules.applyWorkout(
          StreakState.fromUserData(data),
          at,
          xpEarned: xpAward,
        );

        tx.set(
          ref,
          {
            'xp': newXp,
            'rank': XpRules.rankForXp(newXp),
            'seasonId': season.id,
            'seasonXp': seasonXpBase + xpAward,
            ...streak.toUserFields(),
            'stepsLastClaimDate': dayKey,
            'stepsLastClaimXp': xpAward,
            'stepsGoal':
                (data['stepsGoal'] as num?)?.toInt() ?? XpRules.defaultStepsGoal,
          },
          SetOptions(merge: true),
        );

        status = StepsClaimStatus.claimed;
        author = AppUser.fromMap(uid, {
          ...data,
          'xp': newXp,
          'rank': XpRules.rankForXp(newXp),
          'displayName': data['displayName'],
        });
      });
    } catch (_) {
      return StepsClaimResult(
        status: StepsClaimStatus.error,
        steps: steps,
      );
    }

    if (status == StepsClaimStatus.claimed) {
      try {
        await _feed.publishStepsDayPost(
          author: author,
          dayKey: dayKey,
          steps: steps,
          xpEarned: xpAward,
          at: at,
        );
      } catch (_) {}
      try {
        await _challenges.syncStepsChallenges(userId: uid);
      } catch (_) {}
    }

    return StepsClaimResult(
      status: status,
      xpEarned: status == StepsClaimStatus.claimed ? xpAward : 0,
      steps: steps,
    );
  }

  Future<void> syncChallenges() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    await _challenges.syncStepsChallenges(userId: uid, steps: _steps);
  }
}
