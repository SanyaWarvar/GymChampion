import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../auth/domain/app_user.dart';
import '../../challenges/domain/challenge.dart';

/// Локальные напоминания только на этом устройстве (стрик / дедлайн вызова).
class LocalNotificationService {
  LocalNotificationService._();

  static final LocalNotificationService instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _channelId = 'gym_champion_reminders';
  static const _channelName = 'Напоминания GymChampion';
  static const _streakId = 1001;
  static const _challengeIdBase = 2000;

  bool _ready = false;

  Future<void> init() async {
    if (_ready || kIsWeb) return;
    tz_data.initializeTimeZones();
    try {
      final info = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(info.identifier));
    } catch (_) {
      try {
        tz.setLocalLocation(tz.local);
      } catch (_) {}
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(android: android, iOS: ios),
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Стрик и дедлайны вызовов',
        importance: Importance.defaultImportance,
      ),
    );

    _ready = true;
  }

  Future<bool> requestPermission() async {
    if (kIsWeb) return false;
    await init();
    if (Platform.isAndroid) {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final granted = await android?.requestNotificationsPermission();
      return granted ?? true;
    }
    if (Platform.isIOS || Platform.isMacOS) {
      final ios = _plugin.resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin>();
      final granted = await ios?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );
      return granted ?? false;
    }
    return true;
  }

  Future<void> syncFromProfile({
    required AppUser? profile,
    required List<Challenge> activeChallenges,
    required bool workedOutToday,
  }) async {
    if (kIsWeb || profile == null) return;
    await init();

    if (profile.notifyStreakReminder &&
        profile.streakDays > 0 &&
        !workedOutToday) {
      await _scheduleStreakReminder();
    } else {
      await _plugin.cancel(id: _streakId);
    }

    await _cancelChallengeReminders();
    if (profile.notifyChallengeDeadline) {
      var i = 0;
      for (final c in activeChallenges) {
        if (c.status != ChallengeStatus.active) continue;
        final when = c.endsAt.subtract(const Duration(hours: 24));
        if (!when.isAfter(DateTime.now())) continue;
        final other =
            profile.uid == c.challengerId ? c.opponentName : c.challengerName;
        await _scheduleAt(
          id: _challengeIdBase + i,
          when: when,
          title: 'Вызов скоро закончится',
          body: 'Завтра конец вызова vs $other',
          payload: '/challenges/${c.id}',
        );
        i++;
        if (i >= 10) break;
      }
    }
  }

  Future<void> _scheduleStreakReminder() async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20);
    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _plugin.zonedSchedule(
      id: _streakId,
      title: 'Не погаси огонёк',
      body: 'Сегодня ещё нет тренировки — стрик под угрозой',
      scheduledDate: scheduled,
      notificationDetails: _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: '/workout',
    );
  }

  Future<void> _scheduleAt({
    required int id,
    required DateTime when,
    required String title,
    required String body,
    String? payload,
  }) async {
    final scheduled = tz.TZDateTime.from(when.toLocal(), tz.local);
    if (!scheduled.isAfter(tz.TZDateTime.now(tz.local))) return;
    await _plugin.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: scheduled,
      notificationDetails: _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      payload: payload,
    );
  }

  Future<void> _cancelChallengeReminders() async {
    for (var i = 0; i < 10; i++) {
      await _plugin.cancel(id: _challengeIdBase + i);
    }
  }

  NotificationDetails _details() {
    return const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: 'Стрик и дедлайны вызовов',
        importance: Importance.defaultImportance,
        priority: Priority.defaultPriority,
      ),
      iOS: DarwinNotificationDetails(),
    );
  }

  Future<void> cancelAll() async {
    if (!_ready) return;
    await _plugin.cancelAll();
  }
}
