// User Model - โมเดลข้อมูลผู้ใช้งานและสถิติส่วนบุคคล (User Data Structure)
//
// กำหนดโครงสร้างข้อมูลผู้ใช้ เช่น โปรไฟล์, ค่า XP, Level, จำนวนงานที่ทำเสร็จ, สถิติต่อเนื่อง (Streak)
// ข้อมูลการตั้งค่าระบบ (เสียง/การแจ้งเตือน) และการรับส่งข้อมูลกับระบบ Firebase Firestore
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/thai_display.dart';
import 'xp_system.dart';

class User {
  final String id;
  final String name;
  final String email;
  final String avatarUrl;
  final int totalXP;
  final int currentLevel;
  final int tasksCompleted;
  final int groupTasksCompleted;
  final int memberGroupTasksCompleted;
  final int leaderGroupTasksCompleted;
  final int personalTasksCompletedToday;
  final String lastResetDate;
  final int currentStreak;
  final String lastLoginDate;
  final int longestStreak;
  final DateTime joinedAt;
  final bool isOnline;
  final bool isNotificationEnabled;
  final bool isSoundEnabled;

  // 🔥 1. เพิ่มตัวแปร List เก็บ UID สำหรับระบบเพื่อน
  final List<String> friends;
  final List<String> receivedRequests;
  final List<String> sentRequests;
  final List<String> achievementsUnlocked;
  final List<String> unlockedItems;
  final String equippedFrame;
  final String equippedTitle;

  User({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarUrl,
    this.totalXP = 0,
    int? currentLevel,
    this.tasksCompleted = 0,
    this.groupTasksCompleted = 0,
    this.memberGroupTasksCompleted = 0,
    this.leaderGroupTasksCompleted = 0,
    this.personalTasksCompletedToday = 0,
    this.lastResetDate = '',
    int? currentStreak,
    int? streak,
    this.lastLoginDate = '',
    int? longestStreak,
    required this.joinedAt,
    this.isOnline = false,
    this.isNotificationEnabled = true,
    this.isSoundEnabled = true,
    // 🔥 2. กำหนดค่าเริ่มต้นเป็น Array ว่าง เพื่อไม่ให้เป็น null
    this.friends = const [],
    this.receivedRequests = const [],
    this.sentRequests = const [],
    this.achievementsUnlocked = const [],
    this.unlockedItems = const [],
    this.equippedFrame = '',
    this.equippedTitle = '',
  }) : currentLevel = calculateLevelProgress(totalXP).currentLevel,
       currentStreak = currentStreak ?? streak ?? 0,
       longestStreak = longestStreak ?? currentStreak ?? streak ?? 0;

  int get streak => currentStreak;
  int get totalTasksCompleted => tasksCompleted + groupTasksCompleted;
  String get photoUrl => avatarUrl;

  factory User.fromMap(Map<String, dynamic> data, String documentId) {
    final legacyStreak = _readInt(data['streak']);
    final currentStreak = _readInt(
      data['currentStreak'],
      fallback: legacyStreak,
    );
    // 🔥 1. สร้างฟังก์ชันช่วยดักจับค่า Null และแปลงเป็น List อย่างปลอดภัย 100%
    List<String> parseStringList(String key) {
      if (data[key] == null) {
        return []; // ถ้าใน Firestore ไม่มีคีย์นี้ ให้ส่ง Array ว่างกลับไปเลย
      }
      return (data[key] as List<dynamic>).map((e) => e.toString()).toList();
    }

    return User(
      id: documentId,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      avatarUrl: data['avatarUrl'] ?? data['photoUrl'] ?? '',
      totalXP: _readInt(data['totalXP']),
      tasksCompleted: _readInt(data['tasksCompleted']),
      groupTasksCompleted: _readInt(data['groupTasksCompleted']),
      memberGroupTasksCompleted: _readInt(data['memberGroupTasksCompleted']),
      leaderGroupTasksCompleted: _readInt(data['leaderGroupTasksCompleted']),
      personalTasksCompletedToday: _readInt(
        data['personalTasksCompletedToday'],
      ),
      lastResetDate: data['lastResetDate'] ?? '',
      currentStreak: currentStreak,
      lastLoginDate: data['lastLoginDate'] ?? '',
      longestStreak: _readInt(data['longestStreak'], fallback: currentStreak),
      joinedAt: (data['joinedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      isOnline: data['isOnline'] ?? false,
      isNotificationEnabled: data['isNotificationEnabled'] ?? true,
      isSoundEnabled: data['isSoundEnabled'] ?? true,

      // 🔥 2. ให้พาร์สข้อมูลเป็น Array ป้องกัน Null เสมอแทนของเดิม
      friends: parseStringList('friends'),
      receivedRequests: parseStringList('receivedRequests'),
      sentRequests: parseStringList('sentRequests'),
      achievementsUnlocked: parseStringList('achievementsUnlocked'),
      unlockedItems: parseStringList('unlockedItems'),
      equippedFrame: data['equippedFrame'] ?? '',
      equippedTitle: data['equippedTitle'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'avatarUrl': avatarUrl,
      'totalXP': totalXP,
      'currentLevel': calculateLevelProgress(totalXP).currentLevel,
      'tasksCompleted': tasksCompleted,
      'groupTasksCompleted': groupTasksCompleted,
      'memberGroupTasksCompleted': memberGroupTasksCompleted,
      'leaderGroupTasksCompleted': leaderGroupTasksCompleted,
      'personalTasksCompletedToday': personalTasksCompletedToday,
      'lastResetDate': lastResetDate,
      'currentStreak': currentStreak,
      'lastLoginDate': lastLoginDate,
      'longestStreak': longestStreak,
      'joinedAt': joinedAt,
      'isOnline': isOnline,
      'isNotificationEnabled': isNotificationEnabled,
      'isSoundEnabled': isSoundEnabled,
      // 🔥 4. ส่งข้อมูลชุดใหม่ขึ้นไปอัปเดตบน Firestore ด้วย
      'friends': friends,
      'receivedRequests': receivedRequests,
      'sentRequests': sentRequests,
      'achievementsUnlocked': achievementsUnlocked,
      'unlockedItems': unlockedItems,
      'equippedFrame': equippedFrame,
      'equippedTitle': equippedTitle,
    };
  }

  User copyWith({
    String? id,
    String? name,
    String? email,
    String? avatarUrl,
    int? totalXP,
    int? currentLevel,
    int? tasksCompleted,
    int? groupTasksCompleted,
    int? memberGroupTasksCompleted,
    int? leaderGroupTasksCompleted,
    int? personalTasksCompletedToday,
    String? lastResetDate,
    int? currentStreak,
    String? lastLoginDate,
    int? longestStreak,
    DateTime? joinedAt,
    bool? isOnline,
    bool? isNotificationEnabled,
    bool? isSoundEnabled,
    // 🔥 5. เพิ่มตัวแปรมารับพารามิเตอร์ใน CopyWith
    List<String>? friends,
    List<String>? receivedRequests,
    List<String>? sentRequests,
    List<String>? achievementsUnlocked,
    List<String>? unlockedItems,
    String? equippedFrame,
    String? equippedTitle,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      totalXP: totalXP ?? this.totalXP,
      tasksCompleted: tasksCompleted ?? this.tasksCompleted,
      groupTasksCompleted: groupTasksCompleted ?? this.groupTasksCompleted,
      memberGroupTasksCompleted:
          memberGroupTasksCompleted ?? this.memberGroupTasksCompleted,
      leaderGroupTasksCompleted:
          leaderGroupTasksCompleted ?? this.leaderGroupTasksCompleted,
      personalTasksCompletedToday:
          personalTasksCompletedToday ?? this.personalTasksCompletedToday,
      lastResetDate: lastResetDate ?? this.lastResetDate,
      currentStreak: currentStreak ?? this.currentStreak,
      lastLoginDate: lastLoginDate ?? this.lastLoginDate,
      longestStreak: longestStreak ?? this.longestStreak,
      joinedAt: joinedAt ?? this.joinedAt,
      isOnline: isOnline ?? this.isOnline,
      isNotificationEnabled:
          isNotificationEnabled ?? this.isNotificationEnabled,
      isSoundEnabled: isSoundEnabled ?? this.isSoundEnabled,
      // 🔥 6. แมปค่าส่งกลับไป
      friends: friends ?? this.friends,
      receivedRequests: receivedRequests ?? this.receivedRequests,
      sentRequests: sentRequests ?? this.sentRequests,
      achievementsUnlocked: achievementsUnlocked ?? this.achievementsUnlocked,
      unlockedItems: unlockedItems ?? this.unlockedItems,
      equippedFrame: equippedFrame ?? this.equippedFrame,
      equippedTitle: equippedTitle ?? this.equippedTitle,
    );
  }

  LevelProgress get levelProgress => calculateLevelProgress(totalXP);
  int get nextLevelPoints => levelProgress.requiredXp;
  int get progressToNextLevel => levelProgress.progressXp;
  double get progressToNextLevelValue => levelProgress.progressValue;

  String get levelTitle {
    return thaiLevelTitle(currentLevel);
  }

  static int _readInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }
}
