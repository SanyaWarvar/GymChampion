import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/exercise_icon.dart';
import '../../notifications/data/local_notification_service.dart';
import '../application/active_workout_controller.dart';
import '../data/local_workout_store.dart';
import '../data/workout_notification_service.dart';
import '../domain/exercise_catalog.dart';
import '../domain/saved_workout.dart';
import '../domain/workout_models.dart';
import '../domain/workout_template.dart';
import 'exercise_picker_screen.dart';
import 'rest_timer_sheet.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  const ActiveWorkoutScreen({super.key, this.template, this.restore});

  final WorkoutTemplate? template;
  final LocalWorkoutDraft? restore;

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  late final ActiveWorkoutController _controller = ActiveWorkoutController(
    template: widget.template,
    restore: widget.restore,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await LocalNotificationService.instance.requestPermission();
      if (!mounted) return;
      WorkoutNotificationService.instance.attach(_controller);
    });
  }

  @override
  void dispose() {
    WorkoutNotificationService.instance.detach(_controller);
    _controller.dispose();
    super.dispose();
  }

  Future<void> _confirmDiscard() async {
    final shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Выйти из тренировки?'),
            content: const Text(
              'Черновик останется на устройстве — можно продолжить позже.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Остаться'),
              ),
              TextButton(
                onPressed: () async {
                  await _controller.clearLocalDraft();
                  if (context.mounted) Navigator.pop(context, true);
                },
                child: const Text('Сбросить'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Свернуть'),
              ),
            ],
          ),
        ) ??
        false;
    if (shouldPop && mounted) context.pop();
  }

  Future<void> _finish() async {
    if (_controller.totalDoneSets == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Отметь хотя бы один подход')),
      );
      return;
    }

    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Завершить тренировку?'),
            content: const Text(
              'Вы уверены? После этого тренировку нельзя продолжить.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Продолжить тренировку'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Завершить тренировку'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed || !mounted) return;

    _controller.dismissRest();
    await WorkoutNotificationService.instance.stop();
    final draft = WorkoutDraft(
      startedAt: _controller.startedAt,
      finishedAt: DateTime.now(),
      exercises: _controller.exercises,
      fromTemplate: _controller.fromTemplate,
    );
    if (!mounted) return;
    context.pushReplacement('/workout/summary', extra: draft);
  }

  Future<void> _addExercise() async {
    final selected = await openExercisePicker(context);
    if (selected != null) {
      _controller.addExercise(
        selected.name,
        exerciseId: selected.exerciseId,
      );
    }
  }

  Future<void> _onToggleSet(String exerciseId, String setId) async {
    final becameDone = _controller.toggleSetDone(
      exerciseId: exerciseId,
      setId: setId,
    );
    if (becameDone && mounted) {
      _controller.startRest();
      await RestTimerSheet.show(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) _confirmDiscard();
          },
          child: Scaffold(
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(Icons.close),
                onPressed: _confirmDiscard,
              ),
              title: Column(
                children: [
                  const Text('Тренировка'),
                  Text(
                    _controller.elapsedLabel,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: AppColors.amber,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: _finish,
                  child: const Text('Готово'),
                ),
              ],
            ),
            body: _controller.exercises.isEmpty
                ? _EmptyState(onAdd: _addExercise)
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                    itemCount: _controller.exercises.length,
                    itemBuilder: (context, index) {
                      final exercise = _controller.exercises[index];
                      return _ExerciseCard(
                        exercise: exercise,
                        onAddSet: () => _controller.addSet(exercise.id),
                        onRemove: () => _controller.removeExercise(exercise.id),
                        onToggleSet: (setId) =>
                            _onToggleSet(exercise.id, setId),
                        onRemoveSet: (setId) => _controller.removeSet(
                          exerciseId: exercise.id,
                          setId: setId,
                        ),
                        onUpdateSet: (setId, weight, reps) {
                          _controller.updateSet(
                            exerciseId: exercise.id,
                            setId: setId,
                            weightKg: weight,
                            reps: reps,
                          );
                        },
                      );
                    },
                  ),
            bottomNavigationBar: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_controller.exercises.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          [
                            if (_controller.totalVolume > 0)
                              'Объём: ${_controller.totalVolume.round()} кг',
                            if (_controller.totalRunKm > 0)
                              ExerciseCatalog.formatKm(_controller.totalRunKm),
                            'отрезков: ${_controller.totalDoneSets}',
                          ].join(' · '),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(color: AppColors.muted),
                        ),
                      ),
                    FilledButton.icon(
                      onPressed: _addExercise,
                      icon: const Icon(Icons.add),
                      label: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Добавить упражнение'),
                      ),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.amber,
                        foregroundColor: AppColors.background,
                        minimumSize: const Size.fromHeight(48),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.fitness_center, size: 48, color: AppColors.amber),
            const SizedBox(height: 16),
            Text(
              'Добавь первое упражнение',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Вес и повторы, у планки — отягощение и секунды, у бега — км и минуты',
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onAdd,
              child: const Text('Выбрать упражнение'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseCard extends StatelessWidget {
  const _ExerciseCard({
    required this.exercise,
    required this.onAddSet,
    required this.onRemove,
    required this.onToggleSet,
    required this.onRemoveSet,
    required this.onUpdateSet,
  });

  final WorkoutExercise exercise;
  final VoidCallback onAddSet;
  final VoidCallback onRemove;
  final void Function(String setId) onToggleSet;
  final void Function(String setId) onRemoveSet;
  final void Function(String setId, double weight, int reps) onUpdateSet;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
                IconButton(
                  onPressed: onRemove,
                  icon: const Icon(Icons.delete_outline),
                  color: AppColors.muted,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const SizedBox(width: 40),
                Expanded(
                  child: Text(
                    ExerciseCatalog.weightColumnLabel(
                      exerciseId: exercise.exerciseId,
                      name: exercise.name,
                    ),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                ),
                Expanded(
                  child: Text(
                    ExerciseCatalog.qtyColumnLabel(
                      exerciseId: exercise.exerciseId,
                      name: exercise.name,
                    ),
                    style: Theme.of(context)
                        .textTheme
                        .labelSmall
                        ?.copyWith(color: AppColors.muted),
                  ),
                ),
                const SizedBox(width: 48),
              ],
            ),
            ...exercise.sets.asMap().entries.map((entry) {
              final index = entry.key;
              final set = entry.value;
              return _SetRow(
                index: index + 1,
                set: set,
                track: ExerciseCatalog.lookup(
                      exerciseId: exercise.exerciseId,
                      name: exercise.name,
                    )?.track ??
                    ExerciseTrackMode.weightReps,
                onToggle: () => onToggleSet(set.id),
                onRemove: () => onRemoveSet(set.id),
                canRemove: exercise.sets.length > 1,
                onChanged: (weight, reps) => onUpdateSet(set.id, weight, reps),
              );
            }),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onAddSet,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Подход'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetRow extends StatefulWidget {
  const _SetRow({
    required this.index,
    required this.set,
    required this.track,
    required this.onToggle,
    required this.onRemove,
    required this.canRemove,
    required this.onChanged,
  });

  final int index;
  final WorkoutSet set;
  final ExerciseTrackMode track;
  final VoidCallback onToggle;
  final VoidCallback onRemove;
  final bool canRemove;
  final void Function(double weight, int reps) onChanged;

  @override
  State<_SetRow> createState() => _SetRowState();
}

class _SetRowState extends State<_SetRow> {
  late final TextEditingController _weightController;
  late final TextEditingController _repsController;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController(text: _weightText(widget.set));
    _repsController = TextEditingController(text: _qtyText(widget.set));
  }

  @override
  void didUpdateWidget(covariant _SetRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.set.id != widget.set.id) {
      _weightController.text = _weightText(widget.set);
      _repsController.text = _qtyText(widget.set);
    }
  }

  String _fmt(double value) {
    return value == value.roundToDouble()
        ? '${value.round()}'
        : value.toString();
  }

  String _weightText(WorkoutSet set) =>
      set.weightKg == 0 ? '' : _fmt(set.weightKg);

  String _qtyText(WorkoutSet set) {
    if (set.reps == 0) return '';
    if (widget.track == ExerciseTrackMode.run) {
      return ExerciseCatalog.formatClock(set.reps);
    }
    return '${set.reps}';
  }

  void _emit() {
    final weight =
        double.tryParse(_weightController.text.replaceAll(',', '.')) ?? 0;
    final reps = widget.track == ExerciseTrackMode.run
        ? ExerciseCatalog.parseDurationInput(_repsController.text)
        : int.tryParse(_repsController.text) ?? 0;
    widget.onChanged(weight, reps);
  }

  @override
  void dispose() {
    _weightController.dispose();
    _repsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text(
              '${widget.index}',
              style: TextStyle(
                color: widget.set.done ? AppColors.amber : AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              decoration: const InputDecoration(
                isDense: true,
                border: OutlineInputBorder(),
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
              onChanged: (_) => _emit(),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _repsController,
              keyboardType: widget.track == ExerciseTrackMode.run
                  ? const TextInputType.numberWithOptions(decimal: false)
                  : TextInputType.number,
              inputFormatters: widget.track == ExerciseTrackMode.run
                  ? [FilteringTextInputFormatter.allow(RegExp(r'[0-9:]'))]
                  : [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                isDense: true,
                border: const OutlineInputBorder(),
                hintText: widget.track == ExerciseTrackMode.run ? '28:30' : null,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              ),
              onChanged: (_) => _emit(),
            ),
          ),
          IconButton(
            onPressed: widget.onToggle,
            icon: Icon(
              widget.set.done
                  ? Icons.check_circle
                  : Icons.check_circle_outline,
              color: widget.set.done ? AppColors.amber : AppColors.muted,
            ),
          ),
          if (widget.canRemove)
            IconButton(
              onPressed: widget.onRemove,
              icon: const Icon(Icons.remove_circle_outline, size: 20),
              color: AppColors.muted,
            )
          else
            const SizedBox(width: 48),
        ],
      ),
    );
  }
}
