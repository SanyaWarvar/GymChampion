import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../data/rank_check_repository.dart';
import '../domain/rank_check_rules.dart';
import '../domain/xp_rules.dart';

class RankCheckScreen extends StatefulWidget {
  const RankCheckScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  State<RankCheckScreen> createState() => _RankCheckScreenState();
}

class _RankCheckScreenState extends State<RankCheckScreen> {
  final _repo = RankCheckRepository();
  late Future<DateTime?> _lastFuture;
  bool _running = false;

  @override
  void initState() {
    super.initState();
    _lastFuture = _repo.lastCheckAt();
  }

  Future<void> _run() async {
    setState(() => _running = true);
    try {
      final result = await _repo.runCheck();
      if (!mounted) return;
      context.pushReplacement('/rank/check/result', extra: result);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e is StateError ? e.message : 'Не удалось пройти Rank Check',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _running = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final xp = widget.auth.profile?.xp ?? 0;
    final rank = XpRules.rankForXp(xp);
    final norm = RankCheckRules.normForRank(rank);

    return Scaffold(
      appBar: AppBar(title: const Text('Rank Check')),
      body: FutureBuilder<DateTime?>(
        future: _lastFuture,
        builder: (context, snapshot) {
          final last = snapshot.data;
          final can = RankCheckRules.canAttempt(lastCheckAt: last);

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                'Проверка формы',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Раз в 14 дней смотрим твои тренировки за период. '
                'Прошёл — бонус XP. Провал не снимает медаль.',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Норматив для ${XpRules.shortTitleForRank(rank)}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 10),
                    Text('≥ ${norm.minWorkouts} тренировок за 14 дней'),
                    Text('≥ ${norm.minVolumeKg.round()} кг объёма'),
                    Text('Бонус за успех: +${norm.xpBonus} XP'),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (!can && last != null)
                Text(
                  'Следующий check через ${RankCheckRules.daysUntilNext(last)} дн.',
                  style: const TextStyle(color: AppColors.muted),
                )
              else
                const Text(
                  'Можно проходить сейчас',
                  style: TextStyle(color: AppColors.amber),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: (!can || _running) ? null : _run,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: AppColors.background,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text(_running ? 'Считаем…' : 'Пройти Rank Check'),
              ),
            ],
          );
        },
      ),
    );
  }
}
