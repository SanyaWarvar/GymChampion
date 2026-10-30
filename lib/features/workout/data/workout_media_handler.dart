import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../application/rest_timer_controller.dart';
import 'local_workout_store.dart';
import 'workout_media_art.dart';

const _mediaActiveKey = 'workout_media_active_v1';

/// MediaSession: шторка + lock screen с режимами отдых / подход.
class WorkoutMediaHandler extends BaseAudioHandler {
  WorkoutMediaHandler() {
    Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_tick());
    });
  }

  final _store = LocalWorkoutStore();
  String? _lastFingerprint;

  static const completeAction = 'complete_set';
  static const skipRestAction = 'skip_rest';
  static const minus15Action = 'rest_minus_15';
  static const plus15Action = 'rest_plus_15';

  static final _minus15 = MediaControl.custom(
    androidIcon: 'drawable/ic_rest_minus_15',
    label: '−15 с',
    name: minus15Action,
  );
  static final _plus15 = MediaControl.custom(
    androidIcon: 'drawable/ic_rest_plus_15',
    label: '+15 с',
    name: plus15Action,
  );
  static final _skipRest = MediaControl.custom(
    androidIcon: 'drawable/ic_rest_skip',
    label: 'Пропуск',
    name: skipRestAction,
  );
  static final _completeSetControl = MediaControl.custom(
    androidIcon: 'drawable/ic_set_done',
    label: 'Подход ✓',
    name: completeAction,
  );

  Future<void> _tick() async {
    final prefs = await SharedPreferences.getInstance();
    final active = prefs.getBool(_mediaActiveKey) ?? false;
    final restRaw = prefs.getString('rest_timer_v1');
    final draft = await _store.load();
    if (!active && restRaw == null && draft == null) {
      if (mediaItem.value != null) {
        _lastFingerprint = null;
        mediaItem.add(null);
        playbackState.add(PlaybackState(
          processingState: AudioProcessingState.idle,
          playing: false,
        ));
      }
      return;
    }
    await RestTimerController.instance.syncFromDisk();
    await _publish(draft);
  }

  Future<void> _publish(LocalWorkoutDraft? draft) async {
    final rest = RestTimerController.instance;
    final resting = rest.isResting;
    final progress = draft?.nextSetProgress;
    final exerciseName = draft?.nextExerciseName ?? 'Тренировка';
    final exerciseId = draft?.nextExerciseId;

    late final String title;
    late final String artist;
    late final Duration duration;
    late final Duration position;
    late final bool playing;
    late final String artKey;
    late final Uri? artUri;

    if (resting) {
      title = 'Отдых';
      if (rest.restRemainingSeconds == 0) {
        artist = 'Готово';
      } else if (rest.restPaused) {
        artist = 'Пауза · ${rest.restLabel}';
      } else {
        artist = rest.restLabel;
      }
      duration = Duration(seconds: rest.restTotalSeconds.clamp(1, 3600));
      position = Duration(
        seconds: (rest.restTotalSeconds - rest.restRemainingSeconds)
            .clamp(0, rest.restTotalSeconds),
      );
      playing = !rest.restPaused && rest.restRemainingSeconds > 0;
      artKey = restTimerArtAsset;
      artUri = await artUriForRest();
    } else {
      title = exerciseName;
      artist = progress == null
          ? 'План закрыт'
          : 'Подход ${progress.$1 + 1}/${progress.$2}';
      duration = Duration(seconds: ((progress?.$2 ?? 1).clamp(1, 99)) * 60);
      position = Duration(seconds: ((progress?.$1 ?? 0).clamp(0, 99)) * 60);
      playing = false;
      artKey = _exerciseArtKey(exerciseId, exerciseName);
      artUri = await artUriForExercise(
        exerciseId: exerciseId,
        name: exerciseName,
      );
    }

    final canComplete = !resting && draft?.nextExerciseName != null;
    final fingerprint =
        '$title|$artist|$playing|$canComplete|$resting|$artKey|${rest.restPaused}';
    if (fingerprint == _lastFingerprint) return;
    _lastFingerprint = fingerprint;

    mediaItem.add(
      MediaItem(
        id: 'gymchampion_workout',
        title: title,
        artist: artist,
        album: 'GymChampion',
        duration: duration,
        playable: true,
        artUri: artUri,
      ),
    );

    if (resting) {
      final pauseOrPlay =
          rest.restPaused ? MediaControl.play : MediaControl.pause;
      // Compact: −15 · пауза · +15; SKIP в expanded (иконка текстом, не ■).
      final controls = <MediaControl>[
        _minus15,
        pauseOrPlay,
        _plus15,
        _skipRest,
      ];
      playbackState.add(
        PlaybackState(
          controls: controls,
          systemActions: const {},
          androidCompactActionIndices: const [0, 1, 2],
          processingState: AudioProcessingState.ready,
          playing: playing,
          updatePosition: position,
          bufferedPosition: duration,
          speed: playing ? 1.0 : 0.0,
          queueIndex: 0,
        ),
      );
      return;
    }

    // Режим подхода: одна кнопка «Подход ✓», без системных skip prev/next.
    final controls = <MediaControl>[
      if (canComplete) _completeSetControl,
    ];
    playbackState.add(
      PlaybackState(
        controls: controls,
        systemActions: const {},
        androidCompactActionIndices:
            controls.isEmpty ? const <int>[] : const [0],
        processingState: AudioProcessingState.ready,
        playing: false,
        updatePosition: position,
        bufferedPosition: duration,
        speed: 0.0,
        queueIndex: 0,
      ),
    );
  }

  @override
  Future<void> play() async {
    await RestTimerController.instance.syncFromDisk();
    final rest = RestTimerController.instance;
    if (rest.isResting && rest.restPaused) {
      rest.toggleRestPause();
    }
    await _tick();
  }

  @override
  Future<void> pause() async {
    await RestTimerController.instance.syncFromDisk();
    final rest = RestTimerController.instance;
    if (rest.isResting && !rest.restPaused) {
      rest.toggleRestPause();
    }
    await _tick();
  }

  @override
  Future<void> skipToNext() async {}

  @override
  Future<void> skipToPrevious() async {}

  Future<void> _adjustRest(int delta) async {
    await RestTimerController.instance.syncFromDisk();
    if (RestTimerController.instance.isResting) {
      RestTimerController.instance.adjustRemaining(delta);
    }
    _lastFingerprint = null;
    await _tick();
  }

  @override
  Future<void> stop() async {
    // Не используем stop как «пропуск отдыха» — только снятие сессии.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_mediaActiveKey, false);
    _lastFingerprint = null;
    mediaItem.add(null);
    playbackState.add(PlaybackState(
      processingState: AudioProcessingState.idle,
      playing: false,
    ));
    await super.stop();
  }

  @override
  Future<void> customAction(String name, [Map<String, dynamic>? extras]) async {
    switch (name) {
      case completeAction:
        await _completeSet();
      case skipRestAction:
        RestTimerController.instance.dismissRest();
        _lastFingerprint = null;
        await _tick();
      case minus15Action:
        await _adjustRest(-15);
      case plus15Action:
        await _adjustRest(15);
      case 'ensure_session':
        final prefs = await SharedPreferences.getInstance();
        final was = prefs.getBool(_mediaActiveKey) ?? false;
        await prefs.setBool(_mediaActiveKey, true);
        if (!was) await _tick();
      case 'end_session':
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool(_mediaActiveKey, false);
        RestTimerController.instance.dismissRest();
        _lastFingerprint = null;
        mediaItem.add(null);
        playbackState.add(PlaybackState(
          processingState: AudioProcessingState.idle,
          playing: false,
        ));
        await super.stop();
      default:
        await super.customAction(name, extras);
    }
  }

  Future<void> _completeSet() async {
    await RestTimerController.instance.syncFromDisk();
    if (RestTimerController.instance.isResting) {
      await _tick();
      return;
    }
    final draft = await _store.load();
    if (draft == null) {
      await _tick();
      return;
    }
    final name = await draft.completeNextSetAndSave(_store);
    if (name != null) {
      RestTimerController.instance.startRest();
    }
    _lastFingerprint = null;
    await _tick();
  }
}

String _exerciseArtKey(String? id, String? name) =>
    'ex:${id ?? ''}:${name ?? ''}';

AudioHandler? _audioHandler;

Future<void> initWorkoutMediaService() async {
  if (kIsWeb) return;
  if (_audioHandler != null) return;
  try {
    _audioHandler = await AudioService.init(
      builder: WorkoutMediaHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'gym_champion_media_workout',
        androidNotificationChannelName: 'Тренировка',
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
        androidNotificationIcon: 'drawable/ic_stat_workout',
        androidShowNotificationBadge: false,
        // Кнопки на lock screen — без открытия приложения.
        androidNotificationClickStartsActivity: false,
        androidResumeOnClick: false,
        artDownscaleWidth: 256,
        artDownscaleHeight: 256,
      ),
    );
  } catch (e, st) {
    debugPrint('Workout media init failed: $e\n$st');
  }
}

Future<void> workoutMediaEnsureSession() async {
  await _audioHandler?.customAction('ensure_session');
}

Future<void> workoutMediaEndSession() async {
  await _audioHandler?.customAction('end_session');
}

Future<void> workoutMediaRefresh() async {
  await _audioHandler?.customAction('ensure_session');
}
