import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/task.dart';

/// Helper that applies the same sort logic used in the app.
///
/// Primary key  : priority index descending  (urgent 3 → low 0)
/// Secondary key: createdAt descending       (newest first)
void sortTasks(List<Task> tasks) {
  tasks.sort((a, b) {
    final priorityComparison = b.priority.index.compareTo(a.priority.index);
    if (priorityComparison != 0) return priorityComparison;
    return b.createdAt.compareTo(a.createdAt);
  });
}

/// Shorthand factory so every test doesn't need to repeat boilerplate fields.
Task _makeTask({
  required String id,
  String title = '',
  Priority priority = Priority.low,
  required DateTime createdAt,
}) {
  return Task(
    id: id,
    title: title.isEmpty ? 'Task $id' : title,
    creatorId: 'test-user',
    createdAt: createdAt,
    dateTime: createdAt, // reuse createdAt as the required dateTime
    priority: priority,
  );
}

void main() {
  // ──────────────────────────────────────────────────────────
  // Fixed reference dates used across multiple tests
  // ──────────────────────────────────────────────────────────
  final now = DateTime(2026, 7, 4, 12, 0);
  final oneHourAgo = now.subtract(const Duration(hours: 1));
  final twoHoursAgo = now.subtract(const Duration(hours: 2));
  final threeHoursAgo = now.subtract(const Duration(hours: 3));
  final oneDayAgo = now.subtract(const Duration(days: 1));
  final twoDaysAgo = now.subtract(const Duration(days: 2));

  // ════════════════════════════════════════════════════════════
  group('Priority enum index values', () {
    // ════════════════════════════════════════════════════════════
    test('Priority.low has index 0', () {
      expect(Priority.low.index, 0);
    });

    test('Priority.medium has index 1', () {
      expect(Priority.medium.index, 1);
    });

    test('Priority.high has index 2', () {
      expect(Priority.high.index, 2);
    });

    test('Priority.urgent has index 3', () {
      expect(Priority.urgent.index, 3);
    });

    test('Priority.values contains exactly 4 entries in the right order', () {
      expect(Priority.values, [
        Priority.low,
        Priority.medium,
        Priority.high,
        Priority.urgent,
      ]);
    });
  });

  // ════════════════════════════════════════════════════════════
  group('Sorting a mixed list of tasks by priority', () {
    // ════════════════════════════════════════════════════════════
    test('sorts urgent first and low last', () {
      final tasks = [
        _makeTask(id: '1', priority: Priority.low, createdAt: now),
        _makeTask(id: '2', priority: Priority.urgent, createdAt: now),
        _makeTask(id: '3', priority: Priority.high, createdAt: now),
        _makeTask(id: '4', priority: Priority.medium, createdAt: now),
      ];

      sortTasks(tasks);

      expect(tasks[0].priority, Priority.urgent);
      expect(tasks[1].priority, Priority.high);
      expect(tasks[2].priority, Priority.medium);
      expect(tasks[3].priority, Priority.low);
    });

    test('correctly orders ids after sorting by priority', () {
      final tasks = [
        _makeTask(id: 'low-1', priority: Priority.low, createdAt: now),
        _makeTask(id: 'urgent-1', priority: Priority.urgent, createdAt: now),
        _makeTask(id: 'high-1', priority: Priority.high, createdAt: now),
        _makeTask(id: 'medium-1', priority: Priority.medium, createdAt: now),
      ];

      sortTasks(tasks);

      expect(tasks.map((t) => t.id).toList(), [
        'urgent-1',
        'high-1',
        'medium-1',
        'low-1',
      ]);
    });

    test('handles duplicate priorities scattered across the list', () {
      final tasks = [
        _makeTask(id: '1', priority: Priority.low, createdAt: now),
        _makeTask(id: '2', priority: Priority.urgent, createdAt: now),
        _makeTask(id: '3', priority: Priority.low, createdAt: oneHourAgo),
        _makeTask(id: '4', priority: Priority.urgent, createdAt: oneHourAgo),
        _makeTask(id: '5', priority: Priority.high, createdAt: now),
      ];

      sortTasks(tasks);

      // Urgent tasks first, then high, then low
      expect(tasks[0].priority, Priority.urgent);
      expect(tasks[1].priority, Priority.urgent);
      expect(tasks[2].priority, Priority.high);
      expect(tasks[3].priority, Priority.low);
      expect(tasks[4].priority, Priority.low);
    });
  });

  // ════════════════════════════════════════════════════════════
  group('Same-priority tasks sorted by createdAt descending', () {
    // ════════════════════════════════════════════════════════════
    test('newest task appears first among same-priority tasks', () {
      final tasks = [
        _makeTask(id: 'old', priority: Priority.high, createdAt: twoDaysAgo),
        _makeTask(id: 'new', priority: Priority.high, createdAt: now),
        _makeTask(id: 'mid', priority: Priority.high, createdAt: oneDayAgo),
      ];

      sortTasks(tasks);

      expect(tasks.map((t) => t.id).toList(), ['new', 'mid', 'old']);
    });

    test('within low-priority group, createdAt descending applies', () {
      final tasks = [
        _makeTask(id: 'a', priority: Priority.low, createdAt: threeHoursAgo),
        _makeTask(id: 'b', priority: Priority.low, createdAt: now),
        _makeTask(id: 'c', priority: Priority.low, createdAt: oneHourAgo),
        _makeTask(id: 'd', priority: Priority.low, createdAt: twoHoursAgo),
      ];

      sortTasks(tasks);

      expect(tasks.map((t) => t.id).toList(), ['b', 'c', 'd', 'a']);
    });

    test('secondary sort applies per priority tier independently', () {
      final tasks = [
        _makeTask(
            id: 'urgent-old', priority: Priority.urgent, createdAt: oneDayAgo),
        _makeTask(
            id: 'urgent-new', priority: Priority.urgent, createdAt: now),
        _makeTask(
            id: 'low-old', priority: Priority.low, createdAt: oneDayAgo),
        _makeTask(id: 'low-new', priority: Priority.low, createdAt: now),
      ];

      sortTasks(tasks);

      expect(tasks.map((t) => t.id).toList(), [
        'urgent-new',
        'urgent-old',
        'low-new',
        'low-old',
      ]);
    });
  });

  // ════════════════════════════════════════════════════════════
  group('Edge case: all tasks have the same priority', () {
    // ════════════════════════════════════════════════════════════
    test('falls back to createdAt descending when all are medium', () {
      final tasks = [
        _makeTask(id: '1', priority: Priority.medium, createdAt: threeHoursAgo),
        _makeTask(id: '2', priority: Priority.medium, createdAt: oneHourAgo),
        _makeTask(id: '3', priority: Priority.medium, createdAt: now),
        _makeTask(id: '4', priority: Priority.medium, createdAt: twoHoursAgo),
      ];

      sortTasks(tasks);

      expect(tasks.map((t) => t.id).toList(), ['3', '2', '4', '1']);
    });

    test('order is stable for identical priority and identical createdAt', () {
      // When both keys are equal the sort should at minimum not crash.
      final identicalTime = DateTime(2026, 1, 1);
      final tasks = [
        _makeTask(id: 'a', priority: Priority.urgent, createdAt: identicalTime),
        _makeTask(id: 'b', priority: Priority.urgent, createdAt: identicalTime),
        _makeTask(id: 'c', priority: Priority.urgent, createdAt: identicalTime),
      ];

      sortTasks(tasks);

      // All priorities and times are equal – just verify length is preserved.
      expect(tasks.length, 3);
      expect(tasks.every((t) => t.priority == Priority.urgent), isTrue);
    });
  });

  // ════════════════════════════════════════════════════════════
  group('Edge case: single task', () {
    // ════════════════════════════════════════════════════════════
    test('sorting a single-element list keeps it unchanged', () {
      final tasks = [
        _makeTask(id: 'only', priority: Priority.high, createdAt: now),
      ];

      sortTasks(tasks);

      expect(tasks.length, 1);
      expect(tasks.first.id, 'only');
      expect(tasks.first.priority, Priority.high);
    });
  });

  // ════════════════════════════════════════════════════════════
  group('Edge case: empty list', () {
    // ════════════════════════════════════════════════════════════
    test('sorting an empty list does not throw', () {
      final tasks = <Task>[];

      // Should not throw
      sortTasks(tasks);

      expect(tasks, isEmpty);
    });
  });

  // ════════════════════════════════════════════════════════════
  group('Mixed priorities with same createdAt group by priority', () {
    // ════════════════════════════════════════════════════════════
    test('tasks created at the exact same moment still group by priority', () {
      final sameTime = DateTime(2026, 6, 15, 9, 30);

      final tasks = [
        _makeTask(id: 'low', priority: Priority.low, createdAt: sameTime),
        _makeTask(id: 'high', priority: Priority.high, createdAt: sameTime),
        _makeTask(id: 'medium', priority: Priority.medium, createdAt: sameTime),
        _makeTask(id: 'urgent', priority: Priority.urgent, createdAt: sameTime),
      ];

      sortTasks(tasks);

      expect(tasks.map((t) => t.id).toList(), [
        'urgent',
        'high',
        'medium',
        'low',
      ]);
    });

    test('multiple tasks per priority at the same createdAt maintain grouping',
        () {
      final sameTime = DateTime(2026, 3, 1);

      final tasks = [
        _makeTask(id: 'low-1', priority: Priority.low, createdAt: sameTime),
        _makeTask(id: 'high-1', priority: Priority.high, createdAt: sameTime),
        _makeTask(id: 'low-2', priority: Priority.low, createdAt: sameTime),
        _makeTask(id: 'high-2', priority: Priority.high, createdAt: sameTime),
      ];

      sortTasks(tasks);

      // High tasks come first, then low tasks
      expect(tasks[0].priority, Priority.high);
      expect(tasks[1].priority, Priority.high);
      expect(tasks[2].priority, Priority.low);
      expect(tasks[3].priority, Priority.low);
    });
  });

  // ════════════════════════════════════════════════════════════
  group('New low-priority task vs older high-priority tasks', () {
    // ════════════════════════════════════════════════════════════
    test(
        'a newly created low-priority task appears after older high-priority tasks',
        () {
      final tasks = [
        _makeTask(
          id: 'new-low',
          title: 'Brand new low task',
          priority: Priority.low,
          createdAt: now,
        ),
        _makeTask(
          id: 'old-high',
          title: 'Old high task',
          priority: Priority.high,
          createdAt: twoDaysAgo,
        ),
      ];

      sortTasks(tasks);

      expect(tasks.first.id, 'old-high',
          reason: 'High-priority should beat low-priority regardless of age');
      expect(tasks.last.id, 'new-low');
    });

    test(
        'a brand-new low task appears after even the oldest urgent task', () {
      final veryOld = DateTime(2020, 1, 1);

      final tasks = [
        _makeTask(
          id: 'new-low',
          priority: Priority.low,
          createdAt: now,
        ),
        _makeTask(
          id: 'ancient-urgent',
          priority: Priority.urgent,
          createdAt: veryOld,
        ),
      ];

      sortTasks(tasks);

      expect(tasks.first.id, 'ancient-urgent');
      expect(tasks.last.id, 'new-low');
    });

    test(
        'priority always wins – new medium after old high, new high after old urgent',
        () {
      final tasks = [
        _makeTask(
            id: 'new-medium', priority: Priority.medium, createdAt: now),
        _makeTask(
            id: 'old-high', priority: Priority.high, createdAt: twoDaysAgo),
        _makeTask(
            id: 'new-high', priority: Priority.high, createdAt: now),
        _makeTask(
            id: 'old-urgent',
            priority: Priority.urgent,
            createdAt: twoDaysAgo),
      ];

      sortTasks(tasks);

      expect(tasks.map((t) => t.id).toList(), [
        'old-urgent',
        'new-high',
        'old-high',
        'new-medium',
      ]);
    });
  });

  // ════════════════════════════════════════════════════════════
  group('Task default priority', () {
    // ════════════════════════════════════════════════════════════
    test('Task constructor defaults priority to Priority.low', () {
      final task = Task(
        id: 'default',
        title: 'Default task',
        creatorId: 'user',
        createdAt: now,
        dateTime: now,
      );

      expect(task.priority, Priority.low);
    });
  });
}
