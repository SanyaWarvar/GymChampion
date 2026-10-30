import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../auth/domain/app_user.dart';
import '../../notifications/data/notification_repository.dart';
import '../../notifications/domain/app_notification.dart';
import '../../workout/domain/saved_workout.dart';
import '../domain/feed_post.dart';

class FeedRepository {
  FeedRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    NotificationRepository? notifications,
  }) : _auth = auth ?? FirebaseAuth.instance,
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

  CollectionReference<Map<String, dynamic>> get _feed =>
      _firestore.collection('feed');

  CollectionReference<Map<String, dynamic>> _comments(String postId) =>
      _feed.doc(postId).collection('comments');

  /// Стабильный id поста по тренировке — удобно удалять при приватности.
  static String workoutPostId(String userId, String workoutId) =>
      'workout_${userId}_$workoutId';

  Stream<List<FeedPost>> watchFeed({int limit = 40}) {
    return _feed
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => FeedPost.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<FeedPost?> fetchPost(String postId) async {
    final snap = await _feed.doc(postId).get();
    if (!snap.exists || snap.data() == null) return null;
    return FeedPost.fromMap(snap.id, snap.data()!);
  }

  Stream<FeedPost?> watchPost(String postId) {
    return _feed.doc(postId).snapshots().map((snap) {
      if (!snap.exists || snap.data() == null) return null;
      return FeedPost.fromMap(snap.id, snap.data()!);
    });
  }

  Stream<List<FeedComment>> watchComments(String postId) {
    return _comments(postId)
        .orderBy('createdAt', descending: false)
        .limit(100)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((doc) => FeedComment.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<void> publishWorkoutPost({
    required AppUser author,
    required SavedWorkout workout,
  }) async {
    if (workout.isPrivate) return;
    final id = workoutPostId(author.uid, workout.id);
    final post = FeedPost(
      id: id,
      type: FeedPostType.workout,
      userId: author.uid,
      displayName: author.displayName ?? 'Без имени',
      createdAt: workout.finishedAt,
      workoutId: workout.id,
      volumeKg: workout.volumeKg,
      runKm: workout.runKm,
      doneSets: workout.doneSets,
      exerciseCount: workout.exerciseCount,
      xpEarned: workout.xpEarned,
      durationSec: workout.durationSec,
      rankId: author.rank,
      exercises: exercisesFromWorkout(workout),
      hideSetDetails: author.hideWeights,
    );
    await _feed.doc(id).set({
      ...post.toMap(),
      'serverCreatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  static String stepsDayPostId(String userId, String dayKey) =>
      'steps_${userId}_$dayKey';

  Future<void> publishStepsDayPost({
    required AppUser author,
    required String dayKey,
    required int steps,
    required int xpEarned,
    required DateTime at,
  }) async {
    final id = stepsDayPostId(author.uid, dayKey);
    final post = FeedPost(
      id: id,
      type: FeedPostType.stepsDay,
      userId: author.uid,
      displayName: author.displayName ?? 'Без имени',
      createdAt: at,
      xpEarned: xpEarned,
      steps: steps,
      rankId: author.rank,
    );
    await _feed.doc(id).set({
      ...post.toMap(),
      'serverCreatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> removeWorkoutPost({
    required String userId,
    required String workoutId,
  }) async {
    await _feed.doc(workoutPostId(userId, workoutId)).delete();
  }

  Future<void> setReaction({
    required String postId,
    required FeedReaction reaction,
  }) async {
    final uid = _uid;
    final ref = _feed.doc(postId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      final reactions = Map<String, dynamic>.from(
        (data['reactions'] as Map?)?.cast<String, dynamic>() ?? {},
      );
      final current = reactions[uid] as String?;
      if (current == reaction.key) {
        reactions.remove(uid);
      } else {
        reactions[uid] = reaction.key;
      }
      tx.update(ref, {'reactions': reactions});
    });
  }

  Future<void> addComment({
    required String postId,
    required String text,
    required String displayName,
  }) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final uid = _uid;
    final postSnap = await _feed.doc(postId).get();
    if (!postSnap.exists) return;
    final authorId = postSnap.data()?['userId'] as String? ?? '';
    final commentRef = _comments(postId).doc();
    final batch = _firestore.batch();
    batch.set(commentRef, {
      'userId': uid,
      'displayName': displayName,
      'text': trimmed,
      'createdAt': DateTime.now().toIso8601String(),
    });
    batch.update(_feed.doc(postId), {'commentCount': FieldValue.increment(1)});
    await batch.commit();
    if (authorId.isEmpty || authorId == uid) return;
    final preview = trimmed.length > 140
        ? '${trimmed.substring(0, 140)}…'
        : trimmed;
    try {
      await _notifications.createForUser(
        recipientId: authorId,
        type: AppNotificationType.comment,
        title: 'Новый комментарий',
        body: '$displayName: $preview',
        actorId: uid,
        actorName: displayName,
        route: '/feed/$postId',
      );
    } catch (_) {}
  }

  /// Текущая настройка «скрывать веса». Свой пост всегда с подходами.
  Future<bool> hideLoadsFor(FeedPost post) async {
    final viewer = _auth.currentUser?.uid;
    if (viewer != null && viewer == post.userId) return false;
    if (post.userId.isEmpty) return post.hideSetDetails;
    try {
      final snap = await _firestore.collection('users').doc(post.userId).get();
      final live = snap.data()?['hideWeights'] as bool?;
      if (live != null) return live;
    } catch (_) {}
    return post.hideSetDetails;
  }

  /// Упражнения поста. Если в ленте их ещё нет, читает саму тренировку.
  Future<List<FeedExercise>> loadExercises(FeedPost post) async {
    if (post.exercises.isNotEmpty) return post.exercises;
    final workoutId = post.workoutId;
    if (post.type != FeedPostType.workout ||
        workoutId == null ||
        workoutId.isEmpty ||
        post.userId.isEmpty) {
      return const [];
    }
    try {
      final snap = await _firestore
          .collection('users')
          .doc(post.userId)
          .collection('workouts')
          .doc(workoutId)
          .get();
      if (!snap.exists || snap.data() == null) return const [];
      final workout = SavedWorkout.fromMap(snap.id, snap.data()!);
      if (workout.isPrivate && _auth.currentUser?.uid != post.userId) {
        return const [];
      }
      return exercisesFromWorkout(workout);
    } catch (_) {
      return const [];
    }
  }

  static List<FeedExercise> exercisesFromWorkout(SavedWorkout workout) {
    return [
      for (final exercise in workout.exercises)
        if (exercise.name.trim().isNotEmpty)
          FeedExercise(
            name: exercise.name,
            exerciseId: exercise.exerciseId,
            sets: [
              for (final set in exercise.sets)
                if (set.done && set.hasWork)
                  FeedSet(weightKg: set.weightKg, reps: set.reps),
            ],
          ),
    ].where((e) => e.sets.isNotEmpty).toList();
  }
}
