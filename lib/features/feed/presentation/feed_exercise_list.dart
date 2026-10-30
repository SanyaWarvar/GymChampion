import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/exercise_icon.dart';
import '../../workout/domain/exercise_catalog.dart';
import '../data/feed_repository.dart';
import '../domain/feed_post.dart';

class FeedExerciseList extends StatelessWidget {
  const FeedExerciseList({
    super.key,
    required this.exercises,
    this.showLoads = true,
    this.compact = false,
  });

  final List<FeedExercise> exercises;
  final bool showLoads;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    if (exercises.isEmpty) return const SizedBox.shrink();
    if (compact) {
      final shown = exercises.take(4).toList();
      final extra = exercises.length - shown.length;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final exercise in shown)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                exercise.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: AppColors.onDark, fontSize: 13),
              ),
            ),
          if (extra > 0)
            Text(
              'ещё $extra',
              style: const TextStyle(color: AppColors.muted, fontSize: 12),
            ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final exercise in exercises)
          Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
            ),
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
                  ],
                ),
                const SizedBox(height: 8),
                if (!showLoads)
                  Text(
                    _setsLabel(exercise.sets.length),
                    style: const TextStyle(color: AppColors.muted),
                  )
                else
                  for (var i = 0; i < exercise.sets.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        '${i + 1}. ${ExerciseCatalog.formatSet(weightKg: exercise.sets[i].weightKg, qty: exercise.sets[i].reps, exerciseId: exercise.exerciseId, name: exercise.name)}',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ),
              ],
            ),
          ),
      ],
    );
  }
}

class WorkoutPostExercises extends StatefulWidget {
  const WorkoutPostExercises({
    super.key,
    required this.post,
    required this.viewerId,
    this.compact = false,
  });

  final FeedPost post;
  final String viewerId;
  final bool compact;

  @override
  State<WorkoutPostExercises> createState() => _WorkoutPostExercisesState();
}

class _WorkoutPostExercisesState extends State<WorkoutPostExercises> {
  final _repo = FeedRepository();
  late Future<({List<FeedExercise> exercises, bool hideLoads})> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant WorkoutPostExercises oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.post.id != widget.post.id ||
        oldWidget.post.exercises.length != widget.post.exercises.length ||
        oldWidget.post.hideSetDetails != widget.post.hideSetDetails) {
      _future = _load();
    }
  }

  Future<({List<FeedExercise> exercises, bool hideLoads})> _load() async {
    final post = widget.post;
    final exercises = post.exercises.isNotEmpty
        ? post.exercises
        : await _repo.loadExercises(post);
    if (widget.compact) {
      return (exercises: exercises, hideLoads: true);
    }
    final hideLoads = await _repo.hideLoadsFor(post);
    return (exercises: exercises, hideLoads: hideLoads);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.post.type != FeedPostType.workout) {
      return const SizedBox.shrink();
    }
    if (widget.compact && widget.post.exercises.isNotEmpty) {
      return FeedExerciseList(exercises: widget.post.exercises, compact: true);
    }
    return FutureBuilder(
      future: _future,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          if (snapshot.connectionState == ConnectionState.waiting &&
              !widget.compact) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(minHeight: 2),
            );
          }
          return const SizedBox.shrink();
        }
        final data = snapshot.data!;
        if (data.exercises.isEmpty) {
          if (widget.compact) return const SizedBox.shrink();
          return const Text(
            'Список упражнений недоступен',
            style: TextStyle(color: AppColors.muted),
          );
        }
        return FeedExerciseList(
          exercises: data.exercises,
          showLoads: !data.hideLoads,
          compact: widget.compact,
        );
      },
    );
  }
}

String _setsLabel(int count) {
  final mod10 = count % 10;
  final mod100 = count % 100;
  final word = mod10 == 1 && mod100 != 11
      ? 'подход'
      : (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14))
      ? 'подхода'
      : 'подходов';
  return '$count $word';
}
