import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Метеорологическое время года (целые месяцы, северное полушарие).
enum SeasonKind { winter, spring, summer, autumn }

extension SeasonKindX on SeasonKind {
  String get label => switch (this) {
        SeasonKind.winter => 'Зима',
        SeasonKind.spring => 'Весна',
        SeasonKind.summer => 'Лето',
        SeasonKind.autumn => 'Осень',
      };

  String get flavor => switch (this) {
        SeasonKind.winter => 'Железный холод',
        SeasonKind.spring => 'Весенний рывок',
        SeasonKind.summer => 'Летний жар',
        SeasonKind.autumn => 'Осенний набор',
      };

  Color get color => switch (this) {
        SeasonKind.winter => const Color(0xFF5AD4FF),
        SeasonKind.spring => const Color(0xFF5CB85C),
        SeasonKind.summer => const Color(0xFFFF8A3D),
        SeasonKind.autumn => const Color(0xFFC45CFF),
      };
}

/// Сезон = одно время года. Сезонный XP сбрасывается на стыке зима/весна/лето/осень.
@immutable
class Season {
  const Season({
    required this.id,
    required this.kind,
    required this.title,
    required this.startsAt,
    required this.endsAt,
  });

  final String id;
  final SeasonKind kind;
  final String title;
  final DateTime startsAt;
  final DateTime endsAt;

  String get flavor => kind.flavor;

  Color get color => kind.color;

  int get daysLeft {
    final now = DateTime.now();
    if (!now.isBefore(endsAt)) return 0;
    final today = DateTime(now.year, now.month, now.day);
    return endsAt.difference(today).inDays;
  }

  bool contains(DateTime dt) =>
      !dt.isBefore(startsAt) && dt.isBefore(endsAt);

  Season get next => Season.at(endsAt);

  static Season current([DateTime? now]) => at(now ?? DateTime.now());

  /// Зима: 1 дек — 1 мар. Весна: 1 мар — 1 июн. Лето: 1 июн — 1 сен. Осень: 1 сен — 1 дек.
  static Season at(DateTime now) {
    final n = DateTime(now.year, now.month, now.day);
    final SeasonKind kind;
    final DateTime startsAt;
    if (n.month == 12) {
      kind = SeasonKind.winter;
      startsAt = DateTime(n.year, 12, 1);
    } else if (n.month <= 2) {
      kind = SeasonKind.winter;
      startsAt = DateTime(n.year - 1, 12, 1);
    } else if (n.month <= 5) {
      kind = SeasonKind.spring;
      startsAt = DateTime(n.year, 3, 1);
    } else if (n.month <= 8) {
      kind = SeasonKind.summer;
      startsAt = DateTime(n.year, 6, 1);
    } else {
      kind = SeasonKind.autumn;
      startsAt = DateTime(n.year, 9, 1);
    }

    final endsAt = switch (kind) {
      SeasonKind.winter => DateTime(startsAt.year + 1, 3, 1),
      SeasonKind.spring => DateTime(startsAt.year, 6, 1),
      SeasonKind.summer => DateTime(startsAt.year, 9, 1),
      SeasonKind.autumn => DateTime(startsAt.year, 12, 1),
    };

    final yearLabel = kind == SeasonKind.winter
        ? '${startsAt.year}/${((startsAt.year + 1) % 100).toString().padLeft(2, '0')}'
        : '${startsAt.year}';
    final title = '${kind.label} $yearLabel';

    return Season(
      id: '${startsAt.year}-${kind.name}',
      kind: kind,
      title: title,
      startsAt: startsAt,
      endsAt: endsAt,
    );
  }

  static List<Season> yearCycle([DateTime? now]) {
    var cursor = Season.current(now);
    while (cursor.kind != SeasonKind.winter) {
      cursor = Season.at(cursor.startsAt.subtract(const Duration(days: 1)));
    }
    final out = <Season>[];
    for (var i = 0; i < 4; i++) {
      out.add(cursor);
      cursor = cursor.next;
    }
    return out;
  }

  static const rules = [
    'Сезон длится одно время года: зима, весна, лето или осень.',
    'Зима — декабрь–февраль, весна — март–май, лето — июнь–август, осень — сентябрь–ноябрь.',
    'Сезонный XP копится отдельно от общего и обнуляется на стыке времён года.',
    'Медали (Новичок → Титан) зависят от общего XP и не сбрасываются.',
    'Rank Check раз в 2 недели подтверждает, что ты ещё в форме.',
  ];
}
