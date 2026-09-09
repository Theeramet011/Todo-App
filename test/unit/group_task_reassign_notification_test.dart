import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/task.dart';
import 'package:todo_app/models/project.dart';

void main() {
  group('Group Task Reassign Member Classification Tests', () {
    test('Existing project member reassigned is NOT classified as truly new member', () {
      final project = Project(
        id: 'proj_1',
        title: 'โครงงานวิทยาศาสตร์',
        memberIds: ['leader_1', 'member_alice', 'member_bob', 'member_charlie'],
        leaderId: 'leader_1',
        createdAt: DateTime.now(),
      );

      final previousTask = Task(
        id: 'task_1',
        title: 'ออกแบบหน้าจอ',
        creatorId: 'leader_1',
        projectId: 'proj_1',
        type: TaskType.group,
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        assigneeIds: ['member_alice'],
        members: [
          const Member(id: 'leader_1', name: 'Leader'),
          const Member(id: 'member_alice', name: 'Alice', taskTitle: 'UI Design'),
        ],
      );

      final updatedTask = Task(
        id: 'task_1',
        title: 'ออกแบบหน้าจอ',
        creatorId: 'leader_1',
        projectId: 'proj_1',
        type: TaskType.group,
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        assigneeIds: ['member_bob'],
        members: [
          const Member(id: 'leader_1', name: 'Leader'),
          const Member(id: 'member_bob', name: 'Bob', taskTitle: 'UI Design'),
        ],
      );

      final projectMemberIds = project.memberIds.map((id) => id.trim()).toSet();
      final previousTaskMemberIds = previousTask.members
          .map((m) => m.id.trim())
          .where((id) => id.isNotEmpty)
          .toSet();
      final existingGroupUserIds = {
        ...projectMemberIds,
        ...previousTaskMemberIds,
      };

      final previousMemberMap = <String, Member>{
        for (final m in previousTask.members)
          if (m.id.trim().isNotEmpty) m.id.trim(): m,
      };

      final reassignedMembers = <Member>[];
      final trulyNewMembers = <Member>[];

      for (final newM in updatedTask.members) {
        final memberId = newM.id.trim();
        if (memberId.isEmpty || memberId == 'leader_1') continue;

        final oldM = previousMemberMap[memberId];
        final newHasTask =
            newM.taskTitle != null && newM.taskTitle!.trim().isNotEmpty;
        final oldHasTask =
            oldM?.taskTitle != null && oldM!.taskTitle!.trim().isNotEmpty;

        if (oldM == null) {
          if (existingGroupUserIds.contains(memberId)) {
            reassignedMembers.add(newM);
          } else {
            trulyNewMembers.add(newM);
          }
        } else {
          if (newHasTask &&
              (!oldHasTask || oldM.taskTitle!.trim() != newM.taskTitle!.trim())) {
            reassignedMembers.add(newM);
          }
        }
      }

      expect(reassignedMembers.map((m) => m.id), contains('member_bob'));
      expect(trulyNewMembers.isEmpty, isTrue);
    });

    test('Member already in previousTask.members who gets newly assigned a task is classified as reassigned', () {
      // Both Alice and Bob were already in previousTask.members, but Bob had no taskTitle
      final previousTask = Task(
        id: 'task_1',
        title: 'redogrkk',
        creatorId: 'leader_1',
        type: TaskType.group,
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        members: [
          const Member(id: 'leader_1', name: 'Leader'),
          const Member(id: 'member_alice', name: 'Alice', taskTitle: 'Work A'),
          const Member(id: 'member_bob', name: 'Bob', taskTitle: ''),
        ],
      );

      // Leader transfers Work A to Bob, and Alice's task is cleared
      final updatedTask = Task(
        id: 'task_1',
        title: 'redogrkk',
        creatorId: 'leader_1',
        type: TaskType.group,
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        members: [
          const Member(id: 'leader_1', name: 'Leader'),
          const Member(id: 'member_alice', name: 'Alice', taskTitle: ''),
          const Member(id: 'member_bob', name: 'Bob', taskTitle: 'Work A'),
        ],
      );

      final previousMemberMap = <String, Member>{
        for (final m in previousTask.members)
          if (m.id.trim().isNotEmpty) m.id.trim(): m,
      };

      final reassignedMembers = <Member>[];
      for (final newM in updatedTask.members) {
        final memberId = newM.id.trim();
        if (memberId.isEmpty || memberId == 'leader_1') continue;

        final oldM = previousMemberMap[memberId];
        final newHasTask =
            newM.taskTitle != null && newM.taskTitle!.trim().isNotEmpty;
        final oldHasTask =
            oldM?.taskTitle != null && oldM!.taskTitle!.trim().isNotEmpty;

        if (oldM == null) {
          reassignedMembers.add(newM);
        } else {
          if (newHasTask &&
              (!oldHasTask || oldM.taskTitle!.trim() != newM.taskTitle!.trim())) {
            reassignedMembers.add(newM);
          }
        }
      }

      // Bob MUST be detected as reassigned member!
      expect(reassignedMembers.map((m) => m.id), contains('member_bob'));

      // Check unassigned detection: Alice still in members but taskTitle cleared
      final updatedMemberMap = <String, Member>{
        for (final m in updatedTask.members)
          if (m.id.trim().isNotEmpty) m.id.trim(): m,
      };

      final unassignedMemberIds = <String>{};
      for (final oldM in previousTask.members) {
        final oldId = oldM.id.trim();
        if (oldId.isEmpty || oldId == 'leader_1') continue;

        final oldHasTask =
            oldM.taskTitle != null && oldM.taskTitle!.trim().isNotEmpty;
        if (!oldHasTask) continue;

        final newM = updatedMemberMap[oldId];
        final newHasTask =
            newM?.taskTitle != null && newM!.taskTitle!.trim().isNotEmpty;

        if (newM == null || !newHasTask) {
          unassignedMemberIds.add(oldId);
        }
      }

      // Alice MUST be detected as unassigned!
      expect(unassignedMemberIds, contains('member_alice'));
    });

    test('Old assignee who was removed via X button is properly identified as unassigned', () {
      final previousTask = Task(
        id: 'task_1',
        title: 'งานกลุ่ม',
        creatorId: 'leader_1',
        type: TaskType.group,
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        members: [
          const Member(id: 'leader_1', name: 'Leader'),
          const Member(id: 'member_alice', name: 'Alice', taskTitle: 'Part 1'),
        ],
      );

      final updatedTask = Task(
        id: 'task_1',
        title: 'งานกลุ่ม',
        creatorId: 'leader_1',
        type: TaskType.group,
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        members: [
          const Member(id: 'leader_1', name: 'Leader'),
          const Member(id: 'member_bob', name: 'Bob', taskTitle: 'Part 1'),
        ],
      );

      final updatedMemberMap = <String, Member>{
        for (final m in updatedTask.members)
          if (m.id.trim().isNotEmpty) m.id.trim(): m,
      };

      final unassignedMemberIds = <String>{};
      for (final oldM in previousTask.members) {
        final oldId = oldM.id.trim();
        if (oldId.isEmpty || oldId == 'leader_1') continue;

        final oldHasTask =
            oldM.taskTitle != null && oldM.taskTitle!.trim().isNotEmpty;
        if (!oldHasTask) continue;

        final newM = updatedMemberMap[oldId];
        final newHasTask =
            newM?.taskTitle != null && newM!.taskTitle!.trim().isNotEmpty;

        if (newM == null || !newHasTask) {
          unassignedMemberIds.add(oldId);
        }
      }

      expect(unassignedMemberIds, contains('member_alice'));
    });

    test('Adding co-assignee correctly identifies coAssigneeAdded for helper and coAssigneeJoined for main assignee', () {
      // Alice initially works on 'jjj' alone
      final previousTask = Task(
        id: 'task_1',
        title: 'redogrkk',
        creatorId: 'leader_1',
        type: TaskType.group,
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        members: [
          const Member(id: 'leader_1', name: 'Leader'),
          const Member(id: 'member_alice', name: 'Alice', taskTitle: 'jjj', coAssigneeIds: []),
          const Member(id: 'member_bob', name: 'Bob', taskTitle: '', coAssigneeIds: []),
        ],
      );

      // Leader adds Bob as co-assignee to Alice's 'jjj' task
      final updatedTask = Task(
        id: 'task_1',
        title: 'redogrkk',
        creatorId: 'leader_1',
        type: TaskType.group,
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        members: [
          const Member(id: 'leader_1', name: 'Leader'),
          const Member(id: 'member_alice', name: 'Alice', taskTitle: 'jjj', coAssigneeIds: ['member_bob']),
          const Member(id: 'member_bob', name: 'Bob', taskTitle: 'jjj', coAssigneeIds: ['member_alice']),
        ],
      );

      final previousMemberMap = <String, Member>{
        for (final m in previousTask.members)
          if (m.id.trim().isNotEmpty) m.id.trim(): m,
      };

      final processedCoPairs = <String>{};
      final addedCoNotifications = <Map<String, dynamic>>[];

      for (final newM in updatedTask.members) {
        final mainId = newM.id.trim();
        if (mainId.isEmpty) continue;

        final oldM = previousMemberMap[mainId];
        final oldCoIds = (oldM?.coAssigneeIds ?? []).map((id) => id.trim()).toSet();
        final newCoIds = newM.coAssigneeIds.map((id) => id.trim()).toSet();
        final taskLabel = newM.taskTitle?.trim().isNotEmpty == true
            ? newM.taskTitle!.trim()
            : updatedTask.title;

        for (final coId in newCoIds) {
          if (coId.isEmpty || coId == mainId) continue;
          if (oldCoIds.contains(coId)) continue;

          final pairKey = '${([mainId, coId]..sort()).join('_')}_$taskLabel';
          if (processedCoPairs.contains(pairKey)) continue;
          processedCoPairs.add(pairKey);

          final oldCoM = previousMemberMap[coId];
          final mainHadTask = oldM != null && oldM.taskTitle != null && oldM.taskTitle!.trim() == taskLabel;
          final coHadTask = oldCoM != null && oldCoM.taskTitle != null && oldCoM.taskTitle!.trim() == taskLabel;

          String actualMainId = mainId;
          String actualCoId = coId;
          if (!mainHadTask && coHadTask) {
            actualMainId = coId;
            actualCoId = mainId;
          }

          addedCoNotifications.add({
            'mainId': actualMainId,
            'coId': actualCoId,
            'taskTitle': taskLabel,
          });
        }
      }

      expect(addedCoNotifications.length, 1);
      expect(addedCoNotifications.first['mainId'], 'member_alice');
      expect(addedCoNotifications.first['coId'], 'member_bob');
      expect(addedCoNotifications.first['taskTitle'], 'jjj');
    });

    test('Removing co-assignee correctly identifies coAssigneeRemoved for helper and coAssigneeLeft for main assignee', () {
      final previousTask = Task(
        id: 'task_1',
        title: 'redogrkk',
        creatorId: 'leader_1',
        type: TaskType.group,
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        members: [
          const Member(id: 'leader_1', name: 'Leader'),
          const Member(id: 'member_alice', name: 'Alice', taskTitle: 'jjj', coAssigneeIds: ['member_bob']),
          const Member(id: 'member_bob', name: 'Bob', taskTitle: 'jjj', coAssigneeIds: ['member_alice']),
        ],
      );

      // Leader removes Bob from co-assignees
      final updatedTask = Task(
        id: 'task_1',
        title: 'redogrkk',
        creatorId: 'leader_1',
        type: TaskType.group,
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        members: [
          const Member(id: 'leader_1', name: 'Leader'),
          const Member(id: 'member_alice', name: 'Alice', taskTitle: 'jjj', coAssigneeIds: []),
          const Member(id: 'member_bob', name: 'Bob', taskTitle: '', coAssigneeIds: []),
        ],
      );

      final previousMemberMap = <String, Member>{
        for (final m in previousTask.members)
          if (m.id.trim().isNotEmpty) m.id.trim(): m,
      };

      final processedCoPairs = <String>{};
      final removedCoNotifications = <Map<String, dynamic>>[];

      for (final newM in updatedTask.members) {
        final mainId = newM.id.trim();
        if (mainId.isEmpty) continue;

        final oldM = previousMemberMap[mainId];
        final oldCoIds = (oldM?.coAssigneeIds ?? []).map((id) => id.trim()).toSet();
        final newCoIds = newM.coAssigneeIds.map((id) => id.trim()).toSet();
        final taskLabel = oldM?.taskTitle?.trim().isNotEmpty == true
            ? oldM!.taskTitle!.trim()
            : updatedTask.title;

        for (final oldCoId in oldCoIds) {
          if (oldCoId.isEmpty || oldCoId == mainId) continue;
          if (newCoIds.contains(oldCoId)) continue;

          final pairKey =
              'removed_${([mainId, oldCoId]..sort()).join('_')}_$taskLabel';
          if (processedCoPairs.contains(pairKey)) continue;
          processedCoPairs.add(pairKey);

          final oldCoM = previousMemberMap[oldCoId];
          final mainHadTask = oldM != null && oldM.taskTitle != null && oldM.taskTitle!.trim() == taskLabel;
          final coHadTask = oldCoM != null && oldCoM.taskTitle != null && oldCoM.taskTitle!.trim() == taskLabel;

          String actualMainId = mainId;
          String actualCoId = oldCoId;
          if (!mainHadTask && coHadTask) {
            actualMainId = oldCoId;
            actualCoId = mainId;
          }

          removedCoNotifications.add({
            'mainId': actualMainId,
            'coId': actualCoId,
            'taskTitle': taskLabel,
          });
        }
      }

      expect(removedCoNotifications.length, 1);
      expect(removedCoNotifications.first['mainId'], 'member_alice');
      expect(removedCoNotifications.first['coId'], 'member_bob');
    });

    test('Helper removed from task A and reassigned to task B does not trigger false co-assignee removal for task B and gets assigned notification', () {
      // Alice and Bob collaborate on 'tt'
      final previousTask = Task(
        id: 'task_1',
        title: 'noti',
        creatorId: 'leader_1',
        type: TaskType.group,
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        members: [
          const Member(id: 'leader_1', name: 'Leader'),
          const Member(id: 'member_alice', name: 'Alice', taskTitle: 'tt', coAssigneeIds: ['member_bob']),
          const Member(id: 'member_bob', name: 'Bob', taskTitle: 'tt', coAssigneeIds: ['member_alice']),
        ],
      );

      // Leader removes Bob as helper from 'tt', and assigns Bob to task 'login' alone!
      final updatedTask = Task(
        id: 'task_1',
        title: 'noti',
        creatorId: 'leader_1',
        type: TaskType.group,
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        members: [
          const Member(id: 'leader_1', name: 'Leader'),
          const Member(id: 'member_alice', name: 'Alice', taskTitle: 'tt', coAssigneeIds: []),
          const Member(id: 'member_bob', name: 'Bob', taskTitle: 'login', coAssigneeIds: []),
        ],
      );

      final previousMemberMap = <String, Member>{
        for (final m in previousTask.members)
          if (m.id.trim().isNotEmpty) m.id.trim(): m,
      };
      final updatedMemberMap = <String, Member>{
        for (final m in updatedTask.members)
          if (m.id.trim().isNotEmpty) m.id.trim(): m,
      };

      // 1. Task-aware co-assignee detection:
      final previousCoPairs = <String, Map<String, dynamic>>{};
      for (final m in previousTask.members) {
        final mTitle = m.taskTitle?.trim() ?? '';
        final mId = m.id.trim();
        if (mTitle.isEmpty || mId.isEmpty) continue;
        for (final coId in m.coAssigneeIds.map((id) => id.trim())) {
          if (coId.isEmpty || coId == mId) continue;
          final pairUsers = [mId, coId]..sort();
          final pairKey = '$mTitle::${pairUsers[0]}_${pairUsers[1]}';
          if (!previousCoPairs.containsKey(pairKey)) {
            previousCoPairs[pairKey] = {
              'taskTitle': mTitle,
              'user1': pairUsers[0],
              'user2': pairUsers[1],
              'memberId': mId,
            };
          }
        }
      }

      final updatedCoPairs = <String, Map<String, dynamic>>{};
      for (final m in updatedTask.members) {
        final mTitle = m.taskTitle?.trim() ?? '';
        final mId = m.id.trim();
        if (mTitle.isEmpty || mId.isEmpty) continue;
        for (final coId in m.coAssigneeIds.map((id) => id.trim())) {
          if (coId.isEmpty || coId == mId) continue;
          final pairUsers = [mId, coId]..sort();
          final pairKey = '$mTitle::${pairUsers[0]}_${pairUsers[1]}';
          if (!updatedCoPairs.containsKey(pairKey)) {
            updatedCoPairs[pairKey] = {
              'taskTitle': mTitle,
              'user1': pairUsers[0],
              'user2': pairUsers[1],
              'memberId': mId,
            };
          }
        }
      }

      final removedCoNotifications = <Map<String, dynamic>>[];
      for (final entry in previousCoPairs.entries) {
        final pairKey = entry.key;
        if (updatedCoPairs.containsKey(pairKey)) continue;

        final item = entry.value;
        final taskTitle = item['taskTitle'] as String;
        final u1 = item['user1'] as String;
        final u2 = item['user2'] as String;

        final newM1 = updatedMemberMap[u1];
        final newM2 = updatedMemberMap[u2];
        final u1StillHasTask = newM1 != null && newM1.taskTitle?.trim() == taskTitle;
        final u2StillHasTask = newM2 != null && newM2.taskTitle?.trim() == taskTitle;

        String actualMainId = u1;
        String actualCoId = u2;
        if (!u1StillHasTask && u2StillHasTask) {
          actualMainId = u2;
          actualCoId = u1;
        } else if (!u1StillHasTask && !u2StillHasTask) {
          actualMainId = item['memberId'] as String;
          actualCoId = (actualMainId == u1) ? u2 : u1;
        }

        removedCoNotifications.add({
          'mainId': actualMainId,
          'coId': actualCoId,
          'taskTitle': taskTitle,
        });
      }

      // Must ONLY have removed notification for 'tt', NOT 'login'
      expect(removedCoNotifications.length, 1);
      expect(removedCoNotifications.first['taskTitle'], 'tt');
      expect(removedCoNotifications.first['mainId'], 'member_alice');
      expect(removedCoNotifications.first['coId'], 'member_bob');

      // 2. Bob MUST be detected in reassignedMembers and receive taskAssigned for 'login'
      final reassignedMembers = <Member>[];
      for (final newM in updatedTask.members) {
        final memberId = newM.id.trim();
        if (memberId.isEmpty || memberId == 'leader_1') continue;
        final oldM = previousMemberMap[memberId];
        final newHasTask = newM.taskTitle != null && newM.taskTitle!.trim().isNotEmpty;
        final oldHasTask = oldM?.taskTitle != null && oldM!.taskTitle!.trim().isNotEmpty;

        if (newHasTask && (!oldHasTask || oldM.taskTitle!.trim() != newM.taskTitle!.trim())) {
          reassignedMembers.add(newM);
        }
      }

      expect(reassignedMembers.map((m) => m.id), contains('member_bob'));
      final bobMember = reassignedMembers.firstWhere((m) => m.id == 'member_bob');
      expect(bobMember.taskTitle, 'login');
    });

    test('Member task details changed sends specific memberTaskUpdated and excludes member from group broadcast', () {
      final previousTask = Task(
        id: 'task_1',
        title: 'noti',
        creatorId: 'leader_1',
        type: TaskType.group,
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        members: [
          const Member(id: 'leader_1', name: 'Leader'),
          const Member(
            id: 'member_alice',
            name: 'Alice',
            taskTitle: 'Feature A',
            subTasks: ['step 1'],
            description: 'old desc',
          ),
          const Member(
            id: 'member_bob',
            name: 'Bob',
            taskTitle: 'Feature B',
            subTasks: ['step 1'],
          ),
        ],
      );

      // Leader updates Alice's subtasks and description, but taskTitle is unchanged
      final updatedTask = Task(
        id: 'task_1',
        title: 'noti',
        creatorId: 'leader_1',
        type: TaskType.group,
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        members: [
          const Member(id: 'leader_1', name: 'Leader'),
          const Member(
            id: 'member_alice',
            name: 'Alice',
            taskTitle: 'Feature A',
            subTasks: ['step 1', 'step 2 (new)'],
            description: 'new desc',
          ),
          const Member(
            id: 'member_bob',
            name: 'Bob',
            taskTitle: 'Feature B',
            subTasks: ['step 1'],
          ),
        ],
      );

      final previousMemberMap = <String, Member>{
        for (final m in previousTask.members)
          if (m.id.trim().isNotEmpty) m.id.trim(): m,
      };

      final memberDetailUpdatedRecipients = <String, String>{};
      final specificallyHandledMemberIds = <String>{};

      for (final newM in updatedTask.members) {
        final mid = newM.id.trim();
        if (mid.isEmpty || mid == 'leader_1') continue;

        final oldM = previousMemberMap[mid];
        if (oldM == null) continue;

        final oldHasTask = oldM.taskTitle != null && oldM.taskTitle!.trim().isNotEmpty;
        final newHasTask = newM.taskTitle != null && newM.taskTitle!.trim().isNotEmpty;

        if (oldHasTask && newHasTask && oldM.taskTitle!.trim() == newM.taskTitle!.trim()) {
          final subTasksChanged = oldM.subTasks.length != newM.subTasks.length ||
              oldM.subTasks.asMap().entries.any((e) =>
                  e.key >= newM.subTasks.length || e.value != newM.subTasks[e.key]);

          final detailsChanged = oldM.description != newM.description ||
              oldM.workload != newM.workload ||
              oldM.difficulty != newM.difficulty ||
              oldM.risk != newM.risk ||
              subTasksChanged;

          if (detailsChanged) {
            specificallyHandledMemberIds.add(mid);
            memberDetailUpdatedRecipients[mid] = newM.taskTitle!.trim();
          }
        }
      }

      // Alice receives specific member task update
      expect(memberDetailUpdatedRecipients.containsKey('member_alice'), isTrue);
      expect(memberDetailUpdatedRecipients['member_alice'], 'Feature A');

      // Bob's details did not change
      expect(memberDetailUpdatedRecipients.containsKey('member_bob'), isFalse);

      // Alice is excluded from general broadcast recipients
      final recipients = {'member_alice', 'member_bob'};
      recipients.removeAll(specificallyHandledMemberIds);
      expect(recipients.contains('member_alice'), isFalse);
      expect(recipients.contains('member_bob'), isTrue);
    });

    test('groupTaskUpdated is NOT triggered when only member is modified without overall task changes', () {
      final now = DateTime.now();
      final previousTask = Task(
        id: 'task_1',
        title: 'noti',
        description: 'same desc',
        dateTime: now,
        priority: Priority.low,
        category: 'General',
        location: 'Office',
        type: TaskType.group,
        creatorId: 'leader_1',
        createdAt: now,
        subtasks: [SubTask(title: 'Sub 1', isDone: false)],
        members: [
          const Member(id: 'leader_1', name: 'Leader'),
          const Member(id: 'member_alice', name: 'Alice', taskTitle: 'old task'),
        ],
      );

      // Leader only changes Alice's member task to 'new task', but leaves all overall task fields identical
      final updatedTask = Task(
        id: 'task_1',
        title: 'noti',
        description: 'same desc',
        dateTime: now,
        priority: Priority.low,
        category: 'General',
        location: 'Office',
        type: TaskType.group,
        creatorId: 'leader_1',
        createdAt: now,
        subtasks: [SubTask(title: 'Sub 1', isDone: false)],
        members: [
          const Member(id: 'leader_1', name: 'Leader'),
          const Member(id: 'member_alice', name: 'Alice', taskTitle: 'new task'),
        ],
      );

      final isSubtasksChanged =
          previousTask.subtasks.length != updatedTask.subtasks.length ||
          previousTask.subtasks.asMap().entries.any((e) =>
              e.key >= updatedTask.subtasks.length ||
              e.value.title != updatedTask.subtasks[e.key].title ||
              e.value.isDone != updatedTask.subtasks[e.key].isDone);

      final isTaskContentUpdated = previousTask.title.trim() != updatedTask.title.trim() ||
          previousTask.description.trim() != updatedTask.description.trim() ||
          !previousTask.dateTime.isAtSameMomentAs(updatedTask.dateTime) ||
          previousTask.priority != updatedTask.priority ||
          previousTask.category != updatedTask.category ||
          previousTask.location != updatedTask.location ||
          previousTask.isRecurring != updatedTask.isRecurring ||
          previousTask.recurringType != updatedTask.recurringType ||
          isSubtasksChanged;

      // When only member changes, isTaskContentUpdated must be FALSE
      expect(isTaskContentUpdated, isFalse);
    });

    test('groupTaskUpdated IS triggered when overall task fields (title, description, subtasks, etc.) are modified', () {
      final now = DateTime.now();
      final previousTask = Task(
        id: 'task_1',
        title: 'noti',
        description: 'old desc',
        dateTime: now,
        type: TaskType.group,
        creatorId: 'leader_1',
        createdAt: now,
        subtasks: [SubTask(title: 'Sub 1', isDone: false)],
        members: [
          const Member(id: 'leader_1', name: 'Leader'),
        ],
      );

      // 1. Changing overall task description
      final updatedWithDesc = previousTask.copyWith(description: 'new desc');
      expect(previousTask.description.trim() != updatedWithDesc.description.trim(), isTrue);

      // 2. Changing overall task subtasks
      final updatedWithSubtasks = previousTask.copyWith(
        subtasks: [
          SubTask(title: 'Sub 1', isDone: false),
          SubTask(title: 'Sub 2', isDone: false),
        ],
      );
      final isSubtasksChanged =
          previousTask.subtasks.length != updatedWithSubtasks.subtasks.length ||
          previousTask.subtasks.asMap().entries.any((e) =>
              e.key >= updatedWithSubtasks.subtasks.length ||
              e.value.title != updatedWithSubtasks.subtasks[e.key].title ||
              e.value.isDone != updatedWithSubtasks.subtasks[e.key].isDone);
      expect(isSubtasksChanged, isTrue);

      // 3. Changing overall task title
      final updatedWithTitle = previousTask.copyWith(title: 'new noti title');
      expect(previousTask.title.trim() != updatedWithTitle.title.trim(), isTrue);

      // 4. Changing overall task dateTime
      final updatedWithDate = previousTask.copyWith(dateTime: now.add(const Duration(days: 1)));
      expect(!previousTask.dateTime.isAtSameMomentAs(updatedWithDate.dateTime), isTrue);
    });

    test('Rescheduled notification (Option 3) formats messages correctly based on date/time changes', () {
      final baseDate = DateTime(2026, 8, 25, 15, 0); // 25/08/2026 15:00

      // Helper function matching TaskProvider logic
      Map<String, String> computeNotification({
        required DateTime oldDate,
        required DateTime newDate,
        required String actorName,
        required String taskTitle,
      }) {
        final isDateTimeChanged = !oldDate.isAtSameMomentAs(newDate);
        final isDateChanged = isDateTimeChanged &&
            (oldDate.year != newDate.year ||
                oldDate.month != newDate.month ||
                oldDate.day != newDate.day);
        final isTimeChanged = isDateTimeChanged &&
            (oldDate.hour != newDate.hour || oldDate.minute != newDate.minute);

        if (isDateChanged && isTimeChanged) {
          final dateStr = '${newDate.day.toString().padLeft(2, '0')}/${newDate.month.toString().padLeft(2, '0')}/${newDate.year}';
          final timeStr = '${newDate.hour.toString().padLeft(2, '0')}:${newDate.minute.toString().padLeft(2, '0')}';
          return {
            'title': '$actorName เปลี่ยนกำหนดเวลาภารกิจ "$taskTitle"',
            'body': 'กำหนดเวลาใหม่เป็นวันที่ $dateStr เวลา $timeStr น.',
            'stage': 'taskRescheduled',
          };
        } else if (isDateChanged) {
          final dateStr = '${newDate.day.toString().padLeft(2, '0')}/${newDate.month.toString().padLeft(2, '0')}/${newDate.year}';
          final timeStr = '${newDate.hour.toString().padLeft(2, '0')}:${newDate.minute.toString().padLeft(2, '0')}';
          return {
            'title': '$actorName เลื่อนวันส่งภารกิจ "$taskTitle"',
            'body': 'เลื่อนวันส่งใหม่เป็นวันที่ $dateStr (เวลา $timeStr น.)',
            'stage': 'taskDateUpdated',
          };
        } else if (isTimeChanged) {
          final dateStr = '${newDate.day.toString().padLeft(2, '0')}/${newDate.month.toString().padLeft(2, '0')}/${newDate.year}';
          final timeStr = '${newDate.hour.toString().padLeft(2, '0')}:${newDate.minute.toString().padLeft(2, '0')}';
          return {
            'title': '$actorName ปรับเวลาภารกิจ "$taskTitle"',
            'body': 'ปรับเวลาส่งใหม่เป็น $timeStr น. (วันที่ $dateStr)',
            'stage': 'taskTimeUpdated',
          };
        } else {
          return {
            'title': '$actorName แก้ไขภารกิจ "$taskTitle"',
            'body': '$actorName ได้แก้ไขรายละเอียดงานใหม่ เข้าไปเช็คเลย!',
            'stage': 'groupTaskUpdated',
          };
        }
      }

      // Case 1: Both Date and Time Changed
      final bothChanged = computeNotification(
        oldDate: baseDate,
        newDate: DateTime(2026, 8, 26, 17, 0),
        actorName: 'Pookub2',
        taskTitle: 'noti',
      );
      expect(bothChanged['title'], 'Pookub2 เปลี่ยนกำหนดเวลาภารกิจ "noti"');
      expect(bothChanged['body'], 'กำหนดเวลาใหม่เป็นวันที่ 26/08/2026 เวลา 17:00 น.');
      expect(bothChanged['stage'], 'taskRescheduled');

      // Case 2: Only Date Changed (Time identical)
      final dateOnlyChanged = computeNotification(
        oldDate: baseDate,
        newDate: DateTime(2026, 8, 26, 15, 0),
        actorName: 'Pookub2',
        taskTitle: 'noti',
      );
      expect(dateOnlyChanged['title'], 'Pookub2 เลื่อนวันส่งภารกิจ "noti"');
      expect(dateOnlyChanged['body'], 'เลื่อนวันส่งใหม่เป็นวันที่ 26/08/2026 (เวลา 15:00 น.)');
      expect(dateOnlyChanged['stage'], 'taskDateUpdated');

      // Case 3: Only Time Changed (Date identical)
      final timeOnlyChanged = computeNotification(
        oldDate: baseDate,
        newDate: DateTime(2026, 8, 25, 17, 0),
        actorName: 'Pookub2',
        taskTitle: 'noti',
      );
      expect(timeOnlyChanged['title'], 'Pookub2 ปรับเวลาภารกิจ "noti"');
      expect(timeOnlyChanged['body'], 'ปรับเวลาส่งใหม่เป็น 17:00 น. (วันที่ 25/08/2026)');
      expect(timeOnlyChanged['stage'], 'taskTimeUpdated');

      // Case 4: Neither Changed (e.g. general description update)
      final unchanged = computeNotification(
        oldDate: baseDate,
        newDate: baseDate,
        actorName: 'Pookub2',
        taskTitle: 'noti',
      );
      expect(unchanged['title'], 'Pookub2 แก้ไขภารกิจ "noti"');
      expect(unchanged['body'], 'Pookub2 ได้แก้ไขรายละเอียดงานใหม่ เข้าไปเช็คเลย!');
      expect(unchanged['stage'], 'groupTaskUpdated');
    });
  });
}
