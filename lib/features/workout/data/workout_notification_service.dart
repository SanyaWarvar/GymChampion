import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../notifications/data/local_notification_service.dart';
import '../application/active_workout_controller.dart';
import '../application/rest_timer_controller.dart';
import 'local_workout_store.dart';
import 'workout_media_handler.dart';

/// Держит MediaSession тренировки (шторка + lock screen).
/// Контент обновляет [WorkoutMediaHandler] своим тикером — тут только start/stop.
class WorkoutNotificationService {
  WorkoutNotificationService._() {
    RestTimerController.instance.addListener(_onRestChanged);
  }

  static final WorkoutNotificationService instance =
      WorkoutNotificationService._();

  static const notifId = 42001;
  static const channelId = 'gym_champion_workout_v2';
  static const channelName = 'Тренировка';

  static const actionCompleteSet = 'workout_complete_set';
  static const actionToggleRest = 'workout_toggle_rest';
  static const actionSkipRest = 'workout_skip_rest';

  ActiveWorkoutController? _controller;
  final _store = LocalWorkoutStore();
  bool? _lastHadSession;

  void attach(ActiveWorkoutController controller) {
    _controller?.removeListener(_onWorkoutChanged);
    _controller = controller;
    controller.addListener(_onWorkoutChanged);
    unawaited(_ensureReadyAndPublish());
  }

  void detach(ActiveWorkoutController controller) {
    if (!identical(_controller, controller)) return;
    controller.removeListener(_onWorkoutChanged);
    _controller = null;
    unawaited(publish(force: true));
  }

  void _onWorkoutChanged() {
    // Тик elapsed каждую секунду — не дёргаем MediaSession (rate limit Android).
    // Только смена плана/подходов через force из UI-действий не нужна:
    // media handler читает draft с диска сам.
    unawaited(_syncSessionIfChanged());
  }

  void _onRestChanged() => unawaited(_syncSessionIfChanged());

  Future<void> _ensureReadyAndPublish() async {
    await LocalNotificationService.instance.requestPermission();
    await publish(force: true);
  }

  Future<void> _syncSessionIfChanged() async {
    final has = await _computeHasSession();
    if (_lastHadSession == has) return;
    await publish(force: true);
  }

  Future<bool> _computeHasSession() async {
    final c = _controller;
    final resting = RestTimerController.instance.isResting;
    if (c != null || resting) return true;
    final draft = await _store.load();
    return draft != null;
  }

  Future<void> handleAction(String? actionId) async {
    if (actionId == null || actionId.isEmpty) return;
    final c = _controller;
    final rest = RestTimerController.instance;

    switch (actionId) {
      case actionCompleteSet:
        if (c != null) {
          if (c.completeNextSet()) {
            rest.startRest();
          }
        } else {
          final draft = await _store.load();
          if (draft != null) {
            final name = await draft.completeNextSetAndSave(_store);
            if (name != null) {
              rest.startRest();
            }
          }
        }
      case actionToggleRest:
        if (rest.isResting) {
          rest.toggleRestPause();
        } else {
          rest.startRest();
        }
      case actionSkipRest:
        rest.dismissRest();
    }
    await publish(force: true);
  }

  Future<void> publish({bool force = false}) async {
    if (kIsWeb || !Platform.isAndroid) return;

    final hasSession = await _computeHasSession();
    _lastHadSession = hasSession;
    if (!hasSession) {
      await stop();
      return;
    }

    await workoutMediaEnsureSession();
    try {
      await LocalNotificationService.instance.plugin.cancel(id: notifId);
    } catch (_) {}
  }

  Future<void> stop() async {
    _lastHadSession = false;
    if (kIsWeb) return;
    await workoutMediaEndSession();
    try {
      await LocalNotificationService.instance.plugin.cancel(id: notifId);
    } catch (_) {}
  }
}
