import 'package:flutter/foundation.dart';

enum ExerciseTrackMode { weightReps, hold, run }

enum MuscleGroup {
  chest,
  back,
  legs,
  shoulders,
  arms,
  core,
  fullBody,
  cardio,
}

extension MuscleGroupX on MuscleGroup {
  String get label => switch (this) {
        MuscleGroup.chest => 'Грудь',
        MuscleGroup.back => 'Спина',
        MuscleGroup.legs => 'Ноги',
        MuscleGroup.shoulders => 'Плечи',
        MuscleGroup.arms => 'Руки',
        MuscleGroup.core => 'Кор',
        MuscleGroup.fullBody => 'Всё тело',
        MuscleGroup.cardio => 'Кардио',
      };

  String get iconAsset => switch (this) {
        MuscleGroup.chest => 'assets/icons/muscles/chest.jpg',
        MuscleGroup.back => 'assets/icons/muscles/back.jpg',
        MuscleGroup.legs => 'assets/icons/muscles/legs.jpg',
        MuscleGroup.shoulders => 'assets/icons/muscles/shoulders.jpg',
        MuscleGroup.arms => 'assets/icons/muscles/arms.jpg',
        MuscleGroup.core => 'assets/icons/muscles/core.jpg',
        MuscleGroup.fullBody => 'assets/icons/muscles/full_body.jpg',
        MuscleGroup.cardio => 'assets/icons/muscles/cardio.jpg',
      };
}

@immutable
class CatalogExercise {
  const CatalogExercise({
    required this.id,
    required this.name,
    required this.muscle,
    this.track = ExerciseTrackMode.weightReps,
    this.defaultQty = 8,
    this.defaultDistanceKm = 0,
  });

  final String id;
  final String name;
  final MuscleGroup muscle;
  final ExerciseTrackMode track;
  final int defaultQty;
  final double defaultDistanceKm;

  bool get isHold => track == ExerciseTrackMode.hold;
  bool get isRun => track == ExerciseTrackMode.run;

  String get iconAsset => 'assets/icons/exercises/$id.jpg';
}

abstract final class ExerciseCatalog {
  static const exercises = <CatalogExercise>[
    CatalogExercise(id: 'bench_press', name: 'Жим лёжа', muscle: MuscleGroup.chest),
    CatalogExercise(id: 'incline_bench', name: 'Жим на наклонной', muscle: MuscleGroup.chest),
    CatalogExercise(id: 'dumbbell_fly', name: 'Разведение гантелей', muscle: MuscleGroup.chest),
    CatalogExercise(id: 'push_up', name: 'Отжимания', muscle: MuscleGroup.chest),
    CatalogExercise(id: 'chest_press', name: 'Жим в тренажёре', muscle: MuscleGroup.chest),
    CatalogExercise(id: 'pec_deck', name: 'Бабочка', muscle: MuscleGroup.chest),
    CatalogExercise(id: 'cable_crossover', name: 'Кроссовер', muscle: MuscleGroup.chest),
    CatalogExercise(id: 'pull_up', name: 'Подтягивания', muscle: MuscleGroup.back),
    CatalogExercise(id: 'barbell_row', name: 'Тяга штанги в наклоне', muscle: MuscleGroup.back),
    CatalogExercise(id: 'lat_pulldown', name: 'Тяга верхнего блока', muscle: MuscleGroup.back),
    CatalogExercise(id: 'seated_row', name: 'Тяга горизонтального блока', muscle: MuscleGroup.back),
    CatalogExercise(id: 'deadlift', name: 'Становая тяга', muscle: MuscleGroup.back),
    CatalogExercise(id: 'hyperextension', name: 'Гиперэкстензия', muscle: MuscleGroup.back),
    CatalogExercise(id: 'machine_pullover', name: 'Пуловер в тренажёре', muscle: MuscleGroup.back),
    CatalogExercise(id: 't_bar_row', name: 'Тяга Т-грифа', muscle: MuscleGroup.back),
    CatalogExercise(id: 'squat', name: 'Присед', muscle: MuscleGroup.legs),
    CatalogExercise(id: 'front_squat', name: 'Фронтальный присед', muscle: MuscleGroup.legs),
    CatalogExercise(id: 'leg_press', name: 'Жим ногами', muscle: MuscleGroup.legs),
    CatalogExercise(id: 'romanian_deadlift', name: 'Румынская тяга', muscle: MuscleGroup.legs),
    CatalogExercise(id: 'lunge', name: 'Выпады', muscle: MuscleGroup.legs),
    CatalogExercise(id: 'leg_curl', name: 'Сгибания ног', muscle: MuscleGroup.legs),
    CatalogExercise(id: 'leg_extension', name: 'Разгибания ног', muscle: MuscleGroup.legs),
    CatalogExercise(id: 'calf_raise', name: 'Подъёмы на носки', muscle: MuscleGroup.legs),
    CatalogExercise(id: 'hack_squat', name: 'Гакк-присед', muscle: MuscleGroup.legs),
    CatalogExercise(id: 'hip_adductor', name: 'Сведение ног', muscle: MuscleGroup.legs),
    CatalogExercise(id: 'hip_abductor', name: 'Разведение ног', muscle: MuscleGroup.legs),
    CatalogExercise(id: 'hip_thrust_machine', name: 'Ягодичный мост в тренажёре', muscle: MuscleGroup.legs),
    CatalogExercise(id: 'glute_kickback', name: 'Махи назад в кроссовере', muscle: MuscleGroup.legs),
    CatalogExercise(id: 'seated_calf_raise', name: 'Подъёмы на носки сидя', muscle: MuscleGroup.legs),
    CatalogExercise(id: 'ohp', name: 'Жим стоя', muscle: MuscleGroup.shoulders),
    CatalogExercise(id: 'lateral_raise', name: 'Махи в стороны', muscle: MuscleGroup.shoulders),
    CatalogExercise(id: 'face_pull', name: 'Face pull', muscle: MuscleGroup.shoulders),
    CatalogExercise(id: 'shoulder_press_machine', name: 'Жим сидя в тренажёре', muscle: MuscleGroup.shoulders),
    CatalogExercise(id: 'reverse_pec_deck', name: 'Обратная бабочка', muscle: MuscleGroup.shoulders),
    CatalogExercise(id: 'cable_lateral_raise', name: 'Махи в стороны в кроссовере', muscle: MuscleGroup.shoulders),
    CatalogExercise(id: 'barbell_curl', name: 'Сгибания на бицепс', muscle: MuscleGroup.arms),
    CatalogExercise(id: 'hammer_curl', name: 'Молотки', muscle: MuscleGroup.arms),
    CatalogExercise(id: 'triceps_pushdown', name: 'Разгибания на трицепс', muscle: MuscleGroup.arms),
    CatalogExercise(id: 'skull_crusher', name: 'Французский жим', muscle: MuscleGroup.arms),
    CatalogExercise(id: 'dips', name: 'Отжимания на брусьях', muscle: MuscleGroup.arms),
    CatalogExercise(id: 'preacher_curl', name: 'Сгибания на скамье Скотта', muscle: MuscleGroup.arms),
    CatalogExercise(id: 'cable_curl', name: 'Сгибания на бицепс в кроссовере', muscle: MuscleGroup.arms),
    CatalogExercise(id: 'overhead_cable_extension', name: 'Разгибания из-за головы в кроссовере', muscle: MuscleGroup.arms),
    CatalogExercise(id: 'triceps_machine', name: 'Жим на трицепс в тренажёре', muscle: MuscleGroup.arms),
    CatalogExercise(
      id: 'plank',
      name: 'Планка',
      muscle: MuscleGroup.core,
      track: ExerciseTrackMode.hold,
      defaultQty: 45,
    ),
    CatalogExercise(id: 'crunch', name: 'Скручивания', muscle: MuscleGroup.core),
    CatalogExercise(id: 'hanging_leg_raise', name: 'Подъёмы ног в висе', muscle: MuscleGroup.core),
    CatalogExercise(id: 'cable_crunch', name: 'Скручивания в кроссовере', muscle: MuscleGroup.core),
    CatalogExercise(id: 'ab_machine', name: 'Скручивания в тренажёре', muscle: MuscleGroup.core),
    CatalogExercise(
      id: 'run',
      name: 'Бег',
      muscle: MuscleGroup.cardio,
      track: ExerciseTrackMode.run,
      defaultQty: 1800,
      defaultDistanceKm: 5,
    ),
    CatalogExercise(
      id: 'bike',
      name: 'Велотренажёр',
      muscle: MuscleGroup.cardio,
      track: ExerciseTrackMode.run,
      defaultQty: 1800,
      defaultDistanceKm: 10,
    ),
    CatalogExercise(
      id: 'elliptical',
      name: 'Эллипс',
      muscle: MuscleGroup.cardio,
      track: ExerciseTrackMode.run,
      defaultQty: 1800,
      defaultDistanceKm: 5,
    ),
    CatalogExercise(
      id: 'row_erg',
      name: 'Гребной тренажёр',
      muscle: MuscleGroup.cardio,
      track: ExerciseTrackMode.run,
      defaultQty: 1200,
      defaultDistanceKm: 2,
    ),
    CatalogExercise(
      id: 'stair_climber',
      name: 'Степпер',
      muscle: MuscleGroup.cardio,
      track: ExerciseTrackMode.run,
      defaultQty: 1200,
      defaultDistanceKm: 1,
    ),
    CatalogExercise(id: 'farmer_walk', name: 'Прогулка фермера', muscle: MuscleGroup.fullBody),
    CatalogExercise(id: 'kettlebell_swing', name: 'Махи гирей', muscle: MuscleGroup.fullBody),
  ];

  static CatalogExercise? lookup({String? exerciseId, String? name}) {
    if (exerciseId != null) {
      final match = byId(exerciseId);
      if (match != null) return match;
    }
    if (name != null) return byName(name);
    return null;
  }

  static bool isHold({String? exerciseId, String? name}) =>
      lookup(exerciseId: exerciseId, name: name)?.isHold ?? false;

  static bool isRun({String? exerciseId, String? name}) =>
      lookup(exerciseId: exerciseId, name: name)?.isRun ?? false;

  static String weightColumnLabel({String? exerciseId, String? name}) {
    if (isRun(exerciseId: exerciseId, name: name)) return 'Км';
    if (isHold(exerciseId: exerciseId, name: name)) return 'Отяг.';
    return 'Кг';
  }

  static String qtyColumnLabel({String? exerciseId, String? name}) {
    if (isRun(exerciseId: exerciseId, name: name)) return 'Мин';
    if (isHold(exerciseId: exerciseId, name: name)) return 'Сек';
    return 'Повт';
  }

  static String formatDurationSec(int sec) {
    if (sec <= 0) return '';
    final m = sec ~/ 60;
    final s = sec % 60;
    if (s == 0) return '$m мин';
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static String formatClock(int sec) {
    if (sec <= 0) return '';
    final m = sec ~/ 60;
    final s = sec % 60;
    if (s == 0) return '$m';
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  static int parseDurationInput(String raw) {
    final text = raw.trim().replaceAll(',', '.');
    if (text.isEmpty) return 0;
    if (text.contains(':')) {
      final parts = text.split(':');
      final minutes = int.tryParse(parts[0]) ?? 0;
      final seconds = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
      return (minutes * 60 + seconds).clamp(0, 24 * 3600);
    }
    final minutes = double.tryParse(text) ?? 0;
    return (minutes * 60).round().clamp(0, 24 * 3600);
  }

  static int? paceSecPerKm({required double km, required int durationSec}) {
    if (km < 0.2 || durationSec <= 0) return null;
    return (durationSec / km).round();
  }

  static String formatPace(int? secPerKm) {
    if (secPerKm == null || secPerKm <= 0) return '';
    final m = secPerKm ~/ 60;
    final s = secPerKm % 60;
    return '$m:${s.toString().padLeft(2, '0')}/км';
  }

  static String formatKm(double km) {
    if (km <= 0) return '';
    if (km == km.roundToDouble()) return '${km.round()} км';
    return '${km.toStringAsFixed(km < 10 ? 2 : 1)} км';
  }

  static String formatLoad({required double volumeKg, double runKm = 0}) {
    final parts = <String>[];
    if (volumeKg > 0) parts.add('${volumeKg.round()} кг');
    final km = formatKm(runKm);
    if (km.isNotEmpty) parts.add(km);
    return parts.join(' · ');
  }

  static String formatSet({
    required double weightKg,
    required int qty,
    String? exerciseId,
    String? name,
  }) {
    if (isRun(exerciseId: exerciseId, name: name)) {
      final km = formatKm(weightKg);
      final time = formatDurationSec(qty);
      final pace = formatPace(paceSecPerKm(km: weightKg, durationSec: qty));
      if (km.isEmpty && time.isEmpty) return '—';
      if (km.isEmpty) return time;
      if (time.isEmpty) return km;
      if (pace.isEmpty) return '$km · $time';
      return '$km · $time ($pace)';
    }
    final hold = isHold(exerciseId: exerciseId, name: name);
    final kg = weightKg == weightKg.roundToDouble()
        ? '${weightKg.round()}'
        : '$weightKg';
    if (hold) {
      if (weightKg <= 0) return '$qty сек';
      return '$kg кг × $qty сек';
    }
    if (weightKg <= 0) return '$qty повт.';
    return '$kg кг × $qty';
  }

  static CatalogExercise? byId(String id) {
    for (final e in exercises) {
      if (e.id == id) return e;
    }
    return null;
  }

  static CatalogExercise? byName(String name) {
    final q = name.trim().toLowerCase();
    if (q.isEmpty) return null;
    for (final e in exercises) {
      if (e.name.toLowerCase() == q) return e;
    }
    for (final e in exercises) {
      if (e.name.toLowerCase().contains(q) || q.contains(e.name.toLowerCase())) {
        return e;
      }
    }
    return null;
  }

  /// Путь к иконке по id каталога или названию. null — нет в каталоге.
  static String? iconAssetFor({String? exerciseId, String? name}) {
    if (exerciseId != null) {
      final byIdMatch = byId(exerciseId);
      if (byIdMatch != null) return byIdMatch.iconAsset;
      // Ключ уже похож на id файла.
      if (exerciseId.contains('_') || !exerciseId.contains(' ')) {
        return 'assets/icons/exercises/$exerciseId.jpg';
      }
    }
    if (name != null) {
      return byName(name)?.iconAsset;
    }
    return null;
  }

  static List<CatalogExercise> search({
    String query = '',
    MuscleGroup? muscle,
  }) {
    final q = query.trim().toLowerCase();
    return exercises.where((e) {
      final muscleOk = muscle == null || e.muscle == muscle;
      final queryOk = q.isEmpty || e.name.toLowerCase().contains(q);
      return muscleOk && queryOk;
    }).toList();
  }
}
