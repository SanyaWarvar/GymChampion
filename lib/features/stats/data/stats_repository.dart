import '../../rank/domain/mastery_boards.dart';
import '../../workout/data/workout_repository.dart';
import '../../workout/domain/exercise_catalog.dart';
import '../domain/exercise_progress.dart';
import '../domain/stats_models.dart';

class StatsRepository {
  StatsRepository({WorkoutRepository? workouts})
      : _workouts = workouts ?? WorkoutRepository();

  final WorkoutRepository _workouts;

  Future<ExerciseProgress> buildExerciseProgress(String exerciseKey) async {
    final all = await _workouts.fetchMyWorkouts(limit: 120);
    final points = <ExerciseSessionPoint>[];
    var name = ExerciseCatalog.byId(exerciseKey)?.name ?? exerciseKey;
    var allTimeMax = 0.0;
    var allTime1rm = 0.0;
    var allTimeReps = 0;

    // От старых к новым.
    final ordered = [...all]..sort((a, b) => a.finishedAt.compareTo(b.finishedAt));

    for (final w in ordered) {
      var sessionMax = 0.0;
      var session1rm = 0.0;
      var sessionVol = 0.0;
      var sessionSets = 0;
      var sessionReps = 0;

      for (final ex in w.exercises) {
        final key = ex.exerciseId ?? ex.name.toLowerCase();
        if (key != exerciseKey &&
            ex.name.toLowerCase() != exerciseKey.toLowerCase()) {
          continue;
        }
        name = ex.name;
        for (final set in ex.sets) {
          if (!set.done || !set.hasWork) continue;
          sessionSets += 1;
          final run = ExerciseCatalog.isRun(
            exerciseId: ex.exerciseId,
            name: ex.name,
          );
          sessionVol += run ? set.weightKg : set.weightKg * set.reps;
          if (set.weightKg > sessionMax) sessionMax = set.weightKg;
          if (set.reps > sessionReps) sessionReps = set.reps;
          final est = set.weightKg * (1 + set.reps / 30);
          if (est > session1rm) session1rm = est;
        }
      }

      if (sessionSets == 0) continue;
      if (sessionMax > allTimeMax) allTimeMax = sessionMax;
      if (session1rm > allTime1rm) allTime1rm = session1rm;
      if (sessionReps > allTimeReps) allTimeReps = sessionReps;
      points.add(
        ExerciseSessionPoint(
          date: w.finishedAt,
          maxWeightKg: sessionMax,
          bestEstimated1Rm: session1rm,
          volumeKg: sessionVol,
          sets: sessionSets,
          maxReps: sessionReps,
        ),
      );
    }

    return ExerciseProgress(
      exerciseKey: exerciseKey,
      exerciseName: name,
      points: points,
      allTimeMaxWeight: allTimeMax,
      allTimeBest1Rm: allTime1rm,
      allTimeMaxReps: allTimeReps,
    );
  }

  Future<StatsSnapshot> buildSnapshot() async {
    final all = await _workouts.fetchMyWorkouts(limit: 120);
    final now = DateTime.now();
    final weekStart = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: now.weekday - 1));
    final monthStart = DateTime(now.year, now.month);

    var weekVolume = 0.0;
    var monthVolume = 0.0;
    var weekWorkouts = 0;
    var monthWorkouts = 0;

    final dayCounts = <DateTime, int>{};
    for (var i = 0; i < 84; i++) {
      final d = DateTime(now.year, now.month, now.day)
          .subtract(Duration(days: 83 - i));
      dayCounts[d] = 0;
    }

    final maxWeight = <String, double>{};
    final maxReps = <String, int>{};
    final best1rm = <String, double>{};
    final bestSetVol = <String, double>{};
    final names = <String, String>{};
    final muscleSets = <MuscleGroup, int>{
      for (final m in MuscleGroup.values) m: 0,
    };

    for (final w in all) {
      final day = DateTime(
        w.finishedAt.year,
        w.finishedAt.month,
        w.finishedAt.day,
      );
      if (dayCounts.containsKey(day)) {
        dayCounts[day] = (dayCounts[day] ?? 0) + 1;
      }
      if (!w.finishedAt.isBefore(weekStart)) {
        weekVolume += w.volumeKg;
        weekWorkouts += 1;
      }
      if (!w.finishedAt.isBefore(monthStart)) {
        monthVolume += w.volumeKg;
        monthWorkouts += 1;
      }

      for (final ex in w.exercises) {
        final key = ex.exerciseId ?? ex.name.toLowerCase();
        names[key] = ex.name;
        final catalog = ex.exerciseId == null
            ? null
            : ExerciseCatalog.byId(ex.exerciseId!);
        final muscle = catalog?.muscle ?? MuscleGroup.fullBody;

        for (final set in ex.sets) {
          if (!set.done || !set.hasWork) continue;
          muscleSets[muscle] = (muscleSets[muscle] ?? 0) + 1;
          final wKg = set.weightKg;
          maxWeight[key] = (maxWeight[key] ?? 0) > wKg
              ? (maxWeight[key] ?? 0)
              : wKg;
          if (set.reps > (maxReps[key] ?? 0)) maxReps[key] = set.reps;
          // Epley: 1RM ≈ w * (1 + reps/30)
          final est = wKg * (1 + set.reps / 30);
          if (est > (best1rm[key] ?? 0)) best1rm[key] = est;
          final setVol = wKg * set.reps;
          if (setVol > (bestSetVol[key] ?? 0)) bestSetVol[key] = setVol;
        }
      }
    }

    final allRecords = names.keys.map((key) {
      return PersonalRecord(
        exerciseKey: key,
        exerciseName: names[key]!,
        maxWeightKg: maxWeight[key] ?? 0,
        bestEstimated1Rm: best1rm[key] ?? 0,
        bestSetVolume: bestSetVol[key] ?? 0,
        maxReps: maxReps[key] ?? 0,
      );
    }).toList();

    final repsMasters = allRecords.where((r) {
      final board = MasteryBoards.byExerciseId(r.exerciseKey);
      final hold = ExerciseCatalog.isHold(
        exerciseId: r.exerciseKey,
        name: r.exerciseName,
      );
      final run = ExerciseCatalog.isRun(
        exerciseId: r.exerciseKey,
        name: r.exerciseName,
      );
      return (board?.metric == MasteryMetric.maxReps || hold) &&
          r.maxReps > 0 &&
          !run;
    }).toList()
      ..sort((a, b) => b.maxReps.compareTo(a.maxReps));
    final weighted = allRecords.where((r) {
      if (ExerciseCatalog.isHold(
            exerciseId: r.exerciseKey,
            name: r.exerciseName,
          ) ||
          ExerciseCatalog.isRun(
            exerciseId: r.exerciseKey,
            name: r.exerciseName,
          )) {
        return false;
      }
      return r.maxWeightKg >= 1;
    }).toList()
      ..sort((a, b) => b.maxWeightKg.compareTo(a.maxWeightKg));
    final runs = allRecords.where((r) {
      return ExerciseCatalog.isRun(
            exerciseId: r.exerciseKey,
            name: r.exerciseName,
          ) &&
          r.maxWeightKg > 0;
    }).toList()
      ..sort((a, b) => b.maxWeightKg.compareTo(a.maxWeightKg));
    final records = [...repsMasters, ...runs, ...weighted];

    final heatmap = dayCounts.entries
        .map((e) => DayActivity(day: e.key, workoutCount: e.value))
        .toList()
      ..sort((a, b) => a.day.compareTo(b.day));

    final loads = muscleSets.entries
        .where((e) => e.value > 0)
        .map((e) => MuscleLoad(muscle: e.key, sets: e.value))
        .toList()
      ..sort((a, b) => b.sets.compareTo(a.sets));

    return StatsSnapshot(
      weekVolumeKg: weekVolume,
      monthVolumeKg: monthVolume,
      weekWorkouts: weekWorkouts,
      monthWorkouts: monthWorkouts,
      records: records.take(15).toList(),
      heatmap: heatmap,
      muscleLoads: loads,
    );
  }
}
