import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/exercise_icon.dart';
import '../domain/exercise_catalog.dart';

class ExercisePickerResult {
  const ExercisePickerResult({
    required this.name,
    this.exerciseId,
  });

  final String name;
  final String? exerciseId;
}

class ExercisePickerScreen extends StatefulWidget {
  const ExercisePickerScreen({super.key});

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  final _queryController = TextEditingController();
  MuscleGroup? _muscle;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  void _select(CatalogExercise exercise) {
    Navigator.pop(
      context,
      ExercisePickerResult(name: exercise.name, exerciseId: exercise.id),
    );
  }

  void _selectCustom(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    Navigator.pop(context, ExercisePickerResult(name: trimmed));
  }

  @override
  Widget build(BuildContext context) {
    final query = _queryController.text;
    final items = ExerciseCatalog.search(query: query, muscle: _muscle);
    final showCustom = query.trim().isNotEmpty &&
        !ExerciseCatalog.exercises.any(
          (e) => e.name.toLowerCase() == query.trim().toLowerCase(),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Упражнения')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _queryController,
              autofocus: true,
              decoration: const InputDecoration(
                hintText: 'Поиск или своё название',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FilterChip(
                    label: const Text('Все'),
                    selected: _muscle == null,
                    onSelected: (_) => setState(() => _muscle = null),
                  ),
                ),
                ...MuscleGroup.values.map(
                  (m) => Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: FilterChip(
                      avatar: ExerciseIcon(
                        assetPath: m.iconAsset,
                        size: 22,
                        radius: 6,
                      ),
                      label: Text(m.label),
                      selected: _muscle == m,
                      onSelected: (_) => setState(() => _muscle = m),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              children: [
                if (showCustom)
                  ListTile(
                    leading: const Icon(Icons.add, color: AppColors.amber),
                    title: Text('Добавить «${query.trim()}»'),
                    onTap: () => _selectCustom(query),
                  ),
                ...items.map(
                  (e) => ListTile(
                    leading: ExerciseIcon(
                      exerciseId: e.id,
                      name: e.name,
                    ),
                    title: Text(e.name),
                    subtitle: Text(
                      e.muscle.label,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                    onTap: () => _select(e),
                  ),
                ),
                if (items.isEmpty && !showCustom)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Ничего не найдено',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.muted),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<ExercisePickerResult?> openExercisePicker(BuildContext context) {
  return Navigator.of(context).push<ExercisePickerResult>(
    MaterialPageRoute(
      fullscreenDialog: true,
      builder: (_) => const ExercisePickerScreen(),
    ),
  );
}
