import 'exercise_catalog.dart';
import 'workout_models.dart';

class SavedWorkout {
  const SavedWorkout({
    required this.id,
    required this.userId,
    required this.startedAt,
    required this.finishedAt,
    required this.durationSec,
    required this.volumeKg,
    required this.doneSets,
    required this.exerciseCount,
    required this.xpEarned,
    required this.exercises,
    this.isPrivate = false,
  });

  final String id;
  final String userId;
  final DateTime startedAt;
  final DateTime finishedAt;
  final int durationSec;
  final double volumeKg;
  final int doneSets;
  final int exerciseCount;
  final int xpEarned;
  final List<WorkoutExercise> exercises;
  final bool isPrivate;

  String get durationLabel {
    final d = Duration(seconds: durationSec);
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'startedAt': startedAt.toIso8601String(),
      'finishedAt': finishedAt.toIso8601String(),
      'durationSec': durationSec,
      'volumeKg': volumeKg,
      'doneSets': doneSets,
      'exerciseCount': exerciseCount,
      'xpEarned': xpEarned,
      'isPrivate': isPrivate,
      'exercises': exercises.map(_exerciseToMap).toList(),
    };
  }

  factory SavedWorkout.fromMap(String id, Map<String, dynamic> data) {
    final exercisesRaw = data['exercises'] as List<dynamic>? ?? const [];
    return SavedWorkout(
      id: id,
      userId: data['userId'] as String? ?? '',
      startedAt: DateTime.tryParse(data['startedAt'] as String? ?? '') ??
          DateTime.now(),
      finishedAt: DateTime.tryParse(data['finishedAt'] as String? ?? '') ??
          DateTime.now(),
      durationSec: (data['durationSec'] as num?)?.toInt() ?? 0,
      volumeKg: (data['volumeKg'] as num?)?.toDouble() ?? 0,
      doneSets: (data['doneSets'] as num?)?.toInt() ?? 0,
      exerciseCount: (data['exerciseCount'] as num?)?.toInt() ?? 0,
      xpEarned: (data['xpEarned'] as num?)?.toInt() ?? 0,
      isPrivate: data['isPrivate'] as bool? ?? false,
      exercises: exercisesRaw
          .whereType<Map>()
          .map((e) => _exerciseFromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }

  static Map<String, dynamic> _exerciseToMap(WorkoutExercise exercise) {
    return {
      'id': exercise.id,
      'name': exercise.name,
      'exerciseId': exercise.exerciseId,
      'sets': exercise.sets
          .map(
            (s) => {
              'id': s.id,
              'weightKg': s.weightKg,
              'reps': s.reps,
              'done': s.done,
            },
          )
          .toList(),
    };
  }

  static WorkoutExercise _exerciseFromMap(Map<String, dynamic> data) {
    final setsRaw = data['sets'] as List<dynamic>? ?? const [];
    return WorkoutExercise(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? '',
      exerciseId: data['exerciseId'] as String?,
      sets: setsRaw.whereType<Map>().map((s) {
        final map = Map<String, dynamic>.from(s);
        return WorkoutSet(
          id: map['id'] as String? ?? '',
          weightKg: (map['weightKg'] as num?)?.toDouble() ?? 0,
          reps: (map['reps'] as num?)?.toInt() ?? 0,
          done: map['done'] as bool? ?? false,
        );
      }).toList(),
    );
  }

  double get runKm => exercises.fold(0.0, (sum, e) => sum + e.runKm);

  String get loadLabel =>
      ExerciseCatalog.formatLoad(volumeKg: volumeKg, runKm: runKm);
}

class WorkoutDraft {
  const WorkoutDraft({
    required this.startedAt,
    required this.finishedAt,
    required this.exercises,
    this.fromTemplate = false,
  });

  final DateTime startedAt;
  final DateTime finishedAt;
  final List<WorkoutExercise> exercises;
  final bool fromTemplate;

  Duration get duration => finishedAt.difference(startedAt);

  double get volumeKg =>
      exercises.fold(0, (sum, e) => sum + e.volume);

  int get doneSets =>
      exercises.fold(0, (sum, e) => sum + e.doneSets);

  int get exerciseCount => exercises.length;

  double get runKm => exercises.fold(0.0, (sum, e) => sum + e.runKm);

  String get loadLabel =>
      ExerciseCatalog.formatLoad(volumeKg: volumeKg, runKm: runKm);
}
