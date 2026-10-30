import 'package:flutter/foundation.dart';

@immutable
class TemplateSetTarget {
  const TemplateSetTarget({
    this.weightKg = 0,
    this.reps = 8,
  });

  final double weightKg;
  final int reps;

  TemplateSetTarget copyWith({double? weightKg, int? reps}) {
    return TemplateSetTarget(
      weightKg: weightKg ?? this.weightKg,
      reps: reps ?? this.reps,
    );
  }

  Map<String, dynamic> toMap() => {
        'weightKg': weightKg,
        'reps': reps,
      };

  factory TemplateSetTarget.fromMap(Map<String, dynamic> data) {
    return TemplateSetTarget(
      weightKg: (data['weightKg'] as num?)?.toDouble() ?? 0,
      reps: (data['reps'] as num?)?.toInt() ?? 8,
    );
  }
}

@immutable
class TemplateExercise {
  const TemplateExercise({
    required this.name,
    this.exerciseId,
    this.targetSets = 3,
    this.targetReps = 8,
    this.targetWeightKg = 0,
    this.setTargets,
  });

  final String? exerciseId;
  final String name;
  final int targetSets;
  final int targetReps;
  final double targetWeightKg;

  /// Если задано — вес/повторы на каждый подход. Иначе все подходы = target*.
  final List<TemplateSetTarget>? setTargets;

  List<TemplateSetTarget> get resolvedSets {
    final custom = setTargets;
    if (custom != null && custom.isNotEmpty) {
      return List<TemplateSetTarget>.unmodifiable(custom);
    }
    final count = targetSets.clamp(1, 12);
    return List<TemplateSetTarget>.unmodifiable(
      List.generate(
        count,
        (_) => TemplateSetTarget(
          weightKg: targetWeightKg,
          reps: targetReps,
        ),
      ),
    );
  }

  int get effectiveSets => resolvedSets.length;

  TemplateExercise copyWith({
    String? exerciseId,
    String? name,
    int? targetSets,
    int? targetReps,
    double? targetWeightKg,
    List<TemplateSetTarget>? setTargets,
    bool clearSetTargets = false,
  }) {
    return TemplateExercise(
      exerciseId: exerciseId ?? this.exerciseId,
      name: name ?? this.name,
      targetSets: targetSets ?? this.targetSets,
      targetReps: targetReps ?? this.targetReps,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
      setTargets: clearSetTargets ? null : (setTargets ?? this.setTargets),
    );
  }

  /// Меняет число подходов, сохраняя уже введённые значения.
  TemplateExercise withSetCount(int count) {
    final n = count.clamp(1, 12);
    final current = resolvedSets;
    final next = <TemplateSetTarget>[
      for (var i = 0; i < n; i++)
        i < current.length
            ? current[i]
            : TemplateSetTarget(
                weightKg: current.isNotEmpty ? current.last.weightKg : targetWeightKg,
                reps: current.isNotEmpty ? current.last.reps : targetReps,
              ),
    ];
    return copyWith(
      targetSets: n,
      setTargets: next,
      targetReps: next.first.reps,
      targetWeightKg: next.first.weightKg,
    );
  }

  TemplateExercise withSetAt(int index, TemplateSetTarget set) {
    final next = [...resolvedSets];
    if (index < 0 || index >= next.length) return this;
    next[index] = set;
    return copyWith(
      setTargets: next,
      targetSets: next.length,
      targetReps: next.first.reps,
      targetWeightKg: next.first.weightKg,
    );
  }

  Map<String, dynamic> toMap() {
    final sets = resolvedSets;
    return {
      'exerciseId': exerciseId,
      'name': name,
      'targetSets': sets.length,
      'targetReps': sets.isNotEmpty ? sets.first.reps : targetReps,
      'targetWeightKg': sets.isNotEmpty ? sets.first.weightKg : targetWeightKg,
      'setTargets': sets.map((s) => s.toMap()).toList(),
    };
  }

  factory TemplateExercise.fromMap(Map<String, dynamic> data) {
    final rawSets = data['setTargets'] as List<dynamic>?;
    List<TemplateSetTarget>? setTargets;
    if (rawSets != null && rawSets.isNotEmpty) {
      setTargets = rawSets
          .whereType<Map>()
          .map((e) => TemplateSetTarget.fromMap(Map<String, dynamic>.from(e)))
          .toList();
    }
    final targetSets = (data['targetSets'] as num?)?.toInt() ?? 3;
    final targetReps = (data['targetReps'] as num?)?.toInt() ?? 8;
    final targetWeightKg =
        (data['targetWeightKg'] as num?)?.toDouble() ?? 0;
    return TemplateExercise(
      exerciseId: data['exerciseId'] as String?,
      name: data['name'] as String? ?? '',
      targetSets: setTargets?.length ?? targetSets,
      targetReps: targetReps,
      targetWeightKg: targetWeightKg,
      setTargets: setTargets,
    );
  }
}

@immutable
class WorkoutTemplate {
  const WorkoutTemplate({
    required this.id,
    required this.name,
    required this.exercises,
    this.updatedAt,
    this.programId,
    this.programTitle,
    this.dayLabel,
  });

  final String id;
  final String name;
  final List<TemplateExercise> exercises;
  final DateTime? updatedAt;
  final String? programId;
  final String? programTitle;
  final String? dayLabel;

  bool get isProgramDay =>
      programId != null && programId!.trim().isNotEmpty;

  WorkoutTemplate copyWith({
    String? name,
    List<TemplateExercise>? exercises,
    DateTime? updatedAt,
    String? programId,
    String? programTitle,
    String? dayLabel,
    bool clearProgram = false,
  }) {
    return WorkoutTemplate(
      id: id,
      name: name ?? this.name,
      exercises: exercises ?? this.exercises,
      updatedAt: updatedAt ?? this.updatedAt,
      programId: clearProgram ? null : (programId ?? this.programId),
      programTitle: clearProgram ? null : (programTitle ?? this.programTitle),
      dayLabel: clearProgram ? null : (dayLabel ?? this.dayLabel),
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'exercises': exercises.map((e) => e.toMap()).toList(),
        'updatedAt': (updatedAt ?? DateTime.now()).toIso8601String(),
        if (programId != null) 'programId': programId,
        if (programTitle != null) 'programTitle': programTitle,
        if (dayLabel != null) 'dayLabel': dayLabel,
      };

  factory WorkoutTemplate.fromMap(String id, Map<String, dynamic> data) {
    final raw = data['exercises'] as List<dynamic>? ?? const [];
    return WorkoutTemplate(
      id: id,
      name: data['name'] as String? ?? 'Без названия',
      updatedAt: DateTime.tryParse(data['updatedAt'] as String? ?? ''),
      programId: data['programId'] as String?,
      programTitle: data['programTitle'] as String?,
      dayLabel: data['dayLabel'] as String?,
      exercises: raw
          .whereType<Map>()
          .map((e) => TemplateExercise.fromMap(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

/// Стабильный id группы из названия (для своих программ).
String templateProgramIdFromTitle(String title) {
  final raw = title.trim().toLowerCase();
  final slug = raw
      .replaceAll(RegExp(r'\s+'), '_')
      .replaceAll(RegExp(r'[^a-z0-9_а-яё]+', caseSensitive: false), '');
  if (slug.isEmpty) return 'custom_${DateTime.now().millisecondsSinceEpoch}';
  return 'custom_$slug';
}
