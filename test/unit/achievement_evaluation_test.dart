import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/achievement.dart';
import 'package:todo_app/models/user.dart';

/// Helper to build a [User] with only the fields relevant to achievement tests.
/// All counters default to 0 unless specified.
User _makeUser({
  int totalXP = 0,
  int tasksCompleted = 0,
  int groupTasksCompleted = 0,
  int memberGroupTasksCompleted = 0,
  int leaderGroupTasksCompleted = 0,
  int currentStreak = 0,
  List<String> achievementsUnlocked = const [],
}) {
  return User(
    id: 'test-user-id',
    name: 'Test User',
    email: 'test@example.com',
    avatarUrl: '',
    joinedAt: DateTime(2025, 1, 1),
    totalXP: totalXP,
    tasksCompleted: tasksCompleted,
    groupTasksCompleted: groupTasksCompleted,
    memberGroupTasksCompleted: memberGroupTasksCompleted,
    leaderGroupTasksCompleted: leaderGroupTasksCompleted,
        currentLevel: 1,
    currentStreak: currentStreak,
    achievementsUnlocked: achievementsUnlocked,
  );
}

/// Convenience lookup – returns the [Achievement] with the given [id] from the
/// global [availableAchievements] list.
Achievement _findAchievement(String id) {
  return availableAchievements.firstWhere((a) => a.id == id);
}

void main() {
  // ---------------------------------------------------------------------------
  // 1. achievementProgressUnit returns correct Thai units
  // ---------------------------------------------------------------------------
  group('achievementProgressUnit', () {
    test('returns "ภารกิจ" for personal_tasks type', () {
      final achievement = _findAchievement('pathfinder');
      expect(achievementProgressUnit(achievement), 'ภารกิจ');
    });

    test('returns "ภารกิจ" for task_master (personal_tasks)', () {
      final achievement = _findAchievement('task_master');
      expect(achievementProgressUnit(achievement), 'ภารกิจ');
    });

    test('returns "วัน" for streak type', () {
      final achievement = _findAchievement('spark');
      expect(achievementProgressUnit(achievement), 'วัน');
    });

    test('returns "วัน" for on_fire (streak)', () {
      final achievement = _findAchievement('on_fire');
      expect(achievementProgressUnit(achievement), 'วัน');
    });

    test('returns "ภารกิจ" for member_group_tasks type', () {
      final achievement = _findAchievement('team_player');
      expect(achievementProgressUnit(achievement), 'ภารกิจ');
    });

    test('returns "ภารกิจ" for leader_group_tasks type', () {
      final achievement = _findAchievement('squad_captain');
      expect(achievementProgressUnit(achievement), 'ภารกิจ');
    });

    test('returns "Level" for level type', () {
      final achievement = _findAchievement('max_level');
      expect(achievementProgressUnit(achievement), 'Level');
    });
  });

  // ---------------------------------------------------------------------------
  // 2. achievementProgressValue for each achievement type
  // ---------------------------------------------------------------------------
  group('achievementProgressValue', () {
    test('personal_tasks type uses tasksCompleted', () {
      final user = _makeUser(tasksCompleted: 42);
      final achievement = _findAchievement('pathfinder');
      expect(achievementProgressValue(user, achievement), 42);
    });

    test('streak type uses currentStreak', () {
      final user = _makeUser(currentStreak: 15);
      final achievement = _findAchievement('spark');
      expect(achievementProgressValue(user, achievement), 15);
    });

    test('member_group_tasks type uses memberGroupTasksCompleted', () {
      final user = _makeUser(memberGroupTasksCompleted: 8);
      final achievement = _findAchievement('team_player');
      expect(achievementProgressValue(user, achievement), 8);
    });

    test('leader_group_tasks type uses leaderGroupTasksCompleted', () {
      final user = _makeUser(leaderGroupTasksCompleted: 20);
      final achievement = _findAchievement('squad_captain');
      expect(achievementProgressValue(user,
        achievement), 20);
    });

    test('level type uses currentLevel (derived from totalXP)', () {
      // currentLevel = (totalXP ~/ 500) + 1
      // totalXP = 12000 → level = (12000 ~/ 500) + 1 = 25
      final user = _makeUser(totalXP: 12000);
      final achievement = _findAchievement('max_level');
      expect(achievementProgressValue(user, achievement), 25);
    });

    test('level type returns 1 for zero XP', () {
      final user = _makeUser(totalXP: 0);
      final achievement = _findAchievement('max_level');
      // (0 ~/ 500) + 1 = 1
      expect(achievementProgressValue(user, achievement), 1);
    });

    test('level type calculates correctly for boundary XP values', () {
      // 499 XP → level 1, 500 XP → level 2
      final userBelowBoundary = _makeUser(totalXP: 499);
      final userAtBoundary = _makeUser(totalXP: 500);
      final achievement = _findAchievement('max_level');
      expect(achievementProgressValue(userBelowBoundary, achievement), 1);
      expect(achievementProgressValue(userAtBoundary, achievement), 2);
    });
  });

  // ---------------------------------------------------------------------------
  // 3. isAchievementUnlocked returns true when progress >= target
  // ---------------------------------------------------------------------------
  group('isAchievementUnlocked – progress meets target', () {
    test('returns true when tasksCompleted equals targetValue', () {
      final user = _makeUser(tasksCompleted: 10);
      expect(isAchievementUnlocked(user, _findAchievement('pathfinder')), true);
    });

    test('returns true when tasksCompleted exceeds targetValue', () {
      final user = _makeUser(tasksCompleted: 55);
      expect(isAchievementUnlocked(user, _findAchievement('task_master')), true);
    });

    test('returns false when tasksCompleted is below targetValue', () {
      final user = _makeUser(tasksCompleted: 9);
      expect(
          isAchievementUnlocked(user, _findAchievement('pathfinder')), false);
    });

    test('returns true when streak meets target', () {
      final user = _makeUser(currentStreak: 30);
      expect(
          isAchievementUnlocked(user, _findAchievement('unstoppable')), true);
    });

    test('returns false when streak is below target', () {
      final user = _makeUser(currentStreak: 6);
      expect(isAchievementUnlocked(user, _findAchievement('on_fire')), false);
    });

    test('returns true when memberGroupTasksCompleted meets target', () {
      final user = _makeUser(memberGroupTasksCompleted: 5);
      expect(
          isAchievementUnlocked(user, _findAchievement('team_player')), true);
    });

    test('returns true when leaderGroupTasksCompleted meets target', () {
      final user = _makeUser(leaderGroupTasksCompleted: 20);
      expect(
          isAchievementUnlocked(user,
        _findAchievement('squad_captain')), true);
    });

    test('returns true when level meets target (level 25)', () {
      // level 25 requires totalXP = 24 * 500 = 12000
      final user = _makeUser(totalXP: 12000);
      expect(
          isAchievementUnlocked(user, _findAchievement('max_level')), true);
    });

    test('returns false when level is below target', () {
      // level 24 → totalXP = 23 * 500 = 11500
      final user = _makeUser(totalXP: 11500);
      expect(
          isAchievementUnlocked(user, _findAchievement('max_level')), false);
    });
  });

  // ---------------------------------------------------------------------------
  // 4. isAchievementUnlocked returns true when achievement id is already
  //    in achievementsUnlocked, even if progress is below target
  // ---------------------------------------------------------------------------
  group('isAchievementUnlocked – pre-recorded unlock', () {
    test('returns true when id is in achievementsUnlocked despite 0 progress',
        () {
      final user = _makeUser(
        tasksCompleted: 0,
        achievementsUnlocked: ['pathfinder'],
      );
      expect(isAchievementUnlocked(user, _findAchievement('pathfinder')), true);
    });

    test(
        'returns true for streak achievement pre-recorded even with 0 streak',
        () {
      final user = _makeUser(
        currentStreak: 0,
        achievementsUnlocked: ['unstoppable'],
      );
      expect(
          isAchievementUnlocked(user, _findAchievement('unstoppable')), true);
    });

    test('returns false when id is NOT in achievementsUnlocked and progress < target',
        () {
      final user = _makeUser(
        tasksCompleted: 5,
        achievementsUnlocked: ['spark'], // unrelated achievement
      );
      expect(
          isAchievementUnlocked(user, _findAchievement('pathfinder')), false);
    });
  });

  // ---------------------------------------------------------------------------
  // 5. evaluateAchievements counts correctly
  // ---------------------------------------------------------------------------
  group('evaluateAchievements', () {
    test('returns all 9 available achievements', () {
      final user = _makeUser();
      final evaluation = evaluateAchievements(user);
      expect(evaluation.all.length, availableAchievements.length);
      expect(evaluation.totalCount, 9);
    });

    test('zero-progress user has 0 unlocked achievements', () {
      final user = _makeUser();
      final evaluation = evaluateAchievements(user);
      expect(evaluation.unlockedCount, 0);
      expect(evaluation.locked.length, 9);
    });

    test('user meeting some targets has correct unlocked count', () {
      // pathfinder (10 tasks) ✓, spark (3 streak) ✓, team_player (5 member) ✓
      final user = _makeUser(
        tasksCompleted: 10,
        currentStreak: 3,
        memberGroupTasksCompleted: 5,
      );
      final evaluation = evaluateAchievements(user);
      expect(evaluation.unlockedCount, 3);
      expect(evaluation.locked.length, 6);
    });

    test('displayRatio formats correctly', () {
      final user = _makeUser(tasksCompleted: 10, currentStreak: 3);
      final evaluation = evaluateAchievements(user);
      // 2 unlocked: pathfinder + spark
      expect(evaluation.displayRatio, '2/9');
    });

    test('user meeting all targets has 9 unlocked', () {
      final user = _makeUser(
        tasksCompleted: 100,
        currentStreak: 30,
        memberGroupTasksCompleted: 5,
        leaderGroupTasksCompleted: 20,
        totalXP: 12000, // level 25
      );
      final evaluation = evaluateAchievements(user);
      expect(evaluation.unlockedCount, 9);
      expect(evaluation.locked.length, 0);
      expect(evaluation.displayRatio, '9/9');
    });

    test('EvaluatedAchievement has correct progressCount and targetCount', () {
      final user = _makeUser(tasksCompleted: 7);
      final evaluation = evaluateAchievements(user);
      final pathfinderEval =
          evaluation.all.firstWhere((e) => e.achievement.id == 'pathfinder');
      expect(pathfinderEval.progressCount, 7);
      expect(pathfinderEval.targetCount, 10);
      expect(pathfinderEval.isUnlocked, false);
    });
  });

  // ---------------------------------------------------------------------------
  // 6. mergedUnlockedAchievementIds adds newly earned achievement ids
  // ---------------------------------------------------------------------------
  group('mergedUnlockedAchievementIds – new unlocks', () {
    test('adds pathfinder when tasksCompleted reaches 10', () {
      final result = mergedUnlockedAchievementIds(
        existingIds: [],
        tasksCompleted: 10,
        currentStreak: 0,
        groupTasksCompleted: 0,
        memberGroupTasksCompleted: 0,
        leaderGroupTasksCompleted: 0,
        currentLevel: 1,
      );
      expect(result, contains('pathfinder'));
    });

    test('adds all three streak achievements when streak is 30', () {
      final result = mergedUnlockedAchievementIds(
        existingIds: [],
        tasksCompleted: 0,
        currentStreak: 30,
        groupTasksCompleted: 0,
        memberGroupTasksCompleted: 0,
        leaderGroupTasksCompleted: 0,
        currentLevel: 1,
      );
      expect(result, containsAll(['spark', 'on_fire', 'unstoppable']));
    });

    test('adds team_player when memberGroupTasksCompleted reaches 5', () {
      final result = mergedUnlockedAchievementIds(
        existingIds: [],
        tasksCompleted: 0,
        currentStreak: 0,
        groupTasksCompleted: 0,
        memberGroupTasksCompleted: 5,
        leaderGroupTasksCompleted: 0,
        currentLevel: 1,
      );
      expect(result, contains('team_player'));
    });

    test('adds squad_captain when leaderGroupTasksCompleted reaches 20', () {
      final result = mergedUnlockedAchievementIds(
        existingIds: [],
        tasksCompleted: 0,
        currentStreak: 0,
        groupTasksCompleted: 0,
        memberGroupTasksCompleted: 0,
        leaderGroupTasksCompleted: 20,
        currentLevel: 1,
      );
      expect(result, contains('squad_captain'));
    });

    test('does NOT include level-based achievements (handled differently)', () {
      // mergedUnlockedAchievementIds doesn't receive level/totalXP,
      // so level type achievements should NOT be unlocked via this function
      // unless the _progressValueForCounts default-case returns >= target.
      final result = mergedUnlockedAchievementIds(
        existingIds: [],
        tasksCompleted: 0,
        currentStreak: 0,
        groupTasksCompleted: 0,
        memberGroupTasksCompleted: 0,
        leaderGroupTasksCompleted: 0,
        currentLevel: 1,
      );
      expect(result, isNot(contains('max_level')));
    });
  });

  // ---------------------------------------------------------------------------
  // 7. mergedUnlockedAchievementIds preserves existing ids
  // ---------------------------------------------------------------------------
  group('mergedUnlockedAchievementIds – preserves existing', () {
    test('keeps existing ids even when current counts are 0', () {
      final result = mergedUnlockedAchievementIds(
        existingIds: ['pathfinder', 'spark'],
        tasksCompleted: 0,
        currentStreak: 0,
        groupTasksCompleted: 0,
        memberGroupTasksCompleted: 0,
        leaderGroupTasksCompleted: 0,
        currentLevel: 1,
      );
      expect(result, containsAll(['pathfinder', 'spark']));
    });

    test('preserves custom/external ids not in availableAchievements', () {
      final result = mergedUnlockedAchievementIds(
        existingIds: ['custom_badge_xyz'],
        tasksCompleted: 0,
        currentStreak: 0,
        groupTasksCompleted: 0,
        memberGroupTasksCompleted: 0,
        leaderGroupTasksCompleted: 0,
        currentLevel: 1,
      );
      expect(result, contains('custom_badge_xyz'));
    });

    test('does not duplicate already-existing ids', () {
      final result = mergedUnlockedAchievementIds(
        existingIds: ['pathfinder'],
        tasksCompleted: 50, // would also earn pathfinder + task_master
        currentStreak: 0,
        groupTasksCompleted: 0,
        memberGroupTasksCompleted: 0,
        leaderGroupTasksCompleted: 0,
        currentLevel: 1,
      );
      final pathfinderCount =
          result.where((id) => id == 'pathfinder').length;
      expect(pathfinderCount, 1);
      expect(result, contains('task_master'));
    });
  });

  // ---------------------------------------------------------------------------
  // 8. A user with 0 of everything has no achievements unlocked
  // ---------------------------------------------------------------------------
  group('Zero-progress user', () {
    test('has no achievements unlocked via isAchievementUnlocked', () {
      final user = _makeUser();
      for (final achievement in availableAchievements) {
        expect(
          isAchievementUnlocked(user, achievement),
          false,
          reason: '${achievement.id} should NOT be unlocked for a zero-progress user',
        );
      }
    });

    test('evaluateAchievements reports 0 unlocked', () {
      final user = _makeUser();
      final evaluation = evaluateAchievements(user);
      expect(evaluation.unlockedCount, 0);
      expect(evaluation.displayRatio, '0/9');
    });

    test('mergedUnlockedAchievementIds returns empty list for 0 counts', () {
      final result = mergedUnlockedAchievementIds(
        existingIds: [],
        tasksCompleted: 0,
        currentStreak: 0,
        groupTasksCompleted: 0,
        memberGroupTasksCompleted: 0,
        leaderGroupTasksCompleted: 0,
        currentLevel: 1,
      );
      expect(result, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // 9. A user with tasksCompleted = 10 unlocks 'pathfinder' but not
  //    'task_master'
  // ---------------------------------------------------------------------------
  group('Partial personal_tasks unlock', () {
    test('tasksCompleted=10 unlocks pathfinder', () {
      final user = _makeUser(tasksCompleted: 10);
      expect(isAchievementUnlocked(user, _findAchievement('pathfinder')), true);
    });

    test('tasksCompleted=10 does NOT unlock task_master', () {
      final user = _makeUser(tasksCompleted: 10);
      expect(
          isAchievementUnlocked(user, _findAchievement('task_master')), false);
    });

    test('tasksCompleted=10 does NOT unlock legendary_worker', () {
      final user = _makeUser(tasksCompleted: 10);
      expect(
          isAchievementUnlocked(user, _findAchievement('legendary_worker')),
          false);
    });

    test('evaluateAchievements confirms only pathfinder unlocked for tasks', () {
      final user = _makeUser(tasksCompleted: 10);
      final evaluation = evaluateAchievements(user);
      final unlockedIds =
          evaluation.unlocked.map((e) => e.achievement.id).toList();
      expect(unlockedIds, contains('pathfinder'));
      expect(unlockedIds, isNot(contains('task_master')));
      expect(unlockedIds, isNot(contains('legendary_worker')));
    });
  });

  // ---------------------------------------------------------------------------
  // 10. A user with streak = 30 unlocks all streak achievements
  // ---------------------------------------------------------------------------
  group('Full streak unlock', () {
    test('streak=30 unlocks spark (target 3)', () {
      final user = _makeUser(currentStreak: 30);
      expect(isAchievementUnlocked(user, _findAchievement('spark')), true);
    });

    test('streak=30 unlocks on_fire (target 7)', () {
      final user = _makeUser(currentStreak: 30);
      expect(isAchievementUnlocked(user, _findAchievement('on_fire')), true);
    });

    test('streak=30 unlocks unstoppable (target 30)', () {
      final user = _makeUser(currentStreak: 30);
      expect(
          isAchievementUnlocked(user, _findAchievement('unstoppable')), true);
    });

    test('evaluateAchievements lists all 3 streak achievements as unlocked',
        () {
      final user = _makeUser(currentStreak: 30);
      final evaluation = evaluateAchievements(user);
      final unlockedIds =
          evaluation.unlocked.map((e) => e.achievement.id).toSet();
      expect(unlockedIds, containsAll(['spark', 'on_fire', 'unstoppable']));
    });

    test('streak=6 unlocks only spark, not on_fire or unstoppable', () {
      final user = _makeUser(currentStreak: 6);
      expect(isAchievementUnlocked(user, _findAchievement('spark')), true);
      expect(isAchievementUnlocked(user, _findAchievement('on_fire')), false);
      expect(
          isAchievementUnlocked(user, _findAchievement('unstoppable')), false);
    });

    test('streak=7 unlocks spark and on_fire, not unstoppable', () {
      final user = _makeUser(currentStreak: 7);
      expect(isAchievementUnlocked(user, _findAchievement('spark')), true);
      expect(isAchievementUnlocked(user, _findAchievement('on_fire')), true);
      expect(
          isAchievementUnlocked(user, _findAchievement('unstoppable')), false);
    });
  });
}
