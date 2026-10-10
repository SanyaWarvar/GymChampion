import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

class StreakFlame extends StatelessWidget {
  const StreakFlame({
    super.key,
    required this.days,
    this.freezes = 0,
    this.compact = false,
  });

  final int days;
  final int freezes;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final active = days > 0;
    final color = active ? AppColors.amber : AppColors.muted;
    final iconSize = compact ? 16.0 : 22.0;
    final textStyle = TextStyle(
      color: color,
      fontWeight: FontWeight.w800,
      fontSize: compact ? 13 : 16,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.local_fire_department, color: color, size: iconSize),
        const SizedBox(width: 2),
        Text('$days', style: textStyle),
        if (!compact) ...[
          const SizedBox(width: 8),
          Icon(
            Icons.ac_unit,
            color: freezes > 0 ? const Color(0xFF5AD4FF) : AppColors.muted,
            size: 16,
          ),
          const SizedBox(width: 2),
          Text(
            '$freezes',
            style: TextStyle(
              color: freezes > 0 ? const Color(0xFF5AD4FF) : AppColors.muted,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
          ),
        ],
      ],
    );
  }
}
