import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/task.dart';

void main() {
  group('Task and SubTask Models', () {
    test('SubTask creation and state', () {
      final subtask = SubTask(title: 'Test Subtask');
      expect(subtask.title, 'Test Subtask');
      expect(subtask.isDone, false);

      subtask.isDone = true;
      expect(subtask.isDone, true);
    });

    test('Task with subtasks creation', () {
      final subtasks = [
        SubTask(title: 'Sub 1'),
        SubTask(title: 'Sub 2', isDone: true),
      ];

      final task = Task(
        id: '1',
        title: 'Task 1',
        creatorId: 'user1',
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        subtasks: subtasks,
      );

      expect(task.subtasks.length, 2);
      expect(task.subtasks[0].title, 'Sub 1');
      expect(task.subtasks[1].isDone, true);
    });

    test('Task copyWith updates subtasks', () {
      final task = Task(
        id: '1',
        title: 'Task 1',
        creatorId: 'user1',
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        subtasks: [SubTask(title: 'Initial')],
      );

      final updatedTask = task.copyWith(
        subtasks: [SubTask(title: 'Updated', isDone: true)],
        awardedXP: 25,
      );

      expect(updatedTask.subtasks[0].title, 'Updated');
      expect(updatedTask.subtasks[0].isDone, true);
      expect(updatedTask.awardedXP, 25);
      expect(task.subtasks[0].title, 'Initial');
      expect(task.awardedXP, 0);
    });

    test('Task notification flags default to false and serialize', () {
      final task = Task(
        id: '1',
        title: 'Task 1',
        creatorId: 'user1',
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
      );

      final map = task.toMap();

      expect(task.notified1Week, false);
      expect(task.notified1Day, false);
      expect(task.notified1Hour, false);
      expect(task.notifiedExact, false);
      expect(task.notifiedFollowUp, false);
      expect(task.isRecurring, false);
      expect(task.recurringType, 'daily');
      expect(task.recurringDate, null);
      expect(task.recurringTime, null);
      expect(map['notified1Week'], false);
      expect(map['notified1Day'], false);
      expect(map['notified1Hour'], false);
      expect(map['notifiedExact'], false);
      expect(map['notifiedFollowUp'], false);
      expect(map['isRecurring'], false);
      expect(map['recurringType'], 'daily');
      expect(map['recurringDate'], null);
      expect(map['recurringTime'], null);
    });

    test('Task reads notification flags from Firestore data', () {
      final task = Task.fromMap({
        'title': 'Task 1',
        'creatorId': 'user1',
        'createdAt': DateTime.now(),
        'dateTime': DateTime.now(),
        'notified1Week': true,
        'notified1Day': false,
        'notified1Hour': true,
        'notifiedExact': false,
        'notifiedFollowUp': true,
        'isRecurring': true,
        'recurringType': 'custom',
        'recurringDate': DateTime(2026, 6, 10),
        'recurringTime': '09:30',
      }, '1');

      expect(task.notified1Week, true);
      expect(task.notified1Day, false);
      expect(task.notified1Hour, true);
      expect(task.notifiedExact, false);
      expect(task.notifiedFollowUp, true);
      expect(task.isRecurring, true);
      expect(task.recurringType, 'custom');
      expect(task.recurringDate, DateTime(2026, 6, 10));
      expect(task.recurringTime, '09:30');
    });

    test('Task serializes reward block audit fields', () {
      final blockedAt = DateTime(2026, 6, 10, 12, 4);
      final task = Task(
        id: '1',
        title: 'Task 1',
        creatorId: 'user1',
        createdAt: DateTime(2026, 6, 10, 12),
        dateTime: DateTime(2026, 6, 10, 13),
        rewardBlocked: true,
        rewardBlockedReason: 'fast_completion',
        rewardBlockedAt: blockedAt,
        rewardBlockedBy: 'user1',
        completionAgeSeconds: 240,
      );

      final map = task.toMap();
      final restored = Task.fromMap(map, '1');

      expect(restored.rewardBlocked, true);
      expect(restored.rewardBlockedReason, 'fast_completion');
      expect(restored.rewardBlockedAt, blockedAt);
      expect(restored.rewardBlockedBy, 'user1');
      expect(restored.completionAgeSeconds, 240);
    });

    test('Task copyWith preserves and clears reward block audit fields', () {
      final blockedAt = DateTime(2026, 6, 10, 12, 4);
      final task = Task(
        id: '1',
        title: 'Task 1',
        creatorId: 'user1',
        createdAt: DateTime(2026, 6, 10, 12),
        dateTime: DateTime(2026, 6, 10, 13),
        rewardBlocked: true,
        rewardBlockedReason: 'fast_completion',
        rewardBlockedAt: blockedAt,
        rewardBlockedBy: 'user1',
        completionAgeSeconds: 240,
      );

      final preserved = task.copyWith(title: 'Updated');
      final cleared = task.copyWith(
        rewardBlocked: false,
        clearRewardBlockedReason: true,
        clearRewardBlockedAt: true,
        clearRewardBlockedBy: true,
        clearCompletionAgeSeconds: true,
      );

      expect(preserved.rewardBlocked, true);
      expect(preserved.rewardBlockedReason, 'fast_completion');
      expect(preserved.rewardBlockedAt, blockedAt);
      expect(preserved.rewardBlockedBy, 'user1');
      expect(preserved.completionAgeSeconds, 240);
      expect(cleared.rewardBlocked, false);
      expect(cleared.rewardBlockedReason, null);
      expect(cleared.rewardBlockedAt, null);
      expect(cleared.rewardBlockedBy, null);
      expect(cleared.completionAgeSeconds, null);
    });
  });
}
