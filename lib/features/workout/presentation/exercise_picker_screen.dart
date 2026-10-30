import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/exercise_icon.dart';
import '../data/custom_exercise_repository.dart';
import '../domain/custom_exercise.dart';
import '../domain/exercise_catalog.dart';

class ExercisePickerResult {
  const ExercisePickerResult({required this.name, this.exerciseId});

  final String name;
  final String? exerciseId;
}

class ExercisePickerScreen extends StatefulWidget {
  const ExercisePickerScreen({super.key});

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  final _repo = CustomExerciseRepository();
  final _queryController = TextEditingController();
  MuscleGroup? _muscle;
  List<CustomExercise> _custom = const [];
  bool _saving = false;

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

  void _selectCustom(CustomExercise exercise) {
    Navigator.pop(
      context,
      ExercisePickerResult(name: exercise.name, exerciseId: exercise.id),
    );
  }

  Future<void> _create({String initialName = ''}) async {
    if (_saving) return;
    final draft =
        await showModalBottomSheet<({String name, MuscleGroup muscle})>(
          context: context,
          isScrollControlled: true,
          backgroundColor: AppColors.surface,
          builder: (context) => _CreateCustomSheet(
            initialName: initialName,
            initialMuscle: _muscle ?? MuscleGroup.fullBody,
          ),
        );
    if (draft == null || !mounted) return;

    final catalog = _exactCatalog(draft.name);
    if (catalog != null) {
      _select(catalog);
      return;
    }
    final existing = _exactCustom(draft.name);
    if (existing != null) {
      _selectCustom(existing);
      return;
    }

    setState(() => _saving = true);
    try {
      final created = await _repo.create(
        name: draft.name,
        muscle: draft.muscle,
      );
      if (!mounted) return;
      _selectCustom(created);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить упражнение')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete(CustomExercise exercise) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Удалить «${exercise.name}»?'),
        content: const Text(
          'Пропадёт из списка. Прошлые тренировки сохранятся.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _repo.delete(exercise.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось удалить упражнение')),
      );
    }
  }

  CatalogExercise? _exactCatalog(String name) {
    final q = name.trim().toLowerCase();
    for (final exercise in ExerciseCatalog.exercises) {
      if (exercise.name.toLowerCase() == q) return exercise;
    }
    return null;
  }

  CustomExercise? _exactCustom(String name) {
    final q = name.trim().toLowerCase();
    for (final exercise in _custom) {
      if (exercise.name.toLowerCase() == q) return exercise;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final query = _queryController.text.trim();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Упражнения'),
        actions: [
          IconButton(
            tooltip: 'Своё упражнение',
            onPressed: _saving ? null : () => _create(),
            icon: const Icon(Icons.add),
          ),
        ],
      ),
      body: StreamBuilder<List<CustomExercise>>(
        stream: _repo.watchMine(),
        builder: (context, snapshot) {
          _custom = snapshot.data ?? _custom;
          final custom = _filteredCustom(query);
          final items = ExerciseCatalog.search(query: query, muscle: _muscle);
          final showSave =
              query.isNotEmpty &&
              _exactCatalog(query) == null &&
              _exactCustom(query) == null;

          return Column(
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
                  onSubmitted: (value) {
                    if (value.trim().isEmpty) return;
                    _create(initialName: value);
                  },
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
                    if (showSave)
                      ListTile(
                        leading: const Icon(Icons.add, color: AppColors.amber),
                        title: Text('Сохранить «$query» в мои'),
                        subtitle: const Text(
                          'Останется в списке',
                          style: TextStyle(color: AppColors.muted),
                        ),
                        onTap: _saving
                            ? null
                            : () => _create(initialName: query),
                      ),
                    if (custom.isNotEmpty) ...[
                      const _SectionLabel('Мои'),
                      ...custom.map(
                        (e) => ListTile(
                          leading: ExerciseIcon(assetPath: e.muscle.iconAsset),
                          title: Text(e.name),
                          subtitle: Text(
                            e.muscle.label,
                            style: const TextStyle(color: AppColors.muted),
                          ),
                          trailing: IconButton(
                            tooltip: 'Удалить',
                            onPressed: () => _delete(e),
                            icon: const Icon(
                              Icons.delete_outline,
                              color: AppColors.muted,
                            ),
                          ),
                          onTap: () => _selectCustom(e),
                        ),
                      ),
                    ],
                    if (items.isNotEmpty && custom.isNotEmpty)
                      const _SectionLabel('Каталог'),
                    ...items.map(
                      (e) => ListTile(
                        leading: ExerciseIcon(exerciseId: e.id, name: e.name),
                        title: Text(e.name),
                        subtitle: Text(
                          e.muscle.label,
                          style: const TextStyle(color: AppColors.muted),
                        ),
                        onTap: () => _select(e),
                      ),
                    ),
                    if (items.isEmpty && custom.isEmpty && !showSave)
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
          );
        },
      ),
    );
  }

  List<CustomExercise> _filteredCustom(String query) {
    final q = query.toLowerCase();
    return _custom.where((e) {
      final muscleOk = _muscle == null || e.muscle == _muscle;
      final queryOk = q.isEmpty || e.name.toLowerCase().contains(q);
      return muscleOk && queryOk;
    }).toList();
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.muted,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _CreateCustomSheet extends StatefulWidget {
  const _CreateCustomSheet({
    required this.initialName,
    required this.initialMuscle,
  });

  final String initialName;
  final MuscleGroup initialMuscle;

  @override
  State<_CreateCustomSheet> createState() => _CreateCustomSheetState();
}

class _CreateCustomSheetState extends State<_CreateCustomSheet> {
  late final TextEditingController _name;
  late MuscleGroup _muscle;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.initialName);
    _muscle = widget.initialMuscle;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.pop(context, (name: name, muscle: _muscle));
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Своё упражнение',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Останется в списке на этом аккаунте',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            autofocus: widget.initialName.isEmpty,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Название',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _save(),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: MuscleGroup.values.map((group) {
              return FilterChip(
                label: Text(group.label),
                selected: _muscle == group,
                onSelected: (_) => setState(() => _muscle = group),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _name.text.trim().isEmpty ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: AppColors.background,
              ),
              child: const Text('Сохранить'),
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
