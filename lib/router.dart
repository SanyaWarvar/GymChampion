import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/achievements/presentation/achievements_screen.dart';
import 'features/auth/application/auth_controller.dart';
import 'features/auth/domain/app_user.dart';
import 'features/auth/presentation/display_name_screen.dart';
import 'features/auth/presentation/login_screen.dart';
import 'features/auth/presentation/register_screen.dart';
import 'features/auth/presentation/splash_screen.dart';
import 'features/challenges/presentation/challenge_create_screen.dart';
import 'features/challenges/presentation/challenge_detail_screen.dart';
import 'features/challenges/presentation/challenge_list_screen.dart';
import 'features/challenges/presentation/group_challenge_create_screen.dart';
import 'features/challenges/presentation/group_challenge_detail_screen.dart';
import 'features/feed/presentation/feed_screen.dart';
import 'features/feed/presentation/post_detail_screen.dart';
import 'features/profile/presentation/appearance_screen.dart';
import 'features/profile/presentation/edit_profile_screen.dart';
import 'features/profile/presentation/friend_peek_screen.dart';
import 'features/notifications/presentation/notifications_inbox_screen.dart';
import 'features/profile/presentation/notifications_settings_screen.dart';
import 'features/profile/presentation/privacy_settings_screen.dart';
import 'features/profile/presentation/profile_screen.dart';
import 'features/quests/presentation/quests_screen.dart';
import 'features/rank/domain/rank_check_rules.dart';
import 'features/rank/presentation/leaderboard_screen.dart';
import 'features/rank/presentation/rank_check_result_screen.dart';
import 'features/rank/presentation/rank_check_screen.dart';
import 'features/rank/presentation/rank_ladder_screen.dart';
import 'features/rank/presentation/season_info_screen.dart';
import 'features/shell/presentation/main_shell.dart';
import 'features/stats/presentation/exercise_progress_screen.dart';
import 'features/stats/presentation/stats_screen.dart';
import 'features/workout/data/local_workout_store.dart';
import 'features/workout/domain/saved_workout.dart';
import 'features/workout/domain/workout_template.dart';
import 'features/workout/presentation/active_workout_screen.dart';
import 'features/workout/presentation/template_editor_screen.dart';
import 'features/workout/presentation/template_list_screen.dart';
import 'features/workout/presentation/workout_detail_screen.dart';
import 'features/workout/presentation/workout_history_screen.dart';
import 'features/workout/presentation/workout_hub_screen.dart';
import 'features/workout/presentation/workout_summary_screen.dart';

/// Корневой navigator — для bottom sheet / overlay извне роутов (таймер отдыха).
final GlobalKey<NavigatorState> rootNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'root');

GoRouter createRouter(AuthController auth) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/splash',
    refreshListenable: auth,
    redirect: (context, state) {
      final loc = state.matchedLocation;
      final status = auth.status;

      if (status == AuthStatus.loading) {
        return loc == '/splash' ? null : '/splash';
      }

      final loggingIn = loc == '/login' || loc == '/register';
      final naming = loc == '/display-name';

      switch (status) {
        case AuthStatus.unauthenticated:
          return loggingIn ? null : '/login';
        case AuthStatus.needsDisplayName:
          return naming ? null : '/display-name';
        case AuthStatus.authenticated:
          if (loggingIn || naming || loc == '/splash') {
            return '/workout';
          }
          return null;
        case AuthStatus.loading:
          return '/splash';
      }
    },
    routes: [
      GoRoute(
        path: '/splash',
        builder: (context, state) => const SplashScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(auth: auth),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => RegisterScreen(auth: auth),
      ),
      GoRoute(
        path: '/display-name',
        builder: (context, state) => DisplayNameScreen(auth: auth),
      ),
      GoRoute(
        path: '/rank/ladder',
        builder: (context, state) => RankLadderScreen(auth: auth),
      ),
      GoRoute(
        path: '/rank/season',
        builder: (context, state) => SeasonInfoScreen(auth: auth),
      ),
      GoRoute(
        path: '/rank/check',
        builder: (context, state) => RankCheckScreen(auth: auth),
        routes: [
          GoRoute(
            path: 'result',
            builder: (context, state) {
              final result = state.extra as RankCheckResult?;
              if (result == null) {
                return RankCheckScreen(auth: auth);
              }
              return RankCheckResultScreen(result: result);
            },
          ),
        ],
      ),
      GoRoute(
        path: '/achievements',
        builder: (context, state) => const AchievementsScreen(),
      ),
      GoRoute(
        path: '/quests',
        builder: (context, state) => const QuestsScreen(),
      ),
      GoRoute(
        path: '/stats',
        builder: (context, state) => const StatsScreen(),
        routes: [
          GoRoute(
            path: 'exercise/:exerciseKey',
            builder: (context, state) {
              final key = Uri.decodeComponent(
                state.pathParameters['exerciseKey']!,
              );
              final name = state.extra as String?;
              return ExerciseProgressScreen(
                exerciseKey: key,
                exerciseName: name,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/profile/edit',
        builder: (context, state) => EditProfileScreen(auth: auth),
      ),
      GoRoute(
        path: '/profile/appearance',
        builder: (context, state) => const AppearanceScreen(),
      ),
      GoRoute(
        path: '/profile/privacy',
        builder: (context, state) => PrivacySettingsScreen(auth: auth),
      ),
      GoRoute(
        path: '/profile/notifications',
        builder: (context, state) => NotificationsSettingsScreen(auth: auth),
      ),
      GoRoute(
        path: '/notifications',
        builder: (context, state) => const NotificationsInboxScreen(),
      ),
      GoRoute(
        path: '/friends/:userId',
        builder: (context, state) => FriendPeekScreen(
          userId: state.pathParameters['userId']!,
        ),
      ),
      GoRoute(
        path: '/challenges',
        builder: (context, state) => ChallengeListScreen(auth: auth),
        routes: [
          GoRoute(
            path: 'create',
            builder: (context, state) => ChallengeCreateScreen(
              auth: auth,
              preselected: state.extra as AppUser?,
            ),
          ),
          GoRoute(
            path: 'group/create',
            builder: (context, state) => GroupChallengeCreateScreen(auth: auth),
          ),
          GoRoute(
            path: 'group/:challengeId',
            builder: (context, state) => GroupChallengeDetailScreen(
              auth: auth,
              challengeId: state.pathParameters['challengeId']!,
            ),
          ),
          GoRoute(
            path: ':challengeId',
            builder: (context, state) => ChallengeDetailScreen(
              auth: auth,
              challengeId: state.pathParameters['challengeId']!,
            ),
          ),
        ],
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/workout',
                builder: (context, state) => const WorkoutHubScreen(),
                routes: [
                  GoRoute(
                    path: 'active',
                    builder: (context, state) {
                      final extra = state.extra;
                      if (extra is LocalWorkoutDraft) {
                        return ActiveWorkoutScreen(restore: extra);
                      }
                      final template = extra as WorkoutTemplate?;
                      return ActiveWorkoutScreen(template: template);
                    },
                  ),
                  GoRoute(
                    path: 'summary',
                    builder: (context, state) {
                      final draft = state.extra as WorkoutDraft?;
                      if (draft == null) {
                        return const WorkoutHubScreen();
                      }
                      return WorkoutSummaryScreen(draft: draft);
                    },
                  ),
                  GoRoute(
                    path: 'history',
                    builder: (context, state) => const WorkoutHistoryScreen(),
                    routes: [
                      GoRoute(
                        path: ':workoutId',
                        builder: (context, state) => WorkoutDetailScreen(
                          workoutId: state.pathParameters['workoutId']!,
                        ),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'templates',
                    builder: (context, state) => const TemplateListScreen(),
                    routes: [
                      GoRoute(
                        path: 'edit',
                        builder: (context, state) {
                          final initial = state.extra as WorkoutTemplate?;
                          return TemplateEditorScreen(initial: initial);
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/feed',
                builder: (context, state) => FeedScreen(auth: auth),
                routes: [
                  GoRoute(
                    path: ':postId',
                    builder: (context, state) => PostDetailScreen(
                      auth: auth,
                      postId: state.pathParameters['postId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/rank',
                builder: (context, state) => LeaderboardScreen(auth: auth),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (context, state) => ProfileScreen(auth: auth),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
