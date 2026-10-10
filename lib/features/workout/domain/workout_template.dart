import 'package:flutter/foundation.dart';

@immutable
class TemplateExercise {
  const TemplateExercise({
    required this.name,
    this.exerciseId,
    this.targetSets = 3,
    this.targetReps = 8,
    this.targetWeightKg = 0,
  });

  final String? exerciseId;
  final String name;
  final int targetSets;
  final int targetReps;
  final double targetWeightKg;

  TemplateExercise copyWith({
    String? exerciseId,
    String? name,
    int? targetSets,
    int? targetReps,
    double? targetWeightKg,
  }) {
    return TemplateExercise(
      exerciseId: exerciseId ?? this.exerciseId,
      name: name ?? this.name,
      targetSets: targetSets ?? this.targetSets,
      targetReps: targetReps ?? this.targetReps,
      targetWeightKg: targetWeightKg ?? this.targetWeightKg,
    );
  }

  Map<String, dynamic> toMap() => {
        'exerciseId': exerciseId,
        'name': name,
        'targetSets': targetSets,
        'targetReps': targetReps,
        'targetWeightKg': targetWeightKg,
      };

  factory TemplateExercise.fromMap(Map<String, dynamic> data) {
    return TemplateExercise(
      exerciseId: data['exerciseId'] as String?,
      name: data['name'] as String? ?? '',
      targetSets: (data['targetSets'] as num?)?.toInt() ?? 3,
      targetReps: (data['targetReps'] as num?)?.toInt() ?? 8,
      targetWeightKg: (data['targetWeightKg'] as num?)?.toDouble() ?? 0,
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
  }) {
    return WorkoutTemplate(
      id: id,
      name: name ?? this.name,
      exercises: exercises ?? this.exercises,
      updatedAt: updatedAt ?? this.updatedAt,
      programId: programId ?? this.programId,
      programTitle: programTitle ?? this.programTitle,
      dayLabel: dayLabel ?? this.dayLabel,
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
