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
  late final TextEditingController _groupController;
  late final TextEditingController _dayController;
  late List<TemplateExercise> _exercises;
  List<({String id, String title})> _groups = const [];
  String? _programId;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _nameController = TextEditingController(text: initial?.name ?? '');
    _groupController =
        TextEditingController(text: initial?.programTitle ?? '');
    _dayController = TextEditingController(text: initial?.dayLabel ?? '');
    _programId = initial?.programId;
    _exercises = [
      for (final e in initial?.exercises ?? const <TemplateExercise>[])
        e.copyWith(setTargets: e.resolvedSets, targetSets: e.effectiveSets),
    ];
    _loadGroups();
  }

  Future<void> _loadGroups() async {
    try {
      final groups = await _repo.fetchProgramGroups();
      if (!mounted) return;
      setState(() => _groups = groups);
    } catch (_) {}
  }

  @override
  void dispose() {
    _nameController.dispose();
    _groupController.dispose();
    _dayController.dispose();
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
      final reps = catalog?.defaultQty ?? 8;
      final weight = catalog?.defaultDistanceKm ?? 0;
      _exercises.add(
        TemplateExercise(
          name: picked.name,
          exerciseId: picked.exerciseId,
          targetSets: 3,
          targetReps: reps,
          targetWeightKg: weight,
          setTargets: List.generate(
            3,
            (_) => TemplateSetTarget(weightKg: weight, reps: reps),
          ),
        ),
      );
    });
  }

  void _reorder(int oldIndex, int newIndex) {
    setState(() {
      final item = _exercises.removeAt(oldIndex);
      _exercises.insert(newIndex, item);
    });
  }

  ({String? id, String? title, String? day}) _resolveProgram() {
    final title = _groupController.text.trim();
    final day = _dayController.text.trim();
    if (title.isEmpty) {
      return (id: null, title: null, day: null);
    }
    ({String id, String title})? existing;
    for (final g in _groups) {
      if (g.title.toLowerCase() == title.toLowerCase()) {
        existing = g;
        break;
      }
    }
    final keepId = _programId != null &&
        (widget.initial?.programTitle ?? '').toLowerCase() ==
            title.toLowerCase();
    final id = existing?.id ??
        (keepId ? _programId : templateProgramIdFromTitle(title));
    return (
      id: id,
      title: title,
      day: day.isEmpty ? null : day,
    );
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
      final program = _resolveProgram();
      await _repo.saveTemplate(
        WorkoutTemplate(
          id: widget.initial?.id ?? 'new',
          name: name,
          exercises: _exercises,
          programId: program.id,
          programTitle: program.title,
          dayLabel: program.day,
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
    final groupOptions = <String>{
      for (final g in _groups) g.title,
    }.toList()
      ..sort();

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
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            sliver: SliverToBoxAdapter(
              child: _HeaderFields(
                nameController: _nameController,
                groupController: _groupController,
                dayController: _dayController,
                groupOptions: groupOptions,
                onGroupSelected: (title) {
                  ({String id, String title})? match;
                  for (final g in _groups) {
                    if (g.title == title) {
                      match = g;
                      break;
                    }
                  }
                  setState(() {
                    _groupController.text = title;
                    _programId = match?.id;
                  });
                },
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            sliver: SliverReorderableList(
              itemCount: _exercises.length,
              onReorderItem: _reorder,
              itemBuilder: (context, index) {
                final exercise = _exercises[index];
                return _ExerciseCard(
                  key: ValueKey(
                    'ex_${exercise.exerciseId ?? exercise.name}_$index',
                  ),
                  index: index,
                  exercise: exercise,
                  onChanged: (next) =>
                      setState(() => _exercises[index] = next),
                  onRemove: () =>
                      setState(() => _exercises.removeAt(index)),
                );
              },
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            sliver: SliverToBoxAdapter(
              child: OutlinedButton.icon(
                onPressed: _addExercise,
                icon: const Icon(Icons.add),
                label: const Text('Добавить упражнение'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderFields extends StatelessWidget {
  const _HeaderFields({
    required this.nameController,
    required this.groupController,
    required this.dayController,
    required this.groupOptions,
    required this.onGroupSelected,
  });

  final TextEditingController nameController;
  final TextEditingController groupController;
  final TextEditingController dayController;
  final List<String> groupOptions;
  final ValueChanged<String> onGroupSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: nameController,
          decoration: const InputDecoration(
            labelText: 'Название',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: groupController,
          decoration: const InputDecoration(
            labelText: 'Группа (как StrongLifts)',
            hintText: 'Необязательно — заголовок секции',
            border: OutlineInputBorder(),
            helperText: 'Шаблоны с одной группой будут вместе в списке',
          ),
        ),
        if (groupOptions.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final title in groupOptions)
                ActionChip(
                  label: Text(title),
                  onPressed: () => onGroupSelected(title),
                ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        TextField(
          controller: dayController,
          decoration: const InputDecoration(
            labelText: 'День / ярлык',
            hintText: 'Например: День A',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Потяни ☰ чтобы поменять упражнения местами',
          style: TextStyle(color: AppColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    super.key,
    required this.index,
    required this.exercise,
    required this.onChanged,
    required this.onRemove,
  });

  final int index;
  final TemplateExercise exercise;
  final ValueChanged<TemplateExercise> onChanged;
  final VoidCallback onRemove;

  bool get _isRun => ExerciseCatalog.isRun(
        exerciseId: exercise.exerciseId,
        name: exercise.name,
      );

  @override
  Widget build(BuildContext context) {
    final sets = exercise.resolvedSets;
    return Card(
      key: ValueKey('card_$index'),
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: const Padding(
                    padding: EdgeInsets.only(right: 6),
                    child: Icon(Icons.drag_handle, color: AppColors.muted),
                  ),
                ),
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
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SizedBox(
                  width: 96,
                  child: _SetsCountField(
                    count: sets.length,
                    onChanged: (n) => onChanged(exercise.withSetCount(n)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _isRun
                        ? 'км и время на каждый подход'
                        : 'вес и повторы на каждый подход',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < sets.length; i++) ...[
              if (i > 0) const SizedBox(height: 6),
              _SetRow(
                key: ValueKey('set_${exercise.exerciseId ?? exercise.name}_$i'),
                label: 'Пдх ${i + 1}',
                set: sets[i],
                isRun: _isRun,
                exerciseId: exercise.exerciseId,
                exerciseName: exercise.name,
                onChanged: (set) => onChanged(exercise.withSetAt(i, set)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SetsCountField extends StatefulWidget {
  const _SetsCountField({
    required this.count,
    required this.onChanged,
  });

  final int count;
  final ValueChanged<int> onChanged;

  @override
  State<_SetsCountField> createState() => _SetsCountFieldState();
}

class _SetsCountFieldState extends State<_SetsCountField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: '${widget.count}');
  }

  @override
  void didUpdateWidget(covariant _SetsCountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.count != widget.count &&
        _controller.text != '${widget.count}') {
      _controller.text = '${widget.count}';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      decoration: const InputDecoration(
        labelText: 'Подходы',
        border: OutlineInputBorder(),
        isDense: true,
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      onChanged: (value) {
        final n = int.tryParse(value);
        if (n == null) return;
        widget.onChanged(n.clamp(1, 12));
      },
    );
  }
}

class _SetRow extends StatefulWidget {
  const _SetRow({
    super.key,
    required this.label,
    required this.set,
    required this.isRun,
    required this.exerciseId,
    required this.exerciseName,
    required this.onChanged,
  });

  final String label;
  final TemplateSetTarget set;
  final bool isRun;
  final String? exerciseId;
  final String exerciseName;
  final ValueChanged<TemplateSetTarget> onChanged;

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late final TextEditingController _weight;
  late final TextEditingController _reps;

  @override
  void initState() {
    super.initState();
    _weight = TextEditingController(
      text: widget.set.weightKg == 0 ? '' : _fmtNum(widget.set.weightKg),
    );
    _reps = TextEditingController(
      text: widget.isRun
          ? ExerciseCatalog.formatClock(widget.set.reps)
          : '${widget.set.reps}',
    );
  }

  @override
  void didUpdateWidget(covariant _SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.set.weightKg != widget.set.weightKg) {
      final next =
          widget.set.weightKg == 0 ? '' : _fmtNum(widget.set.weightKg);
      if (_weight.text != next) _weight.text = next;
    }
    if (oldWidget.set.reps != widget.set.reps) {
      final next = widget.isRun
          ? ExerciseCatalog.formatClock(widget.set.reps)
          : '${widget.set.reps}';
      if (_reps.text != next) _reps.text = next;
    }
  }

  @override
  void dispose() {
    _weight.dispose();
    _reps.dispose();
    super.dispose();
  }

  String _fmtNum(double v) =>
      v == v.roundToDouble() ? '${v.round()}' : '$v';

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            widget.label,
            style: const TextStyle(
              color: AppColors.muted,
              fontWeight: FontWeight.w600,
              fontSize: 12,
            ),
          ),
        ),
        Expanded(
          child: TextField(
            controller: _weight,
            decoration: InputDecoration(
              labelText: ExerciseCatalog.weightColumnLabel(
                exerciseId: widget.exerciseId,
                name: widget.exerciseName,
              ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (value) {
              final weight =
                  double.tryParse(value.replaceAll(',', '.')) ?? 0;
              widget.onChanged(widget.set.copyWith(weightKg: weight));
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: _reps,
            decoration: InputDecoration(
              labelText: ExerciseCatalog.qtyColumnLabel(
                exerciseId: widget.exerciseId,
                name: widget.exerciseName,
              ),
              hintText: widget.isRun ? '30 или 28:30' : null,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9:]')),
            ],
            onChanged: (value) {
              final reps = widget.isRun
                  ? ExerciseCatalog.parseDurationInput(value)
                  : int.tryParse(value) ?? widget.set.reps;
              widget.onChanged(widget.set.copyWith(reps: reps));
            },
          ),
        ),
      ],
    );
  }
}
