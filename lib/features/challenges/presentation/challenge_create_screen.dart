import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/app_user.dart';
import '../data/challenge_repository.dart';
import '../domain/challenge.dart';

class ChallengeCreateScreen extends StatefulWidget {
  const ChallengeCreateScreen({
    super.key,
    required this.auth,
    this.preselected,
  });

  final AuthController auth;
  final AppUser? preselected;

  @override
  State<ChallengeCreateScreen> createState() => _ChallengeCreateScreenState();
}

class _ChallengeCreateScreenState extends State<ChallengeCreateScreen> {
  final _repo = ChallengeRepository();
  AppUser? _opponent;
  ChallengeMetric _metric = ChallengeMetric.volume;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _opponent = widget.preselected;
  }

  Future<void> _create() async {
    final me = widget.auth.profile;
    final opponent = _opponent;
    if (me == null || opponent == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выбери соперника')),
      );
      return;
    }
    if (me.uid == opponent.uid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Нельзя вызвать самого себя')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final id = await _repo.createChallenge(
        me: me,
        opponent: opponent,
        metric: _metric,
      );
      if (!mounted) return;
      context.pushReplacement('/challenges/$id');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось создать вызов')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUid = widget.auth.profile?.uid;

    return Scaffold(
      appBar: AppBar(title: const Text('Новый вызов')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Соперник',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          if (_opponent != null)
            ListTile(
              tileColor: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              title: Text(_opponent!.displayName ?? 'Без имени'),
              subtitle: Text('${_opponent!.xp} XP'),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _opponent = null),
              ),
            )
          else
            StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('xp', descending: true)
                  .limit(30)
                  .snapshots(),
              builder: (context, snapshot) {
                final docs = snapshot.data?.docs ?? const [];
                final users = docs
                    .map((d) => AppUser.fromMap(d.id, d.data()))
                    .where((u) => u.uid != myUid && u.hasDisplayName)
                    .toList();
                if (users.isEmpty) {
                  return const Text(
                    'Пока нет других игроков',
                    style: TextStyle(color: AppColors.muted),
                  );
                }
                return Column(
                  children: users.map((u) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        tileColor: AppColors.surface,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        title: Text(u.displayName ?? 'Без имени'),
                        subtitle: Text('${u.xp} XP · ${u.workoutCount} трен.'),
                        onTap: () => setState(() => _opponent = u),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          const SizedBox(height: 20),
          Text(
            'Метрика (неделя)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          ...ChallengeMetric.values.map(
            (m) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                tileColor: _metric == m
                    ? AppColors.amber.withValues(alpha: 0.12)
                    : AppColors.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                title: Text(m.label),
                trailing: Icon(
                  _metric == m
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: AppColors.amber,
                ),
                onTap: () => setState(() => _metric = m),
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _create,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: AppColors.background,
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(_saving ? 'Создаём…' : 'Бросить вызов'),
          ),
        ],
      ),
    );
  }
}
