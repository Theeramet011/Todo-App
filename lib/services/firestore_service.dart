import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/xp_system.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // --- ส่วนของข้อมูลผู้ใช้ (Users) ---

  // ดึงข้อมูลผู้ใช้แบบ Real-time ตาม UID
  Stream<DocumentSnapshot> streamUserProfile(String uid) {
    return _db.collection('users').doc(uid).snapshots();
  }

  // อัปเดตคะแนน XP และ Level (เมื่อทำงานสำเร็จ)
  Future<void> updateUserXP(String uid, int newXP, int newLevel) {
    return _db.collection('users').doc(uid).update({
      'totalXP': newXP,
      'currentLevel': calculateLevelProgress(newXP).currentLevel,
    });
  }

  // --- ส่วนของงาน (Tasks) ---

  // ดึงรายการงานที่มอบหมายให้เรา
  Stream<QuerySnapshot> streamMyTasks(String uid) {
    return _db
        .collection('tasks')
        .where('assigneeIds', arrayContains: uid)
        .snapshots();
  }

  // เปลี่ยนสถานะงาน (เช่น ส่งงาน หรือ อนุมัติงาน)
  Future<void> updateTaskStatus(String taskId, String newStatus) {
    return _db.collection('tasks').doc(taskId).update({'status': newStatus});
  }
}
