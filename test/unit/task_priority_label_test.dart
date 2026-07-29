import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/task.dart';

void main() {
  // ─── Helper ───────────────────────────────────────────────────────────
  /// Creates a minimal [Task] with only the required fields filled in.
  /// Any optional parameter can be overridden via named arguments.
  Task createTask({
    String id = 'test-id',
    String title = 'Test Task',
    String creatorId = 'creator-1',
    DateTime? createdAt,
    DateTime? dateTime,
    Priority priority = Priority.low,
    TaskStatus status = TaskStatus.todo,
    TaskType type = TaskType.personal,
    int difficulty = 1,
    int workload = 1,
    int risk = 1,
    List<SubTask> subtasks = const [],
  }) {
    final now = DateTime(2026, 7, 4);
    return Task(
      id: id,
      title: title,
      creatorId: creatorId,
      createdAt: createdAt ?? now,
      dateTime: dateTime ?? now,
      priority: priority,
      status: status,
      type: type,
      difficulty: difficulty,
      workload: workload,
      risk: risk,
      subtasks: subtasks,
    );
  }

  // ─── 1. Default values ────────────────────────────────────────────────
  group('Default values', () {
    test('priority defaults to Priority.low', () {
      final task = createTask();
      expect(task.priority, Priority.low);
    });

    test('status defaults to TaskStatus.todo', () {
      final task = createTask();
      expect(task.status, TaskStatus.todo);
    });

    test('type defaults to TaskType.personal', () {
      final task = createTask();
      expect(task.type, TaskType.personal);
    });

    test('difficulty defaults to 1', () {
      final task = createTask();
      expect(task.difficulty, 1);
    });

    test('workload defaults to 1', () {
      final task = createTask();
      expect(task.workload, 1);
    });

    test('risk defaults to 1', () {
      final task = createTask();
      expect(task.risk, 1);
    });

    test('subtasks defaults to an empty list', () {
      final task = createTask();
      expect(task.subtasks, isEmpty);
    });
  });

  // ─── 2. priorityLabel (Thai labels) ───────────────────────────────────
  group('priorityLabel', () {
    test('returns "ต่ำ" for Priority.low', () {
      final task = createTask(priority: Priority.low);
      expect(task.priorityLabel, 'ต่ำ');
    });

    test('returns "ปานกลาง" for Priority.medium', () {
      final task = createTask(priority: Priority.medium);
      expect(task.priorityLabel, 'ปานกลาง');
    });

    test('returns "สูง" for Priority.high', () {
      final task = createTask(priority: Priority.high);
      expect(task.priorityLabel, 'สูง');
    });

    test('returns "ด่วน" for Priority.urgent', () {
      final task = createTask(priority: Priority.urgent);
      expect(task.priorityLabel, 'ด่วน');
    });

    test('every Priority enum value produces a non-empty label', () {
      for (final p in Priority.values) {
        final task = createTask(priority: p);
        expect(task.priorityLabel, isNotEmpty,
            reason: '${p.name} should have a non-empty label');
      }
    });
  });

  // ─── 3. priorityColor ────────────────────────────────────────────────
  group('priorityColor', () {
    test('returns Color(0xFF00D9A5) for Priority.low', () {
      final task = createTask(priority: Priority.low);
      expect(task.priorityColor, const Color(0xFF00D9A5));
    });

    test('returns Color(0xFF3ABEF9) for Priority.medium', () {
      final task = createTask(priority: Priority.medium);
      expect(task.priorityColor, const Color(0xFF3ABEF9));
    });

    test('returns Color(0xFFFF6B8A) for Priority.high', () {
      final task = createTask(priority: Priority.high);
      expect(task.priorityColor, const Color(0xFFFF6B8A));
    });

    test('returns Color(0xFF9B5DE5) for Priority.urgent', () {
      final task = createTask(priority: Priority.urgent);
      expect(task.priorityColor, const Color(0xFF9B5DE5));
    });

    test('each priority maps to a unique color', () {
      final colors = Priority.values
          .map((p) => createTask(priority: p).priorityColor)
          .toSet();
      expect(colors.length, Priority.values.length,
          reason: 'All priority colors should be distinct');
    });
  });

  // ─── 4. isCompleted ──────────────────────────────────────────────────
  group('isCompleted', () {
    test('returns true when status is TaskStatus.completed', () {
      final task = createTask(status: TaskStatus.completed);
      expect(task.isCompleted, isTrue);
    });

    test('returns false when status is TaskStatus.todo', () {
      final task = createTask(status: TaskStatus.todo);
      expect(task.isCompleted, isFalse);
    });

    test('returns false when status is TaskStatus.inProgress', () {
      final task = createTask(status: TaskStatus.inProgress);
      expect(task.isCompleted, isFalse);
    });

    test('returns false when status is TaskStatus.pending', () {
      final task = createTask(status: TaskStatus.pending);
      expect(task.isCompleted, isFalse);
    });

    test('returns true only for completed among all statuses', () {
      for (final s in TaskStatus.values) {
        final task = createTask(status: s);
        expect(task.isCompleted, s == TaskStatus.completed,
            reason:
                'isCompleted should be ${s == TaskStatus.completed} for ${s.name}');
      }
    });
  });

  // ─── 5. isPersonal / isGroup ──────────────────────────────────────────
  group('isPersonal', () {
    test('returns true when type is TaskType.personal', () {
      final task = createTask(type: TaskType.personal);
      expect(task.isPersonal, isTrue);
    });

    test('returns false when type is TaskType.group', () {
      final task = createTask(type: TaskType.group);
      expect(task.isPersonal, isFalse);
    });
  });

  group('isGroup', () {
    test('returns true when type is TaskType.group', () {
      final task = createTask(type: TaskType.group);
      expect(task.isGroup, isTrue);
    });

    test('returns false when type is TaskType.personal', () {
      final task = createTask(type: TaskType.personal);
      expect(task.isGroup, isFalse);
    });
  });

  group('isPersonal and isGroup are mutually exclusive', () {
    test('a personal task is not a group task', () {
      final task = createTask(type: TaskType.personal);
      expect(task.isPersonal, isTrue);
      expect(task.isGroup, isFalse);
    });

    test('a group task is not a personal task', () {
      final task = createTask(type: TaskType.group);
      expect(task.isGroup, isTrue);
      expect(task.isPersonal, isFalse);
    });
  });

  // ─── 6. progress ─────────────────────────────────────────────────────
  group('progress', () {
    test('returns 0.0 when subtasks are empty and task is not completed', () {
      final task = createTask(status: TaskStatus.todo);
      expect(task.progress, 0.0);
    });

    test('returns 1.0 when subtasks are empty and task is completed', () {
      final task = createTask(status: TaskStatus.completed);
      expect(task.progress, 1.0);
    });

    test('returns 0.0 when no subtasks are done', () {
      final task = createTask(subtasks: [
        SubTask(title: 'A'),
        SubTask(title: 'B'),
        SubTask(title: 'C'),
      ]);
      expect(task.progress, 0.0);
    });

    test('returns 1.0 when all subtasks are done', () {
      final task = createTask(subtasks: [
        SubTask(title: 'A', isDone: true),
        SubTask(title: 'B', isDone: true),
      ]);
      expect(task.progress, 1.0);
    });

    test('returns correct fraction when some subtasks are done', () {
      final task = createTask(subtasks: [
        SubTask(title: 'A', isDone: true),
        SubTask(title: 'B', isDone: false),
        SubTask(title: 'C', isDone: true),
        SubTask(title: 'D', isDone: false),
      ]);
      // 2 out of 4 = 0.5
      expect(task.progress, 0.5);
    });

    test('returns 1/3 when one out of three subtasks is done', () {
      final task = createTask(subtasks: [
        SubTask(title: 'A', isDone: true),
        SubTask(title: 'B', isDone: false),
        SubTask(title: 'C', isDone: false),
      ]);
      expect(task.progress, closeTo(1 / 3, 1e-10));
    });

    test('progress uses subtasks regardless of task completion status', () {
      // Even if task is marked completed, progress is based on subtasks
      final task = createTask(
        status: TaskStatus.completed,
        subtasks: [
          SubTask(title: 'A', isDone: true),
          SubTask(title: 'B', isDone: false),
        ],
      );
      expect(task.progress, 0.5);
    });

    test('returns correct fraction with single subtask done', () {
      final task = createTask(subtasks: [
        SubTask(title: 'Only one', isDone: true),
      ]);
      expect(task.progress, 1.0);
    });

    test('returns 0.0 with single subtask not done', () {
      final task = createTask(subtasks: [
        SubTask(title: 'Only one', isDone: false),
      ]);
      expect(task.progress, 0.0);
    });
  });

  // ─── 7. completedCount ────────────────────────────────────────────────
  group('completedCount', () {
    test('returns 0 when subtasks are empty', () {
      final task = createTask();
      expect(task.completedCount, 0);
    });

    test('returns 0 when no subtasks are done', () {
      final task = createTask(subtasks: [
        SubTask(title: 'A'),
        SubTask(title: 'B'),
      ]);
      expect(task.completedCount, 0);
    });

    test('returns count of done subtasks', () {
      final task = createTask(subtasks: [
        SubTask(title: 'A', isDone: true),
        SubTask(title: 'B', isDone: false),
        SubTask(title: 'C', isDone: true),
      ]);
      expect(task.completedCount, 2);
    });

    test('returns total count when all subtasks are done', () {
      final task = createTask(subtasks: [
        SubTask(title: 'A', isDone: true),
        SubTask(title: 'B', isDone: true),
        SubTask(title: 'C', isDone: true),
      ]);
      expect(task.completedCount, 3);
    });

    test('returns 1 for a single done subtask', () {
      final task = createTask(subtasks: [
        SubTask(title: 'Only', isDone: true),
      ]);
      expect(task.completedCount, 1);
    });
  });

  // ─── 8. calculateXP ──────────────────────────────────────────────────
  group('calculateXP', () {
    // Formula: (difficulty * 15) + (workload * 10) + (risk * 5)

    test('returns 30 with default values (1, 1, 1)', () {
      final task = createTask();
      // (1*15) + (1*10) + (1*5) = 30
      expect(task.calculateXP, 30);
    });

    test('scales correctly with difficulty only', () {
      final task = createTask(difficulty: 5, workload: 1, risk: 1);
      // (5*15) + (1*10) + (1*5) = 75 + 10 + 5 = 90
      expect(task.calculateXP, 90);
    });

    test('scales correctly with workload only', () {
      final task = createTask(difficulty: 1, workload: 5, risk: 1);
      // (1*15) + (5*10) + (1*5) = 15 + 50 + 5 = 70
      expect(task.calculateXP, 70);
    });

    test('scales correctly with risk only', () {
      final task = createTask(difficulty: 1, workload: 1, risk: 5);
      // (1*15) + (1*10) + (5*5) = 15 + 10 + 25 = 50
      expect(task.calculateXP, 50);
    });

    test('calculates correctly with all factors maxed at 5', () {
      final task = createTask(difficulty: 5, workload: 5, risk: 5);
      // (5*15) + (5*10) + (5*5) = 75 + 50 + 25 = 150
      expect(task.calculateXP, 150);
    });

    test('calculates with mixed values (3, 2, 4)', () {
      final task = createTask(difficulty: 3, workload: 2, risk: 4);
      // (3*15) + (2*10) + (4*5) = 45 + 20 + 20 = 85
      expect(task.calculateXP, 85);
    });

    test('calculates with mixed values (2, 4, 1)', () {
      final task = createTask(difficulty: 2, workload: 4, risk: 1);
      // (2*15) + (4*10) + (1*5) = 30 + 40 + 5 = 75
      expect(task.calculateXP, 75);
    });

    test('difficulty has the highest weight (15x)', () {
      final base = createTask(difficulty: 1, workload: 1, risk: 1);
      final highDiff = createTask(difficulty: 2, workload: 1, risk: 1);
      final highWork = createTask(difficulty: 1, workload: 2, risk: 1);
      final highRisk = createTask(difficulty: 1, workload: 1, risk: 2);

      final diffDelta = highDiff.calculateXP - base.calculateXP;
      final workDelta = highWork.calculateXP - base.calculateXP;
      final riskDelta = highRisk.calculateXP - base.calculateXP;

      expect(diffDelta, 15);
      expect(workDelta, 10);
      expect(riskDelta, 5);
      expect(diffDelta, greaterThan(workDelta));
      expect(workDelta, greaterThan(riskDelta));
    });

    test('handles zero values', () {
      final task = createTask(difficulty: 0, workload: 0, risk: 0);
      // (0*15) + (0*10) + (0*5) = 0
      expect(task.calculateXP, 0);
    });

    test('handles large values', () {
      final task = createTask(difficulty: 10, workload: 10, risk: 10);
      // (10*15) + (10*10) + (10*5) = 150 + 100 + 50 = 300
      expect(task.calculateXP, 300);
    });
  });
}
