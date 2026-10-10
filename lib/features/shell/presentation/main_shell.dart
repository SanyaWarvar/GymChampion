import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../workout/data/local_workout_store.dart';
import '../../workout/presentation/minimized_rest_bar.dart';
import '../../workout/presentation/rest_timer_sheet.dart';

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onTap(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  Future<void> _openRest(BuildContext context) async {
    // С другой вкладки — сначала ветка «Тренировка» (indexedStack сохраняет active).
    if (navigationShell.currentIndex != 0) {
      navigationShell.goBranch(0);
    }

    await Future<void>.delayed(Duration.zero);
    if (!context.mounted) return;

    final path = GoRouter.of(context).state.uri.path;
    if (!path.contains('/workout/active')) {
      final draft = await LocalWorkoutStore().load();
      if (!context.mounted) return;
      if (draft != null) {
        context.push('/workout/active', extra: draft);
        await Future<void>.delayed(Duration.zero);
      }
    }

    if (context.mounted) {
      await RestTimerSheet.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          body: navigationShell,
          bottomNavigationBar: NavigationBar(
            selectedIndex: navigationShell.currentIndex,
            onDestinationSelected: _onTap,
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.fitness_center_outlined),
                selectedIcon: Icon(Icons.fitness_center),
                label: 'Тренировка',
              ),
              NavigationDestination(
                icon: Icon(Icons.dynamic_feed_outlined),
                selectedIcon: Icon(Icons.dynamic_feed),
                label: 'Лента',
              ),
              NavigationDestination(
                icon: Icon(Icons.emoji_events_outlined),
                selectedIcon: Icon(Icons.emoji_events),
                label: 'Рейтинг',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: 'Профиль',
              ),
            ],
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          bottom: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: MinimizedRestBar(
                aboveBottomNav: true,
                onOpen: () => unawaited(_openRest(context)),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
