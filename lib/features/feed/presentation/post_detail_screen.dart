import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../auth/application/auth_controller.dart';
import '../../rank/domain/xp_rules.dart';
import '../data/feed_repository.dart';
import '../domain/feed_post.dart';

class PostDetailScreen extends StatefulWidget {
  const PostDetailScreen({
    super.key,
    required this.auth,
    required this.postId,
  });

  final AuthController auth;
  final String postId;

  @override
  State<PostDetailScreen> createState() => _PostDetailScreenState();
}

class _PostDetailScreenState extends State<PostDetailScreen> {
  final _repo = FeedRepository();
  final _commentController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _sendComment() async {
    final text = _commentController.text;
    if (text.trim().isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await _repo.addComment(
        postId: widget.postId,
        text: text,
        displayName: widget.auth.profile?.displayName ?? 'Без имени',
      );
      _commentController.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось отправить комментарий')),
      );
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('d MMM yyyy, HH:mm');
    final myUid = widget.auth.profile?.uid ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Пост')),
      body: StreamBuilder<FeedPost?>(
        stream: _repo.watchPost(widget.postId),
        builder: (context, postSnap) {
          if (!postSnap.hasData &&
              postSnap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final post = postSnap.data;
          if (post == null) {
            return const Center(child: Text('Пост не найден'));
          }

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        post.displayName,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      subtitle: Text(
                        '${post.headline} · ${dateFormat.format(post.createdAt.toLocal())}',
                      ),
                      trailing: const Icon(Icons.person_outline),
                      onTap: () => context.push('/friends/${post.userId}'),
                    ),
                    if (post.type == FeedPostType.workout) ...[
                      const SizedBox(height: 8),
                      Text(
                        post.workoutStatsLine(includeXp: false),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '+${post.xpEarned} XP'
                        '${post.rankId != null ? ' · ${XpRules.titleForRank(post.rankId!)}' : ''}',
                        style: const TextStyle(color: AppColors.amber),
                      ),
                    ],
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: FeedReaction.values.map((reaction) {
                        final selected = post.myReaction(myUid) == reaction;
                        final count = post.reactionCount(reaction);
                        return FilterChip(
                          selected: selected,
                          label: Text('${reaction.emoji} ${reaction.label}'
                              '${count > 0 ? ' · $count' : ''}'),
                          onSelected: (_) => _repo.setReaction(
                            postId: post.id,
                            reaction: reaction,
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Комментарии',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<FeedComment>>(
                      stream: _repo.watchComments(post.id),
                      builder: (context, commentSnap) {
                        final comments = commentSnap.data ?? const [];
                        if (comments.isEmpty) {
                          return const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text(
                              'Пока нет комментариев — будь первым',
                              style: TextStyle(color: AppColors.muted),
                            ),
                          );
                        }
                        return Column(
                          children: comments.map((c) {
                            return Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    c.displayName,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(c.text),
                                ],
                              ),
                            );
                          }).toList(),
                        );
                      },
                    ),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _commentController,
                          decoration: const InputDecoration(
                            hintText: 'Комментарий…',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _sendComment(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _sending ? null : _sendComment,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.amber,
                          foregroundColor: AppColors.background,
                        ),
                        icon: _sending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.send),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
