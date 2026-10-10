import 'package:flutter/foundation.dart';

@immutable
class SplashTheme {
  const SplashTheme({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.asset,
  });

  final String id;
  final String title;
  final String subtitle;
  final String asset;
}

@immutable
class AppIconVariant {
  const AppIconVariant({
    required this.id,
    required this.title,
    required this.asset,
  });

  final String id;
  final String title;
  final String asset;
}

abstract final class SplashThemes {
  static const classic = SplashTheme(
    id: 'classic',
    title: 'Классика',
    subtitle: 'Кубок и гриф',
    asset: 'assets/images/splashes/classic.jpg',
  );

  static const ranks = SplashTheme(
    id: 'ranks',
    title: 'Ранги',
    subtitle: 'Лестница медалей',
    asset: 'assets/images/splashes/ranks.jpg',
  );

  static const xp = SplashTheme(
    id: 'xp',
    title: 'Level Up',
    subtitle: 'XP и прокачка',
    asset: 'assets/images/splashes/xp.jpg',
  );

  static const streak = SplashTheme(
    id: 'streak',
    title: 'Серия',
    subtitle: 'Огонь стрика',
    asset: 'assets/images/splashes/streak.jpg',
  );

  static const titan = SplashTheme(
    id: 'titan',
    title: 'Титан',
    subtitle: 'Финальный герб',
    asset: 'assets/images/splashes/titan.jpg',
  );

  static const all = <SplashTheme>[classic, ranks, xp, streak, titan];

  static SplashTheme byId(String? id) {
    for (final theme in all) {
      if (theme.id == id) return theme;
    }
    return classic;
  }
}

abstract final class AppIconVariants {
  static const barbell = AppIconVariant(
    id: 'barbell',
    title: 'Гриф',
    asset: 'assets/icons/app/barbell.jpg',
  );
  static const crest = AppIconVariant(
    id: 'crest',
    title: 'Герб G',
    asset: 'assets/icons/app/crest.jpg',
  );
  static const medal = AppIconVariant(
    id: 'medal',
    title: 'Медаль',
    asset: 'assets/icons/app/medal.jpg',
  );
  static const flame = AppIconVariant(
    id: 'flame',
    title: 'Стрик',
    asset: 'assets/icons/app/flame.jpg',
  );
  static const crown = AppIconVariant(
    id: 'crown',
    title: 'Корона',
    asset: 'assets/icons/app/crown.jpg',
  );
  static const bolt = AppIconVariant(
    id: 'bolt',
    title: 'Молния',
    asset: 'assets/icons/app/bolt.jpg',
  );

  static const all = <AppIconVariant>[
    barbell,
    crest,
    medal,
    flame,
    crown,
    bolt,
  ];

  static AppIconVariant byId(String? id) {
    for (final icon in all) {
      if (icon.id == id) return icon;
    }
    return bolt;
  }
}
