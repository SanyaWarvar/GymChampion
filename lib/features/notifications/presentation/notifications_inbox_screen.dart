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

  ({IconData icon, Color color, String label}) _meta(AppNotificationType type) {
    return switch (type) {
      AppNotificationType.challengeProgress => (
        icon: Icons.bolt_outlined,
        color: AppColors.amber,
        label: 'Вызов',
      ),
      AppNotificationType.challengeInvite => (
        icon: Icons.sports_kabaddi_outlined,
        color: const Color(0xFF7C9CFF),
        label: 'Приглашение',
      ),
      AppNotificationType.challengeResult => (
        icon: Icons.emoji_events_outlined,
        color: const Color(0xFFFFB74D),
        label: 'Итог',
      ),
      AppNotificationType.groupLead => (
        icon: Icons.military_tech_outlined,
        color: const Color(0xFF80CBC4),
        label: 'Лидер',
      ),
      AppNotificationType.groupGoal => (
        icon: Icons.groups_outlined,
        color: const Color(0xFF80CBC4),
        label: 'Общая цель',
      ),
      AppNotificationType.overtaken => (
        icon: Icons.trending_up,
        color: const Color(0xFFFF8A80),
        label: 'Рейтинг',
      ),
      AppNotificationType.season => (
        icon: Icons.calendar_month_outlined,
        color: const Color(0xFFCE93D8),
        label: 'Сезон',
      ),
      AppNotificationType.comment => (
        icon: Icons.chat_bubble_outline,
        color: AppColors.amber,
        label: 'Комментарий',
      ),
    };
  }

  Future<void> _open(AppNotification n) async {
    if (!n.read) {
      await _repo.markRead(n.id);
    }
    final link = n.deepLink;
    if (!mounted || link == null) return;
    context.push(link);
  }

  String _relativeTime(DateTime at) {
    final local = at.toLocal();
    final now = DateTime.now();
    final diff = now.difference(local);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин';
    if (diff.inHours < 24 && now.day == local.day) {
      return DateFormat('HH:mm').format(local);
    }
    if (diff.inDays < 7) {
      return DateFormat('d MMM, HH:mm').format(local);
    }
    return DateFormat('d MMM').format(local);
  }

  String _dayKey(DateTime at) {
    final local = at.toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(local.year, local.month, local.day);
    final delta = today.difference(day).inDays;
    if (delta == 0) return 'Сегодня';
    if (delta == 1) return 'Вчера';
    return DateFormat('d MMM').format(local);
  }

  List<({String header, List<AppNotification> items})> _group(
    List<AppNotification> items,
  ) {
    final map = <String, List<AppNotification>>{};
    for (final n in items) {
      map.putIfAbsent(_dayKey(n.createdAt), () => []).add(n);
    }
    return [for (final e in map.entries) (header: e.key, items: e.value)];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Уведомления'),
        actions: [
          StreamBuilder<int>(
            stream: _repo.watchUnreadCount(),
            builder: (context, snap) {
              final unread = snap.data ?? 0;
              if (unread == 0) return const SizedBox.shrink();
              return TextButton(
                onPressed: () => _repo.markAllRead(),
                child: Text(
                  'Прочитать · $unread',
                  style: const TextStyle(color: AppColors.amber),
                ),
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _repo.watchMine(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const _EmptyState(
              icon: Icons.wifi_off_rounded,
              title: 'Нет связи',
              subtitle: 'Не удалось загрузить уведомления.\nПроверь интернет.',
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snapshot.data!;
          if (items.isEmpty) {
            return const _EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Пока тихо',
              subtitle: 'Комментарии, прогресс в вызовах,\nобгоны в рейтинге и итоги сезона появятся здесь.',
            );
          }

          final groups = _group(items);
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            itemCount: groups.fold<int>(
              0,
              (sum, g) => sum + 1 + g.items.length,
            ),
            itemBuilder: (context, index) {
              var cursor = 0;
              for (final group in groups) {
                if (index == cursor) {
                  return Padding(
                    padding: EdgeInsets.only(
                      top: cursor == 0 ? 4 : 18,
                      bottom: 10,
                      left: 4,
                    ),
                    child: Text(
                      group.header,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        letterSpacing: 0.4,
                      ),
                    ),
                  );
                }
                cursor++;
                for (final n in group.items) {
                  if (index == cursor) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _NotificationTile(
                        notification: n,
                        meta: _meta(n.type),
                        timeLabel: _relativeTime(n.createdAt),
                        onTap: () => _open(n),
                      ),
                    );
                  }
                  cursor++;
                }
              }
              return const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.notification,
    required this.meta,
    required this.timeLabel,
    required this.onTap,
  });

  final AppNotification notification;
  final ({IconData icon, Color color, String label}) meta;
  final String timeLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final n = notification;
    final unread = !n.read;

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 3,
                color: unread ? meta.color : Colors.transparent,
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: meta.color.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(meta.icon, color: meta.color, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: meta.color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    meta.label,
                                    style: TextStyle(
                                      color: meta.color,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 0.2,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  timeLabel,
                                  style: const TextStyle(
                                    color: AppColors.muted,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              n.title,
                              style: TextStyle(
                                fontWeight: unread
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                fontSize: 15,
                                height: 1.25,
                              ),
                            ),
                            if (n.body.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                n.body,
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 13,
                                  height: 1.35,
                                ),
                              ),
                            ],
                            if (n.actorName.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              Text(
                                n.actorName,
                                style: TextStyle(
                                  color: AppColors.onDark.withValues(
                                    alpha: 0.55,
                                  ),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 34, color: AppColors.muted),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}
