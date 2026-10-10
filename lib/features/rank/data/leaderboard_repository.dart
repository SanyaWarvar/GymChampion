import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../achievements/data/achievement_repository.dart';
import '../../achievements/domain/user_achievement.dart';
import '../../auth/domain/app_user.dart';
import '../../workout/domain/saved_workout.dart';
import '../domain/mastery_boards.dart';
import '../domain/season.dart';
import '../domain/session_records.dart';

enum LeaderboardSort { totalXp, seasonXp, workouts, mastery, streak, session }

class LeaderboardRepository {
  LeaderboardRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  static final Set<String> _backfilledUids = <String>{};

  Stream<List<AppUser>> watch({
    LeaderboardSort sort = LeaderboardSort.totalXp,
    MasteryBoard? board,
    SessionRecordBoard? session,
    int limit = 50,
  }) {
    if (sort == LeaderboardSort.mastery) {
      return watchMastery(board ?? MasteryBoards.defaultBoard, limit: limit);
    }
    if (sort == LeaderboardSort.session) {
      return watchSession(session ?? SessionRecords.defaultBoard, limit: limit);
    }

    final season = Season.current();
    final field = switch (sort) {
      LeaderboardSort.totalXp => 'xp',
      LeaderboardSort.seasonXp => 'seasonXp',
      LeaderboardSort.workouts => 'workoutCount',
      LeaderboardSort.streak => 'streakDays',
      LeaderboardSort.mastery => 'xp',
      LeaderboardSort.session => 'bestSessionXp',
    };

    return _firestore
        .collection('users')
        .orderBy(field, descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
          var users = snap.docs
              .map((doc) => AppUser.fromMap(doc.id, doc.data()))
              .where((u) => u.hasDisplayName && u.showOnLeaderboard)
              .toList();
          if (sort == LeaderboardSort.seasonXp) {
            users = users
                .where((u) => u.seasonId == season.id && u.seasonXp > 0)
                .toList();
          }
          if (sort == LeaderboardSort.streak) {
            users = users.where((u) => u.streakDays > 0).toList();
          }
          return users;
        });
  }

  Stream<List<AppUser>> watchMastery(
    MasteryBoard board, {
    int limit = 50,
  }) {
    return _firestore
        .collection('users')
        .orderBy(board.userField, descending: !board.lowerIsBetter)
        .limit(limit)
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((doc) => AppUser.fromMap(doc.id, doc.data()))
              .where((u) => u.hasDisplayName && u.showOnLeaderboard)
              .where((u) => u.masteryValue(board) > 0)
              .where((u) => !board.isWeight || !u.hideWeights)
              .toList();
        });
  }

  Stream<List<AppUser>> watchSession(
    SessionRecordBoard board, {
    int limit = 50,
  }) {
    return _firestore
        .collection('users')
        .orderBy(board.userField, descending: true)
        .limit(limit)
        .snapshots()
        .map((snap) {
          return snap.docs
              .map((doc) => AppUser.fromMap(doc.id, doc.data()))
              .where((u) => u.hasDisplayName && u.showOnLeaderboard)
              .where((u) => u.sessionRecordValue(board) > 0)
              .where((u) => !board.hideIfWeightsHidden || !u.hideWeights)
              .toList();
        });
  }

  /// Backward-compatible alias.
  Stream<List<AppUser>> watchByXp({int limit = 50}) =>
      watch(sort: LeaderboardSort.totalXp, limit: limit);

  Future<void> backfillMyMasteryIfNeeded() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || _backfilledUids.contains(uid)) return;

    final userRef = _firestore.collection('users').doc(uid);
    final userSnap = await userRef.get();
    final data = userSnap.data() ?? {};
    final needMastery =
        data['masteryBackfilled'] != true ||
        (data['masterySchema'] as num?)?.toInt() != MasteryBoards.schema;
    final needSession = data['sessionRecordsBackfilled'] != true;
    if (!needMastery && !needSession) {
      _backfilledUids.add(uid);
      return;
    }

    final snap = await userRef
        .collection('workouts')
        .orderBy('finishedAt', descending: true)
        .limit(120)
        .get();

    var bests = MasteryBoards.readFromUserData(data);
    var sessions = SessionRecords.readFromUserData(data);
    for (final doc in snap.docs) {
      final workout = SavedWorkout.fromMap(doc.id, doc.data());
      if (needMastery) {
        bests = MasteryBoards.mergeMax(
          bests,
          MasteryBoards.fromExercises(workout.exercises),
        );
      }
      if (needSession) {
        sessions = SessionRecords.mergeMax(sessions, SessionRecords.fromSaved(workout));
      }
    }

    await userRef.set(
      {
        'masteryBackfilled': true,
        'masterySchema': MasteryBoards.schema,
        'sessionRecordsBackfilled': true,
        for (final entry in bests.entries) entry.key: entry.value,
        for (final entry in sessions.entries) entry.key: entry.value,
      },
      SetOptions(merge: true),
    );
    _backfilledUids.add(uid);

    final bestXp = (sessions[SessionRecords.xp.userField] ?? 0).round();
    if (bestXp > 0) {
      try {
        await AchievementRepository().evaluateAndUnlock(
          AchievementEvalContext(
            workoutCount: (data['workoutCount'] as num?)?.toInt() ?? 0,
            totalVolumeKg: (data['totalVolume'] as num?)?.toDouble() ?? 0,
            totalDoneSets: (data['totalDoneSets'] as num?)?.toInt() ?? 0,
            sessionVolumeKg:
                (sessions[SessionRecords.volume.userField] ?? 0).toDouble(),
            sessionDoneSets: 0,
            sessionDurationSec: 0,
            sessionExerciseCount: 0,
            sessionXp: bestXp,
            finishedAt: DateTime.now(),
            rankId: data['rank'] as String? ?? 'novice_1',
            fromTemplate: false,
          ),
        );
      } catch (_) {}
    }
  }
}
