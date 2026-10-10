import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../application/rest_timer_controller.dart';

class RestTimerSheet extends StatelessWidget {
  const RestTimerSheet({super.key});

  static Future<void> show(BuildContext context) {
    final nav = Navigator.maybeOf(context, rootNavigator: true);
    if (nav == null) return Future.value();
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      showDragHandle: true,
      isDismissible: true,
      enableDrag: true,
      builder: (_) => const RestTimerSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rest = RestTimerController.instance;
    return ListenableBuilder(
      listenable: rest,
      builder: (context, _) {
        final remaining = rest.restRemainingSeconds;
        final progress = rest.restProgress;

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
                remaining == 0 ? 'Отдых закончен' : 'Отдых',
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
                      value: progress,
                      strokeWidth: 8,
                      color: AppColors.amber,
                      backgroundColor: AppColors.surface,
                    ),
                    Text(
                      rest.restLabel,
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
                      selected: rest.restTotalSeconds == sec,
                      onSelected: (_) => rest.setRestPreset(sec),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          remaining == 0 ? null : rest.toggleRestPause,
                      child: Text(rest.restPaused ? 'Продолжить' : 'Пауза'),
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
                      child: const Text('Свернуть'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () {
                  rest.dismissRest();
                  Navigator.pop(context);
                },
                child: const Text('Пропустить отдых'),
              ),
            ],
          ),
        );
      },
    );
  }
}
