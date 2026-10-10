import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/season.dart';

class SeasonInfoScreen extends StatelessWidget {
  const SeasonInfoScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final season = Season.current();
    final next = season.next;
    final dateFormat = DateFormat('d MMM yyyy');
    final seasonXp = auth.profile?.seasonXp ?? 0;
    final storedId = auth.profile?.seasonId;
    final xpForThisSeason =
        storedId == null || storedId == season.id ? seasonXp : 0;

    return Scaffold(
      appBar: AppBar(title: const Text('Сезон')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: season.color.withValues(alpha: 0.55)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  season.flavor,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  season.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: season.color,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${dateFormat.format(season.startsAt)} — ${dateFormat.format(season.endsAt.subtract(const Duration(days: 1)))}',
                  style: const TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 12),
                Text(
                  'Осталось ${season.daysLeft} дн. · дальше ${next.title}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  'Твой сезонный XP: $xpForThisSeason',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Год',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          ...Season.yearCycle().map((s) {
            final current = s.id == season.id;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: current
                    ? s.color.withValues(alpha: 0.14)
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: current
                    ? Border.all(color: s.color.withValues(alpha: 0.5))
                    : null,
              ),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: s.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${s.kind.label} · ${s.flavor}',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            color: current ? s.color : null,
                          ),
                        ),
                        Text(
                          '${dateFormat.format(s.startsAt)} — ${dateFormat.format(s.endsAt.subtract(const Duration(days: 1)))}',
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (current)
                    Text(
                      'сейчас',
                      style: TextStyle(
                        color: s.color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          Text(
            'Правила',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 10),
          ...Season.rules.map(
            (rule) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('•  ', style: TextStyle(color: AppColors.amber)),
                  Expanded(child: Text(rule)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
