import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:todo_app/config/colors.dart';
import 'package:todo_app/models/task.dart';
import 'package:todo_app/providers/task_provider.dart';
import 'package:todo_app/widgets/daily_timeline.dart';

class _FakeTaskProvider extends ChangeNotifier implements TaskProvider {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('DailyTimeline Completed Tasks Strikethrough Tests', () {
    testWidgets('renders green strikethrough for completed tasks and normal text for incomplete tasks',
        (WidgetTester tester) async {
      final now = DateTime.now();
      final completedTask = Task(
        id: '1',
        title: 'ส่งงานโจให้เพื่อน',
        description: 'ช้าๆ',
        dateTime: now,
        priority: Priority.urgent,
        status: TaskStatus.completed,
        creatorId: 'user1',
        createdAt: now,
      );

      final incompleteTask = Task(
        id: '2',
        title: 'แก้แอป',
        description: 'งานใหม่',
        dateTime: now,
        priority: Priority.low,
        status: TaskStatus.todo,
        creatorId: 'user1',
        createdAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChangeNotifierProvider<TaskProvider>(
              create: (_) => _FakeTaskProvider(),
              child: DailyTimeline(
                tasks: [completedTask, incompleteTask],
                date: now,
              ),
            ),
          ),
        ),
      );

      // Verify title of completed task has green strikethrough
      final completedTextFinder = find.text('ส่งงานโจให้เพื่อน');
      expect(completedTextFinder, findsOneWidget);

      final completedTextWidget =
          tester.widget<Text>(completedTextFinder);
      expect(completedTextWidget.style?.decoration, TextDecoration.lineThrough);
      expect(
        completedTextWidget.style?.decorationColor,
        AppColors.primaryGreen,
      );
      expect(completedTextWidget.style?.decorationThickness, 2.0);

      // Verify title of incomplete task does NOT have strikethrough
      final incompleteTextFinder = find.text('แก้แอป');
      expect(incompleteTextFinder, findsOneWidget);

      final incompleteTextWidget =
          tester.widget<Text>(incompleteTextFinder);
      expect(incompleteTextWidget.style?.decoration, isNull);
    });
  });
}
