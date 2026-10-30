import 'package:flutter/foundation.dart';

import '../../workout/domain/exercise_catalog.dart';

enum FeedPostType { workout, rankUp, achievement, challenge, stepsDay }

enum FeedReaction { like, krasava, slabak }

extension FeedReactionX on FeedReaction {
  String get key => name;

  String get label => switch (this) {
    FeedReaction.like => 'Лайк',
    FeedReaction.krasava => 'Красава',
    FeedReaction.slabak => 'Слабак',
  };

  String get emoji => switch (this) {
    FeedReaction.like => '👍',
    FeedReaction.krasava => '🔥',
    FeedReaction.slabak => '🤡',
  };

  static FeedReaction? tryParse(String? raw) {
    if (raw == null) return null;
    for (final r in FeedReaction.values) {
      if (r.name == raw) return r;
    }
    return null;
  }
}

@immutable
class FeedComment {
  const FeedComment({
    required this.id,
    required this.userId,
    required this.displayName,
    required this.text,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String displayName;
  final String text;
  final DateTime createdAt;

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'displayName': displayName,
    'text': text,
    'createdAt': createdAt.toIso8601String(),
  };

  factory FeedComment.fromMap(String id, Map<String, dynamic> data) {
    return FeedComment(
      id: id,
      userId: data['userId'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'Без имени',
      text: data['text'] as String? ?? '',
      createdAt:
          DateTime.tryParse(data['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

@immutable
class FeedSet {
  const FeedSet({required this.weightKg, required this.reps});

  final double weightKg;
  final int reps;

  Map<String, dynamic> toMap() => {'weightKg': weightKg, 'reps': reps};

  factory FeedSet.fromMap(Map<String, dynamic> data) {
    return FeedSet(
      weightKg: (data['weightKg'] as num?)?.toDouble() ?? 0,
      reps: (data['reps'] as num?)?.toInt() ?? 0,
    );
  }
}

@immutable
class FeedExercise {
  const FeedExercise({
    required this.name,
    this.exerciseId,
    this.sets = const [],
  });

  final String name;
  final String? exerciseId;
  final List<FeedSet> sets;

  Map<String, dynamic> toMap() => {
    'name': name,
    if (exerciseId != null && exerciseId!.isNotEmpty) 'exerciseId': exerciseId,
    'sets': sets.map((s) => s.toMap()).toList(),
  };

  factory FeedExercise.fromMap(Map<String, dynamic> data) {
    final setsRaw = data['sets'] as List<dynamic>? ?? const [];
    return FeedExercise(
      name: data['name'] as String? ?? '',
      exerciseId: data['exerciseId'] as String?,
      sets: setsRaw
          .whereType<Map>()
          .map((s) => FeedSet.fromMap(Map<String, dynamic>.from(s)))
          .toList(),
    );
  }
}

@immutable
class FeedPost {
  const FeedPost({
    required this.id,
    required this.type,
    required this.userId,
    required this.displayName,
    required this.createdAt,
    this.workoutId,
    this.volumeKg = 0,
    this.runKm = 0,
    this.doneSets = 0,
    this.exerciseCount = 0,
    this.xpEarned = 0,
    this.durationSec = 0,
    this.rankId,
    this.achievementTitle,
    this.steps = 0,
    this.reactions = const {},
    this.commentCount = 0,
    this.exercises = const [],
    this.hideSetDetails = false,
  });

  final String id;
  final FeedPostType type;
  final String userId;
  final String displayName;
  final DateTime createdAt;
  final String? workoutId;
  final double volumeKg;
  final double runKm;
  final int doneSets;
  final int exerciseCount;
  final int xpEarned;
  final int durationSec;
  final String? rankId;
  final String? achievementTitle;
  final int steps;

  /// userId -> reaction key
  final Map<String, String> reactions;
  final int commentCount;
  final List<FeedExercise> exercises;

  /// Автор скрывает веса: в чужой ленте видны названия, без кг и повторов.
  final bool hideSetDetails;

  int reactionCount(FeedReaction reaction) =>
      reactions.values.where((v) => v == reaction.key).length;

  FeedReaction? myReaction(String uid) =>
      FeedReactionX.tryParse(reactions[uid]);

  String get headline => switch (type) {
    FeedPostType.workout => 'завершил тренировку',
    FeedPostType.rankUp => 'поднял медаль',
    FeedPostType.achievement => 'открыл достижение',
    FeedPostType.challenge => 'бросил вызов',
    FeedPostType.stepsDay => 'набил дневную норму шагов',
  };

  String workoutStatsLine({bool includeXp = true}) {
    final load = ExerciseCatalog.formatLoad(volumeKg: volumeKg, runKm: runKm);
    return [
      if (load.isNotEmpty) load,
      '$doneSets подходов',
      '$exerciseCount упр.',
      if (includeXp) '+$xpEarned XP',
    ].join(' · ');
  }

  Map<String, dynamic> toMap() => {
    'type': type.name,
    'userId': userId,
    'displayName': displayName,
    'createdAt': createdAt.toIso8601String(),
    'workoutId': workoutId,
    'volumeKg': volumeKg,
    'runKm': runKm,
    'doneSets': doneSets,
    'exerciseCount': exerciseCount,
    'xpEarned': xpEarned,
    'durationSec': durationSec,
    'rankId': rankId,
    'achievementTitle': achievementTitle,
    'steps': steps,
    'reactions': reactions,
    'commentCount': commentCount,
    'exercises': exercises.map((e) => e.toMap()).toList(),
    'hideSetDetails': hideSetDetails,
  };

  factory FeedPost.fromMap(String id, Map<String, dynamic> data) {
    final typeName = data['type'] as String? ?? 'workout';
    final type = FeedPostType.values.firstWhere(
      (t) => t.name == typeName,
      orElse: () => FeedPostType.workout,
    );
    final reactionsRaw = data['reactions'];
    final reactions = <String, String>{};
    if (reactionsRaw is Map) {
      reactionsRaw.forEach((k, v) {
        if (k is String && v is String) reactions[k] = v;
      });
    }
    return FeedPost(
      id: id,
      type: type,
      userId: data['userId'] as String? ?? '',
      displayName: data['displayName'] as String? ?? 'Без имени',
      createdAt:
          DateTime.tryParse(data['createdAt'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      workoutId: data['workoutId'] as String?,
      volumeKg: (data['volumeKg'] as num?)?.toDouble() ?? 0,
      runKm: (data['runKm'] as num?)?.toDouble() ?? 0,
      doneSets: (data['doneSets'] as num?)?.toInt() ?? 0,
      exerciseCount: (data['exerciseCount'] as num?)?.toInt() ?? 0,
      xpEarned: (data['xpEarned'] as num?)?.toInt() ?? 0,
      durationSec: (data['durationSec'] as num?)?.toInt() ?? 0,
      rankId: data['rankId'] as String?,
      achievementTitle: data['achievementTitle'] as String?,
      steps: (data['steps'] as num?)?.toInt() ?? 0,
      reactions: reactions,
      commentCount: (data['commentCount'] as num?)?.toInt() ?? 0,
      exercises: (data['exercises'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((e) => FeedExercise.fromMap(Map<String, dynamic>.from(e)))
          .where((e) => e.name.isNotEmpty)
          .toList(),
      hideSetDetails: data['hideSetDetails'] as bool? ?? false,
    );
  }
}
