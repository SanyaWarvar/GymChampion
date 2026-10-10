import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_repository.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final _repo = AuthRepository();
  late bool _hideWeights;
  late bool _defaultPrivate;
  late bool _showOnLeaderboard;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final p = widget.auth.profile;
    _hideWeights = p?.hideWeights ?? false;
    _defaultPrivate = p?.defaultWorkoutPrivate ?? false;
    _showOnLeaderboard = p?.showOnLeaderboard ?? true;
  }

  Future<void> _persist() async {
    setState(() => _saving = true);
    try {
      await _repo.updatePrivacy(
        hideWeights: _hideWeights,
        defaultWorkoutPrivate: _defaultPrivate,
        showOnLeaderboard: _showOnLeaderboard,
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось сохранить настройки')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Приватность')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          SwitchListTile(
            tileColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text('Скрывать веса от друзей'),
            subtitle: const Text(
              'В чужих просмотрах не светить детали подходов',
              style: TextStyle(color: AppColors.muted),
            ),
            value: _hideWeights,
            activeThumbColor: AppColors.amber,
            onChanged: (v) async {
              setState(() => _hideWeights = v);
              await _persist();
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            tileColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text('Тренировки приватные по умолчанию'),
            subtitle: const Text(
              'Новые тренировки не попадут в ленту',
              style: TextStyle(color: AppColors.muted),
            ),
            value: _defaultPrivate,
            activeThumbColor: AppColors.amber,
            onChanged: (v) async {
              setState(() => _defaultPrivate = v);
              await _persist();
            },
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            tileColor: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: const Text('Показывать в рейтинге'),
            value: _showOnLeaderboard,
            activeThumbColor: AppColors.amber,
            onChanged: (v) async {
              setState(() => _showOnLeaderboard = v);
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
}
