import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../application/rest_timer_controller.dart';

/// Свёрнутый таймер отдыха — показывается поверх shell.
class MinimizedRestBar extends StatelessWidget {
  const MinimizedRestBar({
    super.key,
    this.aboveBottomNav = false,
    this.onOpen,
  });

  /// Поднять бар над NavigationBar (~80 dp).
  final bool aboveBottomNav;

  /// Тап по бару (навигация на тренировку + sheet).
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final rest = RestTimerController.instance;
    return ListenableBuilder(
      listenable: rest,
      builder: (context, _) {
        if (!rest.isResting) return const SizedBox.shrink();
        final done = rest.restRemainingSeconds == 0;
        final bottomPad = aboveBottomNav ? 72.0 : 0.0;
        return Padding(
          padding: EdgeInsets.only(bottom: bottomPad),
          child: Material(
            color: AppColors.surface,
            elevation: 6,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onOpen,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        value: rest.restProgress.clamp(0.0, 1.0),
                        strokeWidth: 3,
                        color: AppColors.amber,
                        backgroundColor: AppColors.background,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            done
                                ? 'Отдых закончен'
                                : (rest.restPaused
                                    ? 'Отдых на паузе'
                                    : 'Отдых'),
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            rest.restLabel,
                            style: const TextStyle(
                              color: AppColors.amber,
                              fontWeight: FontWeight.w800,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                    ),
                    _BarIcon(
                      icon: rest.restPaused ? Icons.play_arrow : Icons.pause,
                      onTap: done ? null : rest.toggleRestPause,
                    ),
                    _BarIcon(
                      icon: Icons.close,
                      onTap: rest.dismissRest,
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

class _BarIcon extends StatelessWidget {
  const _BarIcon({required this.icon, this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Icon(
          icon,
          color: onTap == null ? Theme.of(context).disabledColor : null,
        ),
      ),
    );
  }
}
