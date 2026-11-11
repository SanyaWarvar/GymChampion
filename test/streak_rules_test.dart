import 'package:flutter_test/flutter_test.dart';
import 'package:gym_champion/features/rank/domain/streak_rules.dart';

void main() {
  group('StreakRules.awardFreezes', () {
    test('converts every 1000 XP into freezes without a cap', () {
      final awarded = StreakRules.awardFreezes(
        freezes: 0,
        freezeXp: 0,
        xpEarned: 3500,
      );

      expect(awarded.freezes, 3);
      expect(awarded.freezeXp, 500);
    });

    test('keeps existing freezes above the old cap of 2', () {
      final awarded = StreakRules.awardFreezes(
        freezes: 2,
        freezeXp: 2500,
      );

      expect(awarded.freezes, 4);
      expect(awarded.freezeXp, 500);
    });
  });

  group('StreakRules.applyClock', () {
    test('converts banked XP while the streak is alive', () {
      final state = StreakState(
        days: 5,
        best: 5,
        freezes: 2,
        freezeXp: 2500,
        lastDate: DateTime(2026, 11, 11),
      );

      final result = StreakRules.applyClock(state, DateTime(2026, 11, 11, 18));

      expect(result.state.freezes, 4);
      expect(result.state.freezeXp, 500);
      expect(result.state.days, 5);
    });
  });
}
