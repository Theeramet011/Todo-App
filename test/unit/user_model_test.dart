import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/user.dart';

/// Helper to create a [User] with sensible defaults so each test only
/// has to specify the fields it cares about.
User _makeUser({
  String id = 'test-id',
  String name = 'Test User',
  String email = 'test@example.com',
  String avatarUrl = 'https://example.com/avatar.png',
  int totalXP = 0,
  int tasksCompleted = 0,
  int groupTasksCompleted = 0,
  int memberGroupTasksCompleted = 0,
  int leaderGroupTasksCompleted = 0,
  int personalTasksCompletedToday = 0,
  String lastResetDate = '',
  int? currentStreak,
  String lastLoginDate = '',
  int? longestStreak,
  DateTime? joinedAt,
  bool isOnline = false,
  bool isNotificationEnabled = true,
  bool isSoundEnabled = true,
  List<String> friends = const [],
  List<String> receivedRequests = const [],
  List<String> sentRequests = const [],
  List<String> achievementsUnlocked = const [],
  List<String> unlockedItems = const [],
  String equippedFrame = '',
  String equippedTitle = '',
}) {
  return User(
    id: id,
    name: name,
    email: email,
    avatarUrl: avatarUrl,
    totalXP: totalXP,
    tasksCompleted: tasksCompleted,
    groupTasksCompleted: groupTasksCompleted,
    memberGroupTasksCompleted: memberGroupTasksCompleted,
    leaderGroupTasksCompleted: leaderGroupTasksCompleted,
    personalTasksCompletedToday: personalTasksCompletedToday,
    lastResetDate: lastResetDate,
    currentStreak: currentStreak,
    lastLoginDate: lastLoginDate,
    longestStreak: longestStreak,
    joinedAt: joinedAt ?? DateTime(2025, 1, 1),
    isOnline: isOnline,
    isNotificationEnabled: isNotificationEnabled,
    isSoundEnabled: isSoundEnabled,
    friends: friends,
    receivedRequests: receivedRequests,
    sentRequests: sentRequests,
    achievementsUnlocked: achievementsUnlocked,
    unlockedItems: unlockedItems,
    equippedFrame: equippedFrame,
    equippedTitle: equippedTitle,
  );
}

void main() {
  // ─────────────────────────────────────────────────────────
  // 1. Default values when creating a User
  // ─────────────────────────────────────────────────────────
  group('Default values', () {
    late User user;

    setUp(() {
      user = _makeUser();
    });

    test('totalXP defaults to 0', () {
      expect(user.totalXP, 0);
    });

    test('tasksCompleted defaults to 0', () {
      expect(user.tasksCompleted, 0);
    });

    test('groupTasksCompleted defaults to 0', () {
      expect(user.groupTasksCompleted, 0);
    });

    test('memberGroupTasksCompleted defaults to 0', () {
      expect(user.memberGroupTasksCompleted, 0);
    });

    test('leaderGroupTasksCompleted defaults to 0', () {
      expect(user.leaderGroupTasksCompleted, 0);
    });

    test('personalTasksCompletedToday defaults to 0', () {
      expect(user.personalTasksCompletedToday, 0);
    });

    test('lastResetDate defaults to empty string', () {
      expect(user.lastResetDate, '');
    });

    test('currentStreak defaults to 0', () {
      expect(user.currentStreak, 0);
    });

    test('lastLoginDate defaults to empty string', () {
      expect(user.lastLoginDate, '');
    });

    test('longestStreak defaults to 0', () {
      expect(user.longestStreak, 0);
    });

    test('isOnline defaults to false', () {
      expect(user.isOnline, false);
    });

    test('isNotificationEnabled defaults to true', () {
      expect(user.isNotificationEnabled, true);
    });

    test('isSoundEnabled defaults to true', () {
      expect(user.isSoundEnabled, true);
    });

    test('equippedFrame defaults to empty string', () {
      expect(user.equippedFrame, '');
    });

    test('equippedTitle defaults to empty string', () {
      expect(user.equippedTitle, '');
    });
  });

  // ─────────────────────────────────────────────────────────
  // 2. currentLevel is auto-calculated from totalXP
  //    Level formula:  (safeTotalXP ~/ 500) + 1
  // ─────────────────────────────────────────────────────────
  group('currentLevel auto-calculation from totalXP', () {
    test('0 XP → level 1', () {
      final user = _makeUser(totalXP: 0);
      expect(user.currentLevel, 1);
    });

    test('499 XP → level 1', () {
      final user = _makeUser(totalXP: 499);
      expect(user.currentLevel, 1);
    });

    test('500 XP → level 2', () {
      final user = _makeUser(totalXP: 500);
      expect(user.currentLevel, 2);
    });

    test('501 XP → level 2', () {
      final user = _makeUser(totalXP: 501);
      expect(user.currentLevel, 2);
    });

    test('999 XP → level 2', () {
      final user = _makeUser(totalXP: 999);
      expect(user.currentLevel, 2);
    });

    test('1000 XP → level 3', () {
      final user = _makeUser(totalXP: 1000);
      expect(user.currentLevel, 3);
    });

    test('2500 XP → level 6', () {
      final user = _makeUser(totalXP: 2500);
      expect(user.currentLevel, 6);
    });

    test('9999 XP → level 20 (boundary)', () {
      final user = _makeUser(totalXP: 9999);
      // 9999 ~/ 500 = 19  →  19 + 1 = 20
      expect(user.currentLevel, 20);
    });

    test('10000 XP → level 21', () {
      final user = _makeUser(totalXP: 10000);
      expect(user.currentLevel, 21);
    });

    test('negative XP is treated as 0 → level 1', () {
      final user = _makeUser(totalXP: -100);
      expect(user.currentLevel, 1);
    });

    test('currentLevel ignores explicitly passed value (always recalculated)',
        () {
      // The constructor ignores any currentLevel parameter; it's always
      // derived from totalXP via the initializer list.
      final user = _makeUser(totalXP: 0);
      expect(user.currentLevel, 1);
    });
  });

  // ─────────────────────────────────────────────────────────
  // 3. Computed getters: streak, totalTasksCompleted, photoUrl
  // ─────────────────────────────────────────────────────────
  group('Computed getters', () {
    test('streak returns currentStreak', () {
      final user = _makeUser(currentStreak: 7);
      expect(user.streak, 7);
    });

    test('streak defaults to 0 when not provided', () {
      final user = _makeUser();
      expect(user.streak, 0);
    });

    test('totalTasksCompleted is tasksCompleted + groupTasksCompleted', () {
      final user = _makeUser(tasksCompleted: 10, groupTasksCompleted: 5);
      expect(user.totalTasksCompleted, 15);
    });

    test('totalTasksCompleted is 0 when both are 0', () {
      final user = _makeUser();
      expect(user.totalTasksCompleted, 0);
    });

    test('totalTasksCompleted only counts tasksCompleted when group is 0', () {
      final user = _makeUser(tasksCompleted: 42);
      expect(user.totalTasksCompleted, 42);
    });

    test('totalTasksCompleted only counts groupTasks when tasks is 0', () {
      final user = _makeUser(groupTasksCompleted: 8);
      expect(user.totalTasksCompleted, 8);
    });

    test('photoUrl returns avatarUrl', () {
      final user = _makeUser(avatarUrl: 'https://example.com/photo.jpg');
      expect(user.photoUrl, 'https://example.com/photo.jpg');
    });

    test('photoUrl returns empty string when avatarUrl is empty', () {
      final user = _makeUser(avatarUrl: '');
      expect(user.photoUrl, '');
    });
  });

  // ─────────────────────────────────────────────────────────
  // 4. Level progress calculations
  // ─────────────────────────────────────────────────────────
  group('Level progress calculations', () {
    test('nextLevelPoints is always 500', () {
      for (final xp in [0, 100, 499, 500, 1000, 9999]) {
        final user = _makeUser(totalXP: xp);
        expect(user.nextLevelPoints, 500, reason: 'Failed for XP = $xp');
      }
    });

    test('progressToNextLevel is totalXP % 500', () {
      expect(_makeUser(totalXP: 0).progressToNextLevel, 0);
      expect(_makeUser(totalXP: 123).progressToNextLevel, 123);
      expect(_makeUser(totalXP: 499).progressToNextLevel, 499);
      expect(_makeUser(totalXP: 500).progressToNextLevel, 0);
      expect(_makeUser(totalXP: 750).progressToNextLevel, 250);
      expect(_makeUser(totalXP: 1234).progressToNextLevel, 234);
    });

    test('progressToNextLevelValue is (totalXP % 500) / 500', () {
      expect(_makeUser(totalXP: 0).progressToNextLevelValue, 0.0);
      expect(_makeUser(totalXP: 250).progressToNextLevelValue, 0.5);
      expect(_makeUser(totalXP: 500).progressToNextLevelValue, 0.0);
      expect(
        _makeUser(totalXP: 100).progressToNextLevelValue,
        closeTo(0.2, 0.001),
      );
      expect(
        _makeUser(totalXP: 1234).progressToNextLevelValue,
        closeTo(234 / 500, 0.001),
      );
    });

    test('levelProgress.currentLevel matches user.currentLevel', () {
      for (final xp in [0, 250, 499, 500, 1000, 5000]) {
        final user = _makeUser(totalXP: xp);
        expect(
          user.levelProgress.currentLevel,
          user.currentLevel,
          reason: 'Mismatch at XP = $xp',
        );
      }
    });

    test('progressToNextLevelValue is clamped between 0.0 and 1.0', () {
      // Negative XP is treated as 0
      final user = _makeUser(totalXP: -500);
      expect(user.progressToNextLevelValue, greaterThanOrEqualTo(0.0));
      expect(user.progressToNextLevelValue, lessThanOrEqualTo(1.0));
    });
  });

  // ─────────────────────────────────────────────────────────
  // 5. copyWith preserves unchanged fields
  // ─────────────────────────────────────────────────────────
  group('copyWith preserves unchanged fields', () {
    test('changing only name preserves all other fields', () {
      final original = _makeUser(
        id: 'u1',
        name: 'Alice',
        email: 'alice@example.com',
        avatarUrl: 'https://img.example.com/alice.png',
        totalXP: 750,
        tasksCompleted: 10,
        groupTasksCompleted: 5,
        memberGroupTasksCompleted: 2,
        leaderGroupTasksCompleted: 3,
        personalTasksCompletedToday: 1,
        lastResetDate: '2025-06-01',
        currentStreak: 4,
        lastLoginDate: '2025-06-01',
        longestStreak: 10,
        isOnline: true,
        isNotificationEnabled: false,
        isSoundEnabled: false,
        friends: ['f1', 'f2'],
        receivedRequests: ['r1'],
        sentRequests: ['s1'],
        achievementsUnlocked: ['a1'],
        unlockedItems: ['item1'],
        equippedFrame: 'bronze_frame',
        equippedTitle: 'Beginner',
      );

      final updated = original.copyWith(name: 'Bob');

      expect(updated.name, 'Bob');
      expect(updated.id, original.id);
      expect(updated.email, original.email);
      expect(updated.avatarUrl, original.avatarUrl);
      expect(updated.totalXP, original.totalXP);
      expect(updated.currentLevel, original.currentLevel);
      expect(updated.tasksCompleted, original.tasksCompleted);
      expect(updated.groupTasksCompleted, original.groupTasksCompleted);
      expect(
        updated.memberGroupTasksCompleted,
        original.memberGroupTasksCompleted,
      );
      expect(
        updated.leaderGroupTasksCompleted,
        original.leaderGroupTasksCompleted,
      );
      expect(
        updated.personalTasksCompletedToday,
        original.personalTasksCompletedToday,
      );
      expect(updated.lastResetDate, original.lastResetDate);
      expect(updated.currentStreak, original.currentStreak);
      expect(updated.lastLoginDate, original.lastLoginDate);
      expect(updated.longestStreak, original.longestStreak);
      expect(updated.joinedAt, original.joinedAt);
      expect(updated.isOnline, original.isOnline);
      expect(updated.isNotificationEnabled, original.isNotificationEnabled);
      expect(updated.isSoundEnabled, original.isSoundEnabled);
      expect(updated.friends, original.friends);
      expect(updated.receivedRequests, original.receivedRequests);
      expect(updated.sentRequests, original.sentRequests);
      expect(updated.achievementsUnlocked, original.achievementsUnlocked);
      expect(updated.unlockedItems, original.unlockedItems);
      expect(updated.equippedFrame, original.equippedFrame);
      expect(updated.equippedTitle, original.equippedTitle);
    });

    test('copyWith with no arguments returns equivalent user', () {
      final original = _makeUser(
        totalXP: 1500,
        tasksCompleted: 20,
        currentStreak: 5,
      );
      final copy = original.copyWith();

      expect(copy.id, original.id);
      expect(copy.name, original.name);
      expect(copy.email, original.email);
      expect(copy.totalXP, original.totalXP);
      expect(copy.currentLevel, original.currentLevel);
      expect(copy.tasksCompleted, original.tasksCompleted);
      expect(copy.currentStreak, original.currentStreak);
    });
  });

  // ─────────────────────────────────────────────────────────
  // 6. copyWith updates specified fields
  // ─────────────────────────────────────────────────────────
  group('copyWith updates specified fields', () {
    test('updates totalXP and recalculates currentLevel', () {
      final user = _makeUser(totalXP: 0);
      expect(user.currentLevel, 1);

      final leveled = user.copyWith(totalXP: 1000);
      expect(leveled.totalXP, 1000);
      expect(leveled.currentLevel, 3);
    });

    test('updates email', () {
      final user = _makeUser(email: 'old@example.com');
      final updated = user.copyWith(email: 'new@example.com');
      expect(updated.email, 'new@example.com');
    });

    test('updates isOnline', () {
      final user = _makeUser(isOnline: false);
      final updated = user.copyWith(isOnline: true);
      expect(updated.isOnline, true);
    });

    test('updates friends list', () {
      final user = _makeUser();
      final updated = user.copyWith(friends: ['uid1', 'uid2']);
      expect(updated.friends, ['uid1', 'uid2']);
    });

    test('updates currentStreak', () {
      final user = _makeUser(currentStreak: 3);
      final updated = user.copyWith(currentStreak: 10);
      expect(updated.currentStreak, 10);
      expect(updated.streak, 10);
    });

    test('updates tasksCompleted and reflects in totalTasksCompleted', () {
      final user = _makeUser(tasksCompleted: 5, groupTasksCompleted: 3);
      final updated = user.copyWith(tasksCompleted: 15);
      expect(updated.totalTasksCompleted, 18); // 15 + 3
    });

    test('updates joinedAt', () {
      final newDate = DateTime(2026, 7, 4);
      final user = _makeUser();
      final updated = user.copyWith(joinedAt: newDate);
      expect(updated.joinedAt, newDate);
    });

    test('updates equippedFrame and equippedTitle', () {
      final user = _makeUser();
      final updated = user.copyWith(
        equippedFrame: 'diamond_frame',
        equippedTitle: 'Champion',
      );
      expect(updated.equippedFrame, 'diamond_frame');
      expect(updated.equippedTitle, 'Champion');
    });

    test('updates multiple fields at once', () {
      final user = _makeUser();
      final updated = user.copyWith(
        name: 'Updated Name',
        totalXP: 2500,
        isOnline: true,
        friends: ['a', 'b', 'c'],
      );
      expect(updated.name, 'Updated Name');
      expect(updated.totalXP, 2500);
      expect(updated.currentLevel, 6);
      expect(updated.isOnline, true);
      expect(updated.friends, ['a', 'b', 'c']);
    });
  });

  // ─────────────────────────────────────────────────────────
  // 7. Friends-related lists default to empty
  // ─────────────────────────────────────────────────────────
  group('Friends-related lists default to empty', () {
    late User user;

    setUp(() {
      user = _makeUser();
    });

    test('friends defaults to empty list', () {
      expect(user.friends, isEmpty);
      expect(user.friends, isA<List<String>>());
    });

    test('receivedRequests defaults to empty list', () {
      expect(user.receivedRequests, isEmpty);
      expect(user.receivedRequests, isA<List<String>>());
    });

    test('sentRequests defaults to empty list', () {
      expect(user.sentRequests, isEmpty);
      expect(user.sentRequests, isA<List<String>>());
    });

    test('achievementsUnlocked defaults to empty list', () {
      expect(user.achievementsUnlocked, isEmpty);
      expect(user.achievementsUnlocked, isA<List<String>>());
    });

    test('unlockedItems defaults to empty list', () {
      expect(user.unlockedItems, isEmpty);
      expect(user.unlockedItems, isA<List<String>>());
    });

    test('friends list preserves values when provided', () {
      final user = _makeUser(friends: ['uid-a', 'uid-b', 'uid-c']);
      expect(user.friends, hasLength(3));
      expect(user.friends, containsAll(['uid-a', 'uid-b', 'uid-c']));
    });

    test('receivedRequests preserves values when provided', () {
      final user = _makeUser(receivedRequests: ['req1']);
      expect(user.receivedRequests, ['req1']);
    });

    test('sentRequests preserves values when provided', () {
      final user = _makeUser(sentRequests: ['sent1', 'sent2']);
      expect(user.sentRequests, ['sent1', 'sent2']);
    });
  });

  // ─────────────────────────────────────────────────────────
  // 8. toMap output (no fromMap / Firestore dependency)
  // ─────────────────────────────────────────────────────────
  group('toMap output', () {
    test('toMap contains all expected keys', () {
      final user = _makeUser();
      final map = user.toMap();

      expect(map, contains('name'));
      expect(map, contains('email'));
      expect(map, contains('avatarUrl'));
      expect(map, contains('totalXP'));
      expect(map, contains('currentLevel'));
      expect(map, contains('tasksCompleted'));
      expect(map, contains('groupTasksCompleted'));
      expect(map, contains('memberGroupTasksCompleted'));
      expect(map, contains('leaderGroupTasksCompleted'));
      expect(map, contains('personalTasksCompletedToday'));
      expect(map, contains('lastResetDate'));
      expect(map, contains('currentStreak'));
      expect(map, contains('lastLoginDate'));
      expect(map, contains('longestStreak'));
      expect(map, contains('joinedAt'));
      expect(map, contains('isOnline'));
      expect(map, contains('isNotificationEnabled'));
      expect(map, contains('isSoundEnabled'));
      expect(map, contains('friends'));
      expect(map, contains('receivedRequests'));
      expect(map, contains('sentRequests'));
      expect(map, contains('achievementsUnlocked'));
      expect(map, contains('unlockedItems'));
      expect(map, contains('equippedFrame'));
      expect(map, contains('equippedTitle'));
    });

    test('toMap does NOT include id (id is the document key)', () {
      final user = _makeUser(id: 'my-id');
      final map = user.toMap();
      expect(map.containsKey('id'), isFalse);
    });

    test('toMap reflects provided field values', () {
      final joinDate = DateTime(2025, 3, 15);
      final user = _makeUser(
        name: 'Map User',
        email: 'map@example.com',
        avatarUrl: 'https://img.example.com/map.png',
        totalXP: 1250,
        tasksCompleted: 20,
        groupTasksCompleted: 10,
        memberGroupTasksCompleted: 4,
        leaderGroupTasksCompleted: 6,
        personalTasksCompletedToday: 3,
        lastResetDate: '2025-06-01',
        currentStreak: 7,
        lastLoginDate: '2025-06-01',
        longestStreak: 14,
        joinedAt: joinDate,
        isOnline: true,
        isNotificationEnabled: false,
        isSoundEnabled: false,
        friends: ['f1'],
        receivedRequests: ['r1'],
        sentRequests: ['s1'],
        achievementsUnlocked: ['a1'],
        unlockedItems: ['item1'],
        equippedFrame: 'gold_frame',
        equippedTitle: 'Expert',
      );

      final map = user.toMap();

      expect(map['name'], 'Map User');
      expect(map['email'], 'map@example.com');
      expect(map['avatarUrl'], 'https://img.example.com/map.png');
      expect(map['totalXP'], 1250);
      // currentLevel recalculated: (1250 ~/ 500) + 1 = 3
      expect(map['currentLevel'], 3);
      expect(map['tasksCompleted'], 20);
      expect(map['groupTasksCompleted'], 10);
      expect(map['memberGroupTasksCompleted'], 4);
      expect(map['leaderGroupTasksCompleted'], 6);
      expect(map['personalTasksCompletedToday'], 3);
      expect(map['lastResetDate'], '2025-06-01');
      expect(map['currentStreak'], 7);
      expect(map['lastLoginDate'], '2025-06-01');
      expect(map['longestStreak'], 14);
      expect(map['joinedAt'], joinDate);
      expect(map['isOnline'], true);
      expect(map['isNotificationEnabled'], false);
      expect(map['isSoundEnabled'], false);
      expect(map['friends'], ['f1']);
      expect(map['receivedRequests'], ['r1']);
      expect(map['sentRequests'], ['s1']);
      expect(map['achievementsUnlocked'], ['a1']);
      expect(map['unlockedItems'], ['item1']);
      expect(map['equippedFrame'], 'gold_frame');
      expect(map['equippedTitle'], 'Expert');
    });

    test('toMap level is consistent with constructor level', () {
      final user = _makeUser(totalXP: 2000);
      final map = user.toMap();
      expect(map['currentLevel'], user.currentLevel);
      expect(map['currentLevel'], 5); // (2000 ~/ 500) + 1
    });

    test('toMap lists are empty when defaults are used', () {
      final user = _makeUser();
      final map = user.toMap();
      expect(map['friends'], isEmpty);
      expect(map['receivedRequests'], isEmpty);
      expect(map['sentRequests'], isEmpty);
      expect(map['achievementsUnlocked'], isEmpty);
      expect(map['unlockedItems'], isEmpty);
    });
  });

  // ─────────────────────────────────────────────────────────
  // Bonus: streak / longestStreak initializer edge cases
  // ─────────────────────────────────────────────────────────
  group('Streak initializer edge cases', () {
    test('longestStreak falls back to currentStreak when not provided', () {
      final user = _makeUser(currentStreak: 12);
      expect(user.longestStreak, 12);
    });

    test('longestStreak uses its own value when provided', () {
      final user = _makeUser(currentStreak: 5, longestStreak: 20);
      expect(user.longestStreak, 20);
    });

    test('both currentStreak and longestStreak default to 0', () {
      final user = _makeUser();
      expect(user.currentStreak, 0);
      expect(user.longestStreak, 0);
    });
  });
}
