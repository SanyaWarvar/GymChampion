import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../data/notification_repository.dart';
import '../domain/app_notification.dart';

class NotificationsInboxScreen extends StatefulWidget {
  const NotificationsInboxScreen({super.key});

  @override
  State<NotificationsInboxScreen> createState() =>
      _NotificationsInboxScreenState();
}

class _NotificationsInboxScreenState extends State<NotificationsInboxScreen> {
  final _repo = NotificationRepository();

  IconData _iconFor(AppNotificationType type) => switch (type) {
        AppNotificationType.challengeProgress ||
        AppNotificationType.challengeInvite ||
        AppNotificationType.challengeResult =>
          Icons.sports_kabaddi_outlined,
        AppNotificationType.groupLead ||
        AppNotificationType.groupGoal =>
          Icons.groups_outlined,
        AppNotificationType.overtaken => Icons.trending_up,
        AppNotificationType.season => Icons.calendar_month_outlined,
      };

  Future<void> _open(AppNotification n) async {
    if (!n.read) {
      await _repo.markRead(n.id);
    }
    final link = n.deepLink;
    if (!mounted || link == null) return;
    context.push(link);
  }

  @override
  Widget build(BuildContext context) {
    final timeFmt = DateFormat('d MMM, HH:mm');
    return Scaffold(
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          TextButton(
            onPressed: () => _repo.markAllRead(),
            child: const Text('Прочитать все'),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _repo.watchMine(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Text(
                'Не удалось загрузить уведомления',
                style: TextStyle(color: AppColors.muted),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Пока пусто.\nПрогресс в вызовах и обгоны появятся здесь.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final n = items[index];
              return Material(
                color: n.read
                    ? AppColors.surface
                    : AppColors.amber.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _open(n),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          _iconFor(n.type),
                          color: n.read ? AppColors.muted : AppColors.amber,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                n.title,
                                style: TextStyle(
                                  fontWeight: n.read
                                      ? FontWeight.w600
                                      : FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                n.body,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                timeFmt.format(n.createdAt.toLocal()),
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!n.read)
                          Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.only(top: 6),
                            decoration: const BoxDecoration(
                              color: AppColors.amber,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
