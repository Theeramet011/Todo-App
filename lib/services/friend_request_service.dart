import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/user.dart';

class FriendRequestService {
  FriendRequestService({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: _functionsRegion);

  static const String _functionsRegion = 'asia-southeast1';

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;

  Future<void> sendFriendRequest({
    required User fromUser,
    required User toUser,
  }) async {
    final requestRef = await _firestore.collection('friend_requests').add({
      'fromId': fromUser.id,
      'toId': toUser.id,
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _createUserNotification(
      userId: toUser.id,
      data: {
        'title': '${fromUser.name} ส่งคำขอเป็นเพื่อน',
        'body': 'กดยอมรับหรือปฏิเสธคำขอนี้ได้ทันที',
        'type': 'FriendRequest',
        'notificationStage': 'friendRequestReceived',
        'notificationKey': 'friend-request-${requestRef.id}',
        'actorId': fromUser.id,
        'actorName': fromUser.name,
        'actorAvatarUrl': fromUser.avatarUrl,
        'friendRequestId': requestRef.id,
      },
    );
  }

  Future<void> acceptFriendRequest({
    required String requestId,
    required String requesterId,
    required User currentUser,
    String? requesterName,
    String? requesterAvatarUrl,
  }) async {
    final batch = _firestore.batch();
    final currentUserRef = _firestore.collection('users').doc(currentUser.id);
    final requesterRef = _firestore.collection('users').doc(requesterId);
    final requestRef = _firestore.collection('friend_requests').doc(requestId);

    batch.update(currentUserRef, {
      'friends': FieldValue.arrayUnion([requesterId]),
    });
    batch.update(requesterRef, {
      'friends': FieldValue.arrayUnion([currentUser.id]),
    });
    batch.delete(requestRef);

    await batch.commit();
    await _hideFriendRequestNotifications(
      userId: currentUser.id,
      requestId: requestId,
    );

    try {
      await _createUserNotification(
        userId: requesterId,
        data: {
          'title': '${currentUser.name} ยอมรับคำขอเป็นเพื่อนแล้ว',
          'body': 'ตอนนี้คุณเป็นเพื่อนกันแล้ว',
          'type': 'FriendAccepted',
          'notificationStage': 'friendRequestAccepted',
          'notificationKey': 'friend-accepted-$requestId',
          'actorId': currentUser.id,
          'actorName': currentUser.name,
          'actorAvatarUrl': currentUser.avatarUrl,
          'friendRequestId': requestId,
        },
      );
    } catch (e) {
      debugPrint('Failed to send accepted notification to requester: $e');
    }

    try {
      // Notification for the person who accepted the request (currentUser)
      await _createUserNotification(
        userId: currentUser.id,
        data: {
          'title': 'คุณและ ${requesterName ?? 'ผู้ใช้'} เป็นเพื่อนกันแล้ว',
          'body': 'ตอนนี้คุณสามารถดูโปรไฟล์และชวนทำภารกิจได้',
          'type': 'FriendAccepted',
          'notificationStage': 'friendRequestAcceptedSelf',
          'notificationKey': 'friend-accepted-self-$requestId',
          'actorId': requesterId,
          'actorName': requesterName ?? 'ผู้ใช้',
          'actorAvatarUrl': requesterAvatarUrl ?? '',
          'friendRequestId': requestId,
        },
      );
    } catch (e) {
      debugPrint('Failed to send accepted notification to self: $e');
    }
  }

  Future<void> declineFriendRequest({
    required String requestId,
    String? recipientId,
  }) async {
    await _firestore.collection('friend_requests').doc(requestId).delete();
    if (recipientId != null && recipientId.trim().isNotEmpty) {
      await _hideFriendRequestNotifications(
        userId: recipientId,
        requestId: requestId,
      );
    }
  }

  Future<void> _hideFriendRequestNotifications({
    required String userId,
    required String requestId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('type', isEqualTo: 'FriendRequest')
          .where('friendRequestId', isEqualTo: requestId)
          .limit(20)
          .get();

      if (snapshot.docs.isEmpty) return;

      final batch = _firestore.batch();
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
          'deletedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (error) {
      debugPrint('Failed to hide friend request notifications: $error');
    }
  }

  Future<void> _createUserNotification({
    required String userId,
    required Map<String, dynamic> data,
  }) async {
    final ref = _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc();

    final now = DateTime.now();
    final expireAt = now.add(const Duration(days: 30));
    await ref.set({
      ...data,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
      'expireAt': Timestamp.fromDate(expireAt),
    });

    // Run push notification asynchronously without blocking
    _pushUserNotification(userId: userId, notificationId: ref.id);
  }

  Future<void> _pushUserNotification({
    required String userId,
    required String notificationId,
  }) async {
    try {
      final callable = _functions.httpsCallable('pushInAppNotification');
      await callable.call<Map<String, dynamic>>({
        'notifications': [
          {'userId': userId, 'notificationId': notificationId},
        ],
      });
    } catch (error) {
      debugPrint('Failed to push friend notification: $error');
    }
  }
}
