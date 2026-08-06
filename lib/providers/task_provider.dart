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
  final List<Project> _allProjects = [];
  final List<Project> _projects = [];
  final List<User> _friends = [];
  final Map<String, User> _userCache = {};
  final Set<String> _pendingUserFetches = {};
  final List<StreamSubscription> _subscriptions = [];
  StreamSubscription<firebase_auth.User?>? _authSubscription;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _taskSubscription;
  String? _currentUserId;

  bool _showXPCapAlert = false;
  bool get showXPCapAlert => _showXPCapAlert;

  void dismissXPCapAlert() {
    _showXPCapAlert = false;
    notifyListeners();
  }

  void _triggerXPCapAlert() {
    _showXPCapAlert = true;
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

    completedGroupTasksToday.sort(
      (a, b) => a.completedAt!.compareTo(b.completedAt!),
    );

    int totalXP = 0;
    for (final task in completedGroupTasksToday) {
      if (task.assigneeIds.contains(leaderId)) {
        final rawAward = task.calculateXP;
        if (totalXP >= 270) {
          continue;
        } else if (totalXP + rawAward >= 270) {
          totalXP = 270;
        } else {
          totalXP += rawAward + 10;
        }
      } else {
        if (totalXP >= 270) {
          continue;
        } else {
          totalXP += 10;
        }
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
    int taskCountDelta = 1;

    final todayXP = getDailyGroupXPForLeader(leaderId);

    if (!task.assigneeIds.contains(leaderId)) {
      // Case 1: Management Only (Leader is NOT an assignee)
      if (todayXP >= 270) {
        leaderXPAward = 0;
        if (isNowCompleted) {
          _triggerXPCapAlert();
        }
      } else {
        leaderXPAward = 10;
        taskCountDelta = 1;
      }
    } else {
      // Case 2: Player-Coach (Leader IS an assignee alongside others)
      int taskXPAward = task.calculateXP;
      if (todayXP >= 270) {
        taskXPAward = 0;
        leaderXPAward = 0;
        if (isNowCompleted) {
          _triggerXPCapAlert();
        }
      } else if (todayXP + taskXPAward >= 270) {
        taskXPAward = 270 - todayXP;
        leaderXPAward = taskXPAward + 10;
        taskCountDelta = 1;
        if (isNowCompleted) {
          _triggerXPCapAlert();
        }
      } else {
        leaderXPAward = taskXPAward + 10;
        taskCountDelta = 1;
      }
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

  List<Task> get todayTasks => todayPersonalTasks;

  List<Task> get todayPersonalTasks {
    final today = _todayString();
    return personalTasks
        .where((task) => _dateString(task.dateTime) == today)
        .toList();
  }

  List<Task> get overduePersonalTasks {
    final today = _todayString();
    return personalTasks
        .where(
          (task) =>
              _dateString(task.dateTime).compareTo(today) < 0 &&
              task.status != TaskStatus.completed,
        )
        .toList();
  }

  List<Task> get todayGroupTasks {
    final today = _todayString();
    return groupTasks
        .where((task) => _dateString(task.dateTime) == today)
        .toList();
  }

  List<Task> get overdueGroupTasks {
    final today = _todayString();
    return groupTasks
        .where(
          (task) =>
              _dateString(task.dateTime).compareTo(today) < 0 &&
              task.status != TaskStatus.completed,
        )
        .toList();
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

    _subscriptions.add(
      _firestore.collection('projects').snapshots().listen((snapshot) {
        _allProjects
          ..clear()
          ..addAll(
            snapshot.docs.map((doc) => Project.fromMap(doc.data(), doc.id)),
          );
        _applyProjectFilter();
        notifyListeners();
      }, onError: (error) => debugPrint('Project stream error: $error')),
    );
  }

  void _handleAuthUserChanged(String? userId) {
    if (_currentUserId == userId) return;
    _currentUserId = userId;
    _tasks.clear();
    _friends.clear();
    _userCache.clear();
    _applyProjectFilter();
    _selectedTask = null;
    _selectedProject = null;
    _totalXP = 0;
    _listenToCurrentUserTasks(userId);
    if (userId != null) {
      loadFriends();
    }
    notifyListeners();
  }

  void _applyProjectFilter() {
    final currentUserId = _currentUserId;
    _projects
      ..clear()
      ..addAll(
        _allProjects.where(
          (project) =>
              currentUserId != null &&
              (project.leaderId == currentUserId ||
                  project.memberIds.contains(currentUserId)),
        ),
      );
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
        }, onError: (error) => debugPrint('Task stream error: $error'));
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

    final batch = _firestore.batch();
    final pushTargets = <Map<String, String>>[];
    for (final userId in normalizedIds.take(450)) {
      final ref = _firestore
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .doc();
      pushTargets.add({'userId': userId, 'notificationId': ref.id});
      batch.set(ref, {
        ...data,
        'isRead': false,
        'createdAt': FieldValue.serverTimestamp(),
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
        'notificationKey': '${task.id}-${comment.id}',
        'actorId': comment.userId,
        'actorName': comment.userName,
        'actorAvatarUrl': comment.userAvatarUrl,
        'commentId': comment.id,
      });
    } catch (error) {
      debugPrint('Failed to create comment notifications: $error');
    }
  }

  Future<void> _notifyTaskSubmitted(Task task, String submitterId) async {
    if (!task.isGroup) return;

    final leaderId = leaderIdForTask(task);
    if (leaderId.isEmpty || leaderId == submitterId) return;

    final submitter = getUserById(submitterId);
    final actorName =
        submitter?.name ?? _auth.currentUser?.displayName ?? 'สมาชิก';
    final actorAvatarUrl =
        submitter?.avatarUrl ?? _auth.currentUser?.photoURL ?? '';
    final submissionText = task.submissionText?.trim() ?? '';
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

  DateTime? _recurringDateTimeFor(Task task) {
    if (!task.isRecurring) return null;

    switch (task.recurringType) {
      case 'daily':
        return task.dateTime.add(const Duration(days: 1));
      case 'weekly':
        return task.dateTime.add(const Duration(days: 7));
      case 'monthly':
        return DateTime(
          task.dateTime.year,
          task.dateTime.month + 1,
          task.dateTime.day,
          task.dateTime.hour,
          task.dateTime.minute,
        );
      case 'yearly':
        return DateTime(
          task.dateTime.year + 1,
          task.dateTime.month,
          task.dateTime.day,
          task.dateTime.hour,
          task.dateTime.minute,
        );
      case 'weekdays':
        DateTime next = task.dateTime.add(const Duration(days: 1));
        while (next.weekday == DateTime.saturday ||
            next.weekday == DateTime.sunday) {
          next = next.add(const Duration(days: 1));
        }
        return next;
      case 'custom':
        return _customRecurringDateTimeFor(task);
      default:
        return _customRecurringDateTimeFor(task) ??
            task.dateTime.add(const Duration(days: 1));
    }
  }

  DateTime? _customRecurringDateTimeFor(Task task) {
    final num = task.customRecurringNum ?? 1;
    final unit = task.customRecurringUnit ?? 'วัน';
    final days = task.customRecurringDays ?? [];
    final mode = task.customRecurringMode ?? 'byDueDate';

    DateTime baseDate = task.dateTime;
    if (mode == 'byFixedDate') {
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
          DateTime candidate = baseDate.add(const Duration(days: 1));
          int daysSearched = 0;
          while (!targetWeekdays.contains(candidate.weekday) &&
              daysSearched < 365) {
            candidate = candidate.add(const Duration(days: 1));
            daysSearched++;
          }
          nextDate = candidate;
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

  Future<void> _cloneRecurringTaskAfterCompletion(Task sourceTask) async {
    final recurringDateTime = _recurringDateTimeFor(sourceTask);
    if (recurringDateTime == null) return;

    // Check if a clone for this exact date and task already exists
    final hasExistingClone = _tasks.any(
      (t) =>
          t.title == sourceTask.title &&
          t.creatorId == sourceTask.creatorId &&
          t.isRecurring == sourceTask.isRecurring &&
          t.recurringType == sourceTask.recurringType &&
          t.dateTime.isAtSameMomentAs(recurringDateTime),
    );

    if (hasExistingClone) return;

    final cloneId = 'task_${DateTime.now().microsecondsSinceEpoch}';
    final clonedTask = sourceTask.copyWith(
      id: cloneId,
      dateTime: recurringDateTime,
      status: TaskStatus.inProgress,
      clearCompletedAt: true,
      isDeleted: false,
      deletedForUserIds: const [],
      hiddenForUserIds: const [],
      notified1Week: false,
      notified1Day: false,
      notified1Hour: false,
      notifiedExact: false,
      notifiedFollowUp: false,
      clearSubmissionText: true,
      clearSubmittedBy: true,
      clearSubmittedAt: true,
      awardedXP: 0,
      subtasks: sourceTask.subtasks
          .map((subtask) => subtask.copyWith(isDone: false))
          .toList(),
      comments: const [],
      customReminders: sourceTask.customReminders.map(
        (minutes, _) => MapEntry(minutes, false),
      ),
    );

    final cloneData = clonedTask.toMap()
      ..addAll({
        'notified1Week': false,
        'notified1Day': false,
        'notified1Hour': false,
        'notifiedExact': false,
        'notifiedFollowUp': false,
      });

    await _firestore.collection('tasks').doc(cloneId).set(cloneData);
  }

  Future<void> _deleteRecurringCloneOnUndo(Task sourceTask) async {
    final recurringDateTime = _recurringDateTimeFor(sourceTask);
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

    final updatedTask = task.copyWith(
      status: TaskStatus.inProgress,
      clearSubmissionText: true,
      clearSubmittedBy: true,
      clearSubmittedAt: true,
      attachments: [],
      clearCompletedAt: true,
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

    await _firestore.collection('tasks').doc(taskId).update({
      'status': TaskStatus.inProgress.name,
      'submissionText': FieldValue.delete(),
      'submittedBy': FieldValue.delete(),
      'submittedAt': FieldValue.delete(),
      'attachments': [],
    });
    if (submitterId != null && submitterId.isNotEmpty && leaderId.isNotEmpty) {
      await _notifyTaskReviewDecision(
        task,
        decision: 'rejected',
        submitterId: submitterId,
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
      );
      _tasks[index] = updatedTask;
      _calculateInitialXP();
      notifyListeners();
    }

    await _firestore.collection('tasks').doc(taskId).set({
      'isDeleted': false,
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
      batch.set(_firestore.collection('tasks').doc(task.id), {
        'status': TaskStatus.pending.name,
        'completedAt': null,
        'awardedXP': 0,
        'rewardBlocked': false,
        'rewardBlockedReason': null,
        'rewardBlockedAt': null,
        'rewardBlockedBy': null,
        'completionAgeSeconds': null,
      }, SetOptions(merge: true));
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
    final blocksReward =
        isNowCompleted &&
        isCompletionRewardBlockedByAge(
          createdAt: task.createdAt,
          completedAt: completedAt,
        );

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
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;

    final task = _tasks[index];
    if (task.isDeleted || (task.isGroup && task.isCompleted)) return;

    final updatedTask = task.copyWith(
      comments: List<Comment>.from(task.comments)..add(comment),
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
    await _notifyTaskComment(updatedTask, comment);
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
