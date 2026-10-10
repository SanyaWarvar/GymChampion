import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/local_workout_store.dart';
import '../domain/exercise_catalog.dart';
import '../domain/workout_models.dart';
import '../domain/workout_template.dart';

class ActiveWorkoutController extends ChangeNotifier {
  ActiveWorkoutController({
    WorkoutTemplate? template,
    LocalWorkoutDraft? restore,
  }) : _store = LocalWorkoutStore() {
    if (restore != null) {
      _startedAt = restore.startedAt;
      _fromTemplate = restore.fromTemplate;
      _exercises.addAll(restore.exercises);
      _idCounter = _inferIdCounter(restore.exercises);
    } else {
      _startedAt = DateTime.now();
      _fromTemplate = template != null;
      if (template != null) {
        for (final item in template.exercises) {
          addExercise(
            item.name,
            exerciseId: item.exerciseId,
            setsCount: item.targetSets,
            weightKg: item.targetWeightKg,
            reps: item.targetReps,
          );
        }
      }
    }
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      notifyListeners();
    });
    _persist();
  }

  final LocalWorkoutStore _store;
  late final DateTime _startedAt;
  late final bool _fromTemplate;
  Timer? _ticker;
  Timer? _persistDebounce;
  final List<WorkoutExercise> _exercises = [];
  int _idCounter = 0;

  bool get fromTemplate => _fromTemplate;

  List<WorkoutExercise> get exercises => List.unmodifiable(_exercises);

  DateTime get startedAt => _startedAt;

  Duration get elapsed => DateTime.now().difference(_startedAt);

  String get elapsedLabel {
    final d = elapsed;
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (h > 0) return '$h:$m:$s';
    return '$m:$s';
  }

  double get totalVolume =>
      _exercises.fold(0.0, (total, e) => total + e.volume);

  double get totalRunKm =>
      _exercises.fold(0.0, (total, e) => total + e.runKm);

  int get totalDoneSets =>
      _exercises.fold(0, (total, e) => total + e.doneSets);

  int _inferIdCounter(List<WorkoutExercise> exercises) {
    var max = 0;
    for (final e in exercises) {
      max = _maxSuffix(e.id, max);
      for (final s in e.sets) {
        max = _maxSuffix(s.id, max);
      }
    }
    return max + 1;
  }

  int _maxSuffix(String id, int current) {
    final parts = id.split('_');
    final n = int.tryParse(parts.isNotEmpty ? parts.last : '') ?? 0;
    return n > current ? n : current;
  }

  String _nextId(String prefix) => '${prefix}_${_idCounter++}';

  void _schedulePersist() {
    _persistDebounce?.cancel();
    _persistDebounce = Timer(const Duration(milliseconds: 350), _persist);
  }

  Future<void> _persist() async {
    try {
      await _store.save(
        startedAt: _startedAt,
        fromTemplate: _fromTemplate,
        exercises: _exercises,
      );
    } catch (_) {}
  }

  Future<void> clearLocalDraft() => _store.clear();

  void addExercise(
    String name, {
    String? exerciseId,
    int setsCount = 1,
    double weightKg = 0,
    int reps = 0,
  }) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    final count = setsCount.clamp(1, 12);
    final catalog = ExerciseCatalog.lookup(
      exerciseId: exerciseId,
      name: trimmed,
    );
    final qty = reps > 0 ? reps : (catalog?.defaultQty ?? 0);
    final load = weightKg > 0 ? weightKg : (catalog?.defaultDistanceKm ?? 0);
    _exercises.add(
      WorkoutExercise(
        id: _nextId('ex'),
        name: trimmed,
        exerciseId: exerciseId,
        sets: List.generate(
          count,
          (_) => WorkoutSet(
            id: _nextId('set'),
            weightKg: load,
            reps: qty,
          ),
        ),
      ),
    );
    notifyListeners();
    _schedulePersist();
  }

  void removeExercise(String exerciseId) {
    _exercises.removeWhere((e) => e.id == exerciseId);
    notifyListeners();
    _schedulePersist();
  }

  void addSet(String exerciseId) {
    final index = _exercises.indexWhere((e) => e.id == exerciseId);
    if (index < 0) return;
    final exercise = _exercises[index];
    final last = exercise.sets.isNotEmpty ? exercise.sets.last : null;
    _exercises[index] = exercise.copyWith(
      sets: [
        ...exercise.sets,
        WorkoutSet(
          id: _nextId('set'),
          weightKg: last?.weightKg ?? 0,
          reps: last?.reps ?? 0,
        ),
      ],
    );
    notifyListeners();
    _schedulePersist();
  }

  void updateSet({
    required String exerciseId,
    required String setId,
    double? weightKg,
    int? reps,
  }) {
    final exIndex = _exercises.indexWhere((e) => e.id == exerciseId);
    if (exIndex < 0) return;
    final exercise = _exercises[exIndex];
    final sets = exercise.sets.map((set) {
      if (set.id != setId) return set;
      return set.copyWith(weightKg: weightKg, reps: reps);
    }).toList();
    _exercises[exIndex] = exercise.copyWith(sets: sets);
    notifyListeners();
    _schedulePersist();
  }

  /// Returns true if set became done (for rest timer).
  bool toggleSetDone({
    required String exerciseId,
    required String setId,
  }) {
    final exIndex = _exercises.indexWhere((e) => e.id == exerciseId);
    if (exIndex < 0) return false;
    final exercise = _exercises[exIndex];
    var becameDone = false;
    final sets = exercise.sets.map((set) {
      if (set.id != setId) return set;
      final nextDone = !set.done;
      if (nextDone) becameDone = true;
      return set.copyWith(done: nextDone);
    }).toList();
    _exercises[exIndex] = exercise.copyWith(sets: sets);
    notifyListeners();
    _schedulePersist();
    return becameDone;
  }

  void removeSet({
    required String exerciseId,
    required String setId,
  }) {
    final exIndex = _exercises.indexWhere((e) => e.id == exerciseId);
    if (exIndex < 0) return;
    final exercise = _exercises[exIndex];
    if (exercise.sets.length <= 1) return;
    _exercises[exIndex] = exercise.copyWith(
      sets: exercise.sets.where((s) => s.id != setId).toList(),
    );
    notifyListeners();
    _schedulePersist();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _persistDebounce?.cancel();
    super.dispose();
  }
}
