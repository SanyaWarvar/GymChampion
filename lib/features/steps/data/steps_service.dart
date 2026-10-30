import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:permission_handler/permission_handler.dart';

/// Чтение шагов из Health Connect / Apple Health.
class StepsService {
  StepsService._();
  static final StepsService instance = StepsService._();

  final Health _health = Health();
  bool _configured = false;
  DateTime? _cacheAt;
  int? _cacheSteps;
  DateTime? _cacheFrom;
  DateTime? _cacheTo;

  static const _types = [HealthDataType.STEPS];
  static const _permissions = [HealthDataAccess.READ];

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  Future<bool> hasPermissions() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return false;
    await _ensureConfigured();
    try {
      final granted = await _health.hasPermissions(_types, permissions: _permissions);
      return granted == true;
    } catch (_) {
      return false;
    }
  }

  /// Запрос ACTIVITY_RECOGNITION + STEPS read.
  Future<bool> ensurePermissions() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return false;
    await _ensureConfigured();
    if (Platform.isAndroid) {
      final status = await Permission.activityRecognition.request();
      if (!status.isGranted && !status.isLimited) {
        return false;
      }
    }
    try {
      final ok = await _health.requestAuthorization(
        _types,
        permissions: _permissions,
      );
      if (ok && Platform.isAndroid) {
        try {
          await _health.requestHealthDataHistoryAuthorization();
        } catch (_) {}
      }
      return ok;
    } catch (e, st) {
      debugPrint('Steps permission failed: $e\n$st');
      return false;
    }
  }

  Future<int> stepsToday() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    return stepsInRange(start, now);
  }

  Future<int> stepsInRange(DateTime from, DateTime to) async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return 0;
    if (!to.isAfter(from)) return 0;

    final cached = _readCache(from, to);
    if (cached != null) return cached;

    await _ensureConfigured();
    final allowed = await hasPermissions();
    if (!allowed) return 0;

    try {
      final total = await _health.getTotalStepsInInterval(from, to);
      final steps = (total ?? 0).clamp(0, 1 << 30);
      _writeCache(from, to, steps);
      return steps;
    } catch (e, st) {
      debugPrint('stepsInRange failed: $e\n$st');
      return 0;
    }
  }

  int? _readCache(DateTime from, DateTime to) {
    final at = _cacheAt;
    if (at == null || _cacheSteps == null) return null;
    if (DateTime.now().difference(at) > const Duration(minutes: 2)) return null;
    if (_cacheFrom != from || _cacheTo == null) return null;
    // Для «сегодня» допускаем небольшой дрейф end.
    if (to.difference(_cacheTo!).abs() > const Duration(minutes: 2)) {
      return null;
    }
    return _cacheSteps;
  }

  void _writeCache(DateTime from, DateTime to, int steps) {
    _cacheAt = DateTime.now();
    _cacheFrom = from;
    _cacheTo = to;
    _cacheSteps = steps;
  }

  void invalidateCache() {
    _cacheAt = null;
    _cacheSteps = null;
  }
}
