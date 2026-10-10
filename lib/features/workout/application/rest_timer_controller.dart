import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Глобальный таймер отдыха — живёт во всём приложении, не только на экране тренировки.
class RestTimerController extends ChangeNotifier {
  RestTimerController._() {
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_onTick());
    });
    unawaited(restore());
  }

  Future<void> _onTick() async {
    // Подхватываем паузу/пропуск с lock screen (MediaSession isolate).
    await syncFromDisk();
    if (!isResting) return;
    notifyListeners();
    await _persist();
  }

  static final RestTimerController instance = RestTimerController._();

  static const _prefsKey = 'rest_timer_v1';

  Timer? _ticker;
  DateTime? _restEndsAt;
  int _restTotalSeconds = 90;
  bool _restPaused = false;
  int? _restPausedRemaining;

  bool get isResting =>
      _restEndsAt != null || (_restPaused && (_restPausedRemaining ?? 0) > 0);

  int get restTotalSeconds => _restTotalSeconds;

  bool get restPaused => _restPaused;

  /// Конец отдыха (для системного chronometer в шторке).
  DateTime? get restEndsAt => _restPaused
      ? DateTime.now().add(Duration(seconds: restRemainingSeconds))
      : _restEndsAt;

  int get restRemainingSeconds {
    if (_restPaused) {
      return (_restPausedRemaining ?? 0).clamp(0, _restTotalSeconds);
    }
    final ends = _restEndsAt;
    if (ends == null) return 0;
    return ends.difference(DateTime.now()).inSeconds.clamp(0, _restTotalSeconds);
  }

  double get restProgress {
    if (_restTotalSeconds <= 0) return 1;
    return (1 - restRemainingSeconds / _restTotalSeconds).clamp(0.0, 1.0);
  }

  String get restLabel {
    final left = restRemainingSeconds;
    final m = (left ~/ 60).toString().padLeft(2, '0');
    final s = (left % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void startRest({int seconds = 90}) {
    _restTotalSeconds = seconds;
    _restPaused = false;
    _restPausedRemaining = null;
    _restEndsAt = DateTime.now().add(Duration(seconds: seconds));
    notifyListeners();
    unawaited(_persist());
  }

  void setRestPreset(int seconds) => startRest(seconds: seconds);

  /// Сдвигает оставшееся время отдыха (кнопки ±15с в шторке).
  void adjustRemaining(int deltaSeconds) {
    if (!isResting) return;
    final next = (restRemainingSeconds + deltaSeconds).clamp(0, 3600);
    if (next > _restTotalSeconds) {
      _restTotalSeconds = next;
    }
    if (_restPaused) {
      if (next <= 0) {
        _restPaused = false;
        _restPausedRemaining = null;
        _restEndsAt = DateTime.now();
      } else {
        _restPausedRemaining = next;
      }
    } else {
      _restEndsAt = DateTime.now().add(Duration(seconds: next));
    }
    notifyListeners();
    unawaited(_persist());
  }

  void toggleRestPause() {
    if (!isResting) return;
    if (_restPaused) {
      final left = (_restPausedRemaining ?? 0).clamp(1, _restTotalSeconds);
      _restPaused = false;
      _restPausedRemaining = null;
      _restEndsAt = DateTime.now().add(Duration(seconds: left));
    } else {
      _restPausedRemaining = restRemainingSeconds;
      _restPaused = true;
      _restEndsAt = null;
    }
    notifyListeners();
    unawaited(_persist());
  }

  void dismissRest() {
    _restEndsAt = null;
    _restPaused = false;
    _restPausedRemaining = null;
    notifyListeners();
    unawaited(_clearPersist());
  }

  Future<void> restore() async {
    await syncFromDisk(forceNotify: true);
  }

  /// Читает состояние с диска (нужно для MediaSession isolate / кнопок lock screen).
  Future<void> syncFromDisk({bool forceNotify = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw == null || raw.isEmpty) {
        if (isResting) {
          _restEndsAt = null;
          _restPaused = false;
          _restPausedRemaining = null;
          notifyListeners();
        }
        return;
      }
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final nextTotal = (map['total'] as num?)?.toInt() ?? 90;
      final nextPaused = map['paused'] as bool? ?? false;
      DateTime? nextEnds;
      int? nextPausedLeft;
      if (nextPaused) {
        nextPausedLeft = (map['pausedLeft'] as num?)?.toInt() ?? 0;
        if ((nextPausedLeft) <= 0) {
          await _clearPersist();
          if (isResting) dismissRest();
          return;
        }
      } else {
        nextEnds = DateTime.tryParse(map['endsAt'] as String? ?? '');
        if (nextEnds == null ||
            nextEnds.isBefore(
                DateTime.now().subtract(const Duration(seconds: 30)))) {
          await _clearPersist();
          if (isResting) {
            _restEndsAt = null;
            _restPaused = false;
            _restPausedRemaining = null;
            notifyListeners();
          }
          return;
        }
      }

      final changed = nextTotal != _restTotalSeconds ||
          nextPaused != _restPaused ||
          nextEnds?.millisecondsSinceEpoch !=
              _restEndsAt?.millisecondsSinceEpoch ||
          nextPausedLeft != _restPausedRemaining;
      _restTotalSeconds = nextTotal;
      _restPaused = nextPaused;
      _restEndsAt = nextEnds;
      _restPausedRemaining = nextPausedLeft;
      if (changed || forceNotify) notifyListeners();
    } catch (_) {}
  }

  Future<void> _persist() async {
    if (!isResting) {
      await _clearPersist();
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _prefsKey,
      jsonEncode({
        'total': _restTotalSeconds,
        'paused': _restPaused,
        'pausedLeft': _restPausedRemaining,
        'endsAt': _restEndsAt?.toIso8601String(),
      }),
    );
  }

  Future<void> _clearPersist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
