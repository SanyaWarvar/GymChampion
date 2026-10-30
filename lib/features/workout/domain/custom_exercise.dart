import 'package:flutter/foundation.dart';

import 'exercise_catalog.dart';

@immutable
class CustomExercise {
  const CustomExercise({
    required this.id,
    required this.name,
    required this.muscle,
  });

  final String id;
  final String name;
  final MuscleGroup muscle;

  Map<String, dynamic> toMap() => {'name': name, 'muscle': muscle.name};

  factory CustomExercise.fromMap(String id, Map<String, dynamic> data) {
    return CustomExercise(
      id: id,
      name: data['name'] as String? ?? '',
      muscle: MuscleGroupX.parse(data['muscle'] as String?),
    );
  }
}
