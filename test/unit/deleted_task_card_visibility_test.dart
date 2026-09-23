import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/task.dart';

/// Logic used in TaskDetailScreen:
/// `if (currentTask.isDeleted && currentTask.isGroup && !isLeader) _buildDeletedTaskCard(),`
bool shouldShowDeletedTaskCard({
  required Task task,
  required bool isLeader,
}) {
  return task.isDeleted && task.isGroup && !isLeader;
}

void main() {
  group('Deleted Task Card Visibility Tests', () {
    test('Personal deleted task should NEVER show the deleted card', () {
      final personalDeletedTask = Task(
        id: 'task_personal_1',
        title: 'งานส่วนตัวที่ถูกลบ',
        creatorId: 'user_1',
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        type: TaskType.personal,
        isDeleted: true,
      );

      // Regardless of leader status, personal tasks never show the card
      expect(
        shouldShowDeletedTaskCard(task: personalDeletedTask, isLeader: true),
        isFalse,
      );
      expect(
        shouldShowDeletedTaskCard(task: personalDeletedTask, isLeader: false),
        isFalse,
      );
    });

    test('Group deleted task should NOT show the card for the leader', () {
      final groupDeletedTask = Task(
        id: 'task_group_1',
        title: 'งานกลุ่มที่ถูกลบ',
        creatorId: 'leader_1',
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        type: TaskType.group,
        isDeleted: true,
      );

      // Leader deleted the task themselves, so it should not show
      expect(
        shouldShowDeletedTaskCard(task: groupDeletedTask, isLeader: true),
        isFalse,
      );
    });

    test('Group deleted task MUST show the card for members', () {
      final groupDeletedTask = Task(
        id: 'task_group_1',
        title: 'งานกลุ่มที่ถูกลบ',
        creatorId: 'leader_1',
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        type: TaskType.group,
        isDeleted: true,
        members: const [
          Member(id: 'leader_1', name: 'Leader'),
          Member(id: 'member_1', name: 'Member 1'),
        ],
      );

      // Member didn't delete the task and needs to know why submission/commenting is disabled
      expect(
        shouldShowDeletedTaskCard(task: groupDeletedTask, isLeader: false),
        isTrue,
      );
    });

    test('Active (non-deleted) tasks should never show the deleted card', () {
      final activeGroupTask = Task(
        id: 'task_group_active',
        title: 'งานกลุ่มปกติ',
        creatorId: 'leader_1',
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        type: TaskType.group,
        isDeleted: false,
      );

      expect(
        shouldShowDeletedTaskCard(task: activeGroupTask, isLeader: false),
        isFalse,
      );
      expect(
        shouldShowDeletedTaskCard(task: activeGroupTask, isLeader: true),
        isFalse,
      );
    });
  });
}
