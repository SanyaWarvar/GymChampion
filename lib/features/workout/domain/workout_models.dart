import 'package:flutter/foundation.dart';

import 'exercise_catalog.dart';

@immutable
class WorkoutSet {
  const WorkoutSet({
    required this.id,
    this.weightKg = 0,
    this.reps = 0,
    this.done = false,
  });

  final String id;
  final double weightKg;
  final int reps;
  final bool done;

  WorkoutSet copyWith({
    double? weightKg,
    int? reps,
    bool? done,
  }) {
    return WorkoutSet(
      id: id,
      weightKg: weightKg ?? this.weightKg,
      reps: reps ?? this.reps,
      done: done ?? this.done,
    );
  }

  double get volume => weightKg * reps;

  bool get hasWork => reps > 0 || weightKg > 0;
}

@immutable
class WorkoutExercise {
  const WorkoutExercise({
    required this.id,
    required this.name,
    this.exerciseId,
    this.sets = const [],
  });

  final String id;
  final String name;
  final String? exerciseId;
  final List<WorkoutSet> sets;

  WorkoutExercise copyWith({
    String? name,
    String? exerciseId,
    List<WorkoutSet>? sets,
  }) {
    return WorkoutExercise(
      id: id,
      name: name ?? this.name,
      exerciseId: exerciseId ?? this.exerciseId,
      sets: sets ?? this.sets,
    );
  }

  double get volume {
    if (ExerciseCatalog.isHold(exerciseId: exerciseId, name: name) ||
        ExerciseCatalog.isRun(exerciseId: exerciseId, name: name)) {
      return 0;
    }
    return sets.where((s) => s.done).fold(0.0, (total, s) => total + s.volume);
  }

  double get runKm {
    if (!ExerciseCatalog.isRun(exerciseId: exerciseId, name: name)) return 0;
    return sets.where((s) => s.done).fold(0.0, (total, s) => total + s.weightKg);
  }

  int get doneSets => sets.where((s) => s.done).length;
}
