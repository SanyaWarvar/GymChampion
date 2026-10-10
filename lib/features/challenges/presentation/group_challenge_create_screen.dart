import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../data/challenge_repository.dart';
import '../domain/challenge.dart';

class GroupChallengeCreateScreen extends StatefulWidget {
  const GroupChallengeCreateScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<GroupChallengeCreateScreen> createState() =>
      _GroupChallengeCreateScreenState();
}

class _GroupChallengeCreateScreenState
    extends State<GroupChallengeCreateScreen> {
  final _repo = ChallengeRepository();
  final _title = TextEditingController(text: 'Месяц вместе');
  final _target = TextEditingController(text: '500');
  ChallengeMetric _metric = ChallengeMetric.xp;
  int _days = 30;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _target.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final me = widget.auth.profile;
    final target = double.tryParse(_target.text.replaceAll(',', '.')) ?? 0;
    if (me == null || target <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Укажи цель больше нуля')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final id = await _repo.createGroupChallenge(
        me: me,
        title: _title.text,
        metric: _metric,
        target: target,
        days: _days,
      );
      if (!mounted) return;
      context.pushReplacement('/challenges/group/$id');
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось создать цель')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Общая цель')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Все с лидерборда сразу в деле. Например: набрать 500 XP за месяц вместе.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Название'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _target,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
            ],
            decoration: const InputDecoration(labelText: 'Цель (сумма всех)'),
          ),
          const SizedBox(height: 20),
          Text(
            'Метрика',
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
          const SizedBox(height: 8),
          Text(
            'Срок',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final d in const [7, 14, 30])
                ChoiceChip(
                  label: Text(d == 30 ? 'Месяц' : '$d дн.'),
                  selected: _days == d,
                  onSelected: (_) => setState(() => _days = d),
                ),
            ],
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _create,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.amber,
              foregroundColor: AppColors.background,
              minimumSize: const Size.fromHeight(48),
            ),
            child: Text(_saving ? 'Создаём…' : 'Запустить цель'),
          ),
        ],
      ),
    );
  }
}
