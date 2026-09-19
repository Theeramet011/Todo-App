import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/task.dart';

String taskSeriesKey(Task task) {
  if (!task.isRecurring) return task.id;
  final cleanTitle = task.title.trim().toLowerCase();
  final creator = task.creatorId;
  final type = task.type.name;
  final project = task.projectId ?? '';
  return '$creator|$type|$project|$cleanTitle';
}

void main() {
  group('Recurring Task Sync & Deduplication Logic Tests', () {
    final now = DateTime(2026, 9, 18, 10, 0); // Friday

    test('taskSeriesKey matches across different recurringTypes for the same task series', () {
      final dailyTask = Task(
        id: 'task_daily',
        title: 'ลำดับความสำคัญปานกลาง(ทุกวัน)',
        creatorId: 'user_1',
        createdAt: now,
        dateTime: DateTime(2026, 9, 18, 11, 0),
        isRecurring: true,
        recurringType: 'daily',
      );

      final customTask = Task(
        id: 'task_custom',
        title: 'ลำดับความสำคัญปานกลาง(ทุกวัน) ', // trailing space
        creatorId: 'user_1',
        createdAt: now,
        dateTime: DateTime(2026, 9, 18, 11, 0),
        isRecurring: true,
        recurringType: 'custom',
        customRecurringDays: const ['ศ.', 'ส.'],
      );

      expect(taskSeriesKey(dailyTask), equals(taskSeriesKey(customTask)));
    });

    test('Identifies duplicate recurring tasks with exact same date/time moment', () {
      final task1 = Task(
        id: 'task_1',
        title: 'ลำดับความสำคัญปานกลาง(ทุกวัน)',
        creatorId: 'user_1',
        createdAt: now.subtract(const Duration(hours: 2)),
        dateTime: DateTime(2026, 9, 18, 11, 0),
        isRecurring: true,
        recurringType: 'daily',
      );

      final task2 = Task(
        id: 'task_2',
        title: 'ลำดับความสำคัญปานกลาง(ทุกวัน)',
        creatorId: 'user_1',
        createdAt: now,
        dateTime: DateTime(2026, 9, 18, 11, 0),
        isRecurring: true,
        recurringType: 'custom',
        customRecurringDays: const ['ศ.', 'ส.'],
      );

      final tasks = [task1, task2];
      final Map<String, List<Task>> grouped = {};
      for (final t in tasks) {
        final key =
            '${t.creatorId}|${t.projectId ?? ''}|${t.title.trim().toLowerCase()}|${t.dateTime.millisecondsSinceEpoch}';
        grouped.putIfAbsent(key, () => []).add(t);
      }

      expect(grouped.length, equals(1));
      final dups = grouped.values.first;
      expect(dups.length, equals(2));

      // Sort by createdAt descending: newest should be kept (task2)
      dups.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      expect(dups.first.id, equals('task_2'));
      expect(dups[1].id, equals('task_1')); // older duplicate to delete
    });

    test('Old future clone detection when recurrence rule changes', () {
      final updatedTask = Task(
        id: 'task_custom',
        title: 'ลำดับความสำคัญปานกลาง(ทุกวัน)',
        creatorId: 'user_1',
        createdAt: now,
        dateTime: DateTime(2026, 9, 18, 11, 0),
        isRecurring: true,
        recurringType: 'custom',
        customRecurringDays: const ['ศ.', 'ส.'],
      );

      // Old clone created for Monday (from daily rule) which is not in ['ศ.', 'ส.']
      final oldFutureClone = Task(
        id: 'task_old_future',
        title: 'ลำดับความสำคัญปานกลาง(ทุกวัน)',
        creatorId: 'user_1',
        createdAt: now.subtract(const Duration(days: 1)),
        dateTime: DateTime(2026, 9, 21, 11, 0), // Monday
        isRecurring: true,
        recurringType: 'daily',
      );

      final isSibling = oldFutureClone.id != updatedTask.id &&
          !oldFutureClone.isDeleted &&
          oldFutureClone.creatorId == updatedTask.creatorId &&
          (oldFutureClone.projectId ?? '') == (updatedTask.projectId ?? '') &&
          oldFutureClone.title.trim().toLowerCase() == updatedTask.title.trim().toLowerCase();

      expect(isSibling, isTrue);
      // Future clone should be cleaned up on recurrence update
      expect(oldFutureClone.dateTime.isAfter(now), isTrue);
    });

    test('Custom recurring on Mon & Tue: After Tuesday, next task jumps to next Monday (no Wednesday created)', () {
      const thaiWeekdays = {
        'อา.': 7,
        'จ.': 1,
        'อ.': 2,
        'พ.': 3,
        'พฤ.': 4,
        'ศ.': 5,
        'ส.': 6,
      };
      final days = ['จ.', 'อ.'];
      final targetWeekdays = days.map((d) => thaiWeekdays[d]).whereType<int>().toList()..sort();

      DateTime calculateNext(DateTime baseDate) {
        final remainingThisWeek = targetWeekdays.where((w) => w > baseDate.weekday).toList();
        if (remainingThisWeek.isNotEmpty) {
          final nextWeekday = remainingThisWeek.first;
          final daysUntilNext = nextWeekday - baseDate.weekday;
          return baseDate.add(Duration(days: daysUntilNext));
        } else {
          final firstWeekday = targetWeekdays.first;
          final daysToEndOfWeek = 7 - baseDate.weekday;
          final totalDaysToAdd = daysToEndOfWeek + firstWeekday;
          return baseDate.add(Duration(days: totalDaysToAdd));
        }
      }

      // Monday (2026-09-14)
      final monday = DateTime(2026, 9, 14, 10, 0);
      expect(monday.weekday, equals(DateTime.monday));
      final afterMonday = calculateNext(monday);
      // After Monday -> Tuesday (2026-09-15)
      expect(afterMonday.weekday, equals(DateTime.tuesday));
      expect(afterMonday, equals(DateTime(2026, 9, 15, 10, 0)));

      // Tuesday (2026-09-15)
      final tuesday = DateTime(2026, 9, 15, 10, 0);
      expect(tuesday.weekday, equals(DateTime.tuesday));
      final afterTuesday = calculateNext(tuesday);
      // After Tuesday -> Must NOT be Wednesday (2026-09-16)! Must jump to next Monday (2026-09-21)
      expect(afterTuesday.weekday, equals(DateTime.monday));
      expect(afterTuesday, equals(DateTime(2026, 9, 21, 10, 0)));
      expect(afterTuesday.difference(tuesday).inDays, equals(6));
    });

    test('calculateNextMatchingRecurringDate correctly calculates shift from Sunday 20 Sep to Monday 21 Sep', () {
      const thaiWeekdays = {
        'อา.': 7,
        'จ.': 1,
        'อ.': 2,
        'พ.': 3,
        'พฤ.': 4,
        'ศ.': 5,
        'ส.': 6,
      };

      DateTime? calculateNextMatching(DateTime baseDate, List<String> selectedDays, {int frequencyNum = 1}) {
        if (selectedDays.isEmpty) return null;
        final targetWeekdays =
            selectedDays.map((d) => thaiWeekdays[d]).whereType<int>().toList()..sort();
        if (targetWeekdays.isEmpty) return null;

        final currentWeekday = baseDate.weekday;
        if (targetWeekdays.contains(currentWeekday)) return null;

        final remainingThisWeek =
            targetWeekdays.where((w) => w > currentWeekday).toList();

        if (remainingThisWeek.isNotEmpty) {
          final nextWeekday = remainingThisWeek.first;
          final daysToAdd = nextWeekday - currentWeekday;
          return DateTime(baseDate.year, baseDate.month, baseDate.day + daysToAdd);
        } else {
          final firstWeekday = targetWeekdays.first;
          final daysToEndOfWeek = 7 - currentWeekday;
          final daysInInterval = (frequencyNum - 1) * 7;
          final totalDaysToAdd = daysToEndOfWeek + daysInInterval + firstWeekday;
          return DateTime(baseDate.year, baseDate.month, baseDate.day + totalDaysToAdd);
        }
      }

      // 1. Sunday (2026-09-20) changed to Monday ['จ.']
      final sunday20 = DateTime(2026, 9, 20);
      expect(sunday20.weekday, equals(DateTime.sunday));
      final nextMon = calculateNextMatching(sunday20, ['จ.']);
      expect(nextMon, isNotNull);
      expect(nextMon, equals(DateTime(2026, 9, 21)));
      expect(nextMon!.isAfter(sunday20), isTrue);

      // 2. Wednesday (2026-09-16) changed to Friday ['ศ.']
      final wed16 = DateTime(2026, 9, 16);
      expect(wed16.weekday, equals(DateTime.wednesday));
      final nextFri = calculateNextMatching(wed16, ['ศ.']);
      expect(nextFri, isNotNull);
      expect(nextFri, equals(DateTime(2026, 9, 18)));
      expect(nextFri!.isAfter(wed16), isTrue);

      // 3. Monday (2026-09-14) with days ['จ.', 'อ.'] -> Already matches Monday, returns null (no shift needed)
      final mon14 = DateTime(2026, 9, 14);
      expect(mon14.weekday, equals(DateTime.monday));
      final alreadyMatches = calculateNextMatching(mon14, ['จ.', 'อ.']);
      expect(alreadyMatches, isNull);

      // 4. Section check in upcoming tasks screen:
      // When today is Saturday (2026-09-19):
      final today = DateTime(2026, 9, 19);
      final endOfThisWeek = today.add(Duration(days: DateTime.sunday - today.weekday)); // Sunday 20 Sep
      final endOfNextWeek = endOfThisWeek.add(const Duration(days: 7)); // Sunday 27 Sep

      // Sunday 20 Sep is tomorrow (difference == 1 day)
      final daysFromToday = sunday20.difference(today).inDays;
      expect(daysFromToday, equals(1)); // Section: Tomorrow

      // Monday 21 Sep is in Next Week section (!isAfter(endOfNextWeek) && isAfter(endOfThisWeek))
      expect(nextMon.isAfter(endOfThisWeek), isTrue);
      expect(!nextMon.isAfter(endOfNextWeek), isTrue); // Section: Next Week
    });

    test('Option 3 logic: Suppresses dialog when date is changed to earlier day, or recurrence is unchanged', () {
      bool shouldShowRecurringShiftDialog({
        required DateTime originalTaskDate,
        required DateTime selectedDate,
        required bool originalIsRecurring,
        required String originalRecurringType,
        required List<String>? originalDays,
        required bool newIsRecurring,
        required String newRecurringType,
        required List<String> newDays,
        required DateTime? nextMatchingDate,
      }) {
        final originalDateOnly = DateTime(originalTaskDate.year, originalTaskDate.month, originalTaskDate.day);
        final selectedDateOnly = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

        // 1. If user deliberately picked an earlier date in calendar:
        final bool isDateChangedToEarlier = selectedDateOnly.isBefore(originalDateOnly);
        if (isDateChangedToEarlier) return false;

        // 2. If recurrence rule did not change:
        final bool isSameDays = (originalDays == null && newDays.isEmpty) ||
            (originalDays != null &&
                originalDays.length == newDays.length &&
                originalDays.every((d) => newDays.contains(d)));

        final bool isRecurrenceRuleChanged = originalIsRecurring != newIsRecurring ||
            originalRecurringType != newRecurringType ||
            !isSameDays;

        if (!isRecurrenceRuleChanged) return false;

        // 3. Only show when new matching date is AFTER current selected date:
        if (newIsRecurring && newRecurringType == 'custom' && newDays.isNotEmpty) {
          if (nextMatchingDate != null && nextMatchingDate.isAfter(selectedDate)) {
            return true;
          }
        }
        return false;
      }

      // Case A: User changes date back from Monday 21 Sep to Sunday 20 Sep
      // Should NOT show dialog! (Option 3 strict manual)
      final caseA = shouldShowRecurringShiftDialog(
        originalTaskDate: DateTime(2026, 9, 21, 16, 0),
        selectedDate: DateTime(2026, 9, 20, 16, 0), // earlier date chosen
        originalIsRecurring: true,
        originalRecurringType: 'custom',
        originalDays: ['จ.'],
        newIsRecurring: true,
        newRecurringType: 'custom',
        newDays: ['จ.'],
        nextMatchingDate: DateTime(2026, 9, 21),
      );
      expect(caseA, isFalse);

      // Case B: User edits text or priority, leaving recurrence days unchanged ('จ.' -> 'จ.')
      // Should NOT show dialog!
      final caseB = shouldShowRecurringShiftDialog(
        originalTaskDate: DateTime(2026, 9, 21, 16, 0),
        selectedDate: DateTime(2026, 9, 21, 16, 0),
        originalIsRecurring: true,
        originalRecurringType: 'custom',
        originalDays: ['จ.'],
        newIsRecurring: true,
        newRecurringType: 'custom',
        newDays: ['จ.'],
        nextMatchingDate: null,
      );
      expect(caseB, isFalse);

      // Case C: User edits task on Sunday 20 Sep, changes recurrence from daily to Monday ['จ.']
      // Should SHOW dialog! (As 21 Sep is after 20 Sep)
      final caseC = shouldShowRecurringShiftDialog(
        originalTaskDate: DateTime(2026, 9, 20, 16, 0),
        selectedDate: DateTime(2026, 9, 20, 16, 0),
        originalIsRecurring: true,
        originalRecurringType: 'daily',
        originalDays: null,
        newIsRecurring: true,
        newRecurringType: 'custom',
        newDays: ['จ.'],
        nextMatchingDate: DateTime(2026, 9, 21),
      );
      expect(caseC, isTrue);
    });
  });
}
