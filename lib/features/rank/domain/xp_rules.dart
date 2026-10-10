import 'package:flutter/material.dart';

/// Медали зала: Новичок → Титан, звёзды 1–5 (у Титана без звёзд).
@immutable
class MedalRank {
  const MedalRank({
    required this.id,
    required this.medalKey,
    required this.title,
    required this.stars,
    required this.threshold,
    required this.missPenalty,
    required this.color,
  });

  final String id;
  final String medalKey;
  final String title;
  final int stars; // 0 у Титана
  final int threshold;
  final int missPenalty;
  final Color color;

  String get label {
    if (stars <= 0) return title;
    return '$title ${'★' * stars}';
  }

  String get shortLabel {
    if (stars <= 0) return title;
    return '$title $stars★';
  }

  String get iconAsset => 'assets/icons/medals/$medalKey.jpg';

  bool get hasStars => stars > 0;
}

/// Система XP и медалей зала.
abstract final class XpRules {
  static const _medalDefs = <(String key, String title, int color)>[
    ('novice', 'Новичок', 0xFF8B7355),
    ('intern', 'Стажёр', 0xFF4CAF7A),
    ('athlete', 'Атлет', 0xFF5CB85C),
    ('gladiator', 'Гладиатор', 0xFF4A9BE8),
    ('champion', 'Чемпион', 0xFF5B7CFF),
    ('master', 'Мастер', 0xFFC45CFF),
    ('colossus', 'Колосс', 0xFF5AD4FF),
    ('titan', 'Титан', 0xFFFF8A3D),
  ];

  /// Старые Dota-ключи из Firestore / ленты.
  static const _legacyMedal = <String, String>{
    'herald': 'novice',
    'guardian': 'intern',
    'crusader': 'athlete',
    'archon': 'gladiator',
    'legend': 'champion',
    'ancient': 'master',
    'divine': 'colossus',
    'immortal': 'titan',
  };

  /// Пороги XP: плотная сессия ~150–220 XP, Титан — долгий сезон, не месяц.
  static final List<MedalRank> ranks = _buildRanks();

  static final List<String> rankOrder =
      ranks.map((r) => r.id).toList(growable: false);

  static final Map<String, int> rankThresholds = {
    for (final r in ranks) r.id: r.threshold,
  };

  static const _missPenaltyByMedal = <String, int>{
    'novice': 35,
    'intern': 50,
    'athlete': 70,
    'gladiator': 95,
    'champion': 125,
    'master': 165,
    'colossus': 210,
    'titan': 260,
  };

  static List<MedalRank> _buildRanks() {
    // Раньше Титан открывался за ~месяц. Теперь лестница растянута:
    // Новичок за первые недели, Гладиатор за сезон, Титан — за долгую серию.
    const starSteps = <String, List<int>>{
      'novice': [0, 350, 800, 1400, 2100],
      'intern': [3000, 4100, 5400, 6900, 8600],
      'athlete': [10800, 13400, 16400, 19800, 23600],
      'gladiator': [28000, 32800, 38000, 43600, 49600],
      'champion': [56400, 60000, 63800, 67800, 72000],
      'master': [76800, 82000, 87600, 93600, 100000],
      'colossus': [107200, 115000, 123400, 132400, 142000],
      'titan': [153000],
    };

    final out = <MedalRank>[];
    for (final (key, title, colorValue) in _medalDefs) {
      final steps = starSteps[key]!;
      final miss = _missPenaltyByMedal[key] ?? 35;
      for (var i = 0; i < steps.length; i++) {
        final stars = key == 'titan' ? 0 : i + 1;
        out.add(
          MedalRank(
            id: key == 'titan' ? 'titan' : '${key}_$stars',
            medalKey: key,
            title: title,
            stars: stars,
            threshold: steps[i],
            missPenalty: miss,
            color: Color(colorValue),
          ),
        );
      }
    }
    return List.unmodifiable(out);
  }

  static String canonicalizeId(String id) {
    if (_legacyMedal.containsKey(id)) return _legacyMedal[id]!;
    final sep = id.lastIndexOf('_');
    if (sep > 0) {
      final prefix = id.substring(0, sep);
      final mapped = _legacyMedal[prefix];
      if (mapped != null) return '$mapped${id.substring(sep)}';
    }
    return id;
  }

  static MedalRank medalForId(String id) {
    final key = canonicalizeId(id);
    for (final r in ranks) {
      if (r.id == key) return r;
    }
    return ranks.first;
  }

  static MedalRank medalForXp(int xp) {
    var current = ranks.first;
    for (final r in ranks) {
      if (xp >= r.threshold) current = r;
    }
    return current;
  }

  /// XP = база + подходы + объём + время + бонус за разнообразие.
  static int xpForWorkout({
    required int doneSets,
    required double volumeKg,
    required int durationSec,
    int exerciseCount = 1,
    double runKm = 0,
  }) {
    final minutes = (durationSec / 60).round().clamp(0, 80);
    final volumeBonus = (volumeKg / 60).round().clamp(0, 160);
    final runBonus = (runKm * 8).round().clamp(0, 140);
    final setsBonus = (doneSets * 6).clamp(0, 90);
    final varietyBonus = exerciseCount >= 4
        ? 24
        : exerciseCount >= 3
            ? 14
            : exerciseCount >= 2
                ? 6
                : 0;
    final enduranceBonus = minutes >= 45 ? 14 : (minutes >= 30 ? 6 : 0);
    return 30 +
        setsBonus +
        volumeBonus +
        runBonus +
        minutes +
        varietyBonus +
        enduranceBonus;
  }

  /// Baseline (Новичок) — для текста без контекста ранга.
  static const int xpForMissedDay = 35;
  static const int maxMissedDaysPerSync = 7;

  static int xpForMissedDayAt(int xp) => medalForXp(xp).missPenalty;

  /// Списывает пропуски по текущему рангу: каждый день считает штраф заново,
  /// поэтому после падения медали следующие дни бьют слабее.
  static ({int xp, int seasonXp, int lost}) applyMissedDays({
    required int xp,
    required int seasonXp,
    required int days,
  }) {
    var nextXp = xp;
    var nextSeason = seasonXp;
    var lost = 0;
    final n = days.clamp(0, maxMissedDaysPerSync);
    for (var i = 0; i < n; i++) {
      final hit = xpForMissedDayAt(nextXp);
      nextXp = (nextXp - hit).clamp(0, 1 << 30);
      nextSeason = (nextSeason - hit).clamp(0, 1 << 30);
      lost += hit;
    }
    return (xp: nextXp, seasonXp: nextSeason, lost: lost);
  }

  static Map<String, int> xpBreakdown({
    required int doneSets,
    required double volumeKg,
    required int durationSec,
    int exerciseCount = 1,
    double runKm = 0,
  }) {
    final minutes = (durationSec / 60).round().clamp(0, 80);
    final volumeBonus = (volumeKg / 60).round().clamp(0, 160);
    final runBonus = (runKm * 8).round().clamp(0, 140);
    final setsBonus = (doneSets * 6).clamp(0, 90);
    final varietyBonus = exerciseCount >= 4
        ? 24
        : exerciseCount >= 3
            ? 14
            : exerciseCount >= 2
                ? 6
                : 0;
    final enduranceBonus = minutes >= 45 ? 14 : (minutes >= 30 ? 6 : 0);
    return {
      'База': 30,
      'Подходы': setsBonus,
      'Объём': volumeBonus,
      'Бег': runBonus,
      'Время': minutes,
      'Разнообразие': varietyBonus,
      'Долгая сессия': enduranceBonus,
    };
  }

  static String rankForXp(int xp) => medalForXp(xp).id;

  static String titleForRank(String rank) => medalForId(rank).label;

  static String shortTitleForRank(String rank) => medalForId(rank).shortLabel;

  static Color colorForRank(String rank) => medalForId(rank).color;

  static int xpToNextRank(int xp) {
    final current = medalForXp(xp);
    final index = ranks.indexWhere((r) => r.id == current.id);
    if (index < 0 || index >= ranks.length - 1) return 0;
    return ranks[index + 1].threshold - xp;
  }

  static String? nextRank(int xp) {
    final current = medalForXp(xp);
    final index = ranks.indexWhere((r) => r.id == current.id);
    if (index < 0 || index >= ranks.length - 1) return null;
    return ranks[index + 1].id;
  }

  static String? nextRankLabel(int xp) {
    final id = nextRank(xp);
    return id == null ? null : titleForRank(id);
  }

  static double progressToNextRank(int xp) {
    final current = medalForXp(xp);
    final index = ranks.indexWhere((r) => r.id == current.id);
    if (index < 0 || index >= ranks.length - 1) return 1;
    final start = ranks[index].threshold;
    final end = ranks[index + 1].threshold;
    if (end <= start) return 1;
    return ((xp - start) / (end - start)).clamp(0.0, 1.0);
  }

  /// Ранг всегда из XP: смена порогов сразу двигает медаль.
  static String normalizeRank(String? stored, int xp) => rankForXp(xp);
}
