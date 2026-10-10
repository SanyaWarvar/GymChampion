import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../achievements/data/achievement_repository.dart';
import '../../achievements/domain/user_achievement.dart';
import '../../auth/domain/app_user.dart';
import '../../challenges/data/challenge_repository.dart';
import '../../feed/data/feed_repository.dart';
import '../../notifications/data/notification_repository.dart';
import '../../notifications/data/notification_scheduler.dart';
import '../../notifications/domain/app_notification.dart';
import '../../quests/data/quest_repository.dart';
import '../../rank/data/leaderboard_repository.dart';
import '../../rank/data/streak_repository.dart';
import '../../rank/domain/mastery_boards.dart';
import '../../rank/domain/season.dart';
import '../../rank/domain/session_records.dart';
import '../../rank/domain/streak_rules.dart';
import '../../rank/domain/xp_rules.dart';
import '../domain/saved_workout.dart';
import 'local_workout_store.dart';

class WorkoutSaveResult {
  const WorkoutSaveResult({
    required this.workout,
    required this.xpEarned,
    required this.totalXp,
    required this.rank,
    this.newlyUnlocked = const [],
    this.completedQuests = const [],
  });

  final SavedWorkout workout;
  final int xpEarned;
  final int totalXp;
  final String rank;
  final List<AchievementLevelUp> newlyUnlocked;
  final List<QuestCompletion> completedQuests;
}

class WorkoutRepository {
  WorkoutRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    AchievementRepository? achievements,
    FeedRepository? feed,
    ChallengeRepository? challenges,
    QuestRepository? quests,
    LocalWorkoutStore? localStore,
    LeaderboardRepository? leaderboard,
    StreakRepository? streaks,
    NotificationRepository? notifications,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _achievements = achievements ?? AchievementRepository(),
        _feed = feed ?? FeedRepository(),
        _challenges = challenges ?? ChallengeRepository(),
        _quests = quests ?? QuestRepository(),
        _localStore = localStore ?? LocalWorkoutStore(),
        _leaderboard = leaderboard ?? LeaderboardRepository(),
        _streaks = streaks ?? StreakRepository(),
        _notifications = notifications ?? NotificationRepository();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final AchievementRepository _achievements;
  final FeedRepository _feed;
  final ChallengeRepository _challenges;
  final QuestRepository _quests;
  final LocalWorkoutStore _localStore;
  final LeaderboardRepository _leaderboard;
  final StreakRepository _streaks;
  final NotificationRepository _notifications;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Нет авторизованного пользователя');
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> _workouts(String uid) =>
      _firestore.collection('users').doc(uid).collection('workouts');

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _firestore.collection('users').doc(uid);

  Future<WorkoutSaveResult> saveWorkout(WorkoutDraft draft) async {
    final uid = _uid;
    final exercises = draft.exercises
        .map(
          (e) => e.copyWith(
            sets: e.sets.where((s) => s.done && s.hasWork).toList(),
          ),
        )
        .where((e) => e.sets.isNotEmpty)
        .toList();

    final volume = exercises.fold<double>(0, (total, e) => total + e.volume);
    final runKm = exercises.fold<double>(0, (total, e) => total + e.runKm);
    final doneSets =
        exercises.fold<int>(0, (total, e) => total + e.sets.length);
    final durationSec = draft.duration.inSeconds.clamp(0, 24 * 3600);
    final xpEarned = XpRules.xpForWorkout(
      doneSets: doneSets,
      volumeKg: volume,
      durationSec: durationSec,
      exerciseCount: exercises.length,
      runKm: runKm,
    );

    final userPreview = await _userDoc(uid).get();
    final isPrivate =
        userPreview.data()?['defaultWorkoutPrivate'] as bool? ?? false;
    final season = Season.current(draft.finishedAt);

    final doc = _workouts(uid).doc();
    final workout = SavedWorkout(
      id: doc.id,
      userId: uid,
      startedAt: draft.startedAt,
      finishedAt: draft.finishedAt,
      durationSec: durationSec,
      volumeKg: volume,
      doneSets: doneSets,
      exerciseCount: exercises.length,
      xpEarned: xpEarned,
      exercises: exercises,
      isPrivate: isPrivate,
    );

    try {
      await _leaderboard.backfillMyMasteryIfNeeded();
    } catch (_) {}
    try {
      await _streaks.ensureSynced(now: draft.finishedAt);
    } catch (_) {}

    final sessionBests = MasteryBoards.fromExercises(exercises);
    final sessionRecords = SessionRecords.fromWorkout(
      xpEarned: xpEarned,
      volumeKg: volume,
      exercises: exercises,
    );

    late final int newWorkoutCount;
    late final double newTotalVolume;
    late final int newTotalDoneSets;
    late final int newXp;
    late final String newRank;
    var bestSessionXp = xpEarned;

    await _firestore.runTransaction((tx) async {
      final userRef = _userDoc(uid);
      final userSnap = await tx.get(userRef);
      final data = userSnap.data() ?? {};
      final currentXp = (data['xp'] as num?)?.toInt() ?? 0;
      final workoutCount = (data['workoutCount'] as num?)?.toInt() ?? 0;
      final totalVolume = (data['totalVolume'] as num?)?.toDouble() ?? 0;
      final totalDoneSets = (data['totalDoneSets'] as num?)?.toInt() ?? 0;
      final storedSeasonId = data['seasonId'] as String?;
      final storedSeasonXp = (data['seasonXp'] as num?)?.toInt() ?? 0;
      final seasonXpBase =
          storedSeasonId == season.id ? storedSeasonXp : 0;
      newXp = currentXp + xpEarned;
      newRank = XpRules.rankForXp(newXp);
      newWorkoutCount = workoutCount + 1;
      newTotalVolume = totalVolume + volume;
      newTotalDoneSets = totalDoneSets + doneSets;
      final storedBests = MasteryBoards.readFromUserData(data);
      final mergedBests = MasteryBoards.mergeMax(storedBests, sessionBests);
      final mergedSessions = SessionRecords.mergeMax(
        SessionRecords.readFromUserData(data),
        sessionRecords,
      );
      bestSessionXp =
          (mergedSessions[SessionRecords.xp.userField] ?? xpEarned).round();
      final streak = StreakRules.applyWorkout(
        StreakState.fromUserData(data),
        draft.finishedAt,
        xpEarned: xpEarned,
      );

      tx.set(doc, {
        ...workout.toMap(),
        'fromTemplate': draft.fromTemplate,
        'seasonId': season.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
      tx.set(
        userRef,
        {
          'xp': newXp,
          'rank': newRank,
          'workoutCount': newWorkoutCount,
          'totalVolume': newTotalVolume,
          'totalDoneSets': newTotalDoneSets,
          'seasonId': season.id,
          'seasonXp': seasonXpBase + xpEarned,
          'lastWorkoutAt': draft.finishedAt.toIso8601String(),
          'updatedAt': FieldValue.serverTimestamp(),
          'masteryBackfilled': true,
          'masterySchema': MasteryBoards.schema,
          'sessionRecordsBackfilled': true,
          'streakBackfilled': true,
          ...streak.toUserFields(),
          for (final entry in mergedBests.entries) entry.key: entry.value,
          for (final entry in mergedSessions.entries) entry.key: entry.value,
        },
        SetOptions(merge: true),
      );
    });

    await _localStore.clear();

    final unlock = await _achievements.evaluateAndUnlock(
      AchievementEvalContext(
        workoutCount: newWorkoutCount,
        totalVolumeKg: newTotalVolume,
        totalDoneSets: newTotalDoneSets,
        sessionVolumeKg: volume,
        sessionDoneSets: doneSets,
        sessionDurationSec: durationSec,
        sessionExerciseCount: exercises.length,
        sessionXp: bestSessionXp,
        finishedAt: draft.finishedAt,
        rankId: newRank,
        fromTemplate: draft.fromTemplate,
        sessionExercises: exercises,
      ),
    );

    final profileSnap = await _userDoc(uid).get();
    final author = AppUser.fromMap(uid, {
      ...?profileSnap.data(),
      'xp': newXp,
      'rank': newRank,
      'workoutCount': newWorkoutCount,
      'totalVolume': newTotalVolume,
    });
    try {
      await _feed.publishWorkoutPost(author: author, workout: workout);
    } catch (_) {
      // Лента не должна ломать сохранение тренировки.
    }
    try {
      await _challenges.applyWorkoutToChallenges(
        userId: uid,
        workout: workout,
        xpEarned: xpEarned,
        actorName: author.displayName ?? 'Участник',
      );
    } catch (_) {}

    try {
      await _notifyOvertaken(
        actor: author,
        oldXp: newXp - xpEarned,
        newXp: newXp,
      );
    } catch (_) {}

    try {
      final refreshed = await _userDoc(uid).get();
      if (refreshed.data() != null) {
        await NotificationScheduler.syncForProfile(
          AppUser.fromMap(uid, refreshed.data()!),
        );
      }
    } catch (_) {}

    var questXp = 0;
    var completedQuests = const <QuestCompletion>[];
    try {
      final questResult = await _quests.applyWorkout(workout);
      completedQuests = questResult.completed;
      questXp = completedQuests.fold<int>(0, (s, c) => s + c.xpReward);
    } catch (_) {}

    final totalXp = newXp + questXp;
    return WorkoutSaveResult(
      workout: workout,
      xpEarned: xpEarned + questXp,
      totalXp: totalXp,
      rank: XpRules.rankForXp(totalXp),
      newlyUnlocked: unlock.newlyUnlocked,
      completedQuests: completedQuests,
    );
  }

  Stream<List<SavedWorkout>> watchMyWorkouts({int limit = 50}) {
    final uid = _uid;
    return _workouts(uid)
        .orderBy('finishedAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => SavedWorkout.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<List<SavedWorkout>> fetchMyWorkouts({int limit = 50}) async {
    final uid = _uid;
    final snap = await _workouts(uid)
        .orderBy('finishedAt', descending: true)
        .limit(limit)
        .get();
    return snap.docs
        .map((doc) => SavedWorkout.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<SavedWorkout?> fetchWorkout(String workoutId) async {
    final snap = await _workouts(_uid).doc(workoutId).get();
    if (!snap.exists || snap.data() == null) return null;
    return SavedWorkout.fromMap(snap.id, snap.data()!);
  }

  Future<void> setWorkoutPrivate({
    required String workoutId,
    required bool isPrivate,
  }) async {
    final uid = _uid;
    await _workouts(uid).doc(workoutId).set(
      {'isPrivate': isPrivate},
      SetOptions(merge: true),
    );
    if (isPrivate) {
      await _feed.removeWorkoutPost(userId: uid, workoutId: workoutId);
    } else {
      final workout = await fetchWorkout(workoutId);
      final profileSnap = await _userDoc(uid).get();
      if (workout != null && profileSnap.data() != null) {
        final author = AppUser.fromMap(uid, profileSnap.data()!);
        await _feed.publishWorkoutPost(author: author, workout: workout);
      }
    }
  }

  Future<MonthSummary> fetchMonthSummary({DateTime? month}) async {
    final now = month ?? DateTime.now();
    final start = DateTime(now.year, now.month);
    final end = DateTime(now.year, now.month + 1);
    final workouts = await fetchMyWorkouts(limit: 100);
    final inMonth = workouts
        .where(
          (w) =>
              !w.finishedAt.isBefore(start) && w.finishedAt.isBefore(end),
        )
        .toList();
    final volume =
        inMonth.fold<double>(0, (total, w) => total + w.volumeKg);
    final avgLoad = inMonth.isEmpty ? 0.0 : volume / inMonth.length;
    return MonthSummary(
      workoutCount: inMonth.length,
      totalVolumeKg: volume,
      averageVolumeKg: avgLoad,
    );
  }

  /// Пишет тем, кого обогнали по XP этой тренировкой.
  Future<void> _notifyOvertaken({
    required AppUser actor,
    required int oldXp,
    required int newXp,
  }) async {
    if (newXp <= oldXp) return;
    final snap = await _firestore
        .collection('users')
        .where('xp', isGreaterThan: oldXp)
        .where('xp', isLessThan: newXp)
        .limit(8)
        .get();
    final name = actor.displayName ?? 'Участник';
    for (final doc in snap.docs) {
      if (doc.id == actor.uid) continue;
      await _notifications.createForUser(
        recipientId: doc.id,
        type: AppNotificationType.overtaken,
        title: 'Тебя обогнали',
        body: '$name обогнал тебя в рейтинге',
        actorId: actor.uid,
        actorName: name,
        route: '/rank',
      );
    }
  }
}

class MonthSummary {
  const MonthSummary({
    required this.workoutCount,
    required this.totalVolumeKg,
    required this.averageVolumeKg,
  });

  final int workoutCount;
  final double totalVolumeKg;
  final double averageVolumeKg;
}
