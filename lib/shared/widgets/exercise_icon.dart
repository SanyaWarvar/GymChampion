import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../features/workout/domain/exercise_catalog.dart';

class ExerciseIcon extends StatelessWidget {
  const ExerciseIcon({
    super.key,
    this.assetPath,
    this.exerciseId,
    this.name,
    this.size = 44,
    this.radius = 10,
  });

  /// Явный путь к ассету.
  final String? assetPath;

  /// Id из каталога (`bench_press`) или ключ PR.
  final String? exerciseId;

  /// Название упражнения — fallback, если нет id.
  final String? name;

  final double size;
  final double radius;

  String? get _resolved =>
      assetPath ??
      ExerciseCatalog.iconAssetFor(exerciseId: exerciseId, name: name);

  @override
  Widget build(BuildContext context) {
    final path = _resolved;
    if (path == null || path.isEmpty) {
      return _fallback();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        path,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => _fallback(),
      ),
    );
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(radius),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.fitness_center,
        color: AppColors.amber,
        size: size * 0.45,
      ),
    );
  }
}
