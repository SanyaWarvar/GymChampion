import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../data/quest_repository.dart';
import '../domain/quest_def.dart';
import '../domain/quest_progress.dart';
import 'quest_icon.dart';

/// Мини-блок заданий на Workout Hub.
class QuestHubSection extends StatelessWidget {
  const QuestHubSection({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = QuestRepository();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Задания',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/quests'),
              child: const Text('Все'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        FutureBuilder<List<QuestBoard>>(
          future: repo.fetchActiveBoards(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            final boards = snapshot.data!;
            final items = <(QuestDef, QuestProgress)>[];
            for (final board in boards) {
              for (final p in board.items) {
                final def = QuestCatalog.byId(p.questId);
                if (def == null) continue;
                items.add((def, p));
              }
            }
            // Показываем до 2 незакрытых, иначе первые 2.
            final open = items.where((e) => !e.$2.completed).take(2).toList();
            final show = open.isNotEmpty ? open : items.take(2).toList();

            return Column(
              children: show.map((pair) {
                final def = pair.$1;
                final p = pair.$2;
                return Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      QuestIcon(quest: def, size: 36, radius: 8),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              def.title,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: p.ratio,
                                minHeight: 5,
                                backgroundColor: AppColors.background,
                                color: AppColors.amber,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        '${p.current.round()}/${p.target.round()}',
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}
