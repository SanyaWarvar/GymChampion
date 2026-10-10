import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/local_workout_store.dart';
import '../domain/exercise_catalog.dart';
import '../domain/workout_models.dart';
import '../domain/workout_template.dart';
import 'rest_timer_controller.dart';

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
      unawaited(syncFromDisk());
      notifyListeners();
    });
    unawaited(_persist());
  }

  bool _dirty = false;
  bool _persisting = false;

  /// Подтягивает только то, что отметил lock screen / шторка (диск впереди).
  /// Не затирает локальные addSet / правки, пока они ещё не записаны.
  Future<void> syncFromDisk() async {
    if (_dirty || _persisting || (_persistDebounce?.isActive ?? false)) {
      return;
    }
    try {
      final draft = await _store.load();
      if (draft == null) return;
      final diskDone =
          draft.exercises.fold<int>(0, (t, e) => t + e.doneSets);
      // Диск отстаёт или равен — память источник истины.
      if (diskDone <= totalDoneSets) return;
      if (_sameDonePattern(draft.exercises, _exercises)) return;
      _exercises
        ..clear()
        ..addAll(draft.exercises);
      notifyListeners();
    } catch (_) {}
  }

  bool _sameDonePattern(List<WorkoutExercise> a, List<WorkoutExercise> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id || a[i].sets.length != b[i].sets.length) {
        return false;
      }
      for (var j = 0; j < a[i].sets.length; j++) {
        if (a[i].sets[j].done != b[i].sets[j].done) return false;
      }
    }
    return true;
  }

  final LocalWorkoutStore _store;
  late final DateTime _startedAt;
  late final bool _fromTemplate;
  Timer? _ticker;
  Timer? _persistDebounce;
  final List<WorkoutExercise> _exercises = [];
  int _idCounter = 0;

  RestTimerController get rest => RestTimerController.instance;

  bool get fromTemplate => _fromTemplate;

  bool get isResting => rest.isResting;
  int get restTotalSeconds => rest.restTotalSeconds;
  bool get restPaused => rest.restPaused;
  int get restRemainingSeconds => rest.restRemainingSeconds;
  double get restProgress => rest.restProgress;
  String get restLabel => rest.restLabel;

  void startRest({int seconds = 90}) => rest.startRest(seconds: seconds);
  void setRestPreset(int seconds) => rest.setRestPreset(seconds);
  void toggleRestPause() => rest.toggleRestPause();
  void dismissRest() => rest.dismissRest();

  List<WorkoutExercise> get exercises => List.unmodifiable(_exercises);

  /// Следующий незакрытый подход по плану (сверху вниз).
  WorkoutPlanStep? get currentPlanStep {
    for (final exercise in _exercises) {
      for (var i = 0; i < exercise.sets.length; i++) {
        final set = exercise.sets[i];
        if (!set.done) {
          return WorkoutPlanStep(
            exercise: exercise,
            set: set,
            setIndex: i,
            setCount: exercise.sets.length,
          );
        }
      }
    }
    return null;
  }

  bool get planComplete =>
      _exercises.isNotEmpty && currentPlanStep == null;

  /// Закрывает следующий подход по плану. true — подход стал выполненным.
  bool completeNextSet() {
    final step = currentPlanStep;
    if (step == null) return false;
    return toggleSetDone(exerciseId: step.exercise.id, setId: step.set.id);
  }

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

  void _schedulePersist({bool immediate = false}) {
    _dirty = true;
    _persistDebounce?.cancel();
    if (immediate) {
      unawaited(_persist());
      return;
    }
    _persistDebounce = Timer(const Duration(milliseconds: 350), () {
      unawaited(_persist());
    });
  }

  Future<void> _persist() async {
    _persistDebounce?.cancel();
    _persisting = true;
    try {
      // Снимок на момент старта записи — не потерять правки mid-await.
      final snapshot = List<WorkoutExercise>.from(_exercises);
      await _store.save(
        startedAt: _startedAt,
        fromTemplate: _fromTemplate,
        exercises: snapshot,
      );
      // Если за время save снова меняли — остаётся dirty через новый schedule.
      if (!(_persistDebounce?.isActive ?? false)) {
        _dirty = false;
      }
    } catch (_) {
      // Оставим dirty, чтобы syncFromDisk не откатил UI.
    } finally {
      _persisting = false;
    }
  }

  Future<void> clearLocalDraft() async {
    rest.dismissRest();
    await _store.clear();
  }

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
    _schedulePersist(immediate: true);
  }

  void removeExercise(String exerciseId) {
    _exercises.removeWhere((e) => e.id == exerciseId);
    notifyListeners();
    _schedulePersist(immediate: true);
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
    _schedulePersist(immediate: true);
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
    _schedulePersist(immediate: true);
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
    _schedulePersist(immediate: true);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _persistDebounce?.cancel();
    super.dispose();
  }
}

@immutable
class WorkoutPlanStep {
  const WorkoutPlanStep({
    required this.exercise,
    required this.set,
    required this.setIndex,
    required this.setCount,
  });

  final WorkoutExercise exercise;
  final WorkoutSet set;
  final int setIndex;
  final int setCount;

  String get setLabel => 'Подход ${setIndex + 1}/$setCount';

  String get loadLabel {
    final catalog = ExerciseCatalog.lookup(
      exerciseId: exercise.exerciseId,
      name: exercise.name,
    );
    if (catalog?.isRun == true) {
      return ExerciseCatalog.formatSet(
        weightKg: set.weightKg,
        qty: set.reps,
        exerciseId: exercise.exerciseId,
        name: exercise.name,
      );
    }
    if (catalog?.isHold == true) {
      return ExerciseCatalog.formatSet(
        weightKg: set.weightKg,
        qty: set.reps,
        exerciseId: exercise.exerciseId,
        name: exercise.name,
      );
    }
    if (set.weightKg <= 0) return '${set.reps} повт.';
    final kg = set.weightKg == set.weightKg.roundToDouble()
        ? '${set.weightKg.round()}'
        : '${set.weightKg}';
    return '$kg кг × ${set.reps}';
  }
}
