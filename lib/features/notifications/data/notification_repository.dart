import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../domain/app_notification.dart';

class NotificationRepository {
  NotificationRepository({FirebaseAuth? auth, FirebaseFirestore? firestore})
    : _auth = auth ?? FirebaseAuth.instance,
      _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  String? get _uid => _auth.currentUser?.uid;

  CollectionReference<Map<String, dynamic>> _inbox(String uid) =>
      _firestore.collection('users').doc(uid).collection('notifications');

  Stream<List<AppNotification>> watchMine({int limit = 60}) {
    final uid = _uid;
    if (uid == null) return const Stream.empty();
    return _inbox(uid)
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => AppNotification.fromMap(d.id, d.data()))
              .toList(),
        );
  }

  Stream<int> watchUnreadCount() {
    final uid = _uid;
    if (uid == null) return Stream.value(0);
    return _inbox(uid)
        .where('read', isEqualTo: false)
        .limit(40)
        .snapshots()
        .map((snap) => snap.docs.length);
  }

  Future<void> markRead(String id) async {
    final uid = _uid;
    if (uid == null) return;
    await _inbox(uid).doc(id).set({'read': true}, SetOptions(merge: true));
  }

  Future<void> markAllRead() async {
    final uid = _uid;
    if (uid == null) return;
    final unread = await _inbox(uid)
        .where('read', isEqualTo: false)
        .limit(80)
        .get();
    if (unread.docs.isEmpty) return;
    final batch = _firestore.batch();
    for (final doc in unread.docs) {
      batch.set(doc.reference, {'read': true}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  /// Пишет уведомление получателю от текущего пользователя (actorId).
  Future<void> createForUser({
    required String recipientId,
    required AppNotificationType type,
    required String title,
    required String body,
    required String actorId,
    required String actorName,
    String? challengeId,
    String? groupChallengeId,
    String? route,
  }) async {
    if (recipientId.isEmpty || actorId.isEmpty) return;

    final allowed = await _recipientAllows(recipientId, type);
    if (!allowed) return;

    final notif = AppNotification(
      id: '',
      type: type,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      read: false,
      actorId: actorId,
      actorName: actorName,
      challengeId: challengeId,
      groupChallengeId: groupChallengeId,
      route: route,
    );
    await _inbox(recipientId).add(notif.toCreateMap());
  }

  Future<bool> _recipientAllows(
    String recipientId,
    AppNotificationType type,
  ) async {
    final snap = await _firestore.collection('users').doc(recipientId).get();
    final data = snap.data() ?? {};
    return switch (type) {
      AppNotificationType.challengeProgress ||
      AppNotificationType.challengeInvite ||
      AppNotificationType.challengeResult ||
      AppNotificationType.groupLead ||
      AppNotificationType.groupGoal =>
        data['notifyChallenges'] as bool? ?? true,
      AppNotificationType.overtaken => data['notifyOvertaken'] as bool? ?? true,
      AppNotificationType.season => data['notifySeason'] as bool? ?? true,
      AppNotificationType.comment => data['notifyComments'] as bool? ?? true,
    };
  }
}
