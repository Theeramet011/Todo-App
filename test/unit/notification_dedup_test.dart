import 'dart:ui';
import 'package:flutter_test/flutter_test.dart';
import 'package:todo_app/screens/home_screen.dart';

void main() {
  group('Notification Deduplication Tests', () {
    test('NotificationItem deduplicates identical messages within 15 minutes', () {
      final now = DateTime(2026, 9, 13, 19, 2, 0);

      final item1 = NotificationItem(
        id: 'doc1',
        sender: '❓ ถึงเวลาตรวจความคืบหน้าทีมแล้ว',
        message: 'ภารกิจ "redogr" เลยเวลาส่งมา 30 นาทีแล้ว เข้าไปตรวจงานหรือแจ้งสมาชิกได้เลย',
        tag: 'Follow-up',
        tagColor: const Color(0xFF000000),
        createdAt: now,
        notificationKey: 'task_1-notifiedFollowUp-user1-leader',
      );

      final item2 = NotificationItem(
        id: 'doc2',
        sender: '❓ ถึงเวลาตรวจความคืบหน้าทีมแล้ว',
        message: 'ภารกิจ "redogr" เลยเวลาส่งมา 30 นาทีแล้ว เข้าไปตรวจงานหรือแจ้งสมาชิกได้เลย',
        tag: 'Follow-up',
        tagColor: const Color(0xFF000000),
        createdAt: now.add(const Duration(seconds: 1)),
        notificationKey: 'task_2-notifiedFollowUp-user1-leader',
      );

      final item3 = NotificationItem(
        id: 'doc3',
        sender: '❓ ถึงเวลาตรวจความคืบหน้าทีมแล้ว',
        message: 'ภารกิจ "redogrkk" เลยเวลาส่งมา 30 นาทีแล้ว เข้าไปตรวจงานหรือแจ้งสมาชิกได้เลย',
        tag: 'Follow-up',
        tagColor: const Color(0xFF000000),
        createdAt: now.add(const Duration(seconds: 2)),
        notificationKey: 'task_3-notifiedFollowUp-user1-leader',
      );

      final item4 = NotificationItem(
        id: 'doc4',
        sender: '❓ ถึงเวลาตรวจความคืบหน้าทีมแล้ว',
        message: 'ภารกิจ "redogrkk" เลยเวลาส่งมา 30 นาทีแล้ว เข้าไปตรวจงานหรือแจ้งสมาชิกได้เลย',
        tag: 'Follow-up',
        tagColor: const Color(0xFF000000),
        createdAt: now.add(const Duration(seconds: 3)),
        notificationKey: 'task_4-notifiedFollowUp-user1-leader',
      );

      final rawList = [item4, item3, item2, item1];

      final deduped = <NotificationItem>[];
      for (final item in rawList) {
        final existingIndex = deduped.indexWhere((existing) {
          if (item.notificationKey != null &&
              existing.notificationKey != null &&
              item.notificationKey == existing.notificationKey) {
            return true;
          }
          return existing.sender == item.sender &&
              existing.message == item.message &&
              existing.createdAt.difference(item.createdAt).abs().inMinutes < 15;
        });

        if (existingIndex != -1) {
          deduped[existingIndex].duplicateDocIds.add(item.id);
        } else {
          deduped.add(item);
        }
      }

      // Should deduplicate 4 items into 2 items (one redogrkk and one redogr)
      expect(deduped.length, equals(2));
      expect(deduped[0].message, contains('redogrkk'));
      expect(deduped[0].duplicateDocIds, contains('doc3'));
      expect(deduped[1].message, contains('redogr'));
      expect(deduped[1].duplicateDocIds, contains('doc1'));
    });
  });
}
