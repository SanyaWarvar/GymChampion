import 'package:flutter/foundation.dart';

import '../../workout/domain/exercise_catalog.dart';
import '../../workout/domain/workout_models.dart';

enum MasteryMetric { maxReps, maxWeightKg, maxDistanceKm, minPaceSec }

@immutable
class MasteryBoard {
  const MasteryBoard({
    required this.id,
    required this.exerciseId,
    required this.title,
    required this.metric,
    required this.userField,
    required this.unit,
  });

  final String id;
  final String exerciseId;
  final String title;
  final MasteryMetric metric;
  final String userField;
  final String unit;

  bool get isWeight => metric == MasteryMetric.maxWeightKg;
  bool get lowerIsBetter => metric == MasteryMetric.minPaceSec;

  String format(num value) {
    if (metric == MasteryMetric.minPaceSec) {
      return ExerciseCatalog.formatPace(value.round());
    }
    if (metric == MasteryMetric.maxDistanceKm) {
      return ExerciseCatalog.formatKm(value.toDouble());
    }
    if (metric == MasteryMetric.maxReps) {
      return '${value.round()} $unit';
    }
    return '${value.round()} $unit';
  }

  num valueFromSet({required double weightKg, required int reps}) {
    return switch (metric) {
      MasteryMetric.maxReps => reps,
      MasteryMetric.maxWeightKg => weightKg,
      MasteryMetric.maxDistanceKm => weightKg,
      MasteryMetric.minPaceSec =>
        ExerciseCatalog.paceSecPerKm(km: weightKg, durationSec: reps) ?? 0,
    };
  }
}

abstract final class MasteryBoards {
  /// Bump when a new board must be recomputed for already-backfilled users.
  static const schema = 3;

  static const pullUps = MasteryBoard(
    id: 'pull_up',
    exerciseId: 'pull_up',
    title: 'Подтягивания',
    metric: MasteryMetric.maxReps,
    userField: 'bestPullUpReps',
    unit: 'раз',
  );

  static const pushUps = MasteryBoard(
    id: 'push_up',
    exerciseId: 'push_up',
    title: 'Отжимания',
    metric: MasteryMetric.maxReps,
    userField: 'bestPushUpReps',
    unit: 'раз',
  );

  static const plank = MasteryBoard(
    id: 'plank',
    exerciseId: 'plank',
    title: 'Планка',
    metric: MasteryMetric.maxReps,
    userField: 'bestPlankSec',
    unit: 'сек',
  );

  static const dips = MasteryBoard(
    id: 'dips',
    exerciseId: 'dips',
    title: 'Брусья',
    metric: MasteryMetric.maxReps,
    userField: 'bestDipsReps',
    unit: 'раз',
  );

  static const bench = MasteryBoard(
    id: 'bench_press',
    exerciseId: 'bench_press',
    title: 'Жим лёжа',
    metric: MasteryMetric.maxWeightKg,
    userField: 'bestBenchKg',
    unit: 'кг',
  );

  static const squat = MasteryBoard(
    id: 'squat',
    exerciseId: 'squat',
    title: 'Присед',
    metric: MasteryMetric.maxWeightKg,
    userField: 'bestSquatKg',
    unit: 'кг',
  );

  static const deadlift = MasteryBoard(
    id: 'deadlift',
    exerciseId: 'deadlift',
    title: 'Становая',
    metric: MasteryMetric.maxWeightKg,
    userField: 'bestDeadliftKg',
    unit: 'кг',
  );

  static const runDistance = MasteryBoard(
    id: 'run_km',
    exerciseId: 'run',
    title: 'Бег · км',
    metric: MasteryMetric.maxDistanceKm,
    userField: 'bestRunKm',
    unit: 'км',
  );

  static const runPace = MasteryBoard(
    id: 'run_pace',
    exerciseId: 'run',
    title: 'Бег · темп',
    metric: MasteryMetric.minPaceSec,
    userField: 'bestRunPaceSec',
    unit: '/км',
  );

  static const ohp = MasteryBoard(
    id: 'ohp',
    exerciseId: 'ohp',
    title: 'Жим стоя',
    metric: MasteryMetric.maxWeightKg,
    userField: 'bestOhpKg',
    unit: 'кг',
  );

  static const all = <MasteryBoard>[
    pullUps,
    pushUps,
    plank,
    runDistance,
    runPace,
    dips,
    bench,
    squat,
    deadlift,
    ohp,
  ];

  static MasteryBoard get defaultBoard => pullUps;

  static MasteryBoard? byExerciseId(String? exerciseId) {
    if (exerciseId == null) return null;
    for (final board in all) {
      if (board.exerciseId == exerciseId || board.id == exerciseId) {
        return board;
      }
    }
    return null;
  }

  static MasteryBoard? byUserField(String field) {
    for (final board in all) {
      if (board.userField == field) return board;
    }
    return null;
  }

  static bool matchesExercise(MasteryBoard board, {String? exerciseId, String? name}) {
    if (exerciseId != null &&
        (exerciseId == board.exerciseId || exerciseId == board.id)) {
      return true;
    }
    if (name == null || name.trim().isEmpty) return false;
    final cat = ExerciseCatalog.byId(board.exerciseId);
    return cat != null && name.trim().toLowerCase() == cat.name.toLowerCase();
  }

  /// Best per-board values from a session (done sets only).
  static Map<String, num> fromExercises(Iterable<WorkoutExercise> exercises) {
    final out = <String, num>{};
    for (final board in all) {
      if (board.metric == MasteryMetric.maxDistanceKm) {
        var totalKm = 0.0;
        for (final ex in exercises) {
          if (!matchesExercise(board, exerciseId: ex.exerciseId, name: ex.name)) {
            continue;
          }
          totalKm += ex.runKm;
        }
        if (totalKm > 0) out[board.userField] = totalKm;
        continue;
      }

      num? best;
      for (final ex in exercises) {
        if (!matchesExercise(board, exerciseId: ex.exerciseId, name: ex.name)) {
          continue;
        }
        for (final set in ex.sets) {
          if (!set.done || !set.hasWork) continue;
          if (board.metric == MasteryMetric.minPaceSec && set.weightKg < 3) {
            continue;
          }
          final v = board.valueFromSet(weightKg: set.weightKg, reps: set.reps);
          if (v <= 0) continue;
          if (best == null) {
            best = v;
          } else if (board.lowerIsBetter) {
            if (v < best) best = v;
          } else if (v > best) {
            best = v;
          }
        }
      }
      if (best != null && best > 0) out[board.userField] = best;
    }
    return out;
  }

  static Map<String, num> mergeMax(Map<String, num> stored, Map<String, num> incoming) {
    if (incoming.isEmpty) return stored;
    final out = Map<String, num>.from(stored);
    for (final entry in incoming.entries) {
      final prev = out[entry.key] ?? 0;
      final board = byUserField(entry.key);
      if (board != null && board.lowerIsBetter) {
        if (prev <= 0 || (entry.value > 0 && entry.value < prev)) {
          out[entry.key] = entry.value;
        }
      } else if (entry.value > prev) {
        out[entry.key] = entry.value;
      }
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
