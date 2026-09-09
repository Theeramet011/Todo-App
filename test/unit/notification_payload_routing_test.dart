import 'package:flutter_test/flutter_test.dart';

bool isCommentNotificationData(Map<String, dynamic> data) {
  final type =
      (data['notificationType'] ?? data['type'] ?? '').toString().toLowerCase();
  final stage = (data['notificationStage'] ?? '').toString().toLowerCase();
  return type == 'comment' || stage == 'commentadded';
}

enum TargetDestination { taskDetail, friends, none }

class NotificationRoutingDecision {
  final TargetDestination destination;
  final String? taskId;
  final bool scrollToComments;

  NotificationRoutingDecision({
    required this.destination,
    this.taskId,
    this.scrollToComments = false,
  });
}

NotificationRoutingDecision decideNotificationRoute(Map<String, dynamic> data) {
  final type =
      (data['notificationType'] ?? data['type'] ?? '').toString().toLowerCase();
  final stage = (data['notificationStage'] ?? '').toString().toLowerCase();

  if (type == 'friendrequest' ||
      type == 'friendaccepted' ||
      stage.startsWith('friendrequest')) {
    return NotificationRoutingDecision(destination: TargetDestination.friends);
  }

  final taskId = data['taskId']?.toString().trim();
  if (taskId == null || taskId.isEmpty) {
    return NotificationRoutingDecision(destination: TargetDestination.none);
  }

  final isComment = isCommentNotificationData(data);
  return NotificationRoutingDecision(
    destination: TargetDestination.taskDetail,
    taskId: taskId,
    scrollToComments: isComment,
  );
}

void main() {
  group('Notification Deep-link and Payload Routing Tests', () {
    test('Comment notification routes to TaskDetail with scrollToComments = true', () {
      final payload = {
        'taskId': 'task_123',
        'notificationType': 'Comment',
        'title': 'Somchai commented',
        'body': 'Good job!',
      };

      expect(isCommentNotificationData(payload), isTrue);

      final decision = decideNotificationRoute(payload);
      expect(decision.destination, equals(TargetDestination.taskDetail));
      expect(decision.taskId, equals('task_123'));
      expect(decision.scrollToComments, isTrue);
    });

    test('Comment notification with notificationStage commentAdded routes with scrollToComments = true', () {
      final payload = {
        'taskId': 'task_456',
        'type': 'Update',
        'notificationStage': 'commentAdded',
        'title': 'New comment',
      };

      expect(isCommentNotificationData(payload), isTrue);

      final decision = decideNotificationRoute(payload);
      expect(decision.destination, equals(TargetDestination.taskDetail));
      expect(decision.taskId, equals('task_456'));
      expect(decision.scrollToComments, isTrue);
    });

    test('Task deadline/reminder notification routes to TaskDetail with scrollToComments = false', () {
      final payload = {
        'taskId': 'task_789',
        'notificationType': 'Reminder',
        'notificationStage': 'custom_60',
        'title': 'Task Reminder',
      };

      expect(isCommentNotificationData(payload), isFalse);

      final decision = decideNotificationRoute(payload);
      expect(decision.destination, equals(TargetDestination.taskDetail));
      expect(decision.taskId, equals('task_789'));
      expect(decision.scrollToComments, isFalse);
    });

    test('Group task status/submission notification routes to TaskDetail with scrollToComments = false', () {
      final payload = {
        'taskId': 'group_task_999',
        'notificationType': 'Submission',
        'title': 'Member submitted work',
      };

      expect(isCommentNotificationData(payload), isFalse);

      final decision = decideNotificationRoute(payload);
      expect(decision.destination, equals(TargetDestination.taskDetail));
      expect(decision.taskId, equals('group_task_999'));
      expect(decision.scrollToComments, isFalse);
    });

    test('FriendRequest and FriendAccepted route directly to Friends screen', () {
      final friendRequestPayload = {
        'notificationType': 'FriendRequest',
        'friendRequestId': 'req_123',
      };

      final friendAcceptedPayload = {
        'notificationType': 'FriendAccepted',
      };

      expect(
        decideNotificationRoute(friendRequestPayload).destination,
        equals(TargetDestination.friends),
      );
      expect(
        decideNotificationRoute(friendAcceptedPayload).destination,
        equals(TargetDestination.friends),
      );
    });

    test('Missing taskId routes to none', () {
      final emptyPayload = {
        'notificationType': 'Reminder',
      };

      expect(
        decideNotificationRoute(emptyPayload).destination,
        equals(TargetDestination.none),
      );
    });
  });
}
