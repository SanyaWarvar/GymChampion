import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../../notifications/data/notification_repository.dart';
import '../../rank/domain/xp_rules.dart';
import '../../rank/presentation/rank_badge.dart';
import '../data/feed_repository.dart';
import '../domain/feed_post.dart';
import 'feed_exercise_list.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key, required this.auth});

  final AuthController auth;

  @override
  Widget build(BuildContext context) {
    final repo = FeedRepository();
    final notifs = NotificationRepository();
    final dateFormat = DateFormat('d MMM, HH:mm');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Лента'),
        actions: [
          StreamBuilder<int>(
            stream: notifs.watchUnreadCount(),
            builder: (context, snapshot) {
              final count = snapshot.data ?? 0;
              return IconButton(
                tooltip: 'Уведомления',
                onPressed: () => context.push('/notifications'),
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text(count > 9 ? '9+' : '$count'),
                  child: const Icon(Icons.notifications_outlined),
                ),
              );
            },
          ),
          IconButton(
            tooltip: 'Вызовы',
            onPressed: () => context.push('/challenges'),
            icon: const Icon(Icons.sports_kabaddi_outlined),
          ),
        ],
      ),
      body: StreamBuilder<List<FeedPost>>(
        stream: repo.watchFeed(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Не удалось загрузить ленту.\nПроверь интернет.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final posts = snapshot.data!;
          if (posts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Text(
                  'Пока тихо.\nЗаверши тренировку — пост появится здесь.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.muted),
                ),
              ),
            );
          }

          final myUid = auth.profile?.uid ?? '';
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: posts.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final post = posts[index];
              return _FeedCard(
                post: post,
                myUid: myUid,
                dateLabel: dateFormat.format(post.createdAt.toLocal()),
                onOpen: () => context.push('/feed/${post.id}'),
                onUser: () => context.push('/friends/${post.userId}'),
                onReact: (reaction) =>
                    repo.setReaction(postId: post.id, reaction: reaction),
              );
            },
          );
        },
      ),
    );
  }
}

class _FeedCard extends StatelessWidget {
  const _FeedCard({
    required this.post,
    required this.myUid,
    required this.dateLabel,
    required this.onOpen,
    required this.onUser,
    required this.onReact,
  });

  final FeedPost post;
  final String myUid;
  final String dateLabel;
  final VoidCallback onOpen;
  final VoidCallback onUser;
  final ValueChanged<FeedReaction> onReact;

  @override
  Widget build(BuildContext context) {
    final myReaction = post.myReaction(myUid);

    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (post.rankId != null) ...[
                    RankBadge(rankId: post.rankId!, size: 34),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: GestureDetector(
                      onTap: onUser,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.displayName,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            '${post.headline} · $dateLabel',
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: AppColors.muted),
                ],
              ),
              if (post.type == FeedPostType.workout) ...[
                const SizedBox(height: 12),
                Text(
                  post.workoutStatsLine(),
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (post.rankId != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    XpRules.shortTitleForRank(post.rankId!),
                    style: TextStyle(
                      color: XpRules.colorForRank(post.rankId!),
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                WorkoutPostExercises(
                  post: post,
                  viewerId: myUid,
                  compact: true,
                ),
              ],
              if (post.type == FeedPostType.stepsDay) ...[
                const SizedBox(height: 12),
                Text(
                  '${post.steps} шагов · +${post.xpEarned} XP',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  for (final reaction in FeedReaction.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: _ReactionChip(
                        reaction: reaction,
                        count: post.reactionCount(reaction),
                        selected: myReaction == reaction,
                        onTap: () => onReact(reaction),
                      ),
                    ),
                  const Spacer(),
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 16,
                    color: AppColors.muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${post.commentCount}',
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReactionChip extends StatelessWidget {
  const _ReactionChip({
    required this.reaction,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final FeedReaction reaction;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: selected
              ? AppColors.amber.withValues(alpha: 0.18)
              : AppColors.background,
          borderRadius: BorderRadius.circular(20),
          border: selected
              ? Border.all(color: AppColors.amber.withValues(alpha: 0.5))
              : null,
        ),
        child: Text(
          '${reaction.emoji}${count > 0 ? ' $count' : ''}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
