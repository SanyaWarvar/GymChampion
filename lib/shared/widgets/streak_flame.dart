import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../features/rank/domain/streak_rules.dart';

class StreakFlame extends StatelessWidget {
  const StreakFlame({
    super.key,
    required this.days,
    this.freezes = 0,
    this.lastDate,
    this.compact = false,
  });

  final int days;
  final int freezes;
  final DateTime? lastDate;
  final bool compact;

  bool get _lit {
    if (days <= 0 || lastDate == null) return false;
    return StreakRules.dateOnly(lastDate!) ==
        StreakRules.dateOnly(DateTime.now());
  }

  @override
  Widget build(BuildContext context) {
    final lit = _lit;
    final hasStreak = days > 0;
    final numberColor = hasStreak ? AppColors.amber : AppColors.muted;
    final iconColor = lit ? AppColors.amber : AppColors.muted;
    final iconSize = compact ? 16.0 : 22.0;
    final textStyle = TextStyle(
      color: numberColor,
      fontWeight: FontWeight.w800,
      fontSize: compact ? 13 : 16,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          lit
              ? Icons.local_fire_department
              : Icons.local_fire_department_outlined,
          color: iconColor,
          size: iconSize,
        ),
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
