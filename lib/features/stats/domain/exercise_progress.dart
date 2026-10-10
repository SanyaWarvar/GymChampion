import 'package:flutter/foundation.dart';

import '../../workout/domain/exercise_catalog.dart';

@immutable
class ExerciseSessionPoint {
  const ExerciseSessionPoint({
    required this.date,
    required this.maxWeightKg,
    required this.bestEstimated1Rm,
    required this.volumeKg,
    required this.sets,
    this.maxReps = 0,
  });

  final DateTime date;
  final double maxWeightKg;
  final double bestEstimated1Rm;
  final double volumeKg;
  final int sets;
  final int maxReps;
}

@immutable
class ExerciseProgress {
  const ExerciseProgress({
    required this.exerciseKey,
    required this.exerciseName,
    required this.points,
    required this.allTimeMaxWeight,
    required this.allTimeBest1Rm,
    this.allTimeMaxReps = 0,
  });

  final String exerciseKey;
  final String exerciseName;
  final List<ExerciseSessionPoint> points;
  final double allTimeMaxWeight;
  final double allTimeBest1Rm;
  final int allTimeMaxReps;

  bool get isEmpty => points.isEmpty;

  bool get isHold => ExerciseCatalog.isHold(
        exerciseId: exerciseKey,
        name: exerciseName,
      );

  bool get isRun => ExerciseCatalog.isRun(
        exerciseId: exerciseKey,
        name: exerciseName,
      );

  bool get isRepsFocused =>
      !isRun && (isHold || (allTimeMaxWeight < 1 && allTimeMaxReps > 0));

  double get latestWeight =>
      points.isEmpty ? 0 : points.last.maxWeightKg;

  double get deltaFromFirst {
    if (points.length < 2) return 0;
    if (isRepsFocused) {
      return (points.last.maxReps - points.first.maxReps).toDouble();
    }
    return points.last.maxWeightKg - points.first.maxWeightKg;
  }
}
