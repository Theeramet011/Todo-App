import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/achievement.dart';
import 'package:todo_app/models/user.dart';
import 'package:todo_app/screens/achievement_list_screen.dart';
import 'package:todo_app/widgets/achievement_summary_card.dart';

void main() {
  test('achievement system reads unlocked ids and progress from user data', () {
    final user = User(
      id: 'user-1',
      name: 'Test User',
      email: 'test@example.com',
      avatarUrl: '',
      tasksCompleted: 12,
      groupTasksCompleted: 3,
      memberGroupTasksCompleted: 3,
      currentStreak: 4,
      joinedAt: DateTime(2026),
      achievementsUnlocked: const ['pathfinder', 'spark'],
    );

    final pathfinder = availableAchievements.firstWhere(
      (achievement) => achievement.id == 'pathfinder',
    );
    final spark = availableAchievements.firstWhere(
      (achievement) => achievement.id == 'spark',
    );
    final teamPlayer = availableAchievements.firstWhere(
      (achievement) => achievement.id == 'team_player',
    );

    expect(availableAchievements, isNotEmpty);
    expect(isAchievementUnlocked(user, pathfinder), isTrue);
    expect(isAchievementUnlocked(user, spark), isTrue);
    expect(isAchievementUnlocked(user, teamPlayer), isFalse);
    expect(achievementProgressValue(user, pathfinder), 12);
    expect(achievementProgressValue(user, spark), 4);
    expect(achievementProgressValue(user, teamPlayer), 3);
    expect(unlockedAchievementCount(user), 2);
  });

  test('achievement screens are constructible with a user object', () {
    final user = User(
      id: 'user-1',
      name: 'Test User',
      email: 'test@example.com',
      avatarUrl: '',
      joinedAt: DateTime(2026),
    );

    expect(AchievementListScreen(user: user), isA<AchievementListScreen>());
    expect(AchievementSummaryCard(user: user), isA<AchievementSummaryCard>());
  });

  test(
    'achievement engine unlocks three badges for 28 tasks and 7 day streak',
    () {
      final user = User(
        id: 'user-1',
        name: 'Test User',
        email: 'test@example.com',
        avatarUrl: '',
        tasksCompleted: 28,
        currentStreak: 7,
        groupTasksCompleted: 0,
        joinedAt: DateTime(2026),
      );

      final evaluation = evaluateAchievements(user);

      expect(evaluation.displayRatio, '3/8');
      expect(
        evaluation.unlocked.map((item) => item.achievement.id),
        containsAll(['pathfinder', 'spark', 'on_fire']),
      );
    },
  );

  test('achievement engine unlocks every badge at its threshold', () {
    final unlockedIds = mergedUnlockedAchievementIds(
      existingIds: const [],
      tasksCompleted: 100,
      currentStreak: 30,
      groupTasksCompleted: 20,
      memberGroupTasksCompleted: 5,
      leaderGroupTasksCompleted: 20,
      currentLevel: 1,
    );

    expect(
      unlockedIds,
      containsAll(availableAchievements.map((item) => item.id)),
    );
    expect(unlockedIds, hasLength(8));
  });

  test(
    'previously unlocked badges remain unlocked after progress decreases',
    () {
      final unlockedIds = mergedUnlockedAchievementIds(
        existingIds: const ['pathfinder', 'on_fire'],
        tasksCompleted: 0,
        currentStreak: 1,
        groupTasksCompleted: 0,
        memberGroupTasksCompleted: 0,
        leaderGroupTasksCompleted: 0,
        currentLevel: 1,
      );

      expect(unlockedIds, containsAll(['pathfinder', 'on_fire']));
    },
  );

  test('group achievements use separate member and leader progress', () {
    final member = User(
      id: 'member-1',
      name: 'Member',
      email: 'member@example.com',
      avatarUrl: '',
      groupTasksCompleted: 20,
      memberGroupTasksCompleted: 5,
      joinedAt: DateTime(2026),
    );
    final leader = User(
      id: 'leader-1',
      name: 'Leader',
      email: 'leader@example.com',
      avatarUrl: '',
      groupTasksCompleted: 20,
      leaderGroupTasksCompleted: 20,
      joinedAt: DateTime(2026),
    );

    expect(
      evaluateAchievements(member).unlocked.map((item) => item.achievement.id),
      contains('team_player'),
    );
    expect(
      evaluateAchievements(member).unlocked.map((item) => item.achievement.id),
      isNot(contains('squad_captain')),
    );
    expect(
      evaluateAchievements(leader).unlocked.map((item) => item.achievement.id),
      contains('squad_captain'),
    );
    expect(
      evaluateAchievements(leader).unlocked.map((item) => item.achievement.id),
      isNot(contains('team_player')),
    );
  });

  test('profile task total combines personal and group tasks', () {
    final user = User(
      id: 'user-1',
      name: 'Test User',
      email: 'test@example.com',
      avatarUrl: '',
      tasksCompleted: 28,
      groupTasksCompleted: 2,
      joinedAt: DateTime(2026),
    );

    expect(user.totalTasksCompleted, 30);
  });

  testWidgets('summary card hides locked badge previews', (tester) async {
    final user = User(
      id: 'user-1',
      name: 'Test User',
      email: 'test@example.com',
      avatarUrl: '',
      joinedAt: DateTime(2026),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: AchievementSummaryCard(user: user)),
      ),
    );

    expect(find.text('0/8'), findsOneWidget);
    expect(find.text('ยังไม่มีตราที่ปลดล็อก'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
  });
}
