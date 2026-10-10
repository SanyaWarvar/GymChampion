import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/exercise_icon.dart';
import '../data/template_repository.dart';
import '../domain/exercise_catalog.dart';
import '../domain/workout_template.dart';
import 'exercise_picker_screen.dart';

class TemplateEditorScreen extends StatefulWidget {
  const TemplateEditorScreen({super.key, this.initial});

  final WorkoutTemplate? initial;

  @override
  State<TemplateEditorScreen> createState() => _TemplateEditorScreenState();
}

class _TemplateEditorScreenState extends State<TemplateEditorScreen> {
  final _repo = TemplateRepository();
  late final TextEditingController _nameController;
  late List<TemplateExercise> _exercises;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initial?.name ?? '');
    _exercises = List.of(widget.initial?.exercises ?? const []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _addExercise() async {
    final picked = await openExercisePicker(context);
    if (picked == null) return;
    setState(() {
      final catalog = ExerciseCatalog.lookup(
        exerciseId: picked.exerciseId,
        name: picked.name,
      );
      _exercises.add(
        TemplateExercise(
          name: picked.name,
          exerciseId: picked.exerciseId,
          targetReps: catalog?.defaultQty ?? 8,
          targetWeightKg: catalog?.defaultDistanceKm ?? 0,
        ),
      );
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введи название шаблона')),
      );
      return;
    }
    if (_exercises.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавь хотя бы одно упражнение')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await _repo.saveTemplate(
        WorkoutTemplate(
          id: widget.initial?.id ?? 'new',
          name: name,
          exercises: _exercises,
          programId: widget.initial?.programId,
          programTitle: widget.initial?.programTitle,
          dayLabel: widget.initial?.dayLabel,
        ),
      );
      if (mounted) context.pop();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить шаблон')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Новый шаблон' : 'Шаблон'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Сохранить'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Название',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          ..._exercises.asMap().entries.map((entry) {
            final index = entry.key;
            final exercise = entry.value;
            return Card(
              color: AppColors.surface,
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        ExerciseIcon(
                          exerciseId: exercise.exerciseId,
                          name: exercise.name,
                          size: 36,
                          radius: 8,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            exercise.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          onPressed: () => setState(() {
                            _exercises.removeAt(index);
                          }),
                          icon: const Icon(Icons.delete_outline),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: ValueKey('${exercise.name}_sets_$index'),
                            controller: TextEditingController(
                              text: '${exercise.targetSets}',
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Подходы',
                              border: OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            onChanged: (value) {
                              final sets = int.tryParse(value) ?? 3;
                              _exercises[index] =
                                  exercise.copyWith(targetSets: sets);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            key: ValueKey('${exercise.name}_reps_$index'),
                            controller: TextEditingController(
                              text: ExerciseCatalog.isRun(
                                    exerciseId: exercise.exerciseId,
                                    name: exercise.name,
                                  )
                                  ? ExerciseCatalog.formatClock(
                                      exercise.targetReps,
                                    )
                                  : '${exercise.targetReps}',
                            ),
                            decoration: InputDecoration(
                              labelText: ExerciseCatalog.qtyColumnLabel(
                                exerciseId: exercise.exerciseId,
                                name: exercise.name,
                              ),
                              hintText: ExerciseCatalog.isRun(
                                    exerciseId: exercise.exerciseId,
                                    name: exercise.name,
                                  )
                                  ? '30 или 28:30'
                                  : null,
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.allow(
                                RegExp(r'[0-9:]'),
                              ),
                            ],
                            onChanged: (value) {
                              final run = ExerciseCatalog.isRun(
                                exerciseId: exercise.exerciseId,
                                name: exercise.name,
                              );
                              final reps = run
                                  ? ExerciseCatalog.parseDurationInput(value)
                                  : int.tryParse(value) ?? 8;
                              _exercises[index] =
                                  exercise.copyWith(targetReps: reps);
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            key: ValueKey('${exercise.name}_kg_$index'),
                            controller: TextEditingController(
                              text: exercise.targetWeightKg == 0
                                  ? ''
                                  : '${exercise.targetWeightKg}',
                            ),
                            decoration: InputDecoration(
                              labelText: ExerciseCatalog.weightColumnLabel(
                                exerciseId: exercise.exerciseId,
                                name: exercise.name,
                              ),
                              border: const OutlineInputBorder(),
                              isDense: true,
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (value) {
                              final weight = double.tryParse(
                                    value.replaceAll(',', '.'),
                                  ) ??
                                  0;
                              _exercises[index] = exercise.copyWith(
                                targetWeightKg: weight,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          OutlinedButton.icon(
            onPressed: _addExercise,
            icon: const Icon(Icons.add),
            label: const Text('Добавить упражнение'),
          ),
        ],
      ),
    );
  }
}
