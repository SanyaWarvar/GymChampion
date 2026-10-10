import 'package:flutter/material.dart';

import '../../../core/appearance/appearance_prefs.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_version_label.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    AppearancePrefs.load().then((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final theme = AppearancePrefs.splash;
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            theme.asset,
            fit: BoxFit.cover,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: EdgeInsets.only(bottom: 48 + bottom),
              child: const CircularProgressIndicator(color: AppColors.amber),
            ),
          ),
          Positioned(
            left: 16,
            bottom: 12 + bottom,
            child: const AppVersionLabel(
              alignment: Alignment.centerLeft,
              dimmed: false,
            ),
          ),
        ],
      ),
    );
  }
}
