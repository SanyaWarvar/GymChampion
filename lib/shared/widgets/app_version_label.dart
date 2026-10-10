import 'package:flutter/material.dart';

import '../../core/app_version.dart';
import '../../core/theme/app_colors.dart';

/// Shows app version (e.g. `v1.1.0 (2)`).
class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({
    super.key,
    this.alignment = Alignment.center,
    this.dimmed = true,
  });

  final AlignmentGeometry alignment;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: Text(
        AppVersion.label,
        style: TextStyle(
          color: dimmed
              ? AppColors.muted.withValues(alpha: 0.85)
              : AppColors.onDark.withValues(alpha: 0.7),
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
