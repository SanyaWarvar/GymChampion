import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';
import '../../challenges/data/challenge_repository.dart';
import '../../challenges/domain/challenge.dart';
import '../../notifications/data/local_notification_service.dart';
import '../../rank/domain/streak_rules.dart';
import '../../workout/data/workout_repository.dart';

class NotificationsSettingsScreen extends StatefulWidget {
  const NotificationsSettingsScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<NotificationsSettingsScreen> createState() =>
      _NotificationsSettingsScreenState();
}

class _NotificationsSettingsScreenState
    extends State<NotificationsSettingsScreen> {
  final _repo = AuthRepository();
  final _locals = LocalNotificationService.instance;
  late bool _overtaken;
  late bool _season;
  late bool _challenges;
  late bool _streakReminder;
  late bool _challengeDeadline;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.auth.profile;
    _overtaken = p?.notifyOvertaken ?? true;
    _season = p?.notifySeason ?? true;
    _challenges = p?.notifyChallenges ?? true;
    _streakReminder = p?.notifyStreakReminder ?? true;
    _challengeDeadline = p?.notifyChallengeDeadline ?? true;
  }

  Future<void> _persist() async {
    setState(() => _saving = true);
    try {
      await _repo.updateNotificationPrefs(
        notifyOvertaken: _overtaken,
        notifySeason: _season,
        notifyChallenges: _challenges,
        notifyStreakReminder: _streakReminder,
        notifyChallengeDeadline: _challengeDeadline,
      );
      if (_streakReminder || _challengeDeadline) {
        await _locals.requestPermission();
      }
      await _resyncLocals();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resyncLocals() async {
    final profile = widget.auth.profile;
    if (profile == null) return;
    var challenges = const <Challenge>[];
    var workedOutToday = false;
    try {
      challenges = await ChallengeRepository().watchMyChallenges().first;
    } catch (_) {}
    try {
      final workouts = await WorkoutRepository().fetchMyWorkouts(limit: 5);
      final today = StreakRules.dateOnly(DateTime.now());
      workedOutToday = workouts.any(
        (w) => StreakRules.dateOnly(w.finishedAt) == today,
      );
    } catch (_) {}
    await _locals.syncFromProfile(
      profile: profile.copyWith(
        notifyStreakReminder: _streakReminder,
        notifyChallengeDeadline: _challengeDeadline,
      ),
      activeChallenges: challenges
          .where((c) => c.status == ChallengeStatus.active)
          .toList(),
      workedOutToday: workedOutToday,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Уведомления')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Лента',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'События от других появляются в приложении в разделе «Уведомления».',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _tile(
            title: 'Тебя обогнали в рейтинге',
            value: _overtaken,
            onChanged: (v) async {
              setState(() => _overtaken = v);
              await _persist();
            },
          ),
          _tile(
            title: 'Сезон и Rank Check',
            value: _season,
            onChanged: (v) async {
              setState(() => _season = v);
              await _persist();
            },
          ),
          _tile(
            title: 'Вызовы и челленджи',
            value: _challenges,
            onChanged: (v) async {
              setState(() => _challenges = v);
              await _persist();
            },
          ),
          const SizedBox(height: 20),
          const Text(
            'На этом устройстве',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          const Text(
            'Локальные напоминания на телефоне (не push другим людям).',
            style: TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 12),
          _tile(
            title: 'Напоминание о стрике (20:00)',
            value: _streakReminder,
            onChanged: (v) async {
              setState(() => _streakReminder = v);
              await _persist();
            },
          ),
          _tile(
            title: 'Дедлайн вызова (за сутки)',
            value: _challengeDeadline,
            onChanged: (v) async {
              setState(() => _challengeDeadline = v);
              await _persist();
            },
          ),
          if (_saving)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _tile({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        tileColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(title),
        value: value,
        activeThumbColor: AppColors.amber,
        onChanged: onChanged,
      ),
    );
  }
}
