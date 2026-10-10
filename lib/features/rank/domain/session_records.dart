import 'package:flutter/foundation.dart';

import '../../workout/domain/exercise_catalog.dart';
import '../../workout/domain/saved_workout.dart';
import '../../workout/domain/workout_models.dart';

enum SessionRecordKind { xp, volume, setLoad }

@immutable
class SessionRecordBoard {
  const SessionRecordBoard({
    required this.id,
    required this.title,
    required this.userField,
    required this.unit,
    required this.kind,
    this.hideIfWeightsHidden = false,
  });

  final String id;
  final String title;
  final String userField;
  final String unit;
  final SessionRecordKind kind;
  final bool hideIfWeightsHidden;

  String format(num value) {
    if (kind == SessionRecordKind.xp) return '${value.round()} $unit';
    if (kind == SessionRecordKind.setLoad) {
      return '${value.round()} $unit';
    }
    return '${value.round()} $unit';
  }
}

abstract final class SessionRecords {
  static const xp = SessionRecordBoard(
    id: 'session_xp',
    title: 'XP за тренировку',
    userField: 'bestSessionXp',
    unit: 'XP',
    kind: SessionRecordKind.xp,
  );

  static const volume = SessionRecordBoard(
    id: 'session_volume',
    title: 'Объём тренировки',
    userField: 'bestSessionVolumeKg',
    unit: 'кг',
    kind: SessionRecordKind.volume,
    hideIfWeightsHidden: true,
  );

  static const setLoad = SessionRecordBoard(
    id: 'session_set',
    title: 'Лучший подход',
    userField: 'bestSetLoad',
    unit: 'кг×повт',
    kind: SessionRecordKind.setLoad,
    hideIfWeightsHidden: true,
  );

  static const all = <SessionRecordBoard>[xp, volume, setLoad];

  static SessionRecordBoard get defaultBoard => xp;

  static double bestSetLoadFrom(Iterable<WorkoutExercise> exercises) {
    var best = 0.0;
    for (final ex in exercises) {
      if (ExerciseCatalog.isHold(exerciseId: ex.exerciseId, name: ex.name) ||
          ExerciseCatalog.isRun(exerciseId: ex.exerciseId, name: ex.name)) {
        continue;
      }
      for (final set in ex.sets) {
        if (!set.done || set.reps <= 0 || set.weightKg <= 0) continue;
        final load = set.weightKg * set.reps;
        if (load > best) best = load;
      }
    }
    return best;
  }

  static Map<String, num> fromWorkout({
    required int xpEarned,
    required double volumeKg,
    required Iterable<WorkoutExercise> exercises,
  }) {
    final setLoad = bestSetLoadFrom(exercises);
    return {
      if (xpEarned > 0) xp.userField: xpEarned,
      if (volumeKg > 0) volume.userField: volumeKg,
      if (setLoad > 0) SessionRecords.setLoad.userField: setLoad,
    };
  }

  static Map<String, num> fromSaved(SavedWorkout workout) {
    return fromWorkout(
      xpEarned: workout.xpEarned,
      volumeKg: workout.volumeKg,
      exercises: workout.exercises,
    );
  }

  static Map<String, num> mergeMax(
    Map<String, num> stored,
    Map<String, num> incoming,
  ) {
    if (incoming.isEmpty) return stored;
    final out = Map<String, num>.from(stored);
    for (final entry in incoming.entries) {
      final prev = out[entry.key] ?? 0;
      if (entry.value > prev) out[entry.key] = entry.value;
    }
    return out;
  }

  static Map<String, num> readFromUserData(Map<String, dynamic> data) {
    final out = <String, num>{};
    for (final board in all) {
      final v = (data[board.userField] as num?) ?? 0;
      if (v > 0) out[board.userField] = v;
    }
    return out;
  }
}
