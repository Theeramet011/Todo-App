// TaskProvider - ตัวจัดการสถานะภารกิจ งานกลุ่ม และการอัปโหลดไฟล์ (Task State Management)
//
// จัดการข้อมูลงานทั้งหมดในแอป (CRUD Tasks) งานส่วนตัว งานกลุ่ม ถังขยะ (Bin) การคำนวณ XP การปลดล็อกรางวัล
// และการอัปโหลด/ลบไฟล์แนบบน Firebase Storage
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/project.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../models/xp_system.dart';
import '../models/achievement.dart';
import '../utils/mock_data.dart';
import '../config/constants.dart';

enum CompletionRewardStatus { awarded, blockedFastCompletion, noChange }

class CompletionRewardResult {
  final CompletionRewardStatus status;
  final int? leveledUpTo;

  const CompletionRewardResult._(this.status, {this.leveledUpTo});

  static const awarded = CompletionRewardResult._(
    CompletionRewardStatus.awarded,
  );
  static const blockedFastCompletion = CompletionRewardResult._(
    CompletionRewardStatus.blockedFastCompletion,
  );
  static const noChange = CompletionRewardResult._(
    CompletionRewardStatus.noChange,
  );

  bool get didLevelUp => leveledUpTo != null;

  CompletionRewardResult copyWith({int? leveledUpTo}) {
    return CompletionRewardResult._(
      status,
      leveledUpTo: leveledUpTo ?? this.leveledUpTo,
    );
  }
}

class TaskProvider with ChangeNotifier {
  static const String _functionsRegion = 'asia-southeast1';

  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final firebase_auth.FirebaseAuth _auth;
  final List<Task> _tasks = [];
  final List<Project> _projects = [];
  final List<User> _friends = [];
  final Map<String, User> _userCache = {};
  final Set<String> _pendingUserFetches = {};
  final List<StreamSubscription> _subscriptions = [];
  StreamSubscription<firebase_auth.User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _taskSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _projectSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userDocSubscription;
  String? _currentUserId;
  final List<DateTime> _recentCompletionTimestamps = [];
  List<DateTime> get recentCompletionTimestamps =>
      List.unmodifiable(_recentCompletionTimestamps);

  bool _showXPCapAlert = false;
  bool get showXPCapAlert => _showXPCapAlert;

  void dismissXPCapAlert() {
    _showXPCapAlert = false;
    notifyListeners();
  }

  int getDailyGroupXPForLeader(String leaderId) {
    final now = DateTime.now();
    final completedGroupTasksToday = _tasks
        .where(
          (t) =>
              t.isGroup &&
              !t.isDeleted &&
              t.isCompleted &&
              !t.rewardBlocked &&
              t.completedAt != null &&
              _isSameDay(t.completedAt!, now),
        )
        .toList();

    int totalXP = 0;
    for (final task in completedGroupTasksToday) {
      if (task.assigneeIds.contains(leaderId)) {
        totalXP += task.calculateXP + 10;
      } else {
        totalXP += 10;
      }
    }
    return totalXP;
  }

  Future<void> _handleGroupTaskCompletionRewards(
    Task task,
    bool isNowCompleted,
  ) async {
    if (!task.isGroup) return;

    final leaderId = leaderIdForTask(task);
    if (leaderId.isEmpty) return;

    final multiplier = isNowCompleted ? 1 : -1;

    int leaderXPAward = 0;
    const int taskCountDelta = 1;

    if (!task.assigneeIds.contains(leaderId)) {
      // Case 1: Management Only (Leader is NOT an assignee)
      leaderXPAward = 10;
    } else {
      // Case 2: Player-Coach (Leader IS an assignee alongside others)
      final taskXPAward = task.calculateXP;
      leaderXPAward = taskXPAward + 10;
    }

    await _updateUserProgress(
      leaderId,
      xpDelta: leaderXPAward * multiplier,
      groupTaskDelta: taskCountDelta * multiplier,
      leaderGroupTaskDelta: taskCountDelta * multiplier,
    );
  }

  int _totalXP = 0;
  Task? _selectedTask;
  Project? _selectedProject;
  DateTime _selectedDate = DateTime.now();
  int _activeSubTabIndex = 0;

  TaskProvider({
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    firebase_auth.FirebaseAuth? auth,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ?? FirebaseFunctions.instanceFor(region: _functionsRegion),
       _auth = auth ?? firebase_auth.FirebaseAuth.instance {
    _currentUserId = _auth.currentUser?.uid;
    _listenToFirestore();
    _calculateInitialXP();
  }

  int get totalXP => _totalXP;
  int get currentLevel => calculateLevelProgress(_totalXP).currentLevel;
  double get xpProgress => calculateLevelProgress(_totalXP).progressValue;
  int get completedPersonalTasksCount {
    final currentUserId = _currentUserId;
    if (currentUserId == null) return 0;
    return _completedPersonalTasksCountFor(currentUserId);
  }

  Future<int?> _userLevelFor(String userId) async {
    final snapshot = await _firestore.collection('users').doc(userId).get();
    final data = snapshot.data();
    if (data == null) return null;
    return calculateLevelProgress(_readInt(data['totalXP'])).currentLevel;
  }

  int get activeSubTabIndex => _activeSubTabIndex;
  List<Project> get projects => List.unmodifiable(_projects);
  List<Task> get groupProjectTasks => groupTasks;
  List<User> get friends => List.unmodifiable(_friends);

  /// ดึงข้อมูลเพื่อนจริง ๆ จาก Firestore
  /// 1. ดึงข้อมูล User ปัจจุบันเพื่อเอา UIDs ของเพื่อนจากฟิลด์ 'friends'
  /// 2. ใช้ query 'whereIn' ดึงข้อมูลโปรไฟล์ของเพื่อนเหล่านั้นทั้งหมดแบบมีประสิทธิภาพ
  /// 3. จัดการแบ่ง chunk ทีละ 30 เพื่อป้องกันข้อจำกัด (whereIn limit) ของ Firestore
  Future<List<User>> getRealFriendsList() async {
    final currentUserId = _currentUserId ?? _auth.currentUser?.uid;
    if (currentUserId == null || currentUserId.isEmpty) {
      return [];
    }

    try {
      // 1. ดึงเอกสารของผู้ใช้ปัจจุบัน
      final userDoc = await _firestore
          .collection('users')
          .doc(currentUserId)
          .get();
      if (!userDoc.exists) return [];

      final data = userDoc.data();
      if (data == null) return [];

      // ดึงรายการ UID ของเพื่อนจาก Array 'friends'
      final List<dynamic>? friendUids = data['friends'] as List<dynamic>?;
      if (friendUids == null || friendUids.isEmpty) {
        return [];
      }

      final List<String> uids = friendUids.map((e) => e.toString()).toList();
      if (uids.isEmpty) return [];

      final List<User> realFriends = [];

      // 2. ใช้ query 'whereIn' โดยแบ่งเป็นชุดละไม่เกิน 30 ตัว (Firestore limitation) เพื่อดึงข้อมูลโปรไฟล์อย่างมีประสิทธิภาพ
      for (var i = 0; i < uids.length; i += 30) {
        final chunk = uids.sublist(
          i,
          i + 30 > uids.length ? uids.length : i + 30,
        );
        final snapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        realFriends.addAll(
          snapshot.docs.map((doc) => User.fromMap(doc.data(), doc.id)),
        );
      }

      return realFriends;
    } catch (e) {
      debugPrint('Error fetching real friends list: $e');
      return [];
    }
  }

  /// โหลดข้อมูลเพื่อนของผู้ใช้ปัจจุบัน แล้วอัปเดต cache และ _friends
  Future<List<User>> loadFriends() async {
    final realFriends = await getRealFriendsList();
    _friends
      ..clear()
      ..addAll(realFriends);
    for (final friend in realFriends) {
      _userCache[friend.id] = friend;
    }
    notifyListeners();
    return realFriends;
  }

  /// ดึงข้อมูล User ทีละคนตาม ID ( On-demand Fetching + Cache )
  Future<User?> fetchUser(String userId) async {
    if (_userCache.containsKey(userId)) return _userCache[userId];
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists || doc.data() == null) return null;
      final user = User.fromMap(doc.data()!, doc.id);
      _userCache[userId] = user;
      return user;
    } catch (e) {
      debugPrint('Error fetching user $userId: $e');
      return null;
    }
  }

  void _fetchUserAndNotify(String userId) {
    if (_pendingUserFetches.contains(userId)) return;
    _pendingUserFetches.add(userId);
    fetchUser(userId).then((user) {
      _pendingUserFetches.remove(userId);
      if (user != null) {
        notifyListeners();
      }
    });
  }

  /// ล้าง User Cache
  void invalidateUserCache([String? userId]) {
    if (userId != null) {
      _userCache.remove(userId);
    } else {
      _userCache.clear();
    }
  }

  Task? get selectedTask => _selectedTask;
  Project? get selectedProject => _selectedProject;
  DateTime get selectedDate => _selectedDate;

  bool _isTaskHiddenForCurrentUser(Task task) {
    final currentUserId = _currentUserId ?? _auth.currentUser?.uid;
    return task.isGroup &&
        currentUserId != null &&
        task.hiddenForUserIds.contains(currentUserId);
  }

  bool _isTaskInCurrentUserBin(Task task) {
    final currentUserId = _currentUserId ?? _auth.currentUser?.uid;
    if (task.isGroup &&
        currentUserId != null &&
        task.hiddenForUserIds.contains(currentUserId)) {
      return false;
    }
    return task.isDeleted ||
        (task.isGroup &&
            currentUserId != null &&
            task.deletedForUserIds.contains(currentUserId) &&
            !task.hiddenForUserIds.contains(currentUserId));
  }

  bool _isTaskVisibleForCurrentUser(Task task) {
    return !_isTaskHiddenForCurrentUser(task) && !_isTaskInCurrentUserBin(task);
  }

  List<Task> get tasks {
    final sortedTasks = _tasks.where(_isTaskVisibleForCurrentUser).toList();
    sortedTasks.sort((a, b) {
      final priorityComparison = b.priority.index.compareTo(a.priority.index);
      if (priorityComparison != 0) return priorityComparison;
      return b.createdAt.compareTo(a.createdAt);
    });
    return List.unmodifiable(sortedTasks);
  }

  List<Task> get deletedTasks {
    final deleted = _tasks.where(_isTaskInCurrentUserBin).toList();
    deleted.sort((a, b) {
      final aTime = a.deletedAt ?? a.createdAt;
      final bTime = b.deletedAt ?? b.createdAt;
      return bTime.compareTo(aTime);
    });
    return List.unmodifiable(deleted);
  }

  List<Task> get personalTasks => tasks.where((t) => t.isPersonal).toList();
  List<Task> get groupTasks => tasks.where((t) => t.isGroup).toList();
  List<Task> get completedTasks {
    final list = tasks.where((t) => t.isCompleted).toList();
    list.sort((a, b) {
      final aTime = a.completedAt ?? a.dateTime;
      final bTime = b.completedAt ?? b.dateTime;
      final timeComp = bTime.compareTo(aTime);
      if (timeComp != 0) return timeComp;
      return b.createdAt.compareTo(a.createdAt);
    });
    return List.unmodifiable(list);
  }
  List<Task> get pendingTasks => tasks.where((t) => !t.isCompleted).toList();

  String _taskSeriesKey(Task task) {
    if (!task.isRecurring) return task.id;
    final cleanTitle = task.title.trim().toLowerCase();
    final creator = task.creatorId;
    final type = task.type.name;
    final project = task.projectId ?? '';
    final recurrence = task.recurringType.trim();
    return '$creator|$type|$project|$cleanTitle|$recurrence';
  }

  List<Task> _collapseRecurringTasks(
    List<Task> taskList, {
    Set<String>? excludeSeriesKeys,
  }) {
    final result = <Task>[];
    final seenKeys = <String>{...?excludeSeriesKeys};

    // เรียงตามเวลาล่าสุดก่อน เพื่อเลือกงานรอบล่าสุดมาแสดงผล
    final sorted = List<Task>.from(taskList)
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));

    for (final task in sorted) {
      if (!task.isRecurring) {
        result.add(task);
        continue;
      }
      final key = _taskSeriesKey(task);
      if (seenKeys.contains(key)) {
        continue;
      }
      seenKeys.add(key);
      result.add(task);
    }

    return result;
  }

  List<Task> get todayTasks => todayPersonalTasks;

  List<Task> get todayPersonalTasks {
    final today = _todayString();
    final rawToday = personalTasks
        .where((task) => _dateString(task.dateTime) == today)
        .toList();
    return _collapseRecurringTasks(rawToday);
  }

  List<Task> get overduePersonalTasks {
    final today = _todayString();
    final rawToday = personalTasks
        .where((task) => _dateString(task.dateTime) == today)
        .toList();
    final todaySeriesKeys = rawToday
        .where((t) => t.isRecurring)
        .map(_taskSeriesKey)
        .toSet();

    final rawOverdue = personalTasks
        .where(
          (task) =>
              _dateString(task.dateTime).compareTo(today) < 0 &&
              task.status != TaskStatus.completed,
        )
        .toList();
    return _collapseRecurringTasks(rawOverdue, excludeSeriesKeys: todaySeriesKeys);
  }

  List<Task> get todayGroupTasks {
    final today = _todayString();
    final rawToday = groupTasks
        .where((task) => _dateString(task.dateTime) == today)
        .toList();
    return _collapseRecurringTasks(rawToday);
  }

  List<Task> get overdueGroupTasks {
    final today = _todayString();
    final rawToday = groupTasks
        .where((task) => _dateString(task.dateTime) == today)
        .toList();
    final todaySeriesKeys = rawToday
        .where((t) => t.isRecurring)
        .map(_taskSeriesKey)
        .toSet();

    final rawOverdue = groupTasks
        .where(
          (task) =>
              _dateString(task.dateTime).compareTo(today) < 0 &&
              task.status != TaskStatus.completed,
        )
        .toList();
    return _collapseRecurringTasks(rawOverdue, excludeSeriesKeys: todaySeriesKeys);
  }

  List<Task> get upcomingTasks {
    final now = DateTime.now();
    return personalTasks
        .where((t) => !t.isCompleted && t.dateTime.isAfter(now))
        .toList();
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _taskSubscription?.cancel();
    _projectSubscription?.cancel();
    _userDocSubscription?.cancel();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    super.dispose();
  }

  void _listenToFirestore() {
    _authSubscription = _auth.authStateChanges().listen((user) {
      _handleAuthUserChanged(user?.uid);
    });
    _listenToCurrentUserTasks(_currentUserId);
    _listenToCurrentUserProjects(_currentUserId);
    _listenToCurrentUserDoc(_currentUserId);
  }

  void _handleAuthUserChanged(String? userId) {
    if (_currentUserId == userId) return;
    _currentUserId = userId;
    _tasks.clear();
    _projects.clear();
    _friends.clear();
    _userCache.clear();
    _selectedTask = null;
    _selectedProject = null;
    _totalXP = 0;
    _listenToCurrentUserTasks(userId);
    _listenToCurrentUserProjects(userId);
    _listenToCurrentUserDoc(userId);
    if (userId != null) {
      loadFriends();
    }
    notifyListeners();
  }

  void _listenToCurrentUserDoc(String? userId) {
    _userDocSubscription?.cancel();

    if (userId == null) {
      return;
    }

    _userDocSubscription = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((snapshot) {
          final data = snapshot.data();
          if (data == null) return;

          final List<dynamic>? friendUids = data['friends'] as List<dynamic>?;
          final currentFriendIds =
              friendUids
                  ?.map((e) => e.toString().trim())
                  .where((e) => e.isNotEmpty)
                  .toSet() ??
              <String>{};
          final loadedFriendIds = _friends.map((f) => f.id.trim()).toSet();

          // หากมีเพื่อนใหม่ที่ยังไม่ได้โหลด หรือรายการเพื่อนเปลี่ยนแปลง ให้โหลดข้อมูลแบบเรียลไทม์ทันที
          if (currentFriendIds.length != loadedFriendIds.length ||
              currentFriendIds.any((id) => !loadedFriendIds.contains(id))) {
            loadFriends();
          }
        }, onError: (error) => debugPrint('User doc stream error: $error'));
  }

  void _listenToCurrentUserProjects(String? userId) {
    _projectSubscription?.cancel();
    _projects.clear();

    if (userId == null) {
      notifyListeners();
      return;
    }

    _projectSubscription = _firestore
        .collection('projects')
        .where(
          Filter.or(
            Filter('leaderId', isEqualTo: userId),
            Filter('memberIds', arrayContains: userId),
          ),
        )
        .snapshots()
        .listen((snapshot) {
          _projects
            ..clear()
            ..addAll(
              snapshot.docs.map((doc) => Project.fromMap(doc.data(), doc.id)),
            );
          notifyListeners();
        }, onError: (error) => debugPrint('Project stream error: $error'));
  }

  void _listenToCurrentUserTasks(String? userId) {
    _taskSubscription?.cancel();
    _tasks.clear();

    if (userId == null) {
      _calculateInitialXP();
      notifyListeners();
      return;
    }

    _taskSubscription = _firestore
        .collection('tasks')
        .where(
          Filter.or(
            Filter('assigneeIds', arrayContains: userId),
            Filter('creatorId', isEqualTo: userId),
          ),
        )
        .snapshots()
        .listen((snapshot) {
          _tasks
            ..clear()
            ..addAll(
              snapshot.docs.map((doc) => Task.fromMap(doc.data(), doc.id)),
            );
          _calculateInitialXP();
          _refreshSelectedTask();
          notifyListeners();
          _ensureUpcomingRecurringTasks();
        }, onError: (error) => debugPrint('Task stream error: $error'));
  }

  void checkRecurringTasks() {
    _ensureUpcomingRecurringTasks();
  }

  void _calculateInitialXP() {
    final currentUserId = _currentUserId;
    int baseXP = _tasks
        .where(
          (task) =>
              task.isPersonal &&
              task.isCompleted &&
              !task.rewardBlocked &&
              !task.isDeleted &&
              (currentUserId != null &&
                  (task.creatorId == currentUserId ||
                      task.assigneeIds.contains(currentUserId))),
        )
        .fold(0, (total, task) {
          final awardedXP = task.awardedXP;
          return (total + (awardedXP > 0 ? awardedXP : task.calculateXP))
              .toInt();
        });

    _totalXP = calculateFinalXpWithLevelBonus(0, baseXP);
  }

  Map<String, dynamic> _milestoneRewardFields({
    required Map<String, dynamic>? data,
    required int oldLevel,
    required int newLevel,
  }) {
    final rewardIds = milestoneRewardIdsForLevelUp(oldLevel, newLevel);

    return {
      'equippedFrame': data?['equippedFrame'] ?? '',
      'equippedTitle': data?['equippedTitle'] ?? '',
      'unlockedItems': rewardIds.isEmpty
          ? _readStringList(data?['unlockedItems'])
          : FieldValue.arrayUnion(rewardIds),
    };
  }

  Future<void> _updateUserProgress(
    String userId, {
    required int xpDelta,
    int personalTaskDelta = 0,
    int groupTaskDelta = 0,
    int memberGroupTaskDelta = 0,
    int leaderGroupTaskDelta = 0,
  }) async {
    final userRef = _firestore.collection('users').doc(userId);
    await _firestore.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      final data = userSnap.data();
      final currentXP = _readInt(data?['totalXP']);
      final newXP = calculateFinalXpWithLevelBonus(currentXP, xpDelta);
      final oldLevel = calculateLevelProgress(currentXP).currentLevel;
      final newLevel = calculateLevelProgress(newXP).currentLevel;
      final newTasksCompleted =
          (_readInt(data?['tasksCompleted']) + personalTaskDelta)
              .clamp(0, 1 << 31)
              .toInt();
      final newGroupTasksCompleted =
          (_readInt(data?['groupTasksCompleted']) + groupTaskDelta)
              .clamp(0, 1 << 31)
              .toInt();
      final newMemberGroupTasksCompleted =
          (_readInt(data?['memberGroupTasksCompleted']) + memberGroupTaskDelta)
              .clamp(0, 1 << 31)
              .toInt();
      final newLeaderGroupTasksCompleted =
          (_readInt(data?['leaderGroupTasksCompleted']) + leaderGroupTaskDelta)
              .clamp(0, 1 << 31)
              .toInt();
      final currentStreak = _readInt(data?['currentStreak']);
      final unlockedIds = mergedUnlockedAchievementIds(
        existingIds: _readStringList(data?['achievementsUnlocked']),
        tasksCompleted: newTasksCompleted,
        currentStreak: currentStreak,
        groupTasksCompleted: newGroupTasksCompleted,
        memberGroupTasksCompleted: newMemberGroupTasksCompleted,
        leaderGroupTasksCompleted: newLeaderGroupTasksCompleted,
        currentLevel: newLevel,
      );

      transaction.set(userRef, {
        'totalXP': newXP,
        'tasksCompleted': newTasksCompleted,
        'groupTasksCompleted': newGroupTasksCompleted,
        'memberGroupTasksCompleted': newMemberGroupTasksCompleted,
        'leaderGroupTasksCompleted': newLeaderGroupTasksCompleted,
        'currentLevel': newLevel,
        'achievementsUnlocked': unlockedIds,
        ..._milestoneRewardFields(
          data: data,
          oldLevel: oldLevel,
          newLevel: newLevel,
        ),
      }, SetOptions(merge: true));
    });
  }

  int _completedPersonalTasksCountFor(String currentUserId) {
    return _tasks
        .where(
          (task) =>
              task.isPersonal &&
              task.isCompleted &&
              !task.rewardBlocked &&
              !task.isDeleted &&
              (task.creatorId == currentUserId ||
                  task.assigneeIds.contains(currentUserId)),
        )
        .length;
  }

  void _refreshSelectedTask() {
    final selectedId = _selectedTask?.id;
    if (selectedId == null) return;
    _selectedTask = _taskById(selectedId);
  }

  Task? _taskById(String taskId) {
    try {
      return _tasks.firstWhere((task) => task.id == taskId);
    } catch (_) {
      return null;
    }
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  String _todayString() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return _dateString(today);
  }

  String _dateString(DateTime date) {
    final localDate = DateTime(date.year, date.month, date.day);
    return DateFormat('yyyy-MM-dd').format(localDate);
  }

  Task _clearRewardBlock(Task task) {
    return task.copyWith(
      rewardBlocked: false,
      clearRewardBlockedReason: true,
      clearRewardBlockedAt: true,
      clearRewardBlockedBy: true,
      clearCompletionAgeSeconds: true,
    );
  }

  Task _applyFastCompletionRewardBlock(
    Task task, {
    required DateTime completedAt,
    required String? userId,
  }) {
    return task.copyWith(
      awardedXP: 0,
      rewardBlocked: true,
      rewardBlockedReason: 'fast_completion',
      rewardBlockedAt: completedAt,
      rewardBlockedBy: userId,
      completionAgeSeconds: completedAt.difference(task.createdAt).inSeconds,
    );
  }

  Future<Task> _completePersonalTaskWithReward(
    String userId,
    Task completedTask,
  ) async {
    final todayString = _todayString();
    final userRef = _firestore.collection('users').doc(userId);
    final taskRef = _firestore.collection('tasks').doc(completedTask.id);
    late Task taskWithAward;
    await _firestore.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      final data = userSnap.data();
      final counter = normalizePersonalTaskCounter(
        completedToday: _readInt(data?['personalTasksCompletedToday']),
        lastResetDate: data?['lastResetDate']?.toString(),
        todayString: todayString,
      );
      final nextCompletedToday = counter.completedToday + 1;
      int awardedXP = calculateDiminishedPersonalTaskXp(
        baseXp: completedTask.calculateXP,
        completedTaskNumber: nextCompletedToday,
      );

      final completedAt = completedTask.completedAt ?? DateTime.now();
      final diffHours = completedAt.difference(completedTask.dateTime).inHours;
      if (diffHours >= 24) {
        final penalty = (awardedXP * 0.12).round();
        awardedXP -= penalty;
        if (awardedXP < 0) awardedXP = 0;
      }
      final currentXP = _readInt(data?['totalXP']);
      final currentTasksCompleted = _readInt(data?['tasksCompleted']);
      final newXP = calculateFinalXpWithLevelBonus(currentXP, awardedXP);
      final oldLevel = calculateLevelProgress(currentXP).currentLevel;
      final newLevel = calculateLevelProgress(newXP).currentLevel;
      taskWithAward = completedTask.copyWith(awardedXP: awardedXP);

      transaction.set(userRef, {
        'totalXP': newXP,
        'tasksCompleted': currentTasksCompleted + 1,
        'currentLevel': newLevel,
        'personalTasksCompletedToday': nextCompletedToday,
        'lastResetDate': todayString,
        'achievementsUnlocked': mergedUnlockedAchievementIds(
          existingIds: _readStringList(data?['achievementsUnlocked']),
          tasksCompleted: currentTasksCompleted + 1,
          currentStreak: _readInt(data?['currentStreak']),
          groupTasksCompleted: _readInt(data?['groupTasksCompleted']),
          memberGroupTasksCompleted: _readInt(
            data?['memberGroupTasksCompleted'],
          ),
          leaderGroupTasksCompleted: _readInt(
            data?['leaderGroupTasksCompleted'],
          ),
          currentLevel: newLevel,
        ),
        ..._milestoneRewardFields(
          data: data,
          oldLevel: oldLevel,
          newLevel: newLevel,
        ),
      }, SetOptions(merge: true));
      transaction.set(taskRef, taskWithAward.toMap(), SetOptions(merge: true));
    });
    return taskWithAward;
  }

  Future<Task> _undoPersonalTaskReward(
    String userId,
    Task revertedTask,
    int previousAwardedXP,
  ) async {
    final userRef = _firestore.collection('users').doc(userId);
    final taskRef = _firestore.collection('tasks').doc(revertedTask.id);
    late Task taskWithoutAward;
    await _firestore.runTransaction((transaction) async {
      final userSnap = await transaction.get(userRef);
      final data = userSnap.data();
      final xpToRemove = previousAwardedXP > 0
          ? previousAwardedXP
          : revertedTask.calculateXP;
      final currentXP = _readInt(data?['totalXP']);
      final currentTasksCompleted = _readInt(data?['tasksCompleted']);
      final currentPersonalCompletedToday = _readInt(
        data?['personalTasksCompletedToday'],
      );
      final newXP = calculateFinalXpWithLevelBonus(currentXP, -xpToRemove);
      final oldLevel = calculateLevelProgress(currentXP).currentLevel;
      final newLevel = calculateLevelProgress(newXP).currentLevel;
      taskWithoutAward = revertedTask.copyWith(awardedXP: 0);

      final newPersonalCompletedToday =
          (currentPersonalCompletedToday - 1).clamp(0, 1 << 31).toInt();

      transaction.set(userRef, {
        'totalXP': newXP,
        'tasksCompleted': (currentTasksCompleted - 1).clamp(0, 1 << 31).toInt(),
        'personalTasksCompletedToday': newPersonalCompletedToday,
        'currentLevel': newLevel,
        ..._milestoneRewardFields(
          data: data,
          oldLevel: oldLevel,
          newLevel: newLevel,
        ),
      }, SetOptions(merge: true));
      transaction.set(
        taskRef,
        taskWithoutAward.toMap(),
        SetOptions(merge: true),
      );
    });
    return taskWithoutAward;
  }

  bool isLeaderForTask(Task task, String? userId) {
    if (userId == null) return false;
    final projectId = task.projectId;
    if (projectId != null) {
      final project = getProjectById(projectId);
      if (project != null) return project.leaderId == userId;
    }
    return task.creatorId == userId;
  }

  String leaderIdForTask(Task task) {
    final projectId = task.projectId;
    if (projectId != null) {
      final project = getProjectById(projectId);
      if (project != null && project.leaderId.isNotEmpty) {
        return project.leaderId;
      }
    }
    return task.creatorId;
  }

  bool canCurrentUserRestoreCompletedTask(Task task) {
    if (!task.isGroup) return true;
    final currentUserId = _currentUserId ?? _auth.currentUser?.uid;
    return currentUserId != null && currentUserId == leaderIdForTask(task);
  }

  bool _isCurrentUserLeaderOfTask(Task task) {
    final currentUserId = _currentUserId ?? _auth.currentUser?.uid;
    return currentUserId != null && currentUserId == leaderIdForTask(task);
  }

  static bool checkAllGroupMembersCompleted({
    required Task task,
    required String leaderId,
  }) {
    if (!task.isGroup) return true;
    final nonLeaderMembers =
        task.members.where((m) => m.id != leaderId).toList();
    final membersToCheck =
        nonLeaderMembers.isNotEmpty ? nonLeaderMembers : task.members;
    if (task.members.isEmpty) {
      return task.isCompleted ||
          (task.submissionText != null &&
              task.submissionText!.trim().isNotEmpty) ||
          task.attachments.isNotEmpty ||
          (task.submittedBy != null && task.submittedBy!.isNotEmpty) ||
          task.status == TaskStatus.pending;
    }
    return membersToCheck.every((m) => m.status == 'completed');
  }

  bool areAllGroupMembersCompleted(Task task) {
    return checkAllGroupMembersCompleted(
      task: task,
      leaderId: leaderIdForTask(task),
    );
  }

  void setActiveSubTabIndex(int index) {
    _activeSubTabIndex = index;
    notifyListeners();
  }

  List<Task> getTasksForDate(DateTime date) {
    return tasks.where((task) => _isSameDay(task.dateTime, date)).toList();
  }

  List<Task> getTasksForProject(String projectId) {
    return tasks.where((t) => t.projectId == projectId).toList();
  }

  Project? getProjectById(String projectId) {
    try {
      return _projects.firstWhere((p) => p.id == projectId);
    } catch (_) {
      return null;
    }
  }

  User? getUserById(String userId) {
    if (userId == MockData.currentUser.id) return MockData.currentUser;
    if (_userCache.containsKey(userId)) {
      return _userCache[userId];
    }
    final friendMatch = _friends.where((f) => f.id == userId).firstOrNull;
    if (friendMatch != null) {
      _userCache[userId] = friendMatch;
      return friendMatch;
    }
    _fetchUserAndNotify(userId);
    return MockData.getUserById(userId);
  }

  void selectTask(Task task) {
    _selectedTask = task;
    notifyListeners();
  }

  void clearSelectedTask() {
    _selectedTask = null;
    notifyListeners();
  }

  void selectProject(Project project) {
    _selectedProject = project;
    notifyListeners();
  }

  Set<String> _taskNotificationRecipientIds(Task task) {
    final ids = <String>{};
    ids.addAll(task.assigneeIds.where((id) => id.trim().isNotEmpty));
    for (final member in task.members) {
      if (member.id.trim().isNotEmpty) ids.add(member.id);
      ids.addAll(member.coAssigneeIds.where((id) => id.trim().isNotEmpty));
    }
    if (task.creatorId.trim().isNotEmpty) ids.add(task.creatorId);
    final leaderId = leaderIdForTask(task);
    if (leaderId.trim().isNotEmpty) ids.add(leaderId);
    return ids;
  }

  Set<String> _groupCreatedNotificationRecipientIds(Task task) {
    final ids = <String>{};
    if (task.members.isNotEmpty) {
      for (final member in task.members) {
        if (member.id.trim().isNotEmpty) ids.add(member.id.trim());
        ids.addAll(
          member.coAssigneeIds
              .where((id) => id.trim().isNotEmpty)
              .map((id) => id.trim()),
        );
      }
    } else {
      ids.addAll(
        task.assigneeIds
            .where((id) => id.trim().isNotEmpty)
            .map((id) => id.trim()),
      );
    }

    ids.remove(task.creatorId);
    ids.remove(leaderIdForTask(task));
    final currentUserId = _currentUserId ?? _auth.currentUser?.uid;
    if (currentUserId != null) ids.remove(currentUserId);
    return ids;
  }

  Future<void> _createUserNotifications(
    Iterable<String> recipientIds,
    Map<String, dynamic> data,
  ) async {
    final normalizedIds = recipientIds
        .where((id) => id.trim().isNotEmpty)
        .map((id) => id.trim())
        .toSet();
    if (normalizedIds.isEmpty) return;

    final sanitizedData = Map<String, dynamic>.from(data);
    if (sanitizedData['title'] != null) {
      sanitizedData['title'] = AppConstants.sanitizeThaiDisplay(
        sanitizedData['title'].toString(),
      );
    }
    if (sanitizedData['body'] != null) {
      sanitizedData['body'] = AppConstants.sanitizeThaiDisplay(
        sanitizedData['body'].toString(),
      );
    }

    final batch = _firestore.batch();
    final pushTargets = <Map<String, String>>[];
    final now = DateTime.now();
    final expireAt = now.add(const Duration(days: 30));
    for (final userId in normalizedIds.take(450)) {
      final ref = _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc();
      pushTargets.add({'userId': userId, 'notificationId': ref.id});
      batch.set(ref, {
        ...sanitizedData,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
        'expireAt': Timestamp.fromDate(expireAt),
      });
    }

    await batch.commit();
    await _pushUserNotifications(pushTargets);
  }

  Future<void> _pushUserNotifications(
    List<Map<String, String>> pushTargets,
  ) async {
    if (pushTargets.isEmpty) return;

    try {
      final callable = _functions.httpsCallable('pushInAppNotification');
      await callable.call<Map<String, dynamic>>({'notifications': pushTargets});
    } catch (error) {
      debugPrint('Failed to push in-app notifications: $error');
    }
  }

  Future<void> _notifyGroupTaskCreated(Task task) async {
    if (!task.isGroup) return;

    final recipients = _groupCreatedNotificationRecipientIds(task);
    if (recipients.isEmpty) return;

    final leader = getUserById(task.creatorId);
    final actorName =
        leader?.name ?? _auth.currentUser?.displayName ?? 'หัวหน้ากลุ่ม';
    final actorAvatarUrl =
        leader?.avatarUrl ?? _auth.currentUser?.photoURL ?? '';

    try {
      await _createUserNotifications(recipients, {
        'title': '$actorName สร้างภารกิจกลุ่มใหม่',
        'body':
            'คุณถูกเพิ่มเข้าร่วมภารกิจ "${task.title}" เปิดดูรายละเอียดและเริ่มภารกิจได้เลย',
        'type': 'Group',
        'taskId': task.id,
        'taskType': 'group',
        'notificationStage': 'groupCreated',
        'notificationKey': '${task.id}-group-created',
        'actorId': task.creatorId,
        'actorName': actorName,
        'actorAvatarUrl': actorAvatarUrl,
      });
    } catch (error) {
      debugPrint('Failed to create group notifications: $error');
    }
  }

  Future<void> _notifyNewGroupMembersAdded(
    Task previousTask,
    Task updatedTask,
  ) async {
    if (!updatedTask.isGroup) return;

    final currentUserId = _currentUserId ?? _auth.currentUser?.uid;
    final leader = getUserById(updatedTask.creatorId);
    final actorUser =
        currentUserId != null ? getUserById(currentUserId) : leader;
    final actorName =
        actorUser?.name ?? _auth.currentUser?.displayName ?? 'หัวหน้ากลุ่ม';
    final actorAvatarUrl =
        actorUser?.avatarUrl ?? _auth.currentUser?.photoURL ?? '';

    // 1. รวบรวม ID ของสมาชิกเดิมที่มีอยู่แล้วในกลุ่ม/โปรเจกต์
    // ประกอบด้วย:
    // - สมาชิกทั้งหมดในโปรเจกต์ (หากเป็นภารกิจในโปรเจกต์ Project.memberIds)
    // - สมาชิกเดิมใน previousTask (members, assigneeIds, coAssigneeIds, creatorId, leaderId)
    final projId = updatedTask.projectId;
    final projectMemberIds = (projId != null && projId.trim().isNotEmpty)
        ? (getProjectById(projId.trim())
                ?.memberIds
                .map((id) => id.trim())
                .toSet() ??
            <String>{})
        : <String>{};

    final previousTaskMemberIds = previousTask.members
        .map((m) => m.id.trim())
        .where((id) => id.isNotEmpty)
        .toSet();

    final previousAllParticipantIds = _taskNotificationRecipientIds(previousTask)
        .map((id) => id.trim())
        .toSet();

    final existingGroupUserIds = <String>{
      ...projectMemberIds,
      ...previousTaskMemberIds,
      ...previousAllParticipantIds,
    };

    // 2. ตรวจสอบสมาชิกที่ได้รับมอบหมายงานใหม่ (Reassigned) หรือสมาชิกใหม่จากภายนอก (Truly New)
    final reassignedMembers = <Member>[];
    final trulyNewMembers = <Member>[];

    final previousMemberMap = <String, Member>{
      for (final m in previousTask.members)
        if (m.id.trim().isNotEmpty) m.id.trim(): m,
    };

    for (final newM in updatedTask.members) {
      final memberId = newM.id.trim();
      if (memberId.isEmpty) continue;
      if (currentUserId != null && memberId == currentUserId) continue;
      if (memberId == leaderIdForTask(updatedTask)) continue;

      final oldM = previousMemberMap[memberId];
      final newHasTask =
          newM.taskTitle != null && newM.taskTitle!.trim().isNotEmpty;
      final oldHasTask =
          oldM?.taskTitle != null && oldM!.taskTitle!.trim().isNotEmpty;

      if (oldM == null) {
        // สมาชิกที่เพิ่งมีชื่อในภารกิจนี้
        if (existingGroupUserIds.contains(memberId)) {
          // เป็นสมาชิกเดิมของกลุ่ม/โปรเจกต์ ที่เพิ่งได้รับมอบหมายงาน
          reassignedMembers.add(newM);
        } else {
          // สมาชิกใหม่จากภายนอกจริงๆ
          trulyNewMembers.add(newM);
        }
      } else {
        // มีชื่ออยู่ในภารกิจเดิมอยู่แล้ว:
        // ตรวจสอบว่าได้รับงานใหม่หรือไม่ (เดิมไม่มีงานแต่ตอนนี้มีงาน หรือเปลี่ยนชื่องานใหม่)
        if (newHasTask &&
            (!oldHasTask || oldM.taskTitle!.trim() != newM.taskTitle!.trim())) {
          reassignedMembers.add(newM);
        }
      }
    }

    // 3. ตรวจสอบสมาชิกเดิมที่เคยมีงานใน previousTask แต่ถูกปลด/เปลี่ยนผู้รับผิดชอบออกไป (Unassigned Members)
    final updatedMemberMap = <String, Member>{
      for (final m in updatedTask.members)
        if (m.id.trim().isNotEmpty) m.id.trim(): m,
    };

    final unassignedMemberIds = <String>{};
    for (final oldM in previousTask.members) {
      final oldId = oldM.id.trim();
      if (oldId.isEmpty) continue;
      if (currentUserId != null && oldId == currentUserId) continue;
      if (oldId == leaderIdForTask(updatedTask)) continue;

      final oldHasTask =
          oldM.taskTitle != null && oldM.taskTitle!.trim().isNotEmpty;
      if (!oldHasTask) continue;

      final newM = updatedMemberMap[oldId];
      final newHasTask =
          newM?.taskTitle != null && newM!.taskTitle!.trim().isNotEmpty;

      // ถูกปลดงานเมื่อ:
      // 1) ถูกลบชื่อออกจากภารกิจ (newM == null)
      // 2) หรือยังมีชื่ออยู่ แต่ taskTitle ถูกล้างเป็นค่าว่าง (newHasTask == false)
      if (newM == null || !newHasTask) {
        unassignedMemberIds.add(oldId);
      }
    }

    // 4. ตรวจสอบการเพิ่มหรือนำออกผู้รับผิดชอบร่วม (Co-Assignees)
    String getMemberName(String id) {
      final u = getUserById(id);
      if (u != null && u.name.trim().isNotEmpty) return u.name.trim();
      for (final m in updatedTask.members) {
        if (m.id == id && m.name.trim().isNotEmpty) return m.name.trim();
      }
      for (final m in previousTask.members) {
        if (m.id == id && m.name.trim().isNotEmpty) return m.name.trim();
      }
      return 'เพื่อนร่วมทีม';
    }

    final addedCoNotifications = <Map<String, dynamic>>[];
    final removedCoNotifications = <Map<String, dynamic>>[];

    // รวบรวมคู่ความสัมพันธ์ผู้รับผิดชอบร่วมใน previousTask โดยผูกกับ taskTitle
    // เพื่อป้องกันการตรวจจับคู่ผิดชื่องาน (Cross-Task Co-Assignee Mismatch)
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

    // รวบรวมคู่ความสัมพันธ์ผู้รับผิดชอบร่วมใน updatedTask โดยผูกกับ taskTitle
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

    // ตรวจหาคู่ผู้ช่วยที่เพิ่งถูกเพิ่มเข้ามาใหม่ (Added Co-assignees)
    for (final entry in updatedCoPairs.entries) {
      final pairKey = entry.key;
      if (previousCoPairs.containsKey(pairKey)) continue;

      final item = entry.value;
      final taskTitle = item['taskTitle'] as String;
      final u1 = item['user1'] as String;
      final u2 = item['user2'] as String;

      final oldM1 = previousMemberMap[u1];
      final oldM2 = previousMemberMap[u2];
      final u1HadTask = oldM1 != null && oldM1.taskTitle?.trim() == taskTitle;
      final u2HadTask = oldM2 != null && oldM2.taskTitle?.trim() == taskTitle;

      String actualMainId = u1;
      String actualCoId = u2;
      if (!u1HadTask && u2HadTask) {
        actualMainId = u2;
        actualCoId = u1;
      } else if (!u1HadTask && !u2HadTask) {
        actualMainId = item['memberId'] as String;
        actualCoId = (actualMainId == u1) ? u2 : u1;
      }

      addedCoNotifications.add({
        'mainId': actualMainId,
        'coId': actualCoId,
        'mainName': getMemberName(actualMainId),
        'coName': getMemberName(actualCoId),
        'taskTitle': taskTitle,
      });
    }

    // ตรวจหาคู่ผู้ช่วยที่เพิ่งถูกนำออก (Removed Co-assignees)
    for (final entry in previousCoPairs.entries) {
      final pairKey = entry.key;
      if (updatedCoPairs.containsKey(pairKey)) continue;

      final item = entry.value;
      final taskTitle = item['taskTitle'] as String;
      final u1 = item['user1'] as String;
      final u2 = item['user2'] as String;

      final newM1 = updatedMemberMap[u1];
      final newM2 = updatedMemberMap[u2];
      final u1StillHasTask =
          newM1 != null && newM1.taskTitle?.trim() == taskTitle;
      final u2StillHasTask =
          newM2 != null && newM2.taskTitle?.trim() == taskTitle;

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
        'mainName': getMemberName(actualMainId),
        'coName': getMemberName(actualCoId),
        'taskTitle': taskTitle,
      });
    }

    try {
      final nowTimestamp = DateTime.now().millisecondsSinceEpoch;

      // --- กรณีที่ 1: สมาชิกเดิมของกลุ่มที่ได้รับมอบหมายงานใหม่ (Reassigned) ---
      for (final member in reassignedMembers) {
        final memberId = member.id.trim();
        if (currentUserId != null && memberId == currentUserId) continue;

        final taskLabel = member.taskTitle?.trim().isNotEmpty == true
            ? member.taskTitle!.trim()
            : updatedTask.title;

        // ข้ามเฉพาะกรณีที่เพิ่งได้รับแจ้งเตือนในฐานะผู้รับผิดชอบร่วมของงานเดียวกันนี้ไปแล้ว
        final alreadyNotifiedAsCoForThisTask = addedCoNotifications.any(
          (item) => item['coId'] == memberId && item['taskTitle'] == taskLabel,
        );
        if (alreadyNotifiedAsCoForThisTask) continue;

        await _createUserNotifications({memberId}, {
          'title': '$actorName มอบหมายงานให้คุณ',
          'body':
              'คุณได้รับมอบหมายงาน "$taskLabel" ในภารกิจ "${updatedTask.title}" เปิดดูรายละเอียดได้เลย',
          'type': 'Group',
          'taskId': updatedTask.id,
          'taskType': 'group',
          'notificationStage': 'taskAssigned',
          'notificationKey':
              '${updatedTask.id}-task-assigned-$memberId-$nowTimestamp',
          'actorId': currentUserId ?? updatedTask.creatorId,
          'actorName': actorName,
          'actorAvatarUrl': actorAvatarUrl,
        });
      }

      // --- กรณีที่ 1.5: เพิ่มผู้รับผิดชอบร่วม (Co-Assignees Added) ---
      for (final item in addedCoNotifications) {
        final actualMainId = item['mainId'] as String;
        final actualCoId = item['coId'] as String;
        final mainName = item['mainName'] as String;
        final coName = item['coName'] as String;
        final taskTitle = item['taskTitle'] as String;

        // 1) แจ้งเตือนไปยังคนที่ถูกเพิ่มเข้ามาช่วย (Co-Assignee)
        if (currentUserId == null || actualCoId != currentUserId) {
          await _createUserNotifications({actualCoId}, {
            'title': '$actorName เพิ่มคุณเป็นผู้รับผิดชอบร่วม',
            'body':
                'คุณได้รับมอบหมายให้ร่วมทำภารกิจ "$taskTitle" กับ $mainName ในภารกิจ "${updatedTask.title}" เปิดดูรายละเอียดได้เลย',
            'type': 'Group',
            'taskId': updatedTask.id,
            'taskType': 'group',
            'notificationStage': 'coAssigneeAdded',
            'notificationKey':
                '${updatedTask.id}-co-assignee-added-$actualCoId-$nowTimestamp',
            'actorId': currentUserId ?? updatedTask.creatorId,
            'actorName': actorName,
            'actorAvatarUrl': actorAvatarUrl,
          });
        }

        // 2) แจ้งเตือนไปยังเจ้าของงานหลัก (Main Assignee)
        if (currentUserId == null || actualMainId != currentUserId) {
          await _createUserNotifications({actualMainId}, {
            'title': '$actorName เพิ่มผู้ช่วยในงานของคุณ',
            'body':
                '$actorName ได้มอบหมายให้ $coName เข้ามาช่วยทำภารกิจ "$taskTitle" แล้ว',
            'type': 'Group',
            'taskId': updatedTask.id,
            'taskType': 'group',
            'notificationStage': 'coAssigneeJoined',
            'notificationKey':
                '${updatedTask.id}-co-assignee-joined-$actualMainId-$nowTimestamp',
            'actorId': currentUserId ?? updatedTask.creatorId,
            'actorName': actorName,
            'actorAvatarUrl': actorAvatarUrl,
          });
        }
      }

      // --- กรณีที่ 1.6: นำผู้รับผิดชอบร่วมออก (Co-Assignees Removed) ---
      for (final item in removedCoNotifications) {
        final actualMainId = item['mainId'] as String;
        final actualCoId = item['coId'] as String;
        final mainName = item['mainName'] as String;
        final coName = item['coName'] as String;
        final taskTitle = item['taskTitle'] as String;

        // 1) แจ้งเตือนไปยังคนที่ถูกนำออก (Removed Co-Assignee)
        if (currentUserId == null || actualCoId != currentUserId) {
          await _createUserNotifications({actualCoId}, {
            'title': '$actorName ปรับเปลี่ยนผู้รับผิดชอบร่วม',
            'body':
                'คุณไม่ได้เป็นผู้รับผิดชอบร่วมในงาน "$taskTitle" กับ $mainName ของภารกิจ "${updatedTask.title}" แล้ว',
            'type': 'Group',
            'taskId': updatedTask.id,
            'taskType': 'group',
            'notificationStage': 'coAssigneeRemoved',
            'notificationKey':
                '${updatedTask.id}-co-assignee-removed-$actualCoId-$nowTimestamp',
            'actorId': currentUserId ?? updatedTask.creatorId,
            'actorName': actorName,
            'actorAvatarUrl': actorAvatarUrl,
          });
        }

        // 2) แจ้งเตือนไปยังเจ้าของงานหลัก (Main Assignee)
        if (currentUserId == null || actualMainId != currentUserId) {
          await _createUserNotifications({actualMainId}, {
            'title': '$actorName ปรับเปลี่ยนผู้รับผิดชอบร่วม',
            'body':
                '$actorName ได้นำ $coName ออกจากการเป็นผู้ช่วยในงาน "$taskTitle"',
            'type': 'Group',
            'taskId': updatedTask.id,
            'taskType': 'group',
            'notificationStage': 'coAssigneeLeft',
            'notificationKey':
                '${updatedTask.id}-co-assignee-left-$actualMainId-$nowTimestamp',
            'actorId': currentUserId ?? updatedTask.creatorId,
            'actorName': actorName,
            'actorAvatarUrl': actorAvatarUrl,
          });
        }
      }

      // --- กรณีที่ 2: สมาชิกเดิมที่ถูกเปลี่ยนผู้รับผิดชอบออก (Unassigned) ---
      if (unassignedMemberIds.isNotEmpty) {
        await _createUserNotifications(unassignedMemberIds, {
          'title': '$actorName ปรับเปลี่ยนผู้รับผิดชอบ',
          'body':
              'ภารกิจ "${updatedTask.title}" มีการปรับเปลี่ยนผู้รับผิดชอบงานแล้ว',
          'type': 'Group',
          'taskId': updatedTask.id,
          'taskType': 'group',
          'notificationStage': 'taskUnassigned',
          'notificationKey':
              '${updatedTask.id}-task-unassigned-$nowTimestamp',
          'actorId': currentUserId ?? updatedTask.creatorId,
          'actorName': actorName,
          'actorAvatarUrl': actorAvatarUrl,
        });
      }

      // --- กรณีที่ 3: สมาชิกใหม่จริงๆ ที่เพิ่งเข้ากลุ่มเป็นครั้งแรก (Truly New Members) ---
      if (trulyNewMembers.isNotEmpty) {
        final trulyNewMemberIds =
            trulyNewMembers.map((m) => m.id.trim()).toSet();
        if (currentUserId != null) trulyNewMemberIds.remove(currentUserId);

        if (trulyNewMemberIds.isNotEmpty) {
          // แจ้งเตือนไปยังสมาชิกใหม่ว่าถูกเพิ่มเข้ากลุ่ม
          await _createUserNotifications(trulyNewMemberIds, {
            'title': '$actorName เพิ่มคุณเข้าร่วมภารกิจกลุ่ม',
            'body':
                'คุณถูกเพิ่มเข้าร่วมภารกิจ "${updatedTask.title}" เปิดดูรายละเอียดและเริ่มภารกิจได้เลย',
            'type': 'Group',
            'taskId': updatedTask.id,
            'taskType': 'group',
            'notificationStage': 'groupMemberAdded',
            'notificationKey':
                '${updatedTask.id}-member-added-$nowTimestamp',
            'actorId': currentUserId ?? updatedTask.creatorId,
            'actorName': actorName,
            'actorAvatarUrl': actorAvatarUrl,
          });

          // แจ้งเตือนไปยังสมาชิกเดิมทุกคนในกลุ่มว่ามีสมาชิกใหม่เข้ากลุ่ม
          final existingRecipients =
              _taskNotificationRecipientIds(updatedTask)
                ..removeAll(trulyNewMemberIds);
          if (currentUserId != null) {
            existingRecipients.remove(currentUserId);
          }

          if (existingRecipients.isNotEmpty) {
            final newMemberNames = trulyNewMembers
                .map((m) => m.name.trim())
                .where((name) => name.isNotEmpty)
                .join(', ');
            final displayName =
                newMemberNames.isNotEmpty ? newMemberNames : 'สมาชิกใหม่';
            await _createUserNotifications(existingRecipients, {
              'title': 'สมาชิกใหม่ในภารกิจ "${updatedTask.title}"',
              'body': '$displayName ถูกเพิ่มเข้ากลุ่มแล้ว',
              'type': 'Group',
              'taskId': updatedTask.id,
              'taskType': 'group',
              'notificationStage': 'groupMemberJoined',
              'notificationKey':
                  '${updatedTask.id}-member-joined-$nowTimestamp',
              'actorId': currentUserId ?? updatedTask.creatorId,
              'actorName': actorName,
              'actorAvatarUrl': actorAvatarUrl,
            });
          }
        }
      }
    } catch (error) {
      debugPrint('Failed to send member notifications: $error');
    }
  }

  Future<void> _notifyGroupTaskUpdated(
    Task previousTask,
    Task updatedTask,
  ) async {
    if (!updatedTask.isGroup) return;

    final currentUserId = _currentUserId ?? _auth.currentUser?.uid;
    final leaderId = leaderIdForTask(updatedTask);

    // ตรวจสอบว่าผู้แก้ไขคือหัวหน้ากลุ่มหรือผู้สร้างงาน
    final isLeaderOrCreator = currentUserId != null &&
        (currentUserId == leaderId || currentUserId == updatedTask.creatorId);

    if (!isLeaderOrCreator) return;

    // หาผู้รับการแจ้งเตือน (สมาชิกทุกคนในกลุ่ม ยกเว้นตัวหัวหน้าเอง)
    final recipients = _taskNotificationRecipientIds(updatedTask);
    recipients.remove(currentUserId);
    recipients.remove(leaderId);
    recipients.remove(updatedTask.creatorId);

    // สมาชิกใหม่ที่เพิ่งถูกเพิ่ม หรือเพิ่งได้รับมอบหมายงานในรอบนี้ จะได้รับแจ้งเตือนเฉพาะเจาะจงอยู่แล้ว
    // จึงคัดแยกออก เพื่อไม่ให้ได้รับแจ้งเตือนซ้ำซ้อน
    final previousMemberMap = <String, Member>{
      for (final m in previousTask.members)
        if (m.id.trim().isNotEmpty) m.id.trim(): m,
    };

    final memberDetailUpdatedRecipients = <String, String>{};
    final specificallyHandledMemberIds = <String>{};
    for (final newM in updatedTask.members) {
      final mid = newM.id.trim();
      if (mid.isEmpty) continue;
      final oldM = previousMemberMap[mid];
      final newHasTask =
          newM.taskTitle != null && newM.taskTitle!.trim().isNotEmpty;
      final oldHasTask =
          oldM?.taskTitle != null && oldM!.taskTitle!.trim().isNotEmpty;

      final oldCoIds = (oldM?.coAssigneeIds ?? []).map((id) => id.trim()).toSet();
      final newCoIds = newM.coAssigneeIds.map((id) => id.trim()).toSet();
      final coChanged = oldCoIds.length != newCoIds.length ||
          oldCoIds.any((id) => !newCoIds.contains(id));

      if (oldM == null ||
          coChanged ||
          (newHasTask &&
              (!oldHasTask || oldM.taskTitle!.trim() != newM.taskTitle!.trim()))) {
        specificallyHandledMemberIds.add(mid);
      } else if (oldHasTask &&
          newHasTask &&
          oldM.taskTitle!.trim() == newM.taskTitle!.trim()) {
        final subTasksChanged = oldM.subTasks.length != newM.subTasks.length ||
            oldM.subTasks.asMap().entries.any((e) =>
                e.key >= newM.subTasks.length ||
                e.value != newM.subTasks[e.key]);

        final detailsChanged = oldM.description != newM.description ||
            oldM.workload != newM.workload ||
            oldM.difficulty != newM.difficulty ||
            oldM.risk != newM.risk ||
            subTasksChanged;

        if (detailsChanged) {
          specificallyHandledMemberIds.add(mid);
          if (mid != currentUserId) {
            memberDetailUpdatedRecipients[mid] = newM.taskTitle!.trim();
          }
        }
      }
    }

    final leader = getUserById(currentUserId);
    final actorName =
        leader?.name ?? _auth.currentUser?.displayName ?? 'หัวหน้ากลุ่ม';
    final actorAvatarUrl =
        leader?.avatarUrl ?? _auth.currentUser?.photoURL ?? '';
    final nowTimestamp = DateTime.now().millisecondsSinceEpoch;

    // ส่งแจ้งเตือนการแก้ไขงานเฉพาะสมาชิกไปยังสมาชิกแต่ละคน
    for (final entry in memberDetailUpdatedRecipients.entries) {
      final targetUserId = entry.key;
      final memberTaskTitle = entry.value;
      try {
        await _createUserNotifications({targetUserId}, {
          'title': '$actorName อัปเดตรายละเอียดงานของคุณ',
          'body':
              'รายละเอียดในงาน "$memberTaskTitle" ของคุณในภารกิจ "${updatedTask.title}" มีการแก้ไขใหม่ เข้าไปเช็คเลย',
          'type': 'Group',
          'taskId': updatedTask.id,
          'taskType': 'group',
          'notificationStage': 'memberTaskUpdated',
          'notificationKey':
              '${updatedTask.id}-member-task-updated-$targetUserId-$nowTimestamp',
          'actorId': currentUserId,
          'actorName': actorName,
          'actorAvatarUrl': actorAvatarUrl,
        });
      } catch (e) {
        debugPrint('Failed to send member task update notification: $e');
      }
    }

    recipients.removeAll(specificallyHandledMemberIds);

    if (recipients.isEmpty) return;

    // ตรวจสอบว่ามีการแก้ไขข้อมูลงานกลุ่มภาพรวมหรือไม่ (เช่น ชื่องาน, รายละเอียด, วันที่เวลา, งานย่อย, ความสำคัญ ฯลฯ)
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

    // ส่งแจ้งเตือนภาพรวมกลุ่มเฉพาะเมื่อมีการแก้ไขฟิลด์ภาพรวมของงานกลุ่มเท่านั้น
    // หากเป็นการแก้ไขเฉพาะสมาชิก (เช่น มอบหมายงาน, แก้ไขรายละเอียดสมาชิก) จะไม่ส่งแจ้งเตือนภาพรวมนี้
    if (!isTaskContentUpdated) return;

    final oldDate = previousTask.dateTime;
    final newDate = updatedTask.dateTime;
    final isDateTimeChanged = !oldDate.isAtSameMomentAs(newDate);

    final isDateChanged = isDateTimeChanged &&
        (oldDate.year != newDate.year ||
            oldDate.month != newDate.month ||
            oldDate.day != newDate.day);

    final isTimeChanged = isDateTimeChanged &&
        (oldDate.hour != newDate.hour || oldDate.minute != newDate.minute);

    String notificationTitle;
    String notificationBody;
    String notificationStage;

    if (isDateChanged && isTimeChanged) {
      final dateStr = DateFormat('dd/MM/yyyy').format(newDate);
      final timeStr = DateFormat('HH:mm').format(newDate);
      notificationTitle =
          '$actorName เปลี่ยนกำหนดเวลาภารกิจ "${updatedTask.title}"';
      notificationBody = 'กำหนดเวลาใหม่เป็นวันที่ $dateStr เวลา $timeStr น.';
      notificationStage = 'taskRescheduled';
    } else if (isDateChanged) {
      final dateStr = DateFormat('dd/MM/yyyy').format(newDate);
      final timeStr = DateFormat('HH:mm').format(newDate);
      notificationTitle =
          '$actorName เลื่อนวันส่งภารกิจ "${updatedTask.title}"';
      notificationBody = 'เลื่อนวันส่งใหม่เป็นวันที่ $dateStr (เวลา $timeStr น.)';
      notificationStage = 'taskDateUpdated';
    } else if (isTimeChanged) {
      final dateStr = DateFormat('dd/MM/yyyy').format(newDate);
      final timeStr = DateFormat('HH:mm').format(newDate);
      notificationTitle =
          '$actorName ปรับเวลาภารกิจ "${updatedTask.title}"';
      notificationBody = 'ปรับเวลาส่งใหม่เป็น $timeStr น. (วันที่ $dateStr)';
      notificationStage = 'taskTimeUpdated';
    } else {
      notificationTitle = '$actorName แก้ไขภารกิจ "${updatedTask.title}"';
      notificationBody = '$actorName ได้แก้ไขรายละเอียดงานใหม่ เข้าไปเช็คเลย!';
      notificationStage = 'groupTaskUpdated';
    }

    try {
      await _createUserNotifications(recipients, {
        'title': notificationTitle,
        'body': notificationBody,
        'type': 'Group',
        'taskId': updatedTask.id,
        'taskType': 'group',
        'notificationStage': notificationStage,
        'notificationKey':
            '${updatedTask.id}-$notificationStage-$nowTimestamp',
        'actorId': currentUserId,
        'actorName': actorName,
        'actorAvatarUrl': actorAvatarUrl,
      });
    } catch (error) {
      debugPrint('Failed to send group task update notifications: $error');
    }
  }

  Future<void> _notifyTaskComment(Task task, Comment comment) async {
    if (!task.isGroup) return;

    final recipients = _taskNotificationRecipientIds(task)
      ..remove(comment.userId);
    if (recipients.isEmpty) return;

    final preview = comment.content.trim().isNotEmpty
        ? comment.content.trim()
        : 'ส่งไฟล์แนบใหม่ในภารกิจนี้';

    try {
      await _createUserNotifications(recipients, {
        'title': '${comment.userName} คอมเมนต์ในภารกิจ "${task.title}"',
        'body': preview.length > 120
            ? '${preview.substring(0, 120)}...'
            : preview,
        'type': 'Comment',
        'taskId': task.id,
        'taskType': 'group',
        'notificationStage': 'commentAdded',
        'notificationKey': 'task-comment-${task.id}',
        'actorId': comment.userId,
        'actorName': comment.userName,
        'actorAvatarUrl': comment.userAvatarUrl,
        'commentId': comment.id,
      });
    } catch (error) {
      debugPrint('Failed to create comment notifications: $error');
    }
  }

  Future<void> _notifyTaskSubmitted(
    Task task,
    String submitterId, {
    String? customSubmissionText,
  }) async {
    if (!task.isGroup) return;

    final leaderId = leaderIdForTask(task);
    if (leaderId.isEmpty || leaderId == submitterId) return;

    final submitter = getUserById(submitterId);
    final actorName =
        submitter?.name ?? _auth.currentUser?.displayName ?? 'สมาชิก';
    final actorAvatarUrl =
        submitter?.avatarUrl ?? _auth.currentUser?.photoURL ?? '';
    final submissionText =
        customSubmissionText?.trim() ?? task.submissionText?.trim() ?? '';
    final body = submissionText.isNotEmpty
        ? submissionText
        : 'ส่งงานเข้ามาให้ตรวจแล้ว เปิดดูรายละเอียดและอนุมัติหรือปฏิเสธได้เลย';

    try {
      await _createUserNotifications(
        [leaderId],
        {
          'title': '$actorName ส่งงาน "${task.title}" ให้ตรวจแล้ว',
          'body': body.length > 120 ? '${body.substring(0, 120)}...' : body,
          'type': 'Submission',
          'taskId': task.id,
          'taskType': 'group',
          'notificationStage': 'taskSubmitted',
          'notificationKey': '${task.id}-submitted-$submitterId',
          'actorId': submitterId,
          'actorName': actorName,
          'actorAvatarUrl': actorAvatarUrl,
        },
      );
    } catch (error) {
      debugPrint('Failed to create submission notification: $error');
    }
  }

  Future<void> _notifyTaskReviewDecision(
    Task task, {
    required String decision,
    required String submitterId,
    required String leaderId,
  }) async {
    if (!task.isGroup || submitterId.isEmpty || submitterId == leaderId) return;

    final leader = getUserById(leaderId);
    final actorName =
        leader?.name ?? _auth.currentUser?.displayName ?? 'หัวหน้า';
    final actorAvatarUrl =
        leader?.avatarUrl ?? _auth.currentUser?.photoURL ?? '';
    final isApproved = decision == 'approved';

    try {
      await _createUserNotifications(
        [submitterId],
        {
          'title': isApproved
              ? '$actorName อนุมัติงาน "${task.title}" แล้ว'
              : '$actorName ปฏิเสธงาน "${task.title}"',
          'body': isApproved
              ? 'งานของคุณผ่านการตรวจแล้ว เยี่ยมมาก!'
              : 'งานถูกส่งกลับมาให้แก้ไข ลองเปิดดูรายละเอียดแล้วส่งใหม่อีกครั้ง',
          'type': isApproved ? 'Approved' : 'Rejected',
          'taskId': task.id,
          'taskType': 'group',
          'notificationStage': isApproved ? 'taskApproved' : 'taskRejected',
          'notificationKey': '${task.id}-$decision-$submitterId',
          'actorId': leaderId,
          'actorName': actorName,
          'actorAvatarUrl': actorAvatarUrl,
        },
      );
    } catch (error) {
      debugPrint('Failed to create review decision notification: $error');
    }
  }

  void clearSelectedProject() {
    _selectedProject = null;
    notifyListeners();
  }

  void setSelectedDate(DateTime date) {
    _selectedDate = date;
    notifyListeners();
  }

  Future<void> addTask(Task task) async {
    _tasks.insert(0, task);
    _calculateInitialXP();
    notifyListeners();

    final taskData = task.toMap()
      ..addAll({
        'notified1Week': false,
        'notified1Day': false,
        'notified1Hour': false,
        'notifiedExact': false,
        'notifiedFollowUp': false,
        'isRecurring': task.isRecurring,
        'recurringType': task.recurringType,
        'recurringDate': task.recurringDate == null
            ? null
            : Timestamp.fromDate(task.recurringDate!),
        'recurringTime': task.recurringTime,
      });

    await _firestore.collection('tasks').doc(task.id).set(taskData);
    await _notifyGroupTaskCreated(task);
  }

  DateTime? _recurringDateTimeFor(Task task, [DateTime? fromDate]) {
    if (!task.isRecurring) return null;

    final baseDate = fromDate ?? task.dateTime;

    switch (task.recurringType) {
      case 'daily':
        return baseDate.add(const Duration(days: 1));
      case 'weekly':
        return baseDate.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(
          baseDate.year,
          baseDate.month + 1,
          baseDate.day,
          baseDate.hour,
          baseDate.minute,
        );
      case 'yearly':
        return DateTime(
          baseDate.year + 1,
          baseDate.month,
          baseDate.day,
          baseDate.hour,
          baseDate.minute,
        );
      case 'weekdays':
        DateTime next = baseDate.add(const Duration(days: 1));
        while (next.weekday == DateTime.saturday ||
            next.weekday == DateTime.sunday) {
          next = next.add(const Duration(days: 1));
        }
        return next;
      case 'custom':
        return _customRecurringDateTimeFor(task, fromDate);
      default:
        return _customRecurringDateTimeFor(task, fromDate) ??
            baseDate.add(const Duration(days: 1));
    }
  }

  DateTime? _nextUpcomingRecurringDateTime(Task task) {
    if (!task.isRecurring) return null;

    final now = DateTime.now();
    DateTime? next = _recurringDateTimeFor(task);
    if (next == null) return null;

    int iterations = 0;
    while (next != null && next.isBefore(now) && iterations < 50) {
      final candidate = _recurringDateTimeFor(task, next);
      if (candidate == null || !candidate.isAfter(next)) break;
      next = candidate;
      iterations++;
    }

    return next;
  }

  DateTime? _customRecurringDateTimeFor(Task task, [DateTime? fromDate]) {
    final num = task.customRecurringNum ?? 1;
    final unit = task.customRecurringUnit ?? 'วัน';
    final days = task.customRecurringDays ?? [];
    final mode = task.customRecurringMode ?? 'byDueDate';

    DateTime baseDate = fromDate ?? task.dateTime;
    if (mode == 'byFixedDate' && fromDate == null) {
      final fixed = task.customRecurringFixedDates ?? [];
      if (fixed.isNotEmpty) {
        final upcoming = fixed.where((d) => d.isAfter(task.dateTime)).toList()
          ..sort((a, b) => a.compareTo(b));
        if (upcoming.isNotEmpty) {
          return upcoming.first;
        }
      }
      if (task.recurringDate != null) {
        baseDate = task.recurringDate!;
      }
    }

    DateTime nextDate;
    if (unit == 'วัน') {
      nextDate = baseDate.add(Duration(days: num));
    } else if (unit == 'สัปดาห์') {
      if (days.isNotEmpty) {
        const thaiWeekdays = {
          'อา.': 7,
          'จ.': 1,
          'อ.': 2,
          'พ.': 3,
          'พฤ.': 4,
          'ศ.': 5,
          'ส.': 6,
        };
        final targetWeekdays =
            days.map((d) => thaiWeekdays[d]).whereType<int>().toList()..sort();

        if (targetWeekdays.isEmpty) {
          nextDate = baseDate.add(Duration(days: num * 7));
        } else {
          // หากมีวันถัดไปที่มากกว่าวันปัจจุบันในสัปดาห์เดียวกัน (เช่น จันทร์ -> อังคาร, จันทร์ -> ศุกร์)
          final remainingThisWeek =
              targetWeekdays.where((w) => w > baseDate.weekday).toList();
          if (remainingThisWeek.isNotEmpty) {
            final nextWeekday = remainingThisWeek.first;
            final daysUntilNext = nextWeekday - baseDate.weekday;
            nextDate = baseDate.add(Duration(days: daysUntilNext));
          } else {
            // จบสัปดาห์นี้แล้ว ข้ามไปยังสัปดาห์รอบถัดไป (เว้นระยะตาม num สัปดาห์)
            final firstWeekday = targetWeekdays.first;
            final daysToEndOfWeek = 7 - baseDate.weekday;
            final daysInNextInterval = (num - 1) * 7;
            final totalDaysToAdd =
                daysToEndOfWeek + daysInNextInterval + firstWeekday;
            nextDate = baseDate.add(Duration(days: totalDaysToAdd));
          }
        }
      } else {
        nextDate = baseDate.add(Duration(days: num * 7));
      }
    } else if (unit == 'เดือน') {
      nextDate = DateTime(
        baseDate.year,
        baseDate.month + num,
        baseDate.day,
        baseDate.hour,
        baseDate.minute,
      );
    } else if (unit == 'ปี') {
      nextDate = DateTime(
        baseDate.year + num,
        baseDate.month,
        baseDate.day,
        baseDate.hour,
        baseDate.minute,
      );
    } else {
      nextDate = baseDate.add(Duration(days: num));
    }

    if (task.recurringTime != null) {
      final parts = task.recurringTime!.split(':');
      if (parts.length == 2) {
        final h = int.tryParse(parts[0]);
        final m = int.tryParse(parts[1]);
        if (h != null && m != null && h >= 0 && h <= 23 && m >= 0 && m <= 59) {
          return DateTime(nextDate.year, nextDate.month, nextDate.day, h, m);
        }
      }
    }

    return nextDate;
  }

  Future<void> _cloneRecurringTaskToDate(
    Task sourceTask,
    DateTime recurringDateTime,
  ) async {
    // Check if a clone for this exact date and task already exists
    final hasExistingClone = _tasks.any(
      (t) =>
          !t.isDeleted &&
          t.title == sourceTask.title &&
          t.creatorId == sourceTask.creatorId &&
          t.isRecurring == sourceTask.isRecurring &&
          t.recurringType == sourceTask.recurringType &&
          t.dateTime.isAtSameMomentAs(recurringDateTime),
    );

    if (hasExistingClone) return;

    final cloneId = 'task_${DateTime.now().microsecondsSinceEpoch}';
    final now = DateTime.now();
    final isPastDue = recurringDateTime.isBefore(now);
    final isPastFollowUp =
        recurringDateTime.add(const Duration(minutes: 30)).isBefore(now);

    final Map<String, bool> initialCustomReminders = {};
    sourceTask.customReminders.forEach((minutesStr, _) {
      final minutes = int.tryParse(minutesStr) ?? 0;
      final reminderTime =
          recurringDateTime.subtract(Duration(minutes: minutes));
      initialCustomReminders[minutesStr] =
          minutes > 0 ? reminderTime.isBefore(now) : isPastDue;
    });

    final notif1Week =
        recurringDateTime.subtract(const Duration(days: 7)).isBefore(now);
    final notif1Day =
        recurringDateTime.subtract(const Duration(days: 1)).isBefore(now);
    final notif1Hour =
        recurringDateTime.subtract(const Duration(hours: 1)).isBefore(now);
    final notifExact = isPastDue;
    final notifFollowUp = isPastFollowUp;

    final clonedTask = sourceTask.copyWith(
      id: cloneId,
      dateTime: recurringDateTime,
      status: TaskStatus.inProgress,
      clearCompletedAt: true,
      isDeleted: false,
      deletedForUserIds: const [],
      hiddenForUserIds: const [],
      notified1Week: notif1Week,
      notified1Day: notif1Day,
      notified1Hour: notif1Hour,
      notifiedExact: notifExact,
      notifiedFollowUp: notifFollowUp,
      clearSubmissionText: true,
      clearSubmittedBy: true,
      clearSubmittedAt: true,
      awardedXP: 0,
      subtasks: sourceTask.subtasks
          .map((subtask) => subtask.copyWith(isDone: false))
          .toList(),
      comments: const [],
      customReminders: initialCustomReminders,
    );

    final cloneData = clonedTask.toMap()
      ..addAll({
        'notified1Week': notif1Week,
        'notified1Day': notif1Day,
        'notified1Hour': notif1Hour,
        'notifiedExact': notifExact,
        'notifiedFollowUp': notifFollowUp,
      });

    await _firestore.collection('tasks').doc(cloneId).set(cloneData);
  }

  Future<void> _completeOlderRecurringClones(Task task, DateTime completedAt) async {
    if (!task.isRecurring) return;

    final olderPendingClones = _tasks.where(
      (t) =>
          t.id != task.id &&
          !t.isDeleted &&
          !t.isCompleted &&
          t.isRecurring &&
          t.title.trim().toLowerCase() == task.title.trim().toLowerCase() &&
          t.creatorId == task.creatorId &&
          (t.projectId ?? '') == (task.projectId ?? '') &&
          t.dateTime.isBefore(task.dateTime),
    ).toList();

    if (olderPendingClones.isEmpty) return;

    final batch = _firestore.batch();
    for (final oldClone in olderPendingClones) {
      final oldIndex = _tasks.indexWhere((t) => t.id == oldClone.id);
      final updatedMembers = oldClone.members
          .map((m) => m.copyWith(status: 'completed'))
          .toList();

      if (oldIndex != -1) {
        _tasks[oldIndex] = oldClone.copyWith(
          status: TaskStatus.completed,
          completedAt: completedAt,
          members: updatedMembers,
        );
      }
      final updateData = <String, dynamic>{
        'status': TaskStatus.completed.name,
        'completedAt': Timestamp.fromDate(completedAt),
      };
      if (oldClone.members.isNotEmpty) {
        updateData['members'] = updatedMembers.map((m) => m.toMap()).toList();
      }
      batch.update(_firestore.collection('tasks').doc(oldClone.id), updateData);
    }
    await batch.commit();
  }

  Future<void> _cloneRecurringTaskAfterCompletion(Task sourceTask) async {
    final recurringDateTime = _nextUpcomingRecurringDateTime(sourceTask) ??
        _recurringDateTimeFor(sourceTask);
    if (recurringDateTime == null) return;

    final now = DateTime.now();
    // หากมีงานในซีรีส์เดียวกันที่ยังไม่เสร็จสำหรับรอบวันนี้หรือรอบในอนาคตอยู่แล้ว ไม่ต้องสร้างซ้ำ
    final hasActiveUpcomingClone = _tasks.any(
      (t) =>
          !t.isDeleted &&
          !t.isCompleted &&
          t.isRecurring &&
          t.title.trim().toLowerCase() == sourceTask.title.trim().toLowerCase() &&
          t.creatorId == sourceTask.creatorId &&
          (t.projectId ?? '') == (sourceTask.projectId ?? '') &&
          (t.dateTime.isAtSameMomentAs(recurringDateTime) || !t.dateTime.isBefore(now)),
    );
    if (hasActiveUpcomingClone) return;

    await _cloneRecurringTaskToDate(sourceTask, recurringDateTime);
  }

  bool _isEnsuringRecurring = false;
  Future<void> _ensureUpcomingRecurringTasks() async {
    if (_isEnsuringRecurring) return;
    final currentUserId = _currentUserId;
    if (currentUserId == null) return;

    _isEnsuringRecurring = true;
    try {
      final now = DateTime.now();
      final recurringTasks = _tasks
          .where(
            (t) =>
                t.isRecurring &&
                !t.isDeleted &&
                t.status != TaskStatus.completed &&
                (t.creatorId == currentUserId ||
                    t.assigneeIds.contains(currentUserId)) &&
                t.dateTime.isBefore(now),
          )
          .toList();

      for (final task in recurringTasks) {
        final upcomingDate = _nextUpcomingRecurringDateTime(task);
        if (upcomingDate == null) continue;

        final hasExisting = _tasks.any(
          (t) =>
              !t.isDeleted &&
              t.title == task.title &&
              t.creatorId == task.creatorId &&
              t.isRecurring == task.isRecurring &&
              t.recurringType == task.recurringType &&
              t.dateTime.isAtSameMomentAs(upcomingDate),
        );

        if (!hasExisting) {
          await _cloneRecurringTaskToDate(task, upcomingDate);
        }
      }
    } catch (e) {
      debugPrint('Error ensuring upcoming recurring tasks: $e');
    } finally {
      _isEnsuringRecurring = false;
    }
  }

  Future<void> _deleteRecurringCloneOnUndo(Task sourceTask) async {
    final recurringDateTime = _nextUpcomingRecurringDateTime(sourceTask) ??
        _recurringDateTimeFor(sourceTask);
    if (recurringDateTime == null) return;

    // ค้นหางานโคลนที่ตรงกับรอบถัดไปและยังไม่ได้ทำเสร็จ
    final cloneIndex = _tasks.indexWhere(
      (t) =>
          t.title == sourceTask.title &&
          t.creatorId == sourceTask.creatorId &&
          t.isRecurring == sourceTask.isRecurring &&
          t.recurringType == sourceTask.recurringType &&
          t.dateTime.isAtSameMomentAs(recurringDateTime) &&
          t.status != TaskStatus.completed,
    );

    if (cloneIndex != -1) {
      final cloneId = _tasks[cloneIndex].id;
      // ลบออกจาก local list ก่อนเพื่อป้องกัน index คลาดเคลื่อนจาก async
      _tasks.removeWhere((t) => t.id == cloneId);
      // ลบออกจาก Firestore
      await _firestore.collection('tasks').doc(cloneId).delete();
    }
  }

  Future<void> updateTask(Task updatedTask) async {
    final index = _tasks.indexWhere((t) => t.id == updatedTask.id);
    final previousTask = index != -1 ? _tasks[index] : null;

    if (index != -1) {
      _tasks[index] = updatedTask;
    } else {
      _tasks.insert(0, updatedTask);
    }
    if (_selectedTask?.id == updatedTask.id) {
      _selectedTask = updatedTask;
    }
    _calculateInitialXP();
    notifyListeners();
    await _firestore
        .collection('tasks')
        .doc(updatedTask.id)
        .set(updatedTask.toMap(), SetOptions(merge: true));

    if (updatedTask.isGroup && previousTask != null) {
      await _notifyNewGroupMembersAdded(previousTask, updatedTask);
      await _notifyGroupTaskUpdated(previousTask, updatedTask);
    }
  }

  Future<void> submitTaskForReview(String taskId, String submissionText) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = _tasks[index];
    if (task.isDeleted || task.isCompleted) return;

    final currentUserId = _currentUserId ?? _auth.currentUser?.uid;
    if (currentUserId == null || currentUserId.isEmpty) return;

    final updatedTask = task.copyWith(
      status: TaskStatus.pending,
      submissionText: submissionText.trim(),
      submittedBy: currentUserId,
      submittedAt: DateTime.now(),
      clearCompletedAt: true,
    );

    _tasks[index] = updatedTask;
    if (_selectedTask?.id == taskId) {
      _selectedTask = updatedTask;
    }
    _calculateInitialXP();
    notifyListeners();

    await _firestore
        .collection('tasks')
        .doc(taskId)
        .set(updatedTask.toMap(), SetOptions(merge: true));
    await _notifyTaskSubmitted(updatedTask, currentUserId);
  }

  Future<void> cancelTaskSubmission(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = _tasks[index];
    if (task.isDeleted || task.isCompleted) return;

    final updatedTask = task.copyWith(
      status: TaskStatus.inProgress,
      clearSubmissionText: true,
      clearSubmittedBy: true,
      clearSubmittedAt: true,
      clearCompletedAt: true,
    );

    _tasks[index] = updatedTask;
    if (_selectedTask?.id == taskId) {
      _selectedTask = updatedTask;
    }
    _calculateInitialXP();
    notifyListeners();

    // In Firestore, we want to clear the submission text and metadata, but keep the attachments list
    await _firestore.collection('tasks').doc(taskId).update({
      'status': TaskStatus.inProgress.name,
      'submissionText': FieldValue.delete(),
      'submittedBy': FieldValue.delete(),
      'submittedAt': FieldValue.delete(),
    });
  }

  Future<void> deleteTaskAttachment(
    String taskId,
    TaskAttachment attachment,
  ) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = _tasks[index];
    if (task.isDeleted || task.isCompleted) return;

    // 1. Delete file from Storage
    try {
      final ref = firebase_storage.FirebaseStorage.instance.refFromURL(
        attachment.fileUrl,
      );
      await ref.delete();
    } catch (e) {
      debugPrint('Error deleting storage file: $e');
    }

    // 2. Remove attachment from local list
    final updatedAttachments = List<TaskAttachment>.from(task.attachments)
      ..removeWhere((a) => a.fileUrl == attachment.fileUrl);

    final updatedTask = task.copyWith(attachments: updatedAttachments);

    _tasks[index] = updatedTask;
    if (_selectedTask?.id == taskId) {
      _selectedTask = updatedTask;
    }
    notifyListeners();

    // 3. Remove attachment map from Firestore
    await _firestore.collection('tasks').doc(taskId).update({
      'attachments': FieldValue.arrayRemove([attachment.toMap()]),
    });
  }

  Future<void> _deleteTaskFilesFromStorage(Task task) async {
    final urls = <String>{};
    for (final a in task.attachments) {
      if (a.fileUrl.isNotEmpty && a.fileUrl.startsWith('http')) {
        urls.add(a.fileUrl);
      }
    }
    for (final comment in task.comments) {
      for (final a in comment.attachments) {
        if (a.fileUrl.isNotEmpty && a.fileUrl.startsWith('http')) {
          urls.add(a.fileUrl);
        }
      }
    }
    for (final url in urls) {
      try {
        final ref = firebase_storage.FirebaseStorage.instance.refFromURL(url);
        await ref.delete();
      } catch (e) {
        debugPrint('Error deleting storage file: $e');
      }
    }
  }

  Future<void> approveTaskSubmission(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = _tasks[index];
    if (task.isDeleted) return;

    if (task.isGroup) {
      final currentUserId = _currentUserId ?? _auth.currentUser?.uid;
      if (currentUserId == null || currentUserId != leaderIdForTask(task)) {
        return;
      }
    }
    final wasCompleted = task.isCompleted;

    final updatedTask = task.copyWith(
      status: TaskStatus.completed,
      completedAt: DateTime.now(),
    );

    _tasks[index] = updatedTask;
    if (_selectedTask?.id == taskId) {
      _selectedTask = updatedTask;
    }
    _calculateInitialXP();
    notifyListeners();

    final submitterId = task.submittedBy;
    final leaderId = task.isGroup ? leaderIdForTask(task) : '';
    final isLeaderSubmitter = task.isGroup && submitterId == leaderId;
    if (submitterId != null && submitterId.isNotEmpty && !wasCompleted) {
      // Find the member's score
      int xpAward = task.calculateXP;
      try {
        final member = task.members.firstWhere((m) => m.id == submitterId);
        if (member.score != null && member.score!.isNotEmpty) {
          xpAward = int.parse(member.score!);
        }
      } catch (_) {
        // Fallback
      }

      if (task.submittedAt != null) {
        final diffHours = task.submittedAt!.difference(task.dateTime).inHours;
        if (diffHours >= 24) {
          final penalty = (xpAward * 0.12).round();
          xpAward -= penalty;
          if (xpAward < 0) xpAward = 0;
        }
      }
      await _updateUserProgress(
        submitterId,
        xpDelta: xpAward,
        personalTaskDelta: task.isPersonal ? 1 : 0,
        groupTaskDelta: task.isGroup && !isLeaderSubmitter ? 1 : 0,
        memberGroupTaskDelta: task.isGroup && !isLeaderSubmitter ? 1 : 0,
      );
    }

    if (task.isGroup && !wasCompleted) {
      await _handleGroupTaskCompletionRewards(task, true);
    }

    await _firestore
        .collection('tasks')
        .doc(taskId)
        .set(updatedTask.toMap(), SetOptions(merge: true));
    if (submitterId != null && submitterId.isNotEmpty && leaderId.isNotEmpty) {
      await _notifyTaskReviewDecision(
        updatedTask,
        decision: 'approved',
        submitterId: submitterId,
        leaderId: leaderId,
      );
    }

    if (!wasCompleted) {
      await _completeOlderRecurringClones(task, updatedTask.completedAt ?? DateTime.now());
      await _cloneRecurringTaskAfterCompletion(task);
    }
  }

  Future<void> rejectTaskSubmission(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = _tasks[index];
    if (task.isDeleted) return;

    if (task.isGroup) {
      final currentUserId = _currentUserId ?? _auth.currentUser?.uid;
      if (currentUserId == null || currentUserId != leaderIdForTask(task)) {
        return;
      }
    }
    final wasCompleted = task.isCompleted;

    // Delete uploaded files from Storage to free up space
    for (final attachment in task.attachments) {
      try {
        final ref = firebase_storage.FirebaseStorage.instance.refFromURL(
          attachment.fileUrl,
        );
        await ref.delete();
      } catch (e) {
        debugPrint('Error deleting storage file on reject: $e');
      }
    }

    final submitterId = task.submittedBy;
    final leaderId = task.isGroup ? leaderIdForTask(task) : '';
    final isLeaderSubmitter = task.isGroup && submitterId == leaderId;

    final updatedTask = task.copyWith(
      status: TaskStatus.inProgress,
      clearSubmissionText: true,
      clearSubmittedBy: true,
      clearSubmittedAt: true,
      attachments: [],
      clearCompletedAt: true,
      deletedForUserIds: submitterId != null && submitterId.isNotEmpty
          ? task.deletedForUserIds.where((id) => id != submitterId).toList()
          : (task.isGroup ? const [] : task.deletedForUserIds),
      hiddenForUserIds: submitterId != null && submitterId.isNotEmpty
          ? task.hiddenForUserIds.where((id) => id != submitterId).toList()
          : (task.isGroup ? const [] : task.hiddenForUserIds),
    );

    _tasks[index] = updatedTask;
    if (_selectedTask?.id == taskId) {
      _selectedTask = updatedTask;
    }
    _calculateInitialXP();
    notifyListeners();
    if (submitterId != null && submitterId.isNotEmpty && wasCompleted) {
      int xpAward = task.calculateXP;
      try {
        final member = task.members.firstWhere((m) => m.id == submitterId);
        if (member.score != null && member.score!.isNotEmpty) {
          xpAward = int.parse(member.score!);
        }
      } catch (_) {
        // Fallback
      }
      await _updateUserProgress(
        submitterId,
        xpDelta: -xpAward,
        personalTaskDelta: task.isPersonal ? -1 : 0,
        groupTaskDelta: task.isGroup && !isLeaderSubmitter ? -1 : 0,
        memberGroupTaskDelta: task.isGroup && !isLeaderSubmitter ? -1 : 0,
      );
    }

    if (task.isGroup && wasCompleted) {
      await _handleGroupTaskCompletionRewards(task, false);
    }

    final rejectUpdateData = <String, dynamic>{
      'status': TaskStatus.inProgress.name,
      'submissionText': FieldValue.delete(),
      'submittedBy': FieldValue.delete(),
      'submittedAt': FieldValue.delete(),
      'attachments': [],
    };
    if (task.isGroup) {
      if (submitterId != null && submitterId.isNotEmpty) {
        rejectUpdateData['deletedForUserIds'] =
            FieldValue.arrayRemove([submitterId]);
        rejectUpdateData['hiddenForUserIds'] =
            FieldValue.arrayRemove([submitterId]);
      } else {
        rejectUpdateData['deletedForUserIds'] = [];
        rejectUpdateData['hiddenForUserIds'] = [];
      }
    }
    await _firestore.collection('tasks').doc(taskId).update(rejectUpdateData);
    if (submitterId != null && submitterId.isNotEmpty && leaderId.isNotEmpty) {
      await _notifyTaskReviewDecision(
        task,
        decision: 'rejected',
        submitterId: submitterId,
        leaderId: leaderId,
      );
    }
  }

  Future<void> submitMemberTaskForReview(
    String taskId,
    String memberId,
    String submissionText,
  ) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = _tasks[index];
    if (task.isDeleted || task.isCompleted) return;

    final memberIndex = task.members.indexWhere((m) => m.id == memberId);
    if (memberIndex == -1) return;

    final updatedMembers = List<Member>.from(task.members);
    final member = updatedMembers[memberIndex];
    final finalAttachments = member.attachments.isNotEmpty
        ? member.attachments
        : (task.submittedBy == memberId ? task.attachments : member.attachments);

    updatedMembers[memberIndex] = member.copyWith(
      status: 'pending',
      submissionText: submissionText.trim(),
      submittedAt: DateTime.now(),
      attachments: finalAttachments,
    );

    final updatedTask = task.copyWith(
      members: updatedMembers,
      attachments: memberId == task.submittedBy ? finalAttachments : task.attachments,
    );

    _tasks[index] = updatedTask;
    if (_selectedTask?.id == taskId) {
      _selectedTask = updatedTask;
    }
    _calculateInitialXP();
    notifyListeners();

    await _firestore.collection('tasks').doc(taskId).update({
      'members': updatedMembers.map((m) => m.toMap()).toList(),
    });
    await _notifyTaskSubmitted(
      updatedTask,
      memberId,
      customSubmissionText: submissionText,
    );
  }

  Future<void> cancelMemberTaskSubmission(
    String taskId,
    String memberId,
  ) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = _tasks[index];
    if (task.isDeleted || task.isCompleted) return;

    final memberIndex = task.members.indexWhere((m) => m.id == memberId);
    if (memberIndex == -1) return;

    final updatedMembers = List<Member>.from(task.members);
    final member = updatedMembers[memberIndex];
    updatedMembers[memberIndex] = member.copyWith(
      status: 'inProgress',
      clearSubmissionText: true,
      clearSubmittedAt: true,
    );

    final updatedTask = task.copyWith(members: updatedMembers);

    _tasks[index] = updatedTask;
    if (_selectedTask?.id == taskId) {
      _selectedTask = updatedTask;
    }
    _calculateInitialXP();
    notifyListeners();

    await _firestore.collection('tasks').doc(taskId).update({
      'members': updatedMembers.map((m) => m.toMap()).toList(),
    });
  }

  Future<void> deleteMemberAttachment(
    String taskId,
    String memberId,
    TaskAttachment attachment,
  ) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = _tasks[index];
    if (task.isDeleted || task.isCompleted) return;

    final memberIndex = task.members.indexWhere((m) => m.id == memberId);
    if (memberIndex == -1) return;

    // 1. Delete file from Storage
    try {
      final ref = firebase_storage.FirebaseStorage.instance.refFromURL(
        attachment.fileUrl,
      );
      await ref.delete();
    } catch (e) {
      debugPrint('Error deleting member storage file: $e');
    }

    // 2. Remove attachment from member's attachments
    final updatedMembers = List<Member>.from(task.members);
    final member = updatedMembers[memberIndex];
    final updatedAttachments = List<TaskAttachment>.from(member.attachments)
      ..removeWhere((a) => a.fileUrl == attachment.fileUrl);

    updatedMembers[memberIndex] = member.copyWith(
      attachments: updatedAttachments,
    );

    final updatedTaskAttachments = List<TaskAttachment>.from(task.attachments)
      ..removeWhere((a) => a.fileUrl == attachment.fileUrl);

    final updatedTask = task.copyWith(
      members: updatedMembers,
      attachments: updatedTaskAttachments,
    );

    _tasks[index] = updatedTask;
    if (_selectedTask?.id == taskId) {
      _selectedTask = updatedTask;
    }
    notifyListeners();

    await _firestore.collection('tasks').doc(taskId).update({
      'members': updatedMembers.map((m) => m.toMap()).toList(),
      'attachments': updatedTaskAttachments.map((a) => a.toMap()).toList(),
    });
  }

  Future<void> approveMemberTaskSubmission(
    String taskId,
    String memberId,
  ) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = _tasks[index];
    if (task.isDeleted) return;

    final leaderId = leaderIdForTask(task);
    if (task.isGroup) {
      final currentUserId = _currentUserId ?? _auth.currentUser?.uid;
      if (currentUserId == null || currentUserId != leaderId) {
        return;
      }
    }

    final memberIndex = task.members.indexWhere((m) => m.id == memberId);
    if (memberIndex == -1) return;

    final member = task.members[memberIndex];
    final wasMemberCompleted = member.status == 'completed';

    final updatedMembers = List<Member>.from(task.members);
    updatedMembers[memberIndex] = member.copyWith(
      status: 'completed',
    );

    // Check if all members are now completed
    final allMembersCompleted = updatedMembers.isNotEmpty &&
        updatedMembers.every((m) => m.status == 'completed');

    final wasTaskCompleted = task.isCompleted;
    final updatedTask = task.copyWith(
      members: updatedMembers,
      status: allMembersCompleted ? TaskStatus.completed : task.status,
      completedAt: allMembersCompleted
          ? (task.completedAt ?? DateTime.now())
          : task.completedAt,
    );

    _tasks[index] = updatedTask;
    if (_selectedTask?.id == taskId) {
      _selectedTask = updatedTask;
    }
    _calculateInitialXP();
    notifyListeners();

    final isLeaderSubmitter = memberId == leaderId;
    if (!wasMemberCompleted) {
      int xpAward = task.calculateXP;
      if (member.score != null && member.score!.isNotEmpty) {
        final parsed = int.tryParse(member.score!);
        if (parsed != null && parsed > 0) {
          xpAward = parsed;
        }
      }

      if (member.submittedAt != null) {
        final diffHours = member.submittedAt!.difference(task.dateTime).inHours;
        if (diffHours >= 24) {
          final penalty = (xpAward * 0.12).round();
          xpAward -= penalty;
          if (xpAward < 0) xpAward = 0;
        }
      }

      await _updateUserProgress(
        memberId,
        xpDelta: xpAward,
        personalTaskDelta: 0,
        groupTaskDelta: !isLeaderSubmitter ? 1 : 0,
        memberGroupTaskDelta: !isLeaderSubmitter ? 1 : 0,
      );
    }

    if (allMembersCompleted && !wasTaskCompleted) {
      await _handleGroupTaskCompletionRewards(task, true);
    }

    final updateData = <String, dynamic>{
      'members': updatedMembers.map((m) => m.toMap()).toList(),
    };
    if (allMembersCompleted && !wasTaskCompleted) {
      updateData['status'] = TaskStatus.completed.name;
      updateData['completedAt'] = Timestamp.fromDate(updatedTask.completedAt!);
    }

    await _firestore.collection('tasks').doc(taskId).update(updateData);

    if (leaderId.isNotEmpty && memberId != leaderId) {
      await _notifyTaskReviewDecision(
        updatedTask,
        decision: 'approved',
        submitterId: memberId,
        leaderId: leaderId,
      );
    }

    if (allMembersCompleted && !wasTaskCompleted) {
      await _completeOlderRecurringClones(task, updatedTask.completedAt ?? DateTime.now());
      await _cloneRecurringTaskAfterCompletion(task);
    }
  }

  Future<void> rejectMemberTaskSubmission(
    String taskId,
    String memberId,
  ) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = _tasks[index];
    if (task.isDeleted) return;

    final leaderId = leaderIdForTask(task);
    if (task.isGroup) {
      final currentUserId = _currentUserId ?? _auth.currentUser?.uid;
      if (currentUserId == null || currentUserId != leaderId) {
        return;
      }
    }

    final memberIndex = task.members.indexWhere((m) => m.id == memberId);
    if (memberIndex == -1) return;

    final member = task.members[memberIndex];
    final wasMemberCompleted = member.status == 'completed';

    final updatedMembers = List<Member>.from(task.members);
    // Keep existing attachments so member can resubmit them or attach more
    final preservedAttachments = member.attachments.isNotEmpty
        ? member.attachments
        : (task.submittedBy == memberId ? task.attachments : member.attachments);

    updatedMembers[memberIndex] = member.copyWith(
      status: 'inProgress',
      clearSubmittedAt: true,
      attachments: preservedAttachments,
    );

    final wasTaskCompleted = task.isCompleted;
    final clearTaskSubmission = task.submittedBy == memberId;
    final updatedTask = task.copyWith(
      members: updatedMembers,
      status: wasTaskCompleted ? TaskStatus.inProgress : task.status,
      clearCompletedAt: wasTaskCompleted,
      clearSubmissionText: clearTaskSubmission,
      clearSubmittedBy: clearTaskSubmission,
      clearSubmittedAt: clearTaskSubmission,
      attachments: clearTaskSubmission ? [] : task.attachments,
      deletedForUserIds: wasTaskCompleted
          ? const []
          : task.deletedForUserIds.where((id) => id != memberId).toList(),
      hiddenForUserIds: wasTaskCompleted
          ? const []
          : task.hiddenForUserIds.where((id) => id != memberId).toList(),
    );

    _tasks[index] = updatedTask;
    if (_selectedTask?.id == taskId) {
      _selectedTask = updatedTask;
    }
    _calculateInitialXP();
    notifyListeners();

    final isLeaderSubmitter = memberId == leaderId;
    if (wasMemberCompleted) {
      int xpAward = task.calculateXP;
      if (member.score != null && member.score!.isNotEmpty) {
        final parsed = int.tryParse(member.score!);
        if (parsed != null && parsed > 0) {
          xpAward = parsed;
        }
      }
      await _updateUserProgress(
        memberId,
        xpDelta: -xpAward,
        personalTaskDelta: 0,
        groupTaskDelta: !isLeaderSubmitter ? -1 : 0,
        memberGroupTaskDelta: !isLeaderSubmitter ? -1 : 0,
      );
    }

    if (wasTaskCompleted) {
      await _handleGroupTaskCompletionRewards(task, false);
    }

    final updateData = <String, dynamic>{
      'members': updatedMembers.map((m) => m.toMap()).toList(),
      if (clearTaskSubmission) ...{
        'submissionText': FieldValue.delete(),
        'submittedBy': FieldValue.delete(),
        'submittedAt': FieldValue.delete(),
        'attachments': [],
      },
      if (wasTaskCompleted) ...{
        'deletedForUserIds': [],
        'hiddenForUserIds': [],
      } else ...{
        'deletedForUserIds': FieldValue.arrayRemove([memberId]),
        'hiddenForUserIds': FieldValue.arrayRemove([memberId]),
      },
    };
    if (wasTaskCompleted) {
      updateData['status'] = TaskStatus.inProgress.name;
      updateData['completedAt'] = FieldValue.delete();
    }

    await _firestore.collection('tasks').doc(taskId).update(updateData);

    if (leaderId.isNotEmpty && memberId != leaderId) {
      await _notifyTaskReviewDecision(
        updatedTask,
        decision: 'rejected',
        submitterId: memberId,
        leaderId: leaderId,
      );
    }
  }

  Future<void> deleteTask(String taskId) async {
    await deleteTasks([taskId]);
  }

  void deleteGroupProjectTask(String id) {
    deleteTask(id);
  }

  Future<void> restoreTask(String taskId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      final task = _tasks[index];
      final currentUserId = _currentUserId ?? _auth.currentUser?.uid;
      final isLocallyDeletedGroupTask =
          task.isGroup &&
          currentUserId != null &&
          task.deletedForUserIds.contains(currentUserId);
      if (task.isGroup && task.isDeleted && !_isCurrentUserLeaderOfTask(task)) {
        return;
      }

      if (isLocallyDeletedGroupTask) {
        final deletedForUserIds = task.deletedForUserIds
            .where((id) => id != currentUserId)
            .toList();
        final updatedTask = task.copyWith(deletedForUserIds: deletedForUserIds);
        _tasks[index] = updatedTask;
        if (_selectedTask?.id == taskId) {
          _selectedTask = updatedTask;
        }
        _calculateInitialXP();
        notifyListeners();

        await _firestore.collection('tasks').doc(taskId).set({
          'deletedForUserIds': FieldValue.arrayRemove([currentUserId]),
          'hiddenForUserIds': FieldValue.arrayRemove([currentUserId]),
        }, SetOptions(merge: true));
        return;
      }

      final updatedTask = task.copyWith(
        isDeleted: false,
        clearDeletedAt: true,
      );
      _tasks[index] = updatedTask;
      _calculateInitialXP();
      notifyListeners();
    }

    await _firestore.collection('tasks').doc(taskId).set({
      'isDeleted': false,
      'deletedAt': FieldValue.delete(),
      'expireAt': FieldValue.delete(),
    }, SetOptions(merge: true));
  }

  Future<void> restoreTasks(List<String> taskIds) async {
    if (taskIds.isEmpty) return;

    final currentUserId = _currentUserId ?? _auth.currentUser?.uid;
    final restoredTasks = <Task>[];
    final locallyRestoredGroupTaskIds = <String>{};

    for (final id in taskIds) {
      final index = _tasks.indexWhere((t) => t.id == id);
      if (index != -1) {
        final task = _tasks[index];
        if (task.isGroup &&
            task.isDeleted &&
            !_isCurrentUserLeaderOfTask(task)) {
          continue;
        }
        final isLocallyDeletedGroupTask =
            task.isGroup &&
            currentUserId != null &&
            task.deletedForUserIds.contains(currentUserId);

        if (isLocallyDeletedGroupTask) {
          final updatedTask = task.copyWith(
            deletedForUserIds: task.deletedForUserIds
                .where((userId) => userId != currentUserId)
                .toList(),
          );
          _tasks[index] = updatedTask;
          restoredTasks.add(updatedTask);
          locallyRestoredGroupTaskIds.add(id);

          if (_selectedTask?.id == id) {
            _selectedTask = updatedTask;
          }
          continue;
        }

        final updatedTask = task.copyWith(
          isDeleted: false,
          clearDeletedAt: true,
          clearExpireAt: true,
        );
        _tasks[index] = updatedTask;
        restoredTasks.add(updatedTask);

        if (_selectedTask?.id == id) {
          _selectedTask = updatedTask;
        }
      }
    }

    _calculateInitialXP();
    notifyListeners();

    final batch = _firestore.batch();
    for (final task in restoredTasks) {
      if (locallyRestoredGroupTaskIds.contains(task.id) &&
          currentUserId != null) {
        batch.set(_firestore.collection('tasks').doc(task.id), {
          'deletedForUserIds': FieldValue.arrayRemove([currentUserId]),
          'hiddenForUserIds': FieldValue.arrayRemove([currentUserId]),
        }, SetOptions(merge: true));
      } else {
        batch.set(_firestore.collection('tasks').doc(task.id), {
          'isDeleted': false,
          'deletedAt': FieldValue.delete(),
          'expireAt': FieldValue.delete(),
        }, SetOptions(merge: true));
      }
    }

    await batch.commit();
  }

  Future<void> restoreCompletedTasks(List<String> taskIds) async {
    if (taskIds.isEmpty) return;

    final currentUserId = _currentUserId ?? _auth.currentUser?.uid;
    final restoredTasks = <Task>[];
    var xpToRemove = 0;
    var personalTaskCountToRemove = 0;

    for (final id in taskIds) {
      final index = _tasks.indexWhere((t) => t.id == id);
      if (index != -1) {
        final task = _tasks[index];
        if (!task.isCompleted) continue;
        if (!canCurrentUserRestoreCompletedTask(task)) continue;

        if (task.isGroup) {
          await _handleGroupTaskCompletionRewards(task, false);
        }

        final updatedTask = _tasks[index].copyWith(
          status: TaskStatus.pending,
          clearCompletedAt: true,
          awardedXP: 0,
          rewardBlocked: false,
          clearRewardBlockedReason: true,
          clearRewardBlockedAt: true,
          clearRewardBlockedBy: true,
          clearCompletionAgeSeconds: true,
          deletedForUserIds: task.isGroup ? const [] : task.deletedForUserIds,
          hiddenForUserIds: task.isGroup ? const [] : task.hiddenForUserIds,
        );
        _tasks[index] = updatedTask;
        restoredTasks.add(updatedTask);
        if (_selectedTask?.id == id) {
          _selectedTask = updatedTask;
        }

        final shouldUpdatePersonalStats =
            currentUserId != null &&
            task.isPersonal &&
            (task.creatorId == currentUserId ||
                task.assigneeIds.contains(currentUserId));
        if (shouldUpdatePersonalStats) {
          xpToRemove += calculateRestoredPersonalTaskXpRemoval(
            awardedXP: task.awardedXP,
            baseXP: task.calculateXP,
          );
          personalTaskCountToRemove += 1;
        }
      }
    }

    if (restoredTasks.isEmpty) return;

    _calculateInitialXP();
    notifyListeners();

    final batch = _firestore.batch();
    for (final task in restoredTasks) {
      final restoreData = <String, dynamic>{
        'status': TaskStatus.pending.name,
        'completedAt': null,
        'awardedXP': 0,
        'rewardBlocked': false,
        'rewardBlockedReason': null,
        'rewardBlockedAt': null,
        'rewardBlockedBy': null,
        'completionAgeSeconds': null,
      };
      if (task.isGroup) {
        restoreData['deletedForUserIds'] = [];
        restoreData['hiddenForUserIds'] = [];
      }
      batch.set(_firestore.collection('tasks').doc(task.id), restoreData, SetOptions(merge: true));
    }

    if (currentUserId != null &&
        (xpToRemove > 0 || personalTaskCountToRemove > 0)) {
      final userRef = _firestore.collection('users').doc(currentUserId);
      final userSnap = await userRef.get();
      final data = userSnap.data();
      final currentXP = _readInt(data?['totalXP']);
      final currentTasksCompleted = _readInt(data?['tasksCompleted']);
      final newXP = calculateFinalXpWithLevelBonus(currentXP, -xpToRemove);
      final oldLevel = calculateLevelProgress(currentXP).currentLevel;
      final newLevel = calculateLevelProgress(newXP).currentLevel;
      final newTasksCompleted =
          (currentTasksCompleted - personalTaskCountToRemove)
              .clamp(0, 1 << 31)
              .toInt();

      batch.set(userRef, {
        'totalXP': newXP,
        'tasksCompleted': newTasksCompleted,
        'currentLevel': newLevel,
        ..._milestoneRewardFields(
          data: data,
          oldLevel: oldLevel,
          newLevel: newLevel,
        ),
      }, SetOptions(merge: true));
    }

    await batch.commit();
  }

  Future<void> permanentlyDeleteTask(String taskId) async {
    Task? task;
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index != -1) {
      task = _tasks[index];
    } else {
      try {
        final snap = await _firestore.collection('tasks').doc(taskId).get();
        if (snap.exists && snap.data() != null) {
          task = Task.fromMap(snap.data()!, taskId);
        }
      } catch (e) {
        debugPrint('Error fetching task for file deletion: $e');
      }
    }

    final currentUserId = _currentUserId ?? _auth.currentUser?.uid;
    if (task?.isGroup == true && currentUserId != null) {
      _tasks.removeWhere((t) => t.id == taskId);
      _calculateInitialXP();
      notifyListeners();

      await _firestore.collection('tasks').doc(taskId).set({
        'deletedForUserIds': FieldValue.arrayRemove([currentUserId]),
        'hiddenForUserIds': FieldValue.arrayUnion([currentUserId]),
      }, SetOptions(merge: true));
      return;
    }

    if (task != null) {
      await _deleteTaskFilesFromStorage(task);
    }

    _tasks.removeWhere((t) => t.id == taskId);
    _calculateInitialXP();
    notifyListeners();
    await _firestore.collection('tasks').doc(taskId).delete();
  }

  Future<void> permanentlyDeleteTasks(List<String> taskIds) async {
    for (final id in taskIds) {
      await permanentlyDeleteTask(id);
    }
  }

  Future<void> emptyBin() async {
    final deletedTasks = _tasks.where(_isTaskInCurrentUserBin).toList();
    final currentUserId = _currentUserId ?? _auth.currentUser?.uid;
    final groupTasksToHide = currentUserId == null
        ? <Task>[]
        : deletedTasks.where((task) => task.isGroup).toList();
    final tasksToDeleteGlobally = deletedTasks
        .where((task) => !groupTasksToHide.any((group) => group.id == task.id))
        .toList();

    for (final task in tasksToDeleteGlobally) {
      await _deleteTaskFilesFromStorage(task);
    }

    _tasks.removeWhere((task) => deletedTasks.any((t) => t.id == task.id));
    _calculateInitialXP();
    notifyListeners();

    final batch = _firestore.batch();
    for (final task in groupTasksToHide) {
      batch.set(_firestore.collection('tasks').doc(task.id), {
        'deletedForUserIds': FieldValue.arrayRemove([currentUserId]),
        'hiddenForUserIds': FieldValue.arrayUnion([currentUserId]),
      }, SetOptions(merge: true));
    }
    for (final task in tasksToDeleteGlobally) {
      batch.delete(_firestore.collection('tasks').doc(task.id));
    }
    await batch.commit();
  }

  Future<void> deleteTasks(List<String> taskIds) async {
    final currentUserId = _currentUserId ?? _auth.currentUser?.uid;
    final localGroupTaskIds = <String>{};
    final globalTaskIds = <String>{};
    final globalGroupTaskIds = <String>{};

    // สร้างเซ็ตเริ่มต้นจากรหัสงานที่ถูกส่งมาลบ
    final expandedTaskIds = <String>{...taskIds};

    // ทำการตรวจสอบงานแต่ละตัวในรายการที่จะลบ
    for (final id in taskIds) {
      final index = _tasks.indexWhere((t) => t.id == id);
      if (index != -1) {
        final task = _tasks[index];
        // หากงานที่จะลบเป็นงานแบบ "ทำซ้ำ (Recurring)"
        if (task.isRecurring) {
          // จะทำการค้นหางานอื่นๆ ทั้งหมดที่อยู่ใน "ซีรีส์เดียวกัน" และ "ยังไม่เสร็จ (Pending)"
          // โดยอิงจากชื่อ, ผู้สร้าง, และประเภทการทำซ้ำ
          final recurringClones = _tasks.where(
            (t) =>
                t.title == task.title &&
                t.creatorId == task.creatorId &&
                t.isRecurring == task.isRecurring &&
                t.recurringType == task.recurringType &&
                !t.isCompleted,
          );

          // นำรหัสงานที่หาเจอทั้งหมด เพิ่มเข้าไปในคิวที่จะทำการลบพร้อมกัน
          // เพื่อให้งานล่วงหน้าในหน้า "ภารกิจเร็วๆ นี้" ถูกลบออกไปทั้งหมด
          for (final clone in recurringClones) {
            expandedTaskIds.add(clone.id);
          }
        }
      }
    }

    final now = DateTime.now();
    final expireAt = now.add(const Duration(days: 30));
    for (final id in expandedTaskIds) {
      final index = _tasks.indexWhere((t) => t.id == id);
      if (index != -1) {
        final task = _tasks[index];
        if (task.isGroup &&
            currentUserId != null &&
            (!_isCurrentUserLeaderOfTask(task) || task.isCompleted)) {
          localGroupTaskIds.add(id);
          _tasks[index] = task.copyWith(
            deletedAt: now,
            deletedForUserIds: {
              ...task.deletedForUserIds,
              currentUserId,
            }.toList(),
          );
        } else {
          globalTaskIds.add(id);
          if (task.isGroup) {
            globalGroupTaskIds.add(id);
          }
          _tasks[index] = task.copyWith(
            isDeleted: true,
            deletedAt: now,
            expireAt: expireAt,
          );
        }
      }
    }
    _calculateInitialXP();
    notifyListeners();

    final batch = _firestore.batch();
    for (final id in localGroupTaskIds) {
      batch.set(_firestore.collection('tasks').doc(id), {
        'deletedAt': Timestamp.fromDate(now),
        'deletedForUserIds': FieldValue.arrayUnion([currentUserId]),
        'hiddenForUserIds': FieldValue.arrayRemove([currentUserId]),
      }, SetOptions(merge: true));
    }
    for (final id in globalTaskIds) {
      batch.set(_firestore.collection('tasks').doc(id), {
        'isDeleted': true,
        'deletedAt': Timestamp.fromDate(now),
        'expireAt': Timestamp.fromDate(expireAt),
        if (globalGroupTaskIds.contains(id)) 'deletedForUserIds': [],
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<CompletionRewardResult> toggleTaskCompletion(
    String taskId, {
    bool? forceStatus,
    bool updateSubtasks = false,
  }) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return CompletionRewardResult.noChange;

    final task = _tasks[index];
    if (task.isGroup) {
      final currentUserId = _currentUserId ?? _auth.currentUser?.uid;
      if (currentUserId == null || currentUserId != leaderIdForTask(task)) {
        return CompletionRewardResult.noChange;
      }
    }
    final wasCompleted = task.isCompleted;
    final newStatus = forceStatus != null
        ? (forceStatus ? TaskStatus.completed : TaskStatus.pending)
        : (task.isCompleted ? TaskStatus.pending : TaskStatus.completed);

    final isNowCompleted = newStatus == TaskStatus.completed;
    if (wasCompleted == isNowCompleted) {
      return CompletionRewardResult.noChange;
    }

    final updatedSubtasks = updateSubtasks
        ? task.subtasks
              .map(
                (s) => SubTask(
                  title: s.title,
                  isDone: newStatus == TaskStatus.completed,
                ),
              )
              .toList()
        : task.subtasks;

    _tasks[index] = task.copyWith(
      status: newStatus,
      subtasks: updatedSubtasks,
    );

    final completedAt = DateTime.now();
    final currentUserId = _currentUserId ?? _auth.currentUser?.uid;
    final previousLevel = isNowCompleted && currentUserId != null
        ? await _userLevelFor(currentUserId)
        : null;

    var updatedTask = task.copyWith(
      status: newStatus,
      completedAt: newStatus == TaskStatus.completed ? completedAt : null,
      clearCompletedAt: newStatus != TaskStatus.completed,
      subtasks: updatedSubtasks,
      awardedXP: newStatus == TaskStatus.completed ? task.awardedXP : 0,
      rewardBlocked: newStatus == TaskStatus.completed
          ? task.rewardBlocked
          : false,
      clearRewardBlockedReason: newStatus != TaskStatus.completed,
      clearRewardBlockedAt: newStatus != TaskStatus.completed,
      clearRewardBlockedBy: newStatus != TaskStatus.completed,
      clearCompletionAgeSeconds: newStatus != TaskStatus.completed,
    );
    var result = CompletionRewardResult.awarded;
    final isBlockedByAge =
        isNowCompleted &&
        isCompletionRewardBlockedByAge(
          createdAt: task.createdAt,
          completedAt: completedAt,
        );
    final isBlockedByBurst =
        isNowCompleted &&
        isCompletionRewardBlockedByBurst(
          recentCompletionTimestamps: _recentCompletionTimestamps,
          completedAt: completedAt,
        );
    final blocksReward = isBlockedByAge || isBlockedByBurst;

    if (isNowCompleted) {
      _recentCompletionTimestamps.removeWhere(
        (t) => completedAt.difference(t) > burstCooldownWindow,
      );
      _recentCompletionTimestamps.add(completedAt);
    }

    if (task.isPersonal) {
      final userId = currentUserId;
      if (userId != null) {
        if (!wasCompleted && isNowCompleted && blocksReward) {
          updatedTask = _applyFastCompletionRewardBlock(
            updatedTask,
            completedAt: completedAt,
            userId: userId,
          );
          result = CompletionRewardResult.blockedFastCompletion;
          await _firestore
              .collection('tasks')
              .doc(taskId)
              .set(updatedTask.toMap(), SetOptions(merge: true));
        } else if (!wasCompleted && isNowCompleted) {
          updatedTask = _clearRewardBlock(updatedTask);
          updatedTask = await _completePersonalTaskWithReward(
            userId,
            updatedTask,
          );
        } else if (wasCompleted && !isNowCompleted) {
          updatedTask = await _undoPersonalTaskReward(
            userId,
            updatedTask,
            task.awardedXP,
          );
        } else {
          await _firestore
              .collection('tasks')
              .doc(taskId)
              .set(updatedTask.toMap(), SetOptions(merge: true));
        }
      } else {
        await _firestore
            .collection('tasks')
            .doc(taskId)
            .set(updatedTask.toMap(), SetOptions(merge: true));
      }
    } else if (task.isGroup) {
      if (!wasCompleted && isNowCompleted && blocksReward) {
        updatedTask = _applyFastCompletionRewardBlock(
          updatedTask,
          completedAt: completedAt,
          userId: currentUserId,
        );
        result = CompletionRewardResult.blockedFastCompletion;
      } else if (!wasCompleted && isNowCompleted) {
        updatedTask = _clearRewardBlock(updatedTask);
        await _handleGroupTaskCompletionRewards(task, true);
      } else if (wasCompleted && !isNowCompleted) {
        await _handleGroupTaskCompletionRewards(task, false);
        updatedTask = updatedTask.copyWith(
          deletedForUserIds: const [],
          hiddenForUserIds: const [],
        );
      }

      await _firestore
          .collection('tasks')
          .doc(taskId)
          .set(updatedTask.toMap(), SetOptions(merge: true));
    }

    _tasks[index] = updatedTask;
    if (_selectedTask?.id == taskId) {
      _selectedTask = updatedTask;
    }
    _calculateInitialXP();
    notifyListeners();

    if (!wasCompleted && isNowCompleted) {
      await _completeOlderRecurringClones(task, completedAt);
      await _cloneRecurringTaskAfterCompletion(task);
    }
    // หากยกเลิกการทำงานเสร็จสิ้น (Undo) ให้ลบงานโคลนที่สร้างขึ้นสำหรับรอบถัดไปทิ้ง
    if (wasCompleted && !isNowCompleted) {
      await _deleteRecurringCloneOnUndo(task);
    }
    if (!wasCompleted &&
        isNowCompleted &&
        result.status == CompletionRewardStatus.awarded &&
        currentUserId != null &&
        previousLevel != null) {
      final nextLevel = await _userLevelFor(currentUserId);
      if (nextLevel != null && nextLevel > previousLevel) {
        result = result.copyWith(leveledUpTo: nextLevel);
      }
    }
    return result;
  }

  Future<CompletionRewardResult> completeTaskWithSubtasks(
    String taskId,
    bool isCompleted,
  ) {
    return toggleTaskCompletion(
      taskId,
      forceStatus: isCompleted,
      updateSubtasks: true,
    );
  }

  Future<CompletionRewardResult?> toggleSubtask(String taskId, int subtaskIndex) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return null;

    final task = _tasks[index];
    if (subtaskIndex < 0 || subtaskIndex >= task.subtasks.length) return null;

    final wasCompleted = task.isCompleted;

    final updatedSubtasks = List<SubTask>.from(task.subtasks);
    final subtask = updatedSubtasks[subtaskIndex];
    updatedSubtasks[subtaskIndex] = subtask.copyWith(isDone: !subtask.isDone);

    final updatedTask = task.copyWith(subtasks: updatedSubtasks);
    _tasks[index] = updatedTask;
    if (_selectedTask?.id == taskId) {
      _selectedTask = updatedTask;
    }
    notifyListeners();

    final allSubtasksDone =
        updatedSubtasks.isNotEmpty && updatedSubtasks.every((s) => s.isDone);

    if (task.type == TaskType.group || task.members.isNotEmpty) {
      await _firestore
          .collection('tasks')
          .doc(taskId)
          .set(updatedTask.toMap(), SetOptions(merge: true));
      return CompletionRewardResult.noChange;
    }

    if (allSubtasksDone && !wasCompleted) {
      return await toggleTaskCompletion(taskId, forceStatus: true);
    } else if (!allSubtasksDone && wasCompleted) {
      return await toggleTaskCompletion(taskId, forceStatus: false);
    } else {
      await _firestore
          .collection('tasks')
          .doc(taskId)
          .set(updatedTask.toMap(), SetOptions(merge: true));
      return CompletionRewardResult.noChange;
    }
  }

  Future<void> toggleMemberSubtask(
    String taskId,
    String memberId,
    String subtaskTitle,
  ) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = _tasks[index];
    final memberIndex = task.members.indexWhere((m) => m.id == memberId);
    if (memberIndex == -1) return;

    final targetMember = task.members[memberIndex];
    final updatedCompleted = List<String>.from(targetMember.completedSubTasks);
    final trimmedTitle = subtaskTitle.trim();

    final existingIndex =
        updatedCompleted.indexWhere((s) => s.trim() == trimmedTitle);
    if (existingIndex != -1) {
      updatedCompleted.removeAt(existingIndex);
    } else {
      updatedCompleted.add(subtaskTitle);
    }

    final updatedMembers = List<Member>.from(task.members);

    for (int i = 0; i < updatedMembers.length; i++) {
      final m = updatedMembers[i];
      if (m.id == memberId ||
          (targetMember.taskTitle != null &&
              targetMember.taskTitle!.isNotEmpty &&
              m.taskTitle == targetMember.taskTitle)) {
        updatedMembers[i] = m.copyWith(completedSubTasks: updatedCompleted);
      }
    }

    List<SubTask> updatedSubtasks = List<SubTask>.from(task.subtasks);
    bool subtasksChanged = false;
    final isNowDone = updatedCompleted.any((s) => s.trim() == trimmedTitle);
    for (int i = 0; i < updatedSubtasks.length; i++) {
      if (updatedSubtasks[i].title.trim() == trimmedTitle) {
        updatedSubtasks[i] = updatedSubtasks[i].copyWith(isDone: isNowDone);
        subtasksChanged = true;
      }
    }

    final updatedTask = task.copyWith(
      members: updatedMembers,
      subtasks: subtasksChanged ? updatedSubtasks : task.subtasks,
    );

    _tasks[index] = updatedTask;
    if (_selectedTask?.id == taskId) {
      _selectedTask = updatedTask;
    }
    notifyListeners();

    await _firestore
        .collection('tasks')
        .doc(taskId)
        .set(updatedTask.toMap(), SetOptions(merge: true));
  }

  Future<void> addComment(String taskId, Comment comment) async {
    return addMultipleComments(taskId, [comment]);
  }

  Future<void> addMultipleComments(
    String taskId,
    List<Comment> newComments,
  ) async {
    if (newComments.isEmpty) return;
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = _tasks[index];
    if (task.isDeleted || (task.isGroup && task.isCompleted)) return;

    final updatedTask = task.copyWith(
      comments: List<Comment>.from(task.comments)..addAll(newComments),
    );
    _tasks[index] = updatedTask;
    if (_selectedTask?.id == taskId) {
      _selectedTask = updatedTask;
    }
    notifyListeners();

    await _firestore
        .collection('tasks')
        .doc(taskId)
        .set(updatedTask.toMap(), SetOptions(merge: true));

    // แจ้งเตือนข้อความหลักเพียงครั้งเดียวเพื่อไม่ให้แจ้งเตือนเด้งซ้ำซ้อน
    final primaryComment = newComments.firstWhere(
      (c) => c.content.trim().isNotEmpty,
      orElse: () => newComments.first,
    );
    await _notifyTaskComment(updatedTask, primaryComment);
  }

  Future<void> deleteComment(String taskId, String commentId) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = _tasks[index];
    final commentIndex = task.comments.indexWhere((c) => c.id == commentId);
    if (commentIndex == -1) return;

    final commentToDelete = task.comments[commentIndex];
    final updatedComments = List<Comment>.from(task.comments)
      ..removeAt(commentIndex);

    final updatedTask = task.copyWith(comments: updatedComments);
    _tasks[index] = updatedTask;
    if (_selectedTask?.id == taskId) {
      _selectedTask = updatedTask;
    }
    notifyListeners();

    await _firestore
        .collection('tasks')
        .doc(taskId)
        .set(updatedTask.toMap(), SetOptions(merge: true));

    // ลบไฟล์แนบออกจาก Firebase Storage เบื้องหลัง
    for (final attachment in commentToDelete.attachments) {
      try {
        if (attachment.fileUrl.isNotEmpty) {
          final ref = firebase_storage.FirebaseStorage.instance.refFromURL(
            attachment.fileUrl,
          );
          await ref.delete();
        }
      } catch (e) {
        debugPrint('Error deleting comment attachment from storage: $e');
      }
    }
  }

  Future<void> addProject(Project project) async {
    _projects.add(project);
    notifyListeners();
    await _firestore
        .collection('projects')
        .doc(project.id)
        .set(project.toMap());
  }

  Future<void> updateProject(Project updatedProject) async {
    final index = _projects.indexWhere((p) => p.id == updatedProject.id);
    if (index != -1) {
      _projects[index] = updatedProject;
      notifyListeners();
    }
    await _firestore
        .collection('projects')
        .doc(updatedProject.id)
        .set(updatedProject.toMap(), SetOptions(merge: true));
  }

  Future<void> deleteProject(String projectId) async {
    final tasksForProject = _tasks
        .where((t) => t.projectId == projectId)
        .toList();
    for (final task in tasksForProject) {
      await _deleteTaskFilesFromStorage(task);
    }

    _projects.removeWhere((p) => p.id == projectId);
    _tasks.removeWhere((t) => t.projectId == projectId);
    _calculateInitialXP();
    notifyListeners();

    final batch = _firestore.batch();
    batch.delete(_firestore.collection('projects').doc(projectId));
    for (final task in tasksForProject) {
      batch.delete(_firestore.collection('tasks').doc(task.id));
    }
    await batch.commit();
  }

  Future<Map<String, dynamic>?> uploadTaskAttachment(String taskId) async {
    final task = _tasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null || task.isDeleted || task.isCompleted) return null;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'png',
          'jpg',
          'jpeg',
          'pdf',
          'docx',
          'xlsx',
          'doc',
          'xls',
          'ppt',
          'pptx',
        ],
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final pickedFile = result.files.first;
      if (pickedFile.size > 10485760) {
        throw Exception('FILE_TOO_LARGE');
      }
      final fileName = pickedFile.name;
      final fileType =
          pickedFile.extension ?? fileName.split('.').last.toLowerCase();

      final storageRef = firebase_storage.FirebaseStorage.instance
          .ref()
          .child('tasks')
          .child(taskId)
          .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');

      firebase_storage.UploadTask uploadTask;
      if (pickedFile.bytes != null) {
        uploadTask = storageRef.putData(pickedFile.bytes!);
      } else if (pickedFile.path != null) {
        uploadTask = storageRef.putFile(File(pickedFile.path!));
      } else {
        return null;
      }

      final snapshot = await uploadTask;
      final fileUrl = await snapshot.ref.getDownloadURL();

      final attachment = {
        'fileName': fileName,
        'fileUrl': fileUrl,
        'fileType': fileType,
        'uploadedAt': Timestamp.now(),
      };

      await _firestore.collection('tasks').doc(taskId).update({
        'attachments': FieldValue.arrayUnion([attachment]),
      });

      return attachment;
    } catch (e) {
      debugPrint('Error uploading task attachment: $e');
      if (e.toString().contains('FILE_TOO_LARGE')) {
        rethrow;
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> uploadMemberAttachment(
    String taskId,
    String memberId,
  ) async {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return null;

    final task = _tasks[index];
    if (task.isDeleted || task.isCompleted) return null;

    final memberIndex = task.members.indexWhere((m) => m.id == memberId);
    if (memberIndex == -1) return null;

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'png',
          'jpg',
          'jpeg',
          'pdf',
          'docx',
          'xlsx',
          'doc',
          'xls',
          'ppt',
          'pptx',
        ],
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final pickedFile = result.files.first;
      if (pickedFile.size > 10485760) {
        throw Exception('FILE_TOO_LARGE');
      }
      final fileName = pickedFile.name;
      final fileType =
          pickedFile.extension ?? fileName.split('.').last.toLowerCase();

      final storageRef = firebase_storage.FirebaseStorage.instance
          .ref()
          .child('tasks')
          .child(taskId)
          .child('members')
          .child(memberId)
          .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');

      firebase_storage.UploadTask uploadTask;
      if (pickedFile.bytes != null) {
        uploadTask = storageRef.putData(pickedFile.bytes!);
      } else if (pickedFile.path != null) {
        uploadTask = storageRef.putFile(File(pickedFile.path!));
      } else {
        return null;
      }

      final snapshot = await uploadTask;
      final fileUrl = await snapshot.ref.getDownloadURL();

      final attachmentMap = {
        'fileName': fileName,
        'fileUrl': fileUrl,
        'fileType': fileType,
        'uploadedAt': Timestamp.now(),
      };
      final newAttachment = TaskAttachment.fromMap(attachmentMap);

      final updatedMembers = List<Member>.from(task.members);
      final member = updatedMembers[memberIndex];
      final baseAttachments = member.attachments.isNotEmpty
          ? List<TaskAttachment>.from(member.attachments)
          : (task.submittedBy == memberId
              ? List<TaskAttachment>.from(task.attachments)
              : <TaskAttachment>[]);
      final updatedAttachments = baseAttachments..add(newAttachment);

      updatedMembers[memberIndex] = member.copyWith(
        attachments: updatedAttachments,
      );

      final updatedTask = task.copyWith(members: updatedMembers);

      _tasks[index] = updatedTask;
      if (_selectedTask?.id == taskId) {
        _selectedTask = updatedTask;
      }
      notifyListeners();

      await _firestore.collection('tasks').doc(taskId).update({
        'members': updatedMembers.map((m) => m.toMap()).toList(),
      });

      return attachmentMap;
    } catch (e) {
      debugPrint('Error uploading member attachment: $e');
      if (e.toString().contains('FILE_TOO_LARGE')) {
        rethrow;
      }
      return null;
    }
  }

  Future<Map<String, dynamic>?> uploadCommentAttachment(String taskId) async {
    final task = _tasks.where((t) => t.id == taskId).firstOrNull;
    if (task == null || task.isDeleted || (task.isGroup && task.isCompleted)) {
      return null;
    }

    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'png',
          'jpg',
          'jpeg',
          'pdf',
          'docx',
          'xlsx',
          'doc',
          'xls',
          'ppt',
          'pptx',
        ],
      );

      if (result == null || result.files.isEmpty) {
        return null;
      }

      final pickedFile = result.files.first;
      if (pickedFile.size > 10485760) {
        throw Exception('FILE_TOO_LARGE');
      }
      final fileName = pickedFile.name;
      final fileType =
          pickedFile.extension ?? fileName.split('.').last.toLowerCase();

      final storageRef = firebase_storage.FirebaseStorage.instance
          .ref()
          .child('tasks')
          .child(taskId)
          .child('comments')
          .child('${DateTime.now().millisecondsSinceEpoch}_$fileName');

      firebase_storage.UploadTask uploadTask;
      if (pickedFile.bytes != null) {
        uploadTask = storageRef.putData(pickedFile.bytes!);
      } else if (pickedFile.path != null) {
        uploadTask = storageRef.putFile(File(pickedFile.path!));
      } else {
        return null;
      }

      final snapshot = await uploadTask;
      final fileUrl = await snapshot.ref.getDownloadURL();

      final attachment = {
        'fileName': fileName,
        'fileUrl': fileUrl,
        'fileType': fileType,
        'uploadedAt': Timestamp.now(),
      };

      return attachment;
    } catch (e) {
      debugPrint('Error uploading comment attachment: $e');
      if (e.toString().contains('FILE_TOO_LARGE')) {
        rethrow;
      }
      return null;
    }
  }
}

int _readInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

List<String> _readStringList(dynamic value) {
  if (value is! Iterable) return const [];
  return value.map((item) => item.toString()).toList();
}
