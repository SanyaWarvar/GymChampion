import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

class RestTimerSheet extends StatefulWidget {
  const RestTimerSheet({super.key, this.initialSeconds = 90});

  final int initialSeconds;

  static Future<void> show(BuildContext context, {int seconds = 90}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => RestTimerSheet(initialSeconds: seconds),
    );
  }

  @override
  State<RestTimerSheet> createState() => _RestTimerSheetState();
}

class _RestTimerSheetState extends State<RestTimerSheet> {
  late int _remaining;
  late int _total;
  Timer? _timer;
  bool _running = true;

  @override
  void initState() {
    super.initState();
    _total = widget.initialSeconds;
    _remaining = widget.initialSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_running) return;
      if (_remaining <= 1) {
        setState(() {
          _remaining = 0;
          _running = false;
        });
        _timer?.cancel();
        return;
      }
      setState(() => _remaining -= 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _setPreset(int seconds) {
    setState(() {
      _total = seconds;
      _remaining = seconds;
      _running = true;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!_running) return;
      if (_remaining <= 1) {
        setState(() {
          _remaining = 0;
          _running = false;
        });
        _timer?.cancel();
        return;
      }
      setState(() => _remaining -= 1);
    });
  }

  String get _label {
    final m = (_remaining ~/ 60).toString().padLeft(2, '0');
    final s = (_remaining % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _total == 0 ? 0.0 : 1 - (_remaining / _total);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        8,
        24,
        MediaQuery.paddingOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _remaining == 0 ? 'Отдых закончен' : 'Отдых',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress.clamp(0.0, 1.0),
                  strokeWidth: 8,
                  color: AppColors.amber,
                  backgroundColor: AppColors.surface,
                ),
                Text(
                  _label,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            children: [
              for (final sec in [60, 90, 120, 180])
                ChoiceChip(
                  label: Text('${sec}s'),
                  selected: _total == sec,
                  onSelected: (_) => _setPreset(sec),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    setState(() => _running = !_running);
                  },
                  child: Text(_running ? 'Пауза' : 'Продолжить'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.amber,
                    foregroundColor: AppColors.background,
                  ),
                  child: const Text('К подходам'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
