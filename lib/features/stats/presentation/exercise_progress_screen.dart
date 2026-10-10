import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/exercise_icon.dart';
import '../../rank/domain/mastery_boards.dart';
import '../../workout/domain/exercise_catalog.dart';
import '../data/stats_repository.dart';
import '../domain/exercise_progress.dart';

class ExerciseProgressScreen extends StatefulWidget {
  const ExerciseProgressScreen({
    super.key,
    required this.exerciseKey,
    this.exerciseName,
  });

  final String exerciseKey;
  final String? exerciseName;

  @override
  State<ExerciseProgressScreen> createState() => _ExerciseProgressScreenState();
}

class _ExerciseProgressScreenState extends State<ExerciseProgressScreen> {
  final _repo = StatsRepository();
  late Future<ExerciseProgress> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.buildExerciseProgress(widget.exerciseKey);
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM');

    return Scaffold(
      appBar: AppBar(title: const Text('Прогресс')),
      body: FutureBuilder<ExerciseProgress>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final progress = snapshot.data!;
          final title = widget.exerciseName ?? progress.exerciseName;

          if (progress.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Пока нет подходов по «$title»',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.muted),
                ),
              ),
            );
          }

          final delta = progress.deltaFromFirst;
          final board = MasteryBoards.byExerciseId(progress.exerciseKey);
          final repsMode = !progress.isRun &&
              (board?.metric == MasteryMetric.maxReps ||
                  progress.isRepsFocused);
          final unit = progress.isRun
              ? 'км'
              : progress.isHold
                  ? 'сек'
                  : repsMode
                      ? (board?.unit ?? 'раз')
                      : 'кг';

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Row(
                children: [
                  ExerciseIcon(
                    exerciseId: progress.exerciseKey,
                    name: progress.exerciseName,
                    size: 52,
                    radius: 12,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        Text(
                          '${progress.points.length} тренировок с этим упражнением',
                          style: const TextStyle(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _StatBox(
                      label: progress.isRun
                          ? 'Макс. дистанция'
                          : progress.isHold
                              ? 'Макс. удержание'
                              : repsMode
                                  ? 'Макс. повторы'
                                  : 'Макс вес',
                      value: progress.isRun
                          ? ExerciseCatalog.formatKm(progress.allTimeMaxWeight)
                          : repsMode
                              ? '${progress.allTimeMaxReps} $unit'
                              : '${progress.allTimeMaxWeight.round()} кг',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatBox(
                      label: repsMode ? 'Последняя' : 'Оценка 1ПМ',
                      value: repsMode
                          ? '${progress.points.last.maxReps} $unit'
                          : '${progress.allTimeBest1Rm.round()} кг',
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatBox(
                      label: 'С первой',
                      value:
                          '${delta >= 0 ? '+' : ''}${delta.round()} $unit',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                progress.isRun
                    ? 'Дистанция по тренировкам'
                    : progress.isHold
                        ? 'Макс. удержание по тренировкам'
                        : repsMode
                            ? 'Макс. повторы по тренировкам'
                            : 'Макс. вес по тренировкам',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 12),
              Container(
                height: 220,
                padding: const EdgeInsets.fromLTRB(8, 16, 12, 8),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: _MetricChart(
                  points: progress.points,
                  repsMode: repsMode,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'История',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              ...progress.points.reversed.map((p) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          dateFormat.format(p.date.toLocal()),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      Text(
                        progress.isRun
                            ? '${ExerciseCatalog.formatKm(p.maxWeightKg)} · ${p.sets} отр.'
                            : repsMode
                                ? '${p.maxReps} раз · ${p.sets} подх.'
                                : '${p.maxWeightKg.round()} кг · ${p.sets} подх.',
                        style: const TextStyle(color: AppColors.muted),
                      ),
                    ],
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  const _StatBox({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
          ),
        ],
      ),
    );
  }
}

class _MetricChart extends StatelessWidget {
  const _MetricChart({required this.points, required this.repsMode});

  final List<ExerciseSessionPoint> points;
  final bool repsMode;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MetricChartPainter(points: points, repsMode: repsMode),
      child: const SizedBox.expand(),
    );
  }
}

class _MetricChartPainter extends CustomPainter {
  _MetricChartPainter({required this.points, required this.repsMode});

  final List<ExerciseSessionPoint> points;
  final bool repsMode;

  double _valueAt(int index) => repsMode
      ? points[index].maxReps.toDouble()
      : points[index].maxWeightKg;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final values = [for (var i = 0; i < points.length; i++) _valueAt(i)];
    var minW = values.reduce((a, b) => a < b ? a : b);
    var maxW = values.reduce((a, b) => a > b ? a : b);
    final padRange = repsMode ? 1.0 : 5.0;
    if ((maxW - minW).abs() < 1) {
      minW = (minW - padRange).clamp(0, double.infinity);
      maxW = maxW + padRange;
    }
    final padL = 36.0;
    final padR = 8.0;
    final padT = 12.0;
    final padB = 28.0;
    final chartW = size.width - padL - padR;
    final chartH = size.height - padT - padB;

    final gridPaint = Paint()
      ..color = AppColors.muted.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    final textPainter = TextPainter(textDirection: ui.TextDirection.ltr);

    for (var i = 0; i < 4; i++) {
      final t = i / 3;
      final y = padT + chartH * (1 - t);
      canvas.drawLine(Offset(padL, y), Offset(size.width - padR, y), gridPaint);
      final label = (minW + (maxW - minW) * t).round().toString();
      textPainter.text = TextSpan(
        text: label,
        style: const TextStyle(color: AppColors.muted, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(0, y - textPainter.height / 2));
    }

    Offset pointAt(int index) {
      final x = points.length == 1
          ? padL + chartW / 2
          : padL + chartW * (index / (points.length - 1));
      final t = (_valueAt(index) - minW) / (maxW - minW);
      final y = padT + chartH * (1 - t);
      return Offset(x, y);
    }

    final linePaint = Paint()
      ..color = AppColors.amber
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path()..moveTo(pointAt(0).dx, pointAt(0).dy);
    for (var i = 1; i < points.length; i++) {
      path.lineTo(pointAt(i).dx, pointAt(i).dy);
    }
    canvas.drawPath(path, linePaint);

    final fillPath = Path.from(path)
      ..lineTo(pointAt(points.length - 1).dx, padT + chartH)
      ..lineTo(pointAt(0).dx, padT + chartH)
      ..close();
    canvas.drawPath(
      fillPath,
      Paint()..color = AppColors.amber.withValues(alpha: 0.12),
    );

    final dotPaint = Paint()..color = AppColors.amber;
    for (var i = 0; i < points.length; i++) {
      canvas.drawCircle(pointAt(i), 3.5, dotPaint);
    }

    // Первая и последняя даты.
    final df = DateFormat('d.MM');
    for (final entry in [
      (0, TextAlign.left),
      (points.length - 1, TextAlign.right),
    ]) {
      final i = entry.$1;
      final align = entry.$2;
      textPainter.text = TextSpan(
        text: df.format(points[i].date.toLocal()),
        style: const TextStyle(color: AppColors.muted, fontSize: 10),
      );
      textPainter.layout();
      final x = align == TextAlign.left
          ? padL
          : size.width - padR - textPainter.width;
      textPainter.paint(canvas, Offset(x, size.height - textPainter.height));
    }
  }

  @override
  bool shouldRepaint(covariant _MetricChartPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.repsMode != repsMode;
}
