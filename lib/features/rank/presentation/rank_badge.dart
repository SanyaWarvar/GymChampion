import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../domain/xp_rules.dart';

class RankBadge extends StatelessWidget {
  const RankBadge({
    super.key,
    required this.rankId,
    this.size = 40,
    this.showLabel = false,
    this.locked = false,
    this.showStars = true,
  });

  final String rankId;
  final double size;
  final bool showLabel;
  final bool locked;
  final bool showStars;

  @override
  Widget build(BuildContext context) {
    final medal = XpRules.medalForId(rankId);
    final radius = size * 0.22;
    final badge = SizedBox(
      width: size,
      height: size,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(radius),
            child: locked
                ? ColorFiltered(
                    colorFilter: const ColorFilter.matrix(<double>[
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0.2126, 0.7152, 0.0722, 0, 0,
                      0, 0, 0, 1, 0,
                    ]),
                    child: Opacity(
                      opacity: 0.45,
                      child: _medalImage(medal, size),
                    ),
                  )
                : _medalImage(medal, size),
          ),
          if (locked)
            Center(
              child: Icon(
                Icons.lock,
                color: AppColors.onDark.withValues(alpha: 0.85),
                size: size * 0.34,
              ),
            ),
          if (showStars && medal.stars > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: -1,
              child: _StarPips(
                filled: medal.stars,
                color: locked ? AppColors.muted : medal.color,
                size: (size * 0.16).clamp(6, 11),
              ),
            ),
        ],
      ),
    );

    if (!showLabel) return badge;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        badge,
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            medal.label,
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: locked ? AppColors.muted : medal.color,
            ),
          ),
        ),
      ],
    );
  }
}

Widget _medalImage(MedalRank medal, double size) {
  return Image.asset(
    medal.iconAsset,
    width: size,
    height: size,
    fit: BoxFit.cover,
    errorBuilder: (_, _, _) => Container(
      width: size,
      height: size,
      color: AppColors.surface,
      alignment: Alignment.center,
      child: Icon(
        Icons.military_tech,
        color: medal.color,
        size: size * 0.5,
      ),
    ),
  );
}

class MedalStarRow extends StatelessWidget {
  const MedalStarRow({
    super.key,
    required this.filled,
    required this.total,
    required this.color,
    this.size = 14,
  });

  final int filled;
  final int total;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (total <= 0) {
      return Icon(Icons.workspace_premium, color: color, size: size + 4);
    }
    return _StarPips(filled: filled, total: total, color: color, size: size);
  }
}

class _StarPips extends StatelessWidget {
  const _StarPips({
    required this.filled,
    required this.color,
    this.total = 5,
    this.size = 8,
  });

  final int filled;
  final int total;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 1; i <= total; i++)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: size * 0.08),
            child: Icon(
              i <= filled ? Icons.star_rounded : Icons.star_outline_rounded,
              size: size,
              color: i <= filled ? color : AppColors.muted.withValues(alpha: 0.45),
            ),
          ),
      ],
    );
  }
}
