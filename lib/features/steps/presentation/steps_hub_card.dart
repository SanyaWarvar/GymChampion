import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../rank/domain/xp_rules.dart';
import '../data/steps_repository.dart';
import '../data/steps_service.dart';

/// Карточка дневных шагов на хабе тренировок.
class StepsHubCard extends StatefulWidget {
  const StepsHubCard({super.key});

  @override
  State<StepsHubCard> createState() => _StepsHubCardState();
}

class _StepsHubCardState extends State<StepsHubCard> {
  final _steps = StepsService.instance;
  final _repo = StepsRepository();

  bool _loading = true;
  bool _hasPermission = false;
  bool _busy = false;
  int _today = 0;
  int _goal = XpRules.defaultStepsGoal;
  bool _claimed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_refresh());
  }

  Future<void> _refresh() async {
    setState(() => _loading = true);
    try {
      final has = await _steps.hasPermissions();
      final goal = await _repo.goalForUser();
      final claimed = await _repo.claimedToday();
      var today = 0;
      if (has) {
        today = await _steps.stepsToday();
        unawaited(_repo.syncChallenges());
      }
      if (!mounted) return;
      setState(() {
        _hasPermission = has;
        _goal = goal;
        _claimed = claimed;
        _today = today;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _connect() async {
    setState(() => _busy = true);
    try {
      final ok = await _steps.ensurePermissions();
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Нужен доступ к шагам в Health Connect',
            ),
          ),
        );
      }
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _claim() async {
    setState(() => _busy = true);
    try {
      _steps.invalidateCache();
      final steps = await _steps.stepsToday();
      final result = await _repo.claimTodayIfEligible(steps: steps);
      if (!mounted) return;
      final msg = switch (result.status) {
        StepsClaimStatus.claimed =>
          '+${result.xpEarned} XP · день засчитан',
        StepsClaimStatus.alreadyClaimed => 'Уже забрал сегодня',
        StepsClaimStatus.belowGoal => 'Ещё не хватает до цели',
        StepsClaimStatus.notSignedIn => 'Войди в аккаунт',
        StepsClaimStatus.error => 'Не удалось засчитать',
      };
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      await _refresh();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final progress = _goal <= 0 ? 0.0 : (_today / _goal).clamp(0.0, 1.0);
    final canClaim = _hasPermission && !_claimed && _today >= _goal;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.amber.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.directions_walk, color: AppColors.amber),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Шаги сегодня',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              if (_loading || _busy)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              else
                IconButton(
                  tooltip: 'Обновить',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh, size: 20),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          const SizedBox(height: 8),
          if (!_hasPermission) ...[
            const Text(
              'Подключи Health Connect, чтобы считать шаги и участвовать в вызовах.',
              style: TextStyle(color: AppColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 10),
            FilledButton(
              onPressed: _busy ? null : _connect,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.amber,
                foregroundColor: AppColors.background,
              ),
              child: const Text('Подключить'),
            ),
          ] else ...[
            Text(
              '$_today / $_goal',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: AppColors.background,
                color: AppColors.amber,
              ),
            ),
            const SizedBox(height: 10),
            if (_claimed)
              Text(
                'День засчитан · +${XpRules.xpForStepsDay} XP',
                style: const TextStyle(
                  color: AppColors.muted,
                  fontWeight: FontWeight.w600,
                ),
              )
            else if (canClaim)
              FilledButton(
                onPressed: _busy ? null : _claim,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.amber,
                  foregroundColor: AppColors.background,
                ),
                child: Text('Забрать ${XpRules.xpForStepsDay} XP'),
              )
            else
              Text(
                'До цели ещё ${(_goal - _today).clamp(0, _goal)} шагов',
                style: const TextStyle(color: AppColors.muted, fontSize: 13),
              ),
          ],
        ],
      ),
    );
  }
}
