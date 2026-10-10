import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/achievement_evaluator.dart';
import '../domain/user_achievement.dart';

class AchievementUnlockResult {
  const AchievementUnlockResult({required this.levelUps});

  final List<AchievementLevelUp> levelUps;

  /// Для обратной совместимости с summary.
  List<AchievementLevelUp> get newlyUnlocked => levelUps;
}

class AchievementRepository {
  AchievementRepository({
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

  CollectionReference<Map<String, dynamic>> _achievements(String uid) =>
      _firestore.collection('users').doc(uid).collection('achievements');

  Stream<List<UserAchievement>> watchUnlocked() {
    final uid = _uid;
    return _achievements(uid).snapshots().map(
          (snap) => snap.docs
              .map((doc) => UserAchievement.fromMap(doc.id, doc.data()))
              .toList(),
        );
  }

  Future<Map<String, UserAchievement>> fetchAll() async {
    final snap = await _achievements(_uid).get();
    return {
      for (final doc in snap.docs)
        doc.id: UserAchievement.fromMap(doc.id, doc.data()),
    };
  }

  /// Проверяет уровни и пишет прогресс. Идемпотентно.
  Future<AchievementUnlockResult> evaluateAndUnlock(
    AchievementEvalContext ctx,
  ) async {
    final uid = _uid;
    final existing = await fetchAll();
    final result = AchievementEvaluator.evaluate(ctx, existing: existing);
    if (result.updates.isEmpty) {
      return const AchievementUnlockResult(levelUps: []);
    }

    final batch = _firestore.batch();
    for (final update in result.updates) {
      batch.set(
        _achievements(uid).doc(update.id),
        update.toMap(),
        SetOptions(merge: true),
      );
    }
    await batch.commit();
    return AchievementUnlockResult(levelUps: result.levelUps);
  }
}
