import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/task.dart';

enum TestUpcomingSection { tomorrow, thisWeek, nextWeek, later }

TestUpcomingSection? classifyTask(Task task, DateTime today) {
  final dueDate = DateTime(
    task.dateTime.year,
    task.dateTime.month,
    task.dateTime.day,
  );

  if (!dueDate.isAfter(today)) return null;

  final daysFromToday = dueDate.difference(today).inDays;
  if (daysFromToday == 1) return TestUpcomingSection.tomorrow;

  final endOfThisWeek = today.add(
    Duration(days: DateTime.sunday - today.weekday),
  );
  if (!dueDate.isAfter(endOfThisWeek)) return TestUpcomingSection.thisWeek;

  final endOfNextWeek = endOfThisWeek.add(const Duration(days: 7));
  if (!dueDate.isAfter(endOfNextWeek)) return TestUpcomingSection.nextWeek;

  return TestUpcomingSection.later;
}

void main() {
  group('Upcoming Tasks Calendar-based 4-Section Grouping Tests', () {
    test('Saturday scenario (Sep 12, 2026): Sep 14-19 correctly classifies into nextWeek, NOT thisWeek', () {
      final saturday = DateTime(2026, 9, 12);

      final taskTomorrowSunday = Task(
        id: 't_tomorrow',
        title: 'งานพรุ่งนี้',
        creatorId: 'user_1',
        createdAt: saturday,
        dateTime: DateTime(2026, 9, 13, 10, 0),
      );

      final taskNextMonday = Task(
        id: 't_mon',
        title: 'งานวันจันทร์หน้า',
        creatorId: 'user_1',
        createdAt: saturday,
        dateTime: DateTime(2026, 9, 14, 10, 0),
      );

      final taskNextSaturday = Task(
        id: 't_sat',
        title: 'งานวันเสาร์หน้า',
        creatorId: 'user_1',
        createdAt: saturday,
        dateTime: DateTime(2026, 9, 19, 15, 0),
      );

      final taskNextSunday = Task(
        id: 't_sun',
        title: 'งานวันอาทิตย์หน้า',
        creatorId: 'user_1',
        createdAt: saturday,
        dateTime: DateTime(2026, 9, 20, 18, 0),
      );

      final taskLater = Task(
        id: 't_later',
        title: 'งานสองสัปดาห์หน้า',
        creatorId: 'user_1',
        createdAt: saturday,
        dateTime: DateTime(2026, 9, 21, 9, 0),
      );

      expect(classifyTask(taskTomorrowSunday, saturday), TestUpcomingSection.tomorrow);
      expect(classifyTask(taskNextMonday, saturday), TestUpcomingSection.nextWeek);
      expect(classifyTask(taskNextSaturday, saturday), TestUpcomingSection.nextWeek);
      expect(classifyTask(taskNextSunday, saturday), TestUpcomingSection.nextWeek);
      expect(classifyTask(taskLater, saturday), TestUpcomingSection.later);
    });

    test('Sunday scenario (Sep 13, 2026): Monday is tomorrow, Tue-Sun is nextWeek, following week is later', () {
      final sunday = DateTime(2026, 9, 13);

      final taskMon = Task(
        id: 't_mon',
        title: 'งานวันจันทร์',
        creatorId: 'user_1',
        createdAt: sunday,
        dateTime: DateTime(2026, 9, 14, 8, 0),
      );

      final taskTue = Task(
        id: 't_tue',
        title: 'งานวันอังคาร',
        creatorId: 'user_1',
        createdAt: sunday,
        dateTime: DateTime(2026, 9, 15, 8, 0),
      );

      final taskSunNext = Task(
        id: 't_sun',
        title: 'งานวันอาทิตย์หน้า',
        creatorId: 'user_1',
        createdAt: sunday,
        dateTime: DateTime(2026, 9, 20, 12, 0),
      );

      final taskLater = Task(
        id: 't_later',
        title: 'งานหลังจากนั้น',
        creatorId: 'user_1',
        createdAt: sunday,
        dateTime: DateTime(2026, 9, 21, 10, 0),
      );

      expect(classifyTask(taskMon, sunday), TestUpcomingSection.tomorrow);
      expect(classifyTask(taskTue, sunday), TestUpcomingSection.nextWeek);
      expect(classifyTask(taskSunNext, sunday), TestUpcomingSection.nextWeek);
      expect(classifyTask(taskLater, sunday), TestUpcomingSection.later);
    });

    test('Mid-week Wednesday scenario (Sep 9, 2026): Thursday is tomorrow, Fri-Sun is thisWeek, next Mon-Sun is nextWeek', () {
      final wednesday = DateTime(2026, 9, 9);

      final taskThu = Task(
        id: 't_thu',
        title: 'งานวันพฤหัสบดี',
        creatorId: 'user_1',
        createdAt: wednesday,
        dateTime: DateTime(2026, 9, 10, 9, 0),
      );

      final taskFri = Task(
        id: 't_fri',
        title: 'งานวันศุกร์นี้',
        creatorId: 'user_1',
        createdAt: wednesday,
        dateTime: DateTime(2026, 9, 11, 14, 0),
      );

      final taskSun = Task(
        id: 't_sun',
        title: 'งานวันอาทิตย์นี้',
        creatorId: 'user_1',
        createdAt: wednesday,
        dateTime: DateTime(2026, 9, 13, 20, 0),
      );

      final taskNextMon = Task(
        id: 't_next_mon',
        title: 'งานวันจันทร์หน้า',
        creatorId: 'user_1',
        createdAt: wednesday,
        dateTime: DateTime(2026, 9, 14, 9, 0),
      );

      final taskLater = Task(
        id: 't_later',
        title: 'งานถัดไป',
        creatorId: 'user_1',
        createdAt: wednesday,
        dateTime: DateTime(2026, 9, 22, 9, 0),
      );

      expect(classifyTask(taskThu, wednesday), TestUpcomingSection.tomorrow);
      expect(classifyTask(taskFri, wednesday), TestUpcomingSection.thisWeek);
      expect(classifyTask(taskSun, wednesday), TestUpcomingSection.thisWeek);
      expect(classifyTask(taskNextMon, wednesday), TestUpcomingSection.nextWeek);
      expect(classifyTask(taskLater, wednesday), TestUpcomingSection.later);
    });
  });
}
