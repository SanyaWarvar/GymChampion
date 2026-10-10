import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/application/auth_controller.dart';
import 'router.dart';

class GymChampionApp extends StatefulWidget {
  const GymChampionApp({super.key, required this.auth});

  final AuthController auth;

  @override
  State<GymChampionApp> createState() => _GymChampionAppState();
}

class _GymChampionAppState extends State<GymChampionApp> {
  late final GoRouter _router = createRouter(widget.auth);

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'GymChampion',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: _router,
    );
  }
}
