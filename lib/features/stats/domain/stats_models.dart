import 'package:flutter/foundation.dart';

import '../../workout/domain/exercise_catalog.dart';

@immutable
class PersonalRecord {
  const PersonalRecord({
    required this.exerciseKey,
    required this.exerciseName,
    required this.maxWeightKg,
    required this.bestEstimated1Rm,
    required this.bestSetVolume,
    this.maxReps = 0,
  });

  final String exerciseKey;
  final String exerciseName;
  final double maxWeightKg;
  final double bestEstimated1Rm;
  final double bestSetVolume;
  final int maxReps;
}

@immutable
class DayActivity {
  const DayActivity({required this.day, required this.workoutCount});

  final DateTime day;
  final int workoutCount;
}

@immutable
class MuscleLoad {
  const MuscleLoad({required this.muscle, required this.sets});

  final MuscleGroup muscle;
  final int sets;
}

@immutable
class StatsSnapshot {
  const StatsSnapshot({
    required this.weekVolumeKg,
    required this.monthVolumeKg,
    required this.weekWorkouts,
    required this.monthWorkouts,
    required this.records,
    required this.heatmap,
    required this.muscleLoads,
  });

  final double weekVolumeKg;
  final double monthVolumeKg;
  final int weekWorkouts;
  final int monthWorkouts;
  final List<PersonalRecord> records;
  final List<DayActivity> heatmap;
  final List<MuscleLoad> muscleLoads;
}
