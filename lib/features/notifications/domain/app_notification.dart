import 'package:flutter/foundation.dart';

enum AppNotificationType {
  challengeProgress,
  challengeInvite,
  challengeResult,
  groupLead,
  groupGoal,
  overtaken,
  season,
  comment,
}

extension AppNotificationTypeX on AppNotificationType {
  String get wire => switch (this) {
    AppNotificationType.challengeProgress => 'challenge_progress',
    AppNotificationType.challengeInvite => 'challenge_invite',
    AppNotificationType.challengeResult => 'challenge_result',
    AppNotificationType.groupLead => 'group_lead',
    AppNotificationType.groupGoal => 'group_goal',
    AppNotificationType.overtaken => 'overtaken',
    AppNotificationType.season => 'season',
    AppNotificationType.comment => 'comment',
  };

  static AppNotificationType fromWire(String? raw) {
    return AppNotificationType.values.firstWhere(
      (t) => t.wire == raw,
      orElse: () => AppNotificationType.challengeProgress,
    );
  }
}

@immutable
class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
    required this.actorId,
    required this.actorName,
    this.challengeId,
    this.groupChallengeId,
    this.route,
  });

  final String id;
  final AppNotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;
  final String actorId;
  final String actorName;
  final String? challengeId;
  final String? groupChallengeId;
  final String? route;

  String? get deepLink {
    if (route != null && route!.isNotEmpty) return route;
    if (challengeId != null && challengeId!.isNotEmpty) {
      return '/challenges/$challengeId';
    }
    if (groupChallengeId != null && groupChallengeId!.isNotEmpty) {
      return '/challenges/group/$groupChallengeId';
    }
    if (type == AppNotificationType.overtaken) return '/rank';
    if (type == AppNotificationType.season) return '/rank/season';
    return null;
  }

  factory AppNotification.fromMap(String id, Map<String, dynamic> data) {
    return AppNotification(
      id: id,
      type: AppNotificationTypeX.fromWire(data['type'] as String?),
      title: data['title'] as String? ?? '',
      body: data['body'] as String? ?? '',
      createdAt:
          DateTime.tryParse(data['createdAt'] as String? ?? '') ??
          DateTime.now(),
      read: data['read'] as bool? ?? false,
      actorId: data['actorId'] as String? ?? '',
      actorName: data['actorName'] as String? ?? '',
      challengeId: data['challengeId'] as String?,
      groupChallengeId: data['groupChallengeId'] as String?,
      route: data['route'] as String?,
    );
  }

  Map<String, dynamic> toCreateMap() => {
    'type': type.wire,
    'title': title,
    'body': body,
    'createdAt': createdAt.toIso8601String(),
    'read': false,
    'actorId': actorId,
    'actorName': actorName,
    if (challengeId != null) 'challengeId': challengeId,
    if (groupChallengeId != null) 'groupChallengeId': groupChallengeId,
    if (route != null) 'route': route,
  };
}
