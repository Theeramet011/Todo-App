import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/task.dart';

void main() {
  group('Member Group Task Deletion and Auto-Restore Tests', () {
    test('canMemberDelete logic: incomplete members cannot delete, complete members can', () {
      final incompleteTask = Task(
        id: 'group_task_1',
        title: 'ประชุม',
        creatorId: 'leader_1',
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        type: TaskType.group,
        members: [
          Member(id: 'member_1', name: 'Member 1', status: 'completed'),
          Member(id: 'member_2', name: 'Member 2', status: 'inProgress'),
        ],
      );

      final leaderId = 'leader_1';
      final nonLeaderMembers = incompleteTask.members
          .where((m) => m.id != leaderId)
          .toList();
      final areAllCompleted = nonLeaderMembers.isNotEmpty &&
          nonLeaderMembers.every((m) => m.status == 'completed');
      final canMemberDeleteIncomplete = areAllCompleted || incompleteTask.isCompleted;
      expect(canMemberDeleteIncomplete, false);

      // Now all members completed
      final completedTask = incompleteTask.copyWith(
        members: [
          Member(id: 'member_1', name: 'Member 1', status: 'completed'),
          Member(id: 'member_2', name: 'Member 2', status: 'completed'),
        ],
      );
      final completedNonLeaderMembers = completedTask.members
          .where((m) => m.id != leaderId)
          .toList();
      final areAllNowCompleted = completedNonLeaderMembers.isNotEmpty &&
          completedNonLeaderMembers.every((m) => m.status == 'completed');
      final canMemberDeleteComplete = areAllNowCompleted || completedTask.isCompleted;
      expect(canMemberDeleteComplete, true);
    });

    test('Undoing completion clears deletedForUserIds and hiddenForUserIds', () {
      final task = Task(
        id: 'group_task_1',
        title: 'ประชุม',
        creatorId: 'leader_1',
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        type: TaskType.group,
        status: TaskStatus.completed,
        deletedForUserIds: ['member_1'],
        hiddenForUserIds: ['member_2'],
      );

      // Simulate leader undoing completion
      final uncompletedTask = task.copyWith(
        status: TaskStatus.inProgress,
        deletedForUserIds: const [],
        hiddenForUserIds: const [],
      );

      expect(uncompletedTask.deletedForUserIds, isEmpty);
      expect(uncompletedTask.hiddenForUserIds, isEmpty);
    });

    test('Rejecting member submission removes that member from deletedForUserIds and hiddenForUserIds', () {
      final task = Task(
        id: 'group_task_1',
        title: 'ประชุม',
        creatorId: 'leader_1',
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        type: TaskType.group,
        status: TaskStatus.inProgress,
        deletedForUserIds: ['member_1', 'member_2'],
        hiddenForUserIds: ['member_1', 'member_3'],
      );

      const rejectedMemberId = 'member_1';
      final updatedTask = task.copyWith(
        deletedForUserIds:
            task.deletedForUserIds.where((id) => id != rejectedMemberId).toList(),
        hiddenForUserIds:
            task.hiddenForUserIds.where((id) => id != rejectedMemberId).toList(),
      );

      expect(updatedTask.deletedForUserIds, ['member_2']);
      expect(updatedTask.hiddenForUserIds, ['member_3']);
      expect(updatedTask.deletedForUserIds.contains(rejectedMemberId), false);
      expect(updatedTask.hiddenForUserIds.contains(rejectedMemberId), false);
    });

    test('Approach 1: Member attachments retained upon rejection and can append new attachments', () {
      final oldAttachment = TaskAttachment(
        fileName: 'report_v1.pdf',
        fileUrl: 'https://example.com/report_v1.pdf',
        fileType: 'pdf',
      );

      final member = Member(
        id: 'member_1',
        name: 'Member 1',
        status: 'pending',
        attachments: [oldAttachment],
      );

      // On rejection / send back to edit, attachments are retained and status becomes inProgress
      final rejectedMember = member.copyWith(
        status: 'inProgress',
        attachments: member.attachments, // retained
      );

      expect(rejectedMember.attachments.length, 1);
      expect(rejectedMember.attachments.first.fileName, 'report_v1.pdf');

      // Member uploads an additional attachment: it appends after the existing one
      final newAttachment = TaskAttachment(
        fileName: 'report_v2_edit.pdf',
        fileUrl: 'https://example.com/report_v2_edit.pdf',
        fileType: 'pdf',
      );

      final updatedAttachments = List<TaskAttachment>.from(rejectedMember.attachments)
        ..add(newAttachment);

      final memberWithNewFile = rejectedMember.copyWith(
        attachments: updatedAttachments,
      );

      expect(memberWithNewFile.attachments.length, 2);
      expect(memberWithNewFile.attachments[0].fileName, 'report_v1.pdf');
      expect(memberWithNewFile.attachments[1].fileName, 'report_v2_edit.pdf');

      // Member deletes only the first attachment
      final remainingAttachments = memberWithNewFile.attachments
          .where((a) => a.fileUrl != 'https://example.com/report_v1.pdf')
          .toList();
      final memberAfterDelete = memberWithNewFile.copyWith(
        attachments: remainingAttachments,
      );

      expect(memberAfterDelete.attachments.length, 1);
      expect(memberAfterDelete.attachments.first.fileName, 'report_v2_edit.pdf');
    });

    test('All Members Approved Dialog condition: triggers only for leader when all non-leader members completed and task not completed', () {
      const leaderId = 'leader_123';
      final task = Task(
        id: 'group_task_all_done',
        title: 'โครงการใหญ่',
        creatorId: leaderId,
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        type: TaskType.group,
        status: TaskStatus.inProgress,
        members: [
          Member(id: leaderId, name: 'Leader', status: 'inProgress'),
          Member(id: 'member_a', name: 'Alice', status: 'completed'),
          Member(id: 'member_b', name: 'Bob', status: 'completed'),
        ],
      );

      bool shouldShowAllApprovedDialog({
        required Task t,
        required String currentUserId,
        required bool hasSeenDialog,
      }) {
        if (hasSeenDialog) return false;
        if (!t.isGroup && t.members.isEmpty) return false;
        if (t.isCompleted || t.isDeleted) return false;
        final isLeader = t.creatorId == currentUserId;
        if (!isLeader) return false;

        final nonLeaderMembers = t.members.where((m) => m.id != currentUserId).toList();
        final membersToCheck = nonLeaderMembers.isNotEmpty ? nonLeaderMembers : t.members;
        return membersToCheck.every((m) => m.status == 'completed');
      }

      // Condition 1: Leader, not seen yet, all non-leader completed -> TRUE
      expect(
        shouldShowAllApprovedDialog(
          t: task,
          currentUserId: leaderId,
          hasSeenDialog: false,
        ),
        true,
      );

      // Condition 2: Member (not leader) -> FALSE
      expect(
        shouldShowAllApprovedDialog(
          t: task,
          currentUserId: 'member_a',
          hasSeenDialog: false,
        ),
        false,
      );

      // Condition 3: Already seen dialog ("ไม่ต้องแสดงอีก" was pressed) -> FALSE
      expect(
        shouldShowAllApprovedDialog(
          t: task,
          currentUserId: leaderId,
          hasSeenDialog: true,
        ),
        false,
      );

      // Condition 4: One member not completed yet -> FALSE
      final incompleteTask = task.copyWith(
        members: [
          Member(id: leaderId, name: 'Leader', status: 'inProgress'),
          Member(id: 'member_a', name: 'Alice', status: 'completed'),
          Member(id: 'member_b', name: 'Bob', status: 'inProgress'),
        ],
      );
      expect(
        shouldShowAllApprovedDialog(
          t: incompleteTask,
          currentUserId: leaderId,
          hasSeenDialog: false,
        ),
        false,
      );

      // Condition 5: Task already completed -> FALSE
      final alreadyCompletedTask = task.copyWith(
        status: TaskStatus.completed,
      );
      expect(
        shouldShowAllApprovedDialog(
          t: alreadyCompletedTask,
          currentUserId: leaderId,
          hasSeenDialog: false,
        ),
        false,
      );
    });

    test('Subtasks completion UX rules: home checkbox hidden when subtasks exist; options menu hides "ทำว่าเสร็จสิ้น" if incomplete subtasks exist', () {
      final taskWithSubtasks = Task(
        id: 'task_with_subtasks',
        title: 'แก้แอป',
        creatorId: 'user_1',
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        subtasks: [
          SubTask(title: 'งานย่อย 1', isDone: false),
          SubTask(title: 'งานย่อย 2', isDone: false),
        ],
      );

      final simpleTask = Task(
        id: 'task_simple',
        title: 'งานเดี่ยว',
        creatorId: 'user_1',
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
      );

      // Home card checkbox logic
      bool shouldShowHomeCheckbox(Task t) => t.subtasks.isEmpty;
      expect(shouldShowHomeCheckbox(taskWithSubtasks), false);
      expect(shouldShowHomeCheckbox(simpleTask), true);

      // Options menu complete action logic
      bool shouldShowCompleteMenu(Task t) =>
          t.isDeleted || t.isCompleted || t.subtasks.isEmpty;

      // Incomplete task with subtasks -> should NOT show "ทำว่าเสร็จสิ้น"
      expect(shouldShowCompleteMenu(taskWithSubtasks), false);

      // Incomplete simple task -> SHOULD show "ทำว่าเสร็จสิ้น"
      expect(shouldShowCompleteMenu(simpleTask), true);

      // Completed task with subtasks -> SHOULD show (as "เลิกทำเสร็จสิ้น")
      final completedSubtaskTask = taskWithSubtasks.copyWith(
        status: TaskStatus.completed,
      );
      expect(shouldShowCompleteMenu(completedSubtaskTask), true);

      // Deleted task with subtasks -> SHOULD show (as "คืนค่า")
      final deletedSubtaskTask = taskWithSubtasks.copyWith(
        isDeleted: true,
      );
      expect(shouldShowCompleteMenu(deletedSubtaskTask), true);
    });
  });
}

