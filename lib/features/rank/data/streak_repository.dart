import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../notifications/data/notification_repository.dart';
import '../../notifications/domain/app_notification.dart';
import '../domain/season.dart';
import '../domain/streak_rules.dart';
import '../domain/xp_rules.dart';

class StreakRepository {
  StreakRepository({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    NotificationRepository? notifications,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _notifications = notifications ?? NotificationRepository();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final NotificationRepository _notifications;

  static String? _syncedKey;

  DocumentReference<Map<String, dynamic>> get _userRef {
    final uid = _auth.currentUser?.uid;
    if (uid == null) throw StateError('Нет авторизованного пользователя');
    return _firestore.collection('users').doc(uid);
  }

  Future<void> ensureSynced({DateTime? now}) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final today = StreakRules.formatDate(now ?? DateTime.now());
    final key = '$uid-$today';
    if (_syncedKey == key) return;

    final userRef = _userRef;
    final snap = await userRef.get();
    final data = snap.data() ?? {};
    final alreadyLive = data['streakBackfilled'] == true;
    var state = StreakState.fromUserData(data);
    var penalizedDays = 0;

    if (!alreadyLive) {
      final workouts = await userRef
          .collection('workouts')
          .orderBy('finishedAt', descending: true)
          .limit(120)
          .get();
      final byDay = <DateTime, int>{};
      for (final doc in workouts.docs) {
        final raw = doc.data()['finishedAt'] as String? ?? '';
        final at = DateTime.tryParse(raw) ?? DateTime.now();
        final day = StreakRules.dateOnly(at);
        final xp = (doc.data()['xpEarned'] as num?)?.toInt() ?? 0;
        byDay[day] = (byDay[day] ?? 0) + xp;
      }
      final days = byDay.keys.toList()..sort();
      state = StreakRules.fromWorkoutDates(
        days,
        now: now,
        xpPerDate: days.map((d) => byDay[d] ?? 0),
      );
    } else {
      final result = StreakRules.applyClock(state, now ?? DateTime.now());
      state = result.state;
      penalizedDays = result.penalizedDays.clamp(0, XpRules.maxMissedDaysPerSync);
    }

    final payload = <String, dynamic>{
      ...state.toUserFields(),
      'streakBackfilled': true,
    };

    final xp = (data['xp'] as num?)?.toInt() ?? 0;
    final season = Season.current(now);
    final sameSeason = data['seasonId'] == season.id;
    final seasonXp = sameSeason ? ((data['seasonXp'] as num?)?.toInt() ?? 0) : 0;
    payload['seasonId'] = season.id;

    if (alreadyLive && penalizedDays > 0) {
      final applied = XpRules.applyMissedDays(
        xp: xp,
        seasonXp: seasonXp,
        days: penalizedDays,
      );
      payload.addAll({
        'xp': applied.xp,
        'seasonXp': applied.seasonXp,
        'rank': XpRules.rankForXp(applied.xp),
        'lastXpPenaltyDays': penalizedDays,
        'lastXpPenalty': applied.lost,
        'lastXpPenaltyAt': DateTime.now().toIso8601String(),
      });
    } else {
      payload['rank'] = XpRules.rankForXp(xp);
      if (!sameSeason) payload['seasonXp'] = 0;
    }

    await userRef.set(payload, SetOptions(merge: true));
    _syncedKey = key;

    if (!sameSeason && data['seasonId'] != null) {
      try {
        final name = data['displayName'] as String? ?? 'Ты';
        await _notifications.createForUser(
          recipientId: uid,
          type: AppNotificationType.season,
          title: 'Новый сезон',
          body: '${season.title} · сезонный XP обнулён',
          actorId: uid,
          actorName: name,
          route: '/rank/season',
        );
      } catch (_) {}
    }
  }
}
