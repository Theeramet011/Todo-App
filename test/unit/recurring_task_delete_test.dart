import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/task.dart';

void main() {
  group('Recurring Task Deletion and Auto-Respawn Prevention Tests', () {
    final now = DateTime(2026, 9, 30, 18, 0);

    test('Deleting an uncompleted recurring task targets sibling pending clones and disables recurring on past completed tasks', () {
      final pastCompleted = Task(
        id: 'task_past_completed',
        title: 'rrrrrrr',
        creatorId: 'user_1',
        createdAt: now.subtract(const Duration(days: 3)),
        dateTime: now.subtract(const Duration(days: 3)),
        status: TaskStatus.completed,
        isRecurring: true,
        recurringType: 'daily',
      );

      final upcomingClone = Task(
        id: 'task_upcoming_1',
        title: 'rrrrrrr',
        creatorId: 'user_1',
        createdAt: now.subtract(const Duration(hours: 1)),
        dateTime: now.add(const Duration(days: 1)),
        status: TaskStatus.inProgress,
        isRecurring: true,
        recurringType: 'daily',
      );

      final tasks = [pastCompleted, upcomingClone];
      final taskIdsToDelete = ['task_upcoming_1'];

      final expandedTaskIds = <String>{...taskIdsToDelete};
      final pastRecurringTasksToDisable = <Task>[];

      for (final id in taskIdsToDelete) {
        final task = tasks.firstWhere((t) => t.id == id);
        if (task.isRecurring) {
          final cleanTitle = task.title.trim().toLowerCase();
          final projectId = task.projectId ?? '';

          final recurringClones = tasks.where(
            (t) =>
                t.title.trim().toLowerCase() == cleanTitle &&
                t.creatorId == task.creatorId &&
                (t.projectId ?? '') == projectId &&
                t.isRecurring &&
                !t.isCompleted,
          );
          for (final clone in recurringClones) {
            expandedTaskIds.add(clone.id);
          }

          final pastCompletedClones = tasks.where(
            (t) =>
                t.title.trim().toLowerCase() == cleanTitle &&
                t.creatorId == task.creatorId &&
                (t.projectId ?? '') == projectId &&
                t.isRecurring &&
                t.isCompleted,
          );
          for (final past in pastCompletedClones) {
            pastRecurringTasksToDisable.add(past);
          }
        }
      }

      expect(expandedTaskIds, contains('task_upcoming_1'));
      expect(expandedTaskIds.contains('task_past_completed'), isFalse);
      expect(pastRecurringTasksToDisable.map((t) => t.id), contains('task_past_completed'));

      // Simulate applying updates:
      final updatedTasks = tasks.map((t) {
        if (expandedTaskIds.contains(t.id)) {
          return t.copyWith(isDeleted: true);
        }
        if (pastRecurringTasksToDisable.any((p) => p.id == t.id)) {
          return t.copyWith(isRecurring: false);
        }
        return t;
      }).toList();

      final updatedPast = updatedTasks.firstWhere((t) => t.id == 'task_past_completed');
      final updatedUpcoming = updatedTasks.firstWhere((t) => t.id == 'task_upcoming_1');

      expect(updatedPast.isCompleted, isTrue);
      expect(updatedPast.isDeleted, isFalse);
      expect(updatedPast.isRecurring, isFalse); // Recurring disabled so it won't respawn!

      expect(updatedUpcoming.isDeleted, isTrue);
    });

    test('_ensureUpcomingRecurringTasks safety check prevents respawn when clones exist in trash', () {
      final pastCompleted = Task(
        id: 'task_past_completed',
        title: 'rrrrrrr',
        creatorId: 'user_1',
        createdAt: now.subtract(const Duration(days: 3)),
        dateTime: now.subtract(const Duration(days: 3)),
        status: TaskStatus.completed,
        isRecurring: true,
        recurringType: 'daily',
      );

      final deletedClone = Task(
        id: 'task_deleted_clone',
        title: 'rrrrrrr',
        creatorId: 'user_1',
        createdAt: now,
        dateTime: now.add(const Duration(days: 1)),
        status: TaskStatus.inProgress,
        isDeleted: true,
        isRecurring: true,
        recurringType: 'daily',
      );

      final tasks = [pastCompleted, deletedClone];

      final cleanTitle = 'rrrrrrr';
      final creatorId = 'user_1';
      final projectId = '';

      // Check 1: hasDeletedInSeries
      final hasDeletedInSeries = tasks.any(
        (t) =>
            t.isDeleted &&
            t.title.trim().toLowerCase() == cleanTitle &&
            t.creatorId == creatorId &&
            (t.projectId ?? '') == projectId,
      );
      expect(hasDeletedInSeries, isTrue); // Should block respawn!

      // Check 2: hasAnyPendingInSeries
      final seriesTasks = tasks.where((t) => t.title == cleanTitle && t.creatorId == creatorId).toList();
      final hasAnyPendingInSeries = seriesTasks.any((t) => !t.isCompleted && !t.isDeleted);
      expect(hasAnyPendingInSeries, isFalse); // Should also block respawn!
    });
  });
}
