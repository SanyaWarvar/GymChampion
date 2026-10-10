import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../auth/domain/app_user.dart';
import '../../workout/domain/saved_workout.dart';
import '../domain/feed_post.dart';

class FeedRepository {
  FeedRepository({
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
    final commentRef = _comments(postId).doc();
    final batch = _firestore.batch();
    batch.set(commentRef, {
      'userId': uid,
      'displayName': displayName,
      'text': trimmed,
      'createdAt': DateTime.now().toIso8601String(),
    });
    batch.update(_feed.doc(postId), {
      'commentCount': FieldValue.increment(1),
    });
    await batch.commit();
  }
}
