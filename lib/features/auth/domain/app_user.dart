import '../../rank/domain/mastery_boards.dart';
import '../../rank/domain/session_records.dart';
import '../../rank/domain/xp_rules.dart';

class AppUser {
  const AppUser({
    required this.uid,
    required this.email,
    this.displayName,
    this.photoUrl,
    this.xp = 0,
    this.rank = 'novice_1',
    this.workoutCount = 0,
    this.totalVolume = 0,
    this.seasonId,
    this.seasonXp = 0,
    this.hideWeights = false,
    this.defaultWorkoutPrivate = false,
    this.showOnLeaderboard = true,
    this.notifyOvertaken = true,
    this.notifySeason = true,
    this.notifyChallenges = true,
    this.notifyStreakReminder = true,
    this.notifyChallengeDeadline = true,
    this.lastRankCheckAt,
    this.masteryBests = const {},
    this.masteryBackfilled = false,
    this.streakDays = 0,
    this.streakBest = 0,
    this.streakFreezes = 0,
    this.streakFreezeXp = 0,
    this.sessionRecords = const {},
  });

  final String uid;
  final String email;
  final String? displayName;
  final String? photoUrl;
  final int xp;
  final String rank;
  final int workoutCount;
  final double totalVolume;
  final String? seasonId;
  final int seasonXp;
  final bool hideWeights;
  final bool defaultWorkoutPrivate;
  final bool showOnLeaderboard;
  final bool notifyOvertaken;
  final bool notifySeason;
  final bool notifyChallenges;
  final bool notifyStreakReminder;
  final bool notifyChallengeDeadline;
  final DateTime? lastRankCheckAt;
  final Map<String, num> masteryBests;
  final bool masteryBackfilled;
  final int streakDays;
  final int streakBest;
  final int streakFreezes;
  final int streakFreezeXp;
  final Map<String, num> sessionRecords;

  bool get hasDisplayName =>
      displayName != null && displayName!.trim().isNotEmpty;

  num masteryValue(MasteryBoard board) => masteryBests[board.userField] ?? 0;

  num sessionRecordValue(SessionRecordBoard board) =>
      sessionRecords[board.userField] ?? 0;

  factory AppUser.fromMap(String uid, Map<String, dynamic> data) {
    final xp = (data['xp'] as num?)?.toInt() ?? 0;
    return AppUser(
      uid: uid,
      email: data['email'] as String? ?? '',
      displayName: data['displayName'] as String?,
      photoUrl: data['photoUrl'] as String?,
      xp: xp,
      rank: XpRules.normalizeRank(data['rank'] as String?, xp),
      workoutCount: (data['workoutCount'] as num?)?.toInt() ?? 0,
      totalVolume: (data['totalVolume'] as num?)?.toDouble() ?? 0,
      seasonId: data['seasonId'] as String?,
      seasonXp: (data['seasonXp'] as num?)?.toInt() ?? 0,
      hideWeights: data['hideWeights'] as bool? ?? false,
      defaultWorkoutPrivate: data['defaultWorkoutPrivate'] as bool? ?? false,
      showOnLeaderboard: data['showOnLeaderboard'] as bool? ?? true,
      notifyOvertaken: data['notifyOvertaken'] as bool? ?? true,
      notifySeason: data['notifySeason'] as bool? ?? true,
      notifyChallenges: data['notifyChallenges'] as bool? ?? true,
      notifyStreakReminder: data['notifyStreakReminder'] as bool? ?? true,
      notifyChallengeDeadline:
          data['notifyChallengeDeadline'] as bool? ?? true,
      lastRankCheckAt:
          DateTime.tryParse(data['lastRankCheckAt'] as String? ?? ''),
      masteryBests: MasteryBoards.readFromUserData(data),
      masteryBackfilled: data['masteryBackfilled'] as bool? ?? false,
      streakDays: (data['streakDays'] as num?)?.toInt() ?? 0,
      streakBest: (data['streakBest'] as num?)?.toInt() ?? 0,
      streakFreezes: (data['streakFreezes'] as num?)?.toInt() ?? 0,
      streakFreezeXp: (data['streakFreezeXp'] as num?)?.toInt() ?? 0,
      sessionRecords: SessionRecords.readFromUserData(data),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      if (photoUrl != null && photoUrl!.trim().isNotEmpty) 'photoUrl': photoUrl,
      'xp': xp,
      'rank': rank,
      'workoutCount': workoutCount,
      'totalVolume': totalVolume,
      'seasonId': seasonId,
      'seasonXp': seasonXp,
      'hideWeights': hideWeights,
      'defaultWorkoutPrivate': defaultWorkoutPrivate,
      'showOnLeaderboard': showOnLeaderboard,
      'notifyOvertaken': notifyOvertaken,
      'notifySeason': notifySeason,
      'notifyChallenges': notifyChallenges,
      'notifyStreakReminder': notifyStreakReminder,
      'notifyChallengeDeadline': notifyChallengeDeadline,
      if (lastRankCheckAt != null)
        'lastRankCheckAt': lastRankCheckAt!.toIso8601String(),
      'masteryBackfilled': masteryBackfilled,
      'streakDays': streakDays,
      'streakBest': streakBest,
      'streakFreezes': streakFreezes,
      'streakFreezeXp': streakFreezeXp,
      ...{
        for (final board in MasteryBoards.all)
          if ((masteryBests[board.userField] ?? 0) > 0)
            board.userField: masteryBests[board.userField],
      },
      ...{
        for (final board in SessionRecords.all)
          if ((sessionRecords[board.userField] ?? 0) > 0)
            board.userField: sessionRecords[board.userField],
      },
    };
  }

  AppUser copyWith({
    String? displayName,
    String? photoUrl,
    int? xp,
    String? rank,
    int? workoutCount,
    double? totalVolume,
    String? seasonId,
    int? seasonXp,
    bool? hideWeights,
    bool? defaultWorkoutPrivate,
    bool? showOnLeaderboard,
    bool? notifyOvertaken,
    bool? notifySeason,
    bool? notifyChallenges,
    bool? notifyStreakReminder,
    bool? notifyChallengeDeadline,
    DateTime? lastRankCheckAt,
    Map<String, num>? masteryBests,
    bool? masteryBackfilled,
    int? streakDays,
    int? streakBest,
    int? streakFreezes,
    int? streakFreezeXp,
    Map<String, num>? sessionRecords,
  }) {
    return AppUser(
      uid: uid,
      email: email,
      displayName: displayName ?? this.displayName,
      photoUrl: photoUrl ?? this.photoUrl,
      xp: xp ?? this.xp,
      rank: rank ?? this.rank,
      workoutCount: workoutCount ?? this.workoutCount,
      totalVolume: totalVolume ?? this.totalVolume,
      seasonId: seasonId ?? this.seasonId,
      seasonXp: seasonXp ?? this.seasonXp,
      hideWeights: hideWeights ?? this.hideWeights,
      defaultWorkoutPrivate:
          defaultWorkoutPrivate ?? this.defaultWorkoutPrivate,
      showOnLeaderboard: showOnLeaderboard ?? this.showOnLeaderboard,
      notifyOvertaken: notifyOvertaken ?? this.notifyOvertaken,
      notifySeason: notifySeason ?? this.notifySeason,
      notifyChallenges: notifyChallenges ?? this.notifyChallenges,
      notifyStreakReminder:
          notifyStreakReminder ?? this.notifyStreakReminder,
      notifyChallengeDeadline:
          notifyChallengeDeadline ?? this.notifyChallengeDeadline,
      lastRankCheckAt: lastRankCheckAt ?? this.lastRankCheckAt,
      masteryBests: masteryBests ?? this.masteryBests,
      masteryBackfilled: masteryBackfilled ?? this.masteryBackfilled,
      streakDays: streakDays ?? this.streakDays,
      streakBest: streakBest ?? this.streakBest,
      streakFreezes: streakFreezes ?? this.streakFreezes,
      streakFreezeXp: streakFreezeXp ?? this.streakFreezeXp,
      sessionRecords: sessionRecords ?? this.sessionRecords,
    );
  }
}
