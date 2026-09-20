import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/models/task.dart';

void main() {
  group('Member Assigned Task UI & Menu Logic Tests', () {
    test('showMyAssignedCard logic: true for assigned member, false if not in group', () {
      final task = Task(
        id: 'group_task_1',
        title: 'โปรเจกต์งานกลุ่ม',
        creatorId: 'leader_1',
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        type: TaskType.group,
        members: [
          Member(
            id: 'member_1',
            name: 'Alice',
            taskTitle: 'ออกแบบ UI',
            description: 'ทำ Figma และ Wireframe',
            difficulty: 'Hard',
            workload: 'Large',
            risk: 'Medium',
            score: '100',
            subTasks: ['Wireframe', 'UI Mockup'],
          ),
          Member(
            id: 'member_2',
            name: 'Bob',
            taskTitle: 'ออกแบบ UI',
            difficulty: 'Medium',
          ),
          Member(
            id: 'leader_1',
            name: 'Leader',
            taskTitle: 'ควบคุมโปรเจกต์',
          ),
        ],
      );

      // Check current user is member_1 (assigned member, not leader)
      const currentUserId = 'member_1';
      final myMember = task.members.where((m) => m.id == currentUserId).firstOrNull;
      bool checkShowMyAssignedCard({required bool isLeader}) {
        return task.isGroup &&
            myMember != null &&
            (!isLeader ||
                (myMember.taskTitle?.trim().isNotEmpty == true ||
                    myMember.subTasks.isNotEmpty));
      }

      expect(checkShowMyAssignedCard(isLeader: false), isTrue);
      expect(checkShowMyAssignedCard(isLeader: true), isTrue);
      expect(myMember?.taskTitle, equals('ออกแบบ UI'));
      expect(myMember?.subTasks.length, equals(2));
    });

    test('Co-assignees filtering finds members sharing identical taskTitle, excluding self', () {
      final task = Task(
        id: 'group_task_1',
        title: 'โปรเจกต์งานกลุ่ม',
        creatorId: 'leader_1',
        createdAt: DateTime.now(),
        dateTime: DateTime.now(),
        type: TaskType.group,
        members: [
          Member(
            id: 'member_1',
            name: 'Alice',
            taskTitle: 'ออกแบบ UI',
          ),
          Member(
            id: 'member_2',
            name: 'Bob',
            taskTitle: 'ออกแบบ UI',
          ),
          Member(
            id: 'member_3',
            name: 'Charlie',
            taskTitle: 'พัฒนา Backend',
          ),
        ],
      );

      final myMember = task.members.firstWhere((m) => m.id == 'member_1');
      final coAssignees = task.members
          .where(
            (m) =>
                m.id != myMember.id &&
                m.taskTitle != null &&
                m.taskTitle!.trim().isNotEmpty &&
                m.taskTitle!.trim() == myMember.taskTitle?.trim(),
          )
          .toList();

      expect(coAssignees.length, equals(1));
      expect(coAssignees.first.id, equals('member_2'));
      expect(coAssignees.first.name, equals('Bob'));
    });

    test('Three-dot menu visibility: hidden for self, visible for other members', () {
      const currentUserId = 'member_1';

      bool shouldShowThreeDotForMember(String memberId) {
        final isSelf = memberId == currentUserId;
        return !isSelf;
      }

      // Member 1 (self): 3-dot menu should be HIDDEN
      expect(shouldShowThreeDotForMember('member_1'), isFalse);

      // Member 2 (other): 3-dot menu should be VISIBLE
      expect(shouldShowThreeDotForMember('member_2'), isTrue);

      // Member 3 (other): 3-dot menu should be VISIBLE
      expect(shouldShowThreeDotForMember('member_3'), isTrue);
    });

    test('Leader card three-dot menu visibility: hidden if user is leader, visible if member views leader', () {
      const leaderId = 'leader_1';

      bool shouldShowThreeDotForLeader({
        required String currentUserId,
        required Member? leaderMember,
      }) {
        return leaderMember != null && leaderId != currentUserId;
      }

      final leaderWithAssignment = Member(
        id: 'leader_1',
        name: 'Leader',
        taskTitle: 'Project Management',
      );

      // Current user is leader (leaderId == currentUserId): 3-dot menu should be HIDDEN
      expect(
        shouldShowThreeDotForLeader(
          currentUserId: 'leader_1',
          leaderMember: leaderWithAssignment,
        ),
        isFalse,
      );

      // Current user is member (leaderId != currentUserId): 3-dot menu should be VISIBLE
      expect(
        shouldShowThreeDotForLeader(
          currentUserId: 'member_1',
          leaderMember: leaderWithAssignment,
        ),
        isTrue,
      );
    });

    test('Late submission badge condition: true only when submitted after task deadline and in leader view', () {
      final deadline = DateTime(2026, 9, 18, 18, 0); // 18:00

      final onTimeMember = Member(
        id: 'member_1',
        name: 'Alice',
        status: 'pending',
        submittedAt: DateTime(2026, 9, 18, 17, 45), // 17:45 (on time)
      );

      final lateMember = Member(
        id: 'member_2',
        name: 'Bob',
        status: 'pending',
        submittedAt: DateTime(2026, 9, 18, 19, 49), // 19:49 (late)
      );

      final inProgressMember = Member(
        id: 'member_3',
        name: 'Charlie',
        status: 'inProgress',
        submittedAt: null,
      );

      final completedLateMember = Member(
        id: 'member_4',
        name: 'Dave',
        status: 'completed',
        submittedAt: DateTime(2026, 9, 18, 19, 0), // late
      );

      bool shouldShowLateBadge({
        required bool isLeader,
        required Member member,
        required DateTime taskDeadline,
      }) {
        final isMemberPending = member.status == 'pending';
        final isMemberCompleted = member.status == 'completed';
        final submittedAt = member.submittedAt;
        final isLateSubmission = submittedAt != null && submittedAt.isAfter(taskDeadline);
        return isLeader && isLateSubmission && (isMemberPending || isMemberCompleted);
      }

      // Leader viewing late pending submission -> TRUE
      expect(
        shouldShowLateBadge(isLeader: true, member: lateMember, taskDeadline: deadline),
        isTrue,
      );

      // Leader viewing on-time pending submission -> FALSE
      expect(
        shouldShowLateBadge(isLeader: true, member: onTimeMember, taskDeadline: deadline),
        isFalse,
      );

      // Leader viewing in-progress member (not yet submitted) -> FALSE
      expect(
        shouldShowLateBadge(isLeader: true, member: inProgressMember, taskDeadline: deadline),
        isFalse,
      );

      // Leader viewing completed late submission -> TRUE
      expect(
        shouldShowLateBadge(isLeader: true, member: completedLateMember, taskDeadline: deadline),
        isTrue,
      );

      // Non-leader viewing late submission -> FALSE
      expect(
        shouldShowLateBadge(isLeader: false, member: lateMember, taskDeadline: deadline),
        isFalse,
      );
    });

    test('Member thaiDifficulty, thaiWorkload, and thaiRisk translations', () {
      const member1 = Member(
        difficulty: 'Easy',
        workload: 'Small',
        risk: 'None',
      );
      expect(member1.thaiDifficulty, equals('ง่าย'));
      expect(member1.thaiWorkload, equals('น้อย'));
      expect(member1.thaiRisk, equals('ต่ำ'));

      const member2 = Member(
        difficulty: 'Medium',
        workload: 'Medium',
        risk: 'Medium',
      );
      expect(member2.thaiDifficulty, equals('ปานกลาง'));
      expect(member2.thaiWorkload, equals('ปานกลาง'));
      expect(member2.thaiRisk, equals('กลาง'));

      const member3 = Member(
        difficulty: 'Hard',
        workload: 'Large',
        risk: 'High',
      );
      expect(member3.thaiDifficulty, equals('ยาก'));
      expect(member3.thaiWorkload, equals('มาก'));
      expect(member3.thaiRisk, equals('สูง'));

      // Case when already in Thai or mixed casing
      const member4 = Member(
        difficulty: 'ยาก',
        workload: 'น้อย',
        risk: 'ต่ำ',
      );
      expect(member4.thaiDifficulty, equals('ยาก'));
      expect(member4.thaiWorkload, equals('น้อย'));
      expect(member4.thaiRisk, equals('ต่ำ'));
    });
  });
}
