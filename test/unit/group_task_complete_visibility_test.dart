import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/task.dart';
import 'package:todo_app/providers/task_provider.dart';

bool canShowToggle({
  required bool isLeader,
  required bool isCompleted,
  required bool areAllCompleted,
}) {
  return isLeader && (isCompleted || areAllCompleted);
}

void main() {
  group('Group Task Complete Toggle Visibility Tests', () {
    test('Personal task always considers all members completed (returns true)', () {
      final personalTask = Task(
        id: 'personal_1',
        title: 'อ่านหนังสือ',
        creatorId: 'user_1',
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        type: TaskType.personal,
      );

      expect(
        TaskProvider.checkAllGroupMembersCompleted(
          task: personalTask,
          leaderId: 'user_1',
        ),
        isTrue,
      );
    });

    test('Group task with members inProgress returns false for areAllGroupMembersCompleted', () {
      final groupTask = Task(
        id: 'group_1',
        title: 'ทำโปรเจกต์',
        creatorId: 'leader_1',
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        type: TaskType.group,
        members: [
          Member(id: 'leader_1', name: 'Leader', status: 'inProgress'),
          Member(id: 'member_1', name: 'Member 1', status: 'completed'),
          Member(id: 'member_2', name: 'Member 2', status: 'inProgress'),
        ],
      );

      final areAllCompleted = TaskProvider.checkAllGroupMembersCompleted(
        task: groupTask,
        leaderId: 'leader_1',
      );
      expect(areAllCompleted, isFalse);

      // For leader: canShowCompleteToggle = isCompleted || areAllCompleted
      expect(
        canShowToggle(
          isLeader: true,
          isCompleted: groupTask.isCompleted,
          areAllCompleted: areAllCompleted,
        ),
        isFalse,
      );
    });

    test('Group task with all non-leader members completed returns true and shows toggle_complete', () {
      final groupTask = Task(
        id: 'group_2',
        title: 'ทำโปรเจกต์',
        creatorId: 'leader_1',
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        type: TaskType.group,
        members: [
          Member(id: 'leader_1', name: 'Leader', status: 'inProgress'),
          Member(id: 'member_1', name: 'Member 1', status: 'completed'),
          Member(id: 'member_2', name: 'Member 2', status: 'completed'),
        ],
      );

      final areAllCompleted = TaskProvider.checkAllGroupMembersCompleted(
        task: groupTask,
        leaderId: 'leader_1',
      );
      expect(areAllCompleted, isTrue);

      // Leader can now see toggle_complete ("ทำว่าเสร็จสิ้น")
      expect(
        canShowToggle(
          isLeader: true,
          isCompleted: groupTask.isCompleted,
          areAllCompleted: areAllCompleted,
        ),
        isTrue,
      );

      // Non-leader member can never see toggle_complete
      expect(
        canShowToggle(
          isLeader: false,
          isCompleted: groupTask.isCompleted,
          areAllCompleted: areAllCompleted,
        ),
        isFalse,
      );
    });

    test('Completed group task always allows leader to see toggle_complete (undo)', () {
      final completedGroupTask = Task(
        id: 'group_3',
        title: 'ทำโปรเจกต์เสร็จแล้ว',
        creatorId: 'leader_1',
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        type: TaskType.group,
        status: TaskStatus.completed,
        members: [
          Member(id: 'leader_1', name: 'Leader', status: 'completed'),
          Member(id: 'member_1', name: 'Member 1', status: 'inProgress'),
        ],
      );

      final areAllCompleted = TaskProvider.checkAllGroupMembersCompleted(
        task: completedGroupTask,
        leaderId: 'leader_1',
      );

      expect(
        canShowToggle(
          isLeader: true,
          isCompleted: completedGroupTask.isCompleted,
          areAllCompleted: areAllCompleted,
        ),
        isTrue,
      );
    });

    test('Group task with empty members checks submission / completion status', () {
      final emptyGroupTaskUnsubmitted = Task(
        id: 'group_4',
        title: 'งานกลุ่มเดี่ยว',
        creatorId: 'leader_1',
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        type: TaskType.group,
        members: const [],
      );

      expect(
        TaskProvider.checkAllGroupMembersCompleted(
          task: emptyGroupTaskUnsubmitted,
          leaderId: 'leader_1',
        ),
        isFalse,
      );

      final emptyGroupTaskSubmitted = emptyGroupTaskUnsubmitted.copyWith(
        submissionText: 'ส่งรายงานสรุปแล้ว',
      );

      expect(
        TaskProvider.checkAllGroupMembersCompleted(
          task: emptyGroupTaskSubmitted,
          leaderId: 'leader_1',
        ),
        isTrue,
      );
    });
  });
}
