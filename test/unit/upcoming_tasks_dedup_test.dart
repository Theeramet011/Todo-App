import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/task.dart';

String _taskSeriesKey(Task task) {
  final cleanTitle = task.title.trim().toLowerCase();
  final creator = task.creatorId;
  final type = task.type.name;
  final project = task.projectId ?? '';
  return '$creator|$type|$project|$cleanTitle';
}

enum UpcomingSection { tomorrow, thisWeek, later }

Map<UpcomingSection, List<Task>> groupUpcomingTasks(
  List<Task> tasks, {
  DateTime? referenceDate,
  Map<String, Task> exitingTasks = const {},
}) {
  final now = referenceDate ?? DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final grouped = {
    UpcomingSection.tomorrow: <Task>[],
    UpcomingSection.thisWeek: <Task>[],
    UpcomingSection.later: <Task>[],
  };

  final candidateTasks = <Task>[];
  for (final task in tasks) {
    final isExiting = exitingTasks.containsKey(task.id);
    if (task.isCompleted && !isExiting) continue;

    final dueDate = DateTime(
      task.dateTime.year,
      task.dateTime.month,
      task.dateTime.day,
    );

    if (!dueDate.isAfter(today)) continue;
    candidateTasks.add(task);
  }

  candidateTasks.sort((a, b) => a.dateTime.compareTo(b.dateTime));

  final seenSeries = <String>{};
  for (final task in candidateTasks) {
    final seriesKey = _taskSeriesKey(task);
    if (seenSeries.contains(seriesKey)) {
      continue;
    }
    seenSeries.add(seriesKey);

    final dueDate = DateTime(
      task.dateTime.year,
      task.dateTime.month,
      task.dateTime.day,
    );

    final daysFromToday = dueDate.difference(today).inDays;
    if (daysFromToday == 1) {
      grouped[UpcomingSection.tomorrow]!.add(task);
    } else if (daysFromToday <= 7) {
      grouped[UpcomingSection.thisWeek]!.add(task);
    } else {
      grouped[UpcomingSection.later]!.add(task);
    }
  }

  for (final sectionTasks in grouped.values) {
    sectionTasks.sort((a, b) {
      final priorityComparison = b.priority.index.compareTo(a.priority.index);
      if (priorityComparison != 0) return priorityComparison;
      return a.dateTime.compareTo(b.dateTime);
    });
  }

  return grouped;
}

void main() {
  group('Upcoming Tasks Deduplication & Consolidation', () {
    final today = DateTime(2026, 9, 5, 12, 0);

    test('deduplicates recurring / same-title tasks to show only closest time first', () {
      final task1 = Task(
        id: 'task_1',
        title: 'แก้แอป',
        creatorId: 'user_1',
        createdAt: today,
        dateTime: DateTime(2026, 9, 6, 16, 0),
        priority: Priority.low,
      );

      final task2 = Task(
        id: 'task_2',
        title: 'แก้แอป',
        creatorId: 'user_1',
        createdAt: today,
        dateTime: DateTime(2026, 9, 6, 23, 0),
        priority: Priority.low,
      );

      final task3 = Task(
        id: 'task_3',
        title: 'แก้แอป',
        creatorId: 'user_1',
        createdAt: today,
        dateTime: DateTime(2026, 9, 7, 0, 0),
        priority: Priority.low,
      );

      final task4 = Task(
        id: 'task_4',
        title: 'ส่งงานโจให้เพื่อน',
        creatorId: 'user_1',
        createdAt: today,
        dateTime: DateTime(2026, 9, 7, 16, 0),
        priority: Priority.medium,
      );

      final allTasks = [task2, task3, task1, task4];
      final grouped = groupUpcomingTasks(allTasks, referenceDate: today);

      // In "Tomorrow" (6 Sep 2026): Only task1 (16:00) should be present, not task2 (23:00)
      expect(grouped[UpcomingSection.tomorrow]!.length, 1);
      expect(grouped[UpcomingSection.tomorrow]!.first.id, 'task_1');
      expect(grouped[UpcomingSection.tomorrow]!.first.dateTime, DateTime(2026, 9, 6, 16, 0));

      // In "This Week" (7 Sep 2026): Only task4 should be present, task3 (00:00) should be suppressed
      expect(grouped[UpcomingSection.thisWeek]!.length, 1);
      expect(grouped[UpcomingSection.thisWeek]!.first.id, 'task_4');
      expect(grouped[UpcomingSection.thisWeek]!.first.title, 'ส่งงานโจให้เพื่อน');
    });

    test('when earlier task is completed, next recurring instance appears', () {
      final task1Completed = Task(
        id: 'task_1',
        title: 'แก้แอป',
        creatorId: 'user_1',
        createdAt: today,
        dateTime: DateTime(2026, 9, 6, 16, 0),
        status: TaskStatus.completed,
      );

      final task2 = Task(
        id: 'task_2',
        title: 'แก้แอป',
        creatorId: 'user_1',
        createdAt: today,
        dateTime: DateTime(2026, 9, 6, 23, 0),
      );

      final task3 = Task(
        id: 'task_3',
        title: 'แก้แอป',
        creatorId: 'user_1',
        createdAt: today,
        dateTime: DateTime(2026, 9, 7, 0, 0),
      );

      final allTasks = [task1Completed, task2, task3];
      final grouped = groupUpcomingTasks(allTasks, referenceDate: today);

      // Now task_2 (23:00) is the closest active instance
      expect(grouped[UpcomingSection.tomorrow]!.length, 1);
      expect(grouped[UpcomingSection.tomorrow]!.first.id, 'task_2');
      expect(grouped[UpcomingSection.tomorrow]!.first.dateTime, DateTime(2026, 9, 6, 23, 0));
    });
  });

  group('HomeScreen Today & Overdue Recurring Tasks Collapsing', () {
    String taskSeriesKey(Task task) {
      if (!task.isRecurring) return task.id;
      final cleanTitle = task.title.trim().toLowerCase();
      final creator = task.creatorId;
      final type = task.type.name;
      final project = task.projectId ?? '';
      final recurrence = task.recurringType.trim();
      return '$creator|$type|$project|$cleanTitle|$recurrence';
    }

    List<Task> collapseRecurringTasks(
      List<Task> taskList, {
      Set<String>? excludeSeriesKeys,
    }) {
      final result = <Task>[];
      final seenKeys = <String>{...?excludeSeriesKeys};

      final sorted = List<Task>.from(taskList)
        ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

      for (final task in sorted) {
        if (!task.isRecurring) {
          result.add(task);
          continue;
        }
        final key = taskSeriesKey(task);
        if (seenKeys.contains(key)) {
          continue;
        }
        seenKeys.add(key);
        result.add(task);
      }

      return result;
    }

    test('collapses duplicate overdue recurring tasks to show only the single latest overdue card', () {
      final now = DateTime(2026, 9, 5, 12, 0);
      final overdueDay1 = Task(
        id: 'redogr_1',
        title: 'redogr',
        creatorId: 'user_1',
        createdAt: now.subtract(const Duration(days: 3)),
        dateTime: now.subtract(const Duration(days: 2)),
        isRecurring: true,
        recurringType: 'daily',
      );
      final overdueDay2 = Task(
        id: 'redogr_2',
        title: 'redogr',
        creatorId: 'user_1',
        createdAt: now.subtract(const Duration(days: 2)),
        dateTime: now.subtract(const Duration(days: 1)),
        isRecurring: true,
        recurringType: 'daily',
      );

      final collapsed = collapseRecurringTasks([overdueDay1, overdueDay2]);
      expect(collapsed.length, 1);
      expect(collapsed.first.id, 'redogr_2');
    });

    test('suppresses overdue recurring tasks if an active task for today already exists', () {
      final now = DateTime(2026, 9, 5, 12, 0);
      final todayTask = Task(
        id: 'redogr_today',
        title: 'redogr',
        creatorId: 'user_1',
        createdAt: now.subtract(const Duration(days: 1)),
        dateTime: now,
        isRecurring: true,
        recurringType: 'daily',
      );
      final overdueDay1 = Task(
        id: 'redogr_old_1',
        title: 'redogr',
        creatorId: 'user_1',
        createdAt: now.subtract(const Duration(days: 3)),
        dateTime: now.subtract(const Duration(days: 2)),
        isRecurring: true,
        recurringType: 'daily',
      );
      final overdueDay2 = Task(
        id: 'redogr_old_2',
        title: 'redogr',
        creatorId: 'user_1',
        createdAt: now.subtract(const Duration(days: 2)),
        dateTime: now.subtract(const Duration(days: 1)),
        isRecurring: true,
        recurringType: 'daily',
      );

      final todayCollapsed = collapseRecurringTasks([todayTask]);
      expect(todayCollapsed.length, 1);
      expect(todayCollapsed.first.id, 'redogr_today');

      final todaySeriesKeys = todayCollapsed
          .where((t) => t.isRecurring)
          .map(taskSeriesKey)
          .toSet();

      final overdueCollapsed = collapseRecurringTasks(
        [overdueDay1, overdueDay2],
        excludeSeriesKeys: todaySeriesKeys,
      );

      // Overdue list should be empty because today already has the active redogr card
      expect(overdueCollapsed.isEmpty, true);
    });

    test('does not collapse different non-recurring tasks even if they have the same title', () {
      final now = DateTime(2026, 9, 5, 12, 0);
      final nonRecurring1 = Task(
        id: 'task_nr_1',
        title: 'ส่งเอกสาร',
        creatorId: 'user_1',
        createdAt: now,
        dateTime: now,
        isRecurring: false,
      );
      final nonRecurring2 = Task(
        id: 'task_nr_2',
        title: 'ส่งเอกสาร',
        creatorId: 'user_1',
        createdAt: now,
        dateTime: now.add(const Duration(hours: 1)),
        isRecurring: false,
      );

      final collapsed = collapseRecurringTasks([nonRecurring1, nonRecurring2]);
      expect(collapsed.length, 2);
    });
  });
}
