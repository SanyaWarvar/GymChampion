import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/quest_def.dart';

class QuestIcon extends StatelessWidget {
  const QuestIcon({
    super.key,
    required this.quest,
    this.size = 40,
    this.radius = 10,
  });

  final QuestDef quest;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        quest.iconAsset,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          color: AppColors.surface,
          child: Icon(quest.icon, color: AppColors.amber, size: size * 0.5),
        ),
      ),
    );
  }
}
