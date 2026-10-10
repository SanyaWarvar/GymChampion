import 'package:flutter/material.dart';

import '../../../core/appearance/appearance_prefs.dart';
import '../../../core/appearance/splash_themes.dart';
import '../../../core/theme/app_colors.dart';

class AppearanceScreen extends StatefulWidget {
  const AppearanceScreen({super.key});

  @override
  State<AppearanceScreen> createState() => _AppearanceScreenState();
}

class _AppearanceScreenState extends State<AppearanceScreen> {
  late String _splashId;
  late String _iconId;

  @override
  void initState() {
    super.initState();
    _splashId = AppearancePrefs.splashId;
    _iconId = AppearancePrefs.iconId;
    AppearancePrefs.load().then((_) {
      if (!mounted) return;
      setState(() {
        _splashId = AppearancePrefs.splashId;
        _iconId = AppearancePrefs.iconId;
      });
    });
  }

  Future<void> _pickSplash(SplashTheme theme) async {
    await AppearancePrefs.setSplash(theme.id);
    if (!mounted) return;
    setState(() => _splashId = theme.id);
  }

  Future<void> _pickIcon(AppIconVariant icon) async {
    await AppearancePrefs.setIcon(icon.id);
    if (!mounted) return;
    setState(() => _iconId = icon.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          icon.id == AppIconVariants.bolt.id
              ? '«Молния» — текущая иконка приложения'
              : 'Запомнил «${icon.title}». На рабочем столе пока молния.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Оформление')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          Text(
            'Загрузочный экран',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Показывается при входе. Можно менять когда угодно.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: SplashThemes.all.length,
              separatorBuilder: (_, _) => const SizedBox(width: 10),
              itemBuilder: (context, index) {
                final theme = SplashThemes.all[index];
                final selected = theme.id == _splashId;
                return _SplashCard(
                  theme: theme,
                  selected: selected,
                  onTap: () => _pickSplash(theme),
                );
              },
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Иконка приложения',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 6),
          const Text(
            'На телефоне сейчас «Молния». Остальные — запасные варианты.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: AppIconVariants.all.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 0.82,
            ),
            itemBuilder: (context, index) {
              final icon = AppIconVariants.all[index];
              return _IconCard(
                icon: icon,
                selected: icon.id == _iconId,
                onTap: () => _pickIcon(icon),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SplashCard extends StatelessWidget {
  const _SplashCard({
    required this.theme,
    required this.selected,
    required this.onTap,
  });

  final SplashTheme theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 128,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? AppColors.amber : Colors.transparent,
                    width: 2,
                  ),
                ),
                padding: const EdgeInsets.all(2),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(theme.asset, fit: BoxFit.cover),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              theme.title,
              style: TextStyle(
                fontWeight: FontWeight.w800,
                color: selected ? AppColors.amber : AppColors.onDark,
              ),
            ),
            Text(
              theme.subtitle,
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class _IconCard extends StatelessWidget {
  const _IconCard({
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final AppIconVariant icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: selected ? AppColors.amber : Colors.transparent,
                  width: 2,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Image.asset(icon.asset, fit: BoxFit.cover),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            icon.title,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 12,
              color: selected ? AppColors.amber : AppColors.onDark,
            ),
          ),
        ],
      ),
    );
  }
}
