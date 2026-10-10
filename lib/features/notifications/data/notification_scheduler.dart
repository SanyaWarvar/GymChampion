import '../../auth/domain/app_user.dart';
import '../../challenges/data/challenge_repository.dart';
import '../../challenges/domain/challenge.dart';
import '../../rank/domain/streak_rules.dart';
import '../../workout/data/workout_repository.dart';
import 'local_notification_service.dart';

abstract final class NotificationScheduler {
  static Future<void> syncForProfile(AppUser? profile) async {
    if (profile == null) return;
    var challenges = const <Challenge>[];
    var workedOutToday = false;
    try {
      challenges = await ChallengeRepository().watchMyChallenges().first;
    } catch (_) {}
    try {
      final workouts = await WorkoutRepository().fetchMyWorkouts(limit: 8);
      final today = StreakRules.dateOnly(DateTime.now());
      workedOutToday = workouts.any(
        (w) => StreakRules.dateOnly(w.finishedAt) == today,
      );
    } catch (_) {}

    await LocalNotificationService.instance.syncFromProfile(
      profile: profile,
      activeChallenges: challenges
          .where((c) => c.status == ChallengeStatus.active)
          .toList(),
      workedOutToday: workedOutToday,
    );
  }
}
