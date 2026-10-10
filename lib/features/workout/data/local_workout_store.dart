import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/workout_models.dart';

/// Локальный черновик активной тренировки (переживает убийство приложения).
class LocalWorkoutStore {
  static const _key = 'active_workout_draft_v1';

  Future<void> save({
    required DateTime startedAt,
    required bool fromTemplate,
    required List<WorkoutExercise> exercises,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final payload = {
      'startedAt': startedAt.toIso8601String(),
      'fromTemplate': fromTemplate,
      'savedAt': DateTime.now().toIso8601String(),
      'exercises': exercises.map(_exerciseToJson).toList(),
    };
    await prefs.setString(_key, jsonEncode(payload));
  }

  Future<LocalWorkoutDraft?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final exercisesRaw = map['exercises'] as List<dynamic>? ?? const [];
      return LocalWorkoutDraft(
        startedAt: DateTime.tryParse(map['startedAt'] as String? ?? '') ??
            DateTime.now(),
        fromTemplate: map['fromTemplate'] as bool? ?? false,
        exercises: exercisesRaw
            .whereType<Map>()
            .map((e) => _exerciseFromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }

  Map<String, dynamic> _exerciseToJson(WorkoutExercise e) => {
        'id': e.id,
        'name': e.name,
        'exerciseId': e.exerciseId,
        'sets': e.sets
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

  WorkoutExercise _exerciseFromJson(Map<String, dynamic> data) {
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
}

class LocalWorkoutDraft {
  const LocalWorkoutDraft({
    required this.startedAt,
    required this.fromTemplate,
    required this.exercises,
  });

  final DateTime startedAt;
  final bool fromTemplate;
  final List<WorkoutExercise> exercises;

  /// Закрывает следующий незакрытый подход и сохраняет черновик.
  /// Возвращает название упражнения или null.
  Future<String?> completeNextSetAndSave(LocalWorkoutStore store) async {
    for (var ei = 0; ei < exercises.length; ei++) {
      final exercise = exercises[ei];
      for (var si = 0; si < exercise.sets.length; si++) {
        final set = exercise.sets[si];
        if (set.done) continue;
        final newSets = [...exercise.sets];
        newSets[si] = set.copyWith(done: true);
        final updated = [...exercises];
        updated[ei] = exercise.copyWith(sets: newSets);
        await store.save(
          startedAt: startedAt,
          fromTemplate: fromTemplate,
          exercises: updated,
        );
        return exercise.name;
      }
    }
    return null;
  }

  String? get nextExerciseName {
    for (final exercise in exercises) {
      if (exercise.sets.any((s) => !s.done)) return exercise.name;
    }
    return null;
  }

  String? get nextExerciseId {
    for (final exercise in exercises) {
      if (exercise.sets.any((s) => !s.done)) return exercise.exerciseId;
    }
    return null;
  }

  (int index, int count)? get nextSetProgress {
    for (final exercise in exercises) {
      for (var i = 0; i < exercise.sets.length; i++) {
        if (!exercise.sets[i].done) {
          return (i, exercise.sets.length);
        }
      }
    }
    return null;
  }
}
