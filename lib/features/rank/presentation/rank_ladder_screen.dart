import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../domain/xp_rules.dart';
import 'rank_badge.dart';

class RankLadderScreen extends StatelessWidget {
  const RankLadderScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final xp = auth.profile?.xp ?? 0;
    final current = XpRules.medalForXp(xp);
    final tiers = <String, List<MedalRank>>{};
    for (final medal in XpRules.ranks) {
      tiers.putIfAbsent(medal.medalKey, () => []).add(medal);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Медали')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Как качается XP',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Плотная сессия даёт больше, чем короткая, но потолки жёсткие.\n'
            '30 база + 6 за подход (до 90) + объём/60 кг + бег×8 км + минуты (до 80).\n'
            'Бонусы: 2–4+ упражнений (+6/14/24) и сессия 30/45 мин (+6/14).\n'
            'Квесты дают меньше XP сверху. Пропуск без заморозки режет XP сильнее на высокой медали (−35 на Новичке, −260 на Титане), звезда может упасть. Заморозка за каждые 1000 XP (накопительно), XP не тратит, закрывает пропуск и прибавляет этот день к серии.\n'
            'Медали: Новичок → Титан, внутри 1–5 ★.',
            style: TextStyle(color: AppColors.muted),
          ),
          const SizedBox(height: 12),
          _CurrentProgress(xp: xp, current: current),
          const SizedBox(height: 20),
          ...tiers.entries.map((entry) {
            final medals = entry.value;
            final first = medals.first;
            final reached = medals.where((m) => xp >= m.threshold).toList();
            final locked = reached.isEmpty;
            final filledStars = locked ? 0 : reached.last.stars;
            final isCurrentTier = current.medalKey == first.medalKey;
            final previewId = locked ? first.id : reached.last.id;
            final status = locked
                ? 'с ${first.threshold} XP · пропуск −${first.missPenalty}'
                : isCurrentTier
                ? '$xp XP · ${XpRules.xpToNextRank(xp) > 0 ? 'ещё ${XpRules.xpToNextRank(xp)} до следующей ★' : 'максимум'} · пропуск −${first.missPenalty}'
                : 'открыто · пропуск −${first.missPenalty}';
            return Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => showMedalPreview(
                  context,
                  rankId: previewId,
                  caption: status,
                ),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isCurrentTier
                        ? first.color.withValues(alpha: 0.14)
                        : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: isCurrentTier
                        ? Border.all(color: first.color.withValues(alpha: 0.55))
                        : null,
                  ),
                  child: Row(
                    children: [
                      RankBadge(rankId: previewId, size: 64, showStars: false),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              first.title,
                              style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color: first.color,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              status,
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 12,
                              ),
                            ),
                            const SizedBox(height: 6),
                            MedalStarRow(
                              filled: filledStars,
                              total: first.hasStars ? 5 : 0,
                              color: first.color,
                            ),
                          ],
                        ),
                      ),
                      if (isCurrentTier)
                        Text(
                          'ты тут',
                          style: TextStyle(
                            color: first.color,
                            fontWeight: FontWeight.w700,
                          ),
                        )
                      else if (!locked)
                        Icon(Icons.check_circle, color: first.color, size: 20),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _CurrentProgress extends StatelessWidget {
  const _CurrentProgress({required this.xp, required this.current});

  final int xp;
  final MedalRank current;

  @override
  Widget build(BuildContext context) {
    final toNext = XpRules.xpToNextRank(xp);
    final next = XpRules.nextRankLabel(xp);
    final caption = next == null
        ? '$xp XP · Титан'
        : '$xp XP · $toNext до $next';
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () =>
            showMedalPreview(context, rankId: current.id, caption: caption),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: current.color.withValues(alpha: 0.4)),
          ),
          child: Row(
            children: [
              RankBadge(rankId: current.id, size: 64),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      current.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: current.color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: XpRules.progressToNextRank(xp),
                        minHeight: 8,
                        backgroundColor: AppColors.background,
                        color: current.color,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      caption,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
