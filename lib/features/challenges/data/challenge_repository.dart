import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../auth/domain/app_user.dart';
import '../../notifications/data/notification_repository.dart';
import '../../notifications/domain/app_notification.dart';
import '../../workout/domain/saved_workout.dart';
import '../domain/challenge.dart';
import '../domain/group_challenge.dart';

class ChallengeRepository {
  ChallengeRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    NotificationRepository? notifications,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _notifications = notifications ?? NotificationRepository();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final NotificationRepository _notifications;

  String get _uid {
    final user = _auth.currentUser;
    if (user == null) throw StateError('Нет авторизованного пользователя');
    return user.uid;
  }

  CollectionReference<Map<String, dynamic>> get _challenges =>
      _firestore.collection('challenges');

  CollectionReference<Map<String, dynamic>> get _groupChallenges =>
      _firestore.collection('group_challenges');

  Stream<List<Challenge>> watchMyChallenges() {
    final uid = _uid;
    return _challenges
        .where('participantIds', arrayContains: uid)
        .limit(40)
        .snapshots()
        .map((snap) {
          final list = snap.docs
              .map((d) => Challenge.fromMap(d.id, d.data()))
              .toList()
            ..sort((a, b) => b.endsAt.compareTo(a.endsAt));
          return list;
        });
  }

  Future<Challenge?> fetchChallenge(String id) async {
    final snap = await _challenges.doc(id).get();
    if (!snap.exists || snap.data() == null) return null;
    return Challenge.fromMap(snap.id, snap.data()!);
  }

  Stream<Challenge?> watchChallenge(String id) {
    return _challenges.doc(id).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return Challenge.fromMap(snap.id, snap.data()!);
    });
  }

  Future<String> createChallenge({
    required AppUser me,
    required AppUser opponent,
    required ChallengeMetric metric,
    int days = 7,
  }) async {
    final now = DateTime.now();
    final ends = now.add(Duration(days: days));
    final doc = _challenges.doc();
    await doc.set({
      'challengerId': me.uid,
      'challengerName': me.displayName ?? 'Без имени',
      'opponentId': opponent.uid,
      'opponentName': opponent.displayName ?? 'Без имени',
      'participantIds': [me.uid, opponent.uid],
      'metric': metric.name,
      'status': ChallengeStatus.pending.name,
      'startsAt': now.toIso8601String(),
      'endsAt': ends.toIso8601String(),
      'challengerScore': 0,
      'opponentScore': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    final actorName = me.displayName ?? 'Без имени';
    try {
      await _notifications.createForUser(
        recipientId: opponent.uid,
        type: AppNotificationType.challengeInvite,
        title: 'Новый вызов',
        body: '$actorName вызвал тебя · ${metric.label}',
        actorId: me.uid,
        actorName: actorName,
        challengeId: doc.id,
      );
    } catch (_) {}

    return doc.id;
  }

  Future<void> accept(String challengeId) async {
    final snap = await _challenges.doc(challengeId).get();
    final data = snap.data();
    await _challenges.doc(challengeId).set({
      'status': ChallengeStatus.active.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (data == null) return;
    final c = Challenge.fromMap(challengeId, data);
    final me = _uid;
    final actorName =
        me == c.opponentId ? c.opponentName : c.challengerName;
    final recipientId =
        me == c.opponentId ? c.challengerId : c.opponentId;
    try {
      await _notifications.createForUser(
        recipientId: recipientId,
        type: AppNotificationType.challengeInvite,
        title: 'Вызов принят',
        body: '$actorName принял вызов',
        actorId: me,
        actorName: actorName,
        challengeId: challengeId,
      );
    } catch (_) {}
  }

  Future<void> decline(String challengeId) async {
    await _challenges.doc(challengeId).set({
      'status': ChallengeStatus.declined.name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Обновляет счётчики активных вызовов после тренировки.
  Future<void> applyWorkoutToChallenges({
    required String userId,
    required SavedWorkout workout,
    required int xpEarned,
    String? actorName,
  }) async {
    final snap = await _challenges
        .where('participantIds', arrayContains: userId)
        .get();

    if (snap.docs.isEmpty) {
      await applyWorkoutToGroupChallenges(
        userId: userId,
        workout: workout,
        xpEarned: xpEarned,
        actorName: actorName,
      );
      return;
    }

    final batch = _firestore.batch();
    final now = DateTime.now();
    var writes = 0;
    final progressEvents = <_ChallengeProgressEvent>[];
    final completedEvents = <Challenge>[];

    for (final doc in snap.docs) {
      final data = doc.data();
      if (data['kind'] == 'group') continue;
      final c = Challenge.fromMap(doc.id, data);
      if (c.status != ChallengeStatus.active &&
          c.status != ChallengeStatus.pending) {
        continue;
      }
      if (now.isAfter(c.endsAt)) {
        batch.set(
          doc.reference,
          {'status': ChallengeStatus.completed.name},
          SetOptions(merge: true),
        );
        writes++;
        completedEvents.add(c);
        continue;
      }
      if (c.status != ChallengeStatus.active) continue;
      final isChallenger = c.challengerId == userId;
      final field =
          isChallenger ? 'challengerScore' : 'opponentScore';
      final delta = switch (c.metric) {
        ChallengeMetric.volume => workout.volumeKg,
        ChallengeMetric.workouts => 1.0,
        ChallengeMetric.xp => xpEarned.toDouble(),
        ChallengeMetric.run => workout.runKm,
      };
      if (delta <= 0) continue;
      batch.update(doc.reference, {field: FieldValue.increment(delta)});
      writes++;

      final myScore =
          (isChallenger ? c.challengerScore : c.opponentScore) + delta;
      final theirScore =
          isChallenger ? c.opponentScore : c.challengerScore;
      final recipientId =
          isChallenger ? c.opponentId : c.challengerId;
      progressEvents.add(
        _ChallengeProgressEvent(
          challenge: c,
          delta: delta,
          myScore: myScore,
          theirScore: theirScore,
          recipientId: recipientId,
          leading: myScore >= theirScore,
        ),
      );
    }
    if (writes > 0) await batch.commit();

    final name = actorName ?? 'Участник';
    for (final event in progressEvents) {
      try {
        final lead = event.leading ? ' · лидирует' : '';
        await _notifications.createForUser(
          recipientId: event.recipientId,
          type: AppNotificationType.challengeProgress,
          title: 'Прогресс в вызове',
          body:
              '$name ${event.challenge.metric.progressVerb(event.delta)}$lead',
          actorId: userId,
          actorName: name,
          challengeId: event.challenge.id,
        );
      } catch (_) {}
    }

    for (final c in completedEvents) {
      await _notifyChallengeResult(c, actorId: userId, actorName: name);
    }

    await applyWorkoutToGroupChallenges(
      userId: userId,
      workout: workout,
      xpEarned: xpEarned,
      actorName: actorName,
    );
  }

  Future<void> _notifyChallengeResult(
    Challenge c, {
    required String actorId,
    required String actorName,
  }) async {
    final winnerId = c.challengerScore == c.opponentScore
        ? null
        : (c.challengerScore > c.opponentScore
            ? c.challengerId
            : c.opponentId);
    final winnerName = winnerId == null
        ? null
        : (winnerId == c.challengerId ? c.challengerName : c.opponentName);
    final body = winnerName == null
        ? 'Вызов окончен · ничья'
        : 'Вызов окончен · победа: $winnerName';

    for (final recipientId in [c.challengerId, c.opponentId]) {
      if (recipientId == actorId) continue;
      try {
        await _notifications.createForUser(
          recipientId: recipientId,
          type: AppNotificationType.challengeResult,
          title: 'Итог вызова',
          body: body,
          actorId: actorId,
          actorName: actorName,
          challengeId: c.id,
        );
      } catch (_) {}
    }
  }

  Stream<List<GroupChallenge>> watchGroupChallenges() {
    return _groupChallenges.limit(30).snapshots().map((snap) {
      final list = snap.docs
          .map((d) => GroupChallenge.fromMap(d.id, d.data()))
          .toList()
        ..sort((a, b) => b.endsAt.compareTo(a.endsAt));
      return list;
    });
  }

  Stream<GroupChallenge?> watchGroupChallenge(String id) {
    return _groupChallenges.doc(id).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return GroupChallenge.fromMap(snap.id, snap.data()!);
    });
  }

  Future<String> createGroupChallenge({
    required AppUser me,
    required String title,
    required ChallengeMetric metric,
    required double target,
    int days = 30,
  }) async {
    final usersSnap = await _firestore
        .collection('users')
        .orderBy('xp', descending: true)
        .limit(40)
        .get();
    final names = <String, String>{me.uid: me.displayName ?? 'Я'};
    final scores = <String, double>{me.uid: 0};
    final ids = <String>{me.uid};
    for (final doc in usersSnap.docs) {
      final user = AppUser.fromMap(doc.id, doc.data());
      if (!user.hasDisplayName || !user.showOnLeaderboard) continue;
      ids.add(user.uid);
      names[user.uid] = user.displayName ?? 'Без имени';
      scores[user.uid] = 0;
    }

    final now = DateTime.now();
    final doc = _groupChallenges.doc();
    await doc.set({
      'kind': 'group',
      'title': title.trim().isEmpty ? 'Общая цель' : title.trim(),
      'creatorId': me.uid,
      'metric': metric.name,
      'target': target,
      'status': GroupChallengeStatus.active.name,
      'startsAt': now.toIso8601String(),
      'endsAt': now.add(Duration(days: days)).toIso8601String(),
      'participantIds': ids.toList(),
      'names': names,
      'scores': scores,
      'totalScore': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  Future<void> joinGroupChallenge({
    required String challengeId,
    required AppUser me,
  }) async {
    await _groupChallenges.doc(challengeId).set({
      'participantIds': FieldValue.arrayUnion([me.uid]),
      'names.${me.uid}': me.displayName ?? 'Без имени',
      'scores.${me.uid}': 0,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> applyWorkoutToGroupChallenges({
    required String userId,
    required SavedWorkout workout,
    required int xpEarned,
    String? actorName,
  }) async {
    final snap = await _groupChallenges
        .where('participantIds', arrayContains: userId)
        .get();
    if (snap.docs.isEmpty) return;

    final batch = _firestore.batch();
    final now = DateTime.now();
    var writes = 0;
    final leadEvents = <_GroupLeadEvent>[];
    final goalEvents = <GroupChallenge>[];

    for (final doc in snap.docs) {
      final c = GroupChallenge.fromMap(doc.id, doc.data());
      if (now.isAfter(c.endsAt) || c.reached) {
        if (c.status != GroupChallengeStatus.completed) {
          batch.set(
            doc.reference,
            {'status': GroupChallengeStatus.completed.name},
            SetOptions(merge: true),
          );
          writes++;
        }
        continue;
      }
      if (c.status != GroupChallengeStatus.active) continue;
      final delta = switch (c.metric) {
        ChallengeMetric.volume => workout.volumeKg,
        ChallengeMetric.workouts => 1.0,
        ChallengeMetric.xp => xpEarned.toDouble(),
        ChallengeMetric.run => workout.runKm,
      };
      if (delta <= 0) continue;

      final prevLeader = _leaderId(c.scores);
      final nextScores = Map<String, double>.from(c.scores);
      nextScores[userId] = (nextScores[userId] ?? 0) + delta;
      final nextLeader = _leaderId(nextScores);
      final nextTotal = c.totalScore + delta;
      final goalReached = nextTotal >= c.target;

      batch.update(doc.reference, {
        'scores.$userId': FieldValue.increment(delta),
        'totalScore': FieldValue.increment(delta),
        if (goalReached) 'status': GroupChallengeStatus.completed.name,
      });
      writes++;

      if (nextLeader == userId && prevLeader != userId) {
        leadEvents.add(_GroupLeadEvent(challenge: c, recipientIds: [
          for (final id in c.participantIds)
            if (id != userId) id,
        ]));
      }
      if (goalReached) {
        goalEvents.add(c);
      }
    }
    if (writes > 0) await batch.commit();

    final name = actorName ?? 'Участник';
    for (final event in leadEvents) {
      for (final recipientId in event.recipientIds) {
        try {
          await _notifications.createForUser(
            recipientId: recipientId,
            type: AppNotificationType.groupLead,
            title: 'Смена лидера',
            body: '$name вышел в лидеры в «${event.challenge.title}»',
            actorId: userId,
            actorName: name,
            groupChallengeId: event.challenge.id,
          );
        } catch (_) {}
      }
    }

    for (final c in goalEvents) {
      for (final recipientId in c.participantIds) {
        if (recipientId == userId) continue;
        try {
          await _notifications.createForUser(
            recipientId: recipientId,
            type: AppNotificationType.groupGoal,
            title: 'Цель набрана',
            body: 'Общая цель «${c.title}» достигнута',
            actorId: userId,
            actorName: name,
            groupChallengeId: c.id,
          );
        } catch (_) {}
      }
    }
  }

  String? _leaderId(Map<String, double> scores) {
    if (scores.isEmpty) return null;
    String? bestId;
    var best = -1.0;
    for (final e in scores.entries) {
      if (e.value > best) {
        best = e.value;
        bestId = e.key;
      }
    }
    return bestId;
  }
}

class _ChallengeProgressEvent {
  const _ChallengeProgressEvent({
    required this.challenge,
    required this.delta,
    required this.myScore,
    required this.theirScore,
    required this.recipientId,
    required this.leading,
  });

  final Challenge challenge;
  final double delta;
  final double myScore;
  final double theirScore;
  final String recipientId;
  final bool leading;
}

class _GroupLeadEvent {
  const _GroupLeadEvent({
    required this.challenge,
    required this.recipientIds,
  });

  final GroupChallenge challenge;
  final List<String> recipientIds;
}
