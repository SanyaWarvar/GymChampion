import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../data/quest_repository.dart';
import '../domain/quest_def.dart';
import '../domain/quest_progress.dart';
import 'quest_icon.dart';

class QuestsScreen extends StatelessWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final repo = QuestRepository();

    return Scaffold(
      appBar: AppBar(title: const Text('Задания')),
      body: StreamBuilder<List<QuestBoard>>(
        stream: repo.watchActiveBoards(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Не удалось загрузить задания',
                style: TextStyle(color: AppColors.muted),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final boards = snapshot.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                'Выполняй на тренировках — получишь бонус XP',
                style: TextStyle(color: AppColors.muted),
              ),
              const SizedBox(height: 12),
              ...boards.map((board) {
                final title = board.period == QuestPeriod.daily
                    ? 'Сегодня'
                    : 'Эта неделя';
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 8, bottom: 8),
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          color: AppColors.muted,
                        ),
                      ),
                    ),
                    ...board.items.map((item) {
                      final def = QuestCatalog.byId(item.questId);
                      if (def == null) return const SizedBox.shrink();
                      return _QuestTile(def: def, progress: item);
                    }),
                  ],
                );
              }),
            ],
          );
        },
      ),
    );
  }
}

class _QuestTile extends StatelessWidget {
  const _QuestTile({required this.def, required this.progress});

  final QuestDef def;
  final QuestProgress progress;

  @override
  Widget build(BuildContext context) {
    final done = progress.completed;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: done
            ? AppColors.amber.withValues(alpha: 0.12)
            : AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: done
            ? Border.all(color: AppColors.amber.withValues(alpha: 0.4))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              QuestIcon(quest: def, size: 40, radius: 10),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  def.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: done ? AppColors.onDark : AppColors.muted,
                  ),
                ),
              ),
              Text(
                '+${def.xpReward} XP',
                style: const TextStyle(
                  color: AppColors.amber,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            def.description,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.ratio,
              minHeight: 6,
              backgroundColor: AppColors.background,
              color: AppColors.amber,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${progress.current.round()} / ${progress.target.round()}'
            '${done ? ' · готово' : ''}',
            style: const TextStyle(color: AppColors.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
