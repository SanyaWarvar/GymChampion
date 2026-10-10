import 'exercise_catalog.dart';
import 'workout_template.dart';

/// Built-in workout variants. Seeded into the user's templates once.
abstract final class PresetTemplates {
  static TemplateExercise _ex(
    String id, {
    int sets = 3,
    int reps = 8,
    double weight = 0,
  }) {
    final cat = ExerciseCatalog.byId(id);
    return TemplateExercise(
      exerciseId: id,
      name: cat?.name ?? id,
      targetSets: sets,
      targetReps: reps,
      targetWeightKg: weight,
    );
  }

  static final all = <WorkoutTemplate>[
    WorkoutTemplate(
      id: 'preset_push',
      name: 'Push — грудь / плечи / трицепс',
      exercises: [
        _ex('bench_press', sets: 4, reps: 6),
        _ex('incline_bench', sets: 3, reps: 8),
        _ex('ohp', sets: 3, reps: 8),
        _ex('lateral_raise', sets: 3, reps: 12),
        _ex('dips', sets: 3, reps: 10),
        _ex('triceps_pushdown', sets: 3, reps: 12),
      ],
    ),
    WorkoutTemplate(
      id: 'preset_pull',
      name: 'Pull — спина / бицепс',
      exercises: [
        _ex('pull_up', sets: 4, reps: 6),
        _ex('barbell_row', sets: 4, reps: 8),
        _ex('lat_pulldown', sets: 3, reps: 10),
        _ex('seated_row', sets: 3, reps: 10),
        _ex('face_pull', sets: 3, reps: 15),
        _ex('barbell_curl', sets: 3, reps: 10),
        _ex('hammer_curl', sets: 2, reps: 12),
      ],
    ),
    WorkoutTemplate(
      id: 'preset_legs',
      name: 'Legs — ноги',
      exercises: [
        _ex('squat', sets: 4, reps: 6),
        _ex('romanian_deadlift', sets: 3, reps: 8),
        _ex('leg_press', sets: 3, reps: 10),
        _ex('lunge', sets: 3, reps: 10),
        _ex('leg_curl', sets: 3, reps: 12),
        _ex('calf_raise', sets: 4, reps: 15),
      ],
    ),
    WorkoutTemplate(
      id: 'preset_upper',
      name: 'Upper — верх тела',
      exercises: [
        _ex('bench_press', sets: 4, reps: 6),
        _ex('barbell_row', sets: 4, reps: 8),
        _ex('ohp', sets: 3, reps: 8),
        _ex('lat_pulldown', sets: 3, reps: 10),
        _ex('lateral_raise', sets: 3, reps: 12),
        _ex('barbell_curl', sets: 2, reps: 10),
        _ex('triceps_pushdown', sets: 2, reps: 12),
      ],
    ),
    WorkoutTemplate(
      id: 'preset_full_body',
      name: 'Full body',
      exercises: [
        _ex('squat', sets: 3, reps: 8),
        _ex('bench_press', sets: 3, reps: 8),
        _ex('barbell_row', sets: 3, reps: 8),
        _ex('ohp', sets: 3, reps: 10),
        _ex('romanian_deadlift', sets: 3, reps: 8),
        _ex('plank', sets: 3, reps: 45),
      ],
    ),
    WorkoutTemplate(
      id: 'preset_chest',
      name: 'Грудь + трицепс',
      exercises: [
        _ex('bench_press', sets: 4, reps: 6),
        _ex('incline_bench', sets: 3, reps: 8),
        _ex('dumbbell_fly', sets: 3, reps: 12),
        _ex('dips', sets: 3, reps: 10),
        _ex('skull_crusher', sets: 3, reps: 10),
        _ex('triceps_pushdown', sets: 3, reps: 12),
      ],
    ),
    WorkoutTemplate(
      id: 'preset_sl_a',
      name: 'StrongLifts 5×5 · День A',
      programId: 'stronglifts',
      programTitle: 'StrongLifts 5×5',
      dayLabel: 'День A',
      exercises: [
        _ex('squat', sets: 5, reps: 5),
        _ex('bench_press', sets: 5, reps: 5),
        _ex('barbell_row', sets: 5, reps: 5),
      ],
    ),
    WorkoutTemplate(
      id: 'preset_sl_b',
      name: 'StrongLifts 5×5 · День B',
      programId: 'stronglifts',
      programTitle: 'StrongLifts 5×5',
      dayLabel: 'День B',
      exercises: [
        _ex('squat', sets: 5, reps: 5),
        _ex('ohp', sets: 5, reps: 5),
        _ex('pull_up', sets: 5, reps: 5),
      ],
    ),
    WorkoutTemplate(
      id: 'preset_ss_a',
      name: 'Starting Strength · День A',
      programId: 'starting_strength',
      programTitle: 'Starting Strength',
      dayLabel: 'День A',
      exercises: [
        _ex('squat', sets: 3, reps: 5),
        _ex('bench_press', sets: 3, reps: 5),
        _ex('barbell_row', sets: 3, reps: 5),
      ],
    ),
    WorkoutTemplate(
      id: 'preset_ss_b',
      name: 'Starting Strength · День B',
      programId: 'starting_strength',
      programTitle: 'Starting Strength',
      dayLabel: 'День B',
      exercises: [
        _ex('squat', sets: 3, reps: 5),
        _ex('ohp', sets: 3, reps: 5),
        _ex('pull_up', sets: 3, reps: 5),
      ],
    ),
    WorkoutTemplate(
      id: 'preset_back',
      name: 'Спина + бицепс',
      exercises: [
        _ex('pull_up', sets: 3, reps: 8),
        _ex('barbell_row', sets: 3, reps: 8),
        _ex('seated_row', sets: 3, reps: 10),
        _ex('face_pull', sets: 3, reps: 15),
        _ex('barbell_curl', sets: 3, reps: 10),
        _ex('hammer_curl', sets: 2, reps: 12),
      ],
    ),
    WorkoutTemplate(
      id: 'preset_run_a',
      name: 'Бег · День A — лёгкие 5 км',
      programId: 'run',
      programTitle: 'Бег',
      dayLabel: 'День A · лёгкие 5 км',
      exercises: [
        _ex('run', sets: 1, reps: 30 * 60, weight: 5),
      ],
    ),
    WorkoutTemplate(
      id: 'preset_run_b',
      name: 'Бег · День B — интервалы 6×1 км',
      programId: 'run',
      programTitle: 'Бег',
      dayLabel: 'День B · интервалы 6×1 км',
      exercises: [
        _ex('run', sets: 6, reps: 4 * 60, weight: 1),
      ],
    ),
    WorkoutTemplate(
      id: 'preset_run_c',
      name: 'Бег · День C — длинные 10 км',
      programId: 'run',
      programTitle: 'Бег',
      dayLabel: 'День C · длинные 10 км',
      exercises: [
        _ex('run', sets: 1, reps: 55 * 60, weight: 10),
      ],
    ),
    WorkoutTemplate(
      id: 'preset_shoulders_arms',
      name: 'Плечи + руки',
      exercises: [
        _ex('ohp', sets: 4, reps: 8),
        _ex('lateral_raise', sets: 4, reps: 12),
        _ex('face_pull', sets: 3, reps: 15),
        _ex('barbell_curl', sets: 3, reps: 10),
        _ex('hammer_curl', sets: 3, reps: 12),
        _ex('skull_crusher', sets: 3, reps: 10),
        _ex('triceps_pushdown', sets: 3, reps: 12),
      ],
    ),
  ];
}
