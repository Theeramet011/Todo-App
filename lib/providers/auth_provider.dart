// AuthProvider - ตัวจัดการสถานะระบบยืนยันตัวตนและการเข้าใช้งาน (Authentication State Management)
//
// จัดการสถานะผู้ใช้ปัจจุบัน (User State) การเข้าสู่ระบบด้วย Google/Email การออกจากระบบ
// การอัปเดตข้อมูลส่วนตัว (Profile/XP/Streak) และการเชื่อมโยงข้อมูลผู้ใช้กับ Firebase Firestore
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:intl/intl.dart';
import '../models/achievement.dart';
import '../models/user.dart';
import '../models/xp_system.dart';
import '../config/constants.dart';

class AuthProvider with ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;
  bool _isLoggedIn = false;
  bool _isAuthInitialized = false;
  String? _errorMessage;

  User? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _isLoggedIn;
  bool get isAuthInitialized => _isAuthInitialized;
  String? get errorMessage => _errorMessage;

  // แก้ไข 1: ใช้ GoogleSignIn.instance (Singleton ใน v7+)
  final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  final firebase_auth.FirebaseAuth _auth = firebase_auth.FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription<firebase_auth.User?>? _authSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSubscription;
  StreamSubscription<String>? _tokenRefreshSubscription;

  // เพิ่มตัวแปรสำหรับเช็คการตั้งค่า GoogleSignIn
  bool _isGoogleSignInInitialized = false;

  AuthProvider() {
    _authSubscription = _auth.authStateChanges().listen(
      _handleAuthStateChanged,
    );
    if (_supportsFirebaseMessaging) {
      _tokenRefreshSubscription = FirebaseMessaging.instance.onTokenRefresh
          .listen((_) => saveDeviceTokenToFirestore());
    }
  }

  Future<void> _handleAuthStateChanged(firebase_auth.User? fbUser) async {
    if (fbUser == null) {
      await _userSubscription?.cancel();
      _userSubscription = null;
      _currentUser = null;
      _isLoggedIn = false;
      _isAuthInitialized = true;
      _isLoading = false;
      notifyListeners();
      return;
    }

    final userDoc = _firestore.collection('users').doc(fbUser.uid);
    DocumentSnapshot<Map<String, dynamic>>? snapshot;

    final connectivityResult = await Connectivity().checkConnectivity();
    final isOffline = connectivityResult.contains(ConnectivityResult.none);

    try {
      if (isOffline) {
        snapshot = await userDoc.get(const GetOptions(source: Source.cache));
      } else {
        // Fast path: อ่านจาก Cache ก่อนเพื่อความรวดเร็วในการเปิดแอป
        try {
          snapshot = await userDoc.get(const GetOptions(source: Source.cache));
        } catch (_) {
          snapshot = null;
        }

        // หากใน Cache ยังไม่มี (เช่น ติดตั้งใหม่หรือเพิ่งสมัคร) ให้ดึงจาก Server
        if (snapshot == null || !snapshot.exists || snapshot.data() == null) {
          snapshot = await userDoc
              .get(const GetOptions(source: Source.serverAndCache))
              .timeout(const Duration(seconds: 3));
        }
      }
    } catch (e) {
      debugPrint('Error fetching user doc: $e');
      if (!isOffline && (snapshot == null || !snapshot.exists)) {
        try {
          snapshot = await userDoc.get(const GetOptions(source: Source.cache));
        } catch (e2) {
          debugPrint('Error fetching user from cache: $e2');
        }
      }
    }

    final data = snapshot?.data();

    if (snapshot != null && snapshot.exists && data != null) {
      _currentUser = User.fromMap(data, snapshot.id).copyWith(
        isOnline: !isOffline,
        name: data['name'] ?? fbUser.displayName ?? 'New User',
        email: data['email'] ?? fbUser.email ?? '',
        avatarUrl: data['avatarUrl'] ?? fbUser.photoURL ?? '',
      );
    } else {
      _currentUser = User(
        id: fbUser.uid,
        name: fbUser.displayName ?? 'New User',
        email: fbUser.email ?? '',
        avatarUrl: fbUser.photoURL ?? 'https://i.pravatar.cc/150?img=1',
        joinedAt: DateTime.now(),
        isOnline: !isOffline,
      );
    }

    _listenToCurrentUser(fbUser.uid);
    _isLoggedIn = true;
    _isAuthInitialized = true;
    _isLoading = false;
    notifyListeners();

    Future.microtask(() async {
      try {
        await userDoc.set(_currentUser!.toMap(), SetOptions(merge: true));
      } catch (e) {
        debugPrint('Failed to set user doc offline: $e');
      }
      if (!isOffline) {
        try {
          await saveDeviceTokenToFirestore();
        } catch (e) {
          debugPrint('Failed to save device token: $e');
        }
        try {
          await checkAndUpdateStreak(fbUser.uid);
        } catch (e) {
          debugPrint('Failed to check and update streak: $e');
        }
      }
    });
  }

  Future<void> saveDeviceTokenToFirestore() async {
    if (!_supportsFirebaseMessaging) {
      debugPrint(
        'Skipping FCM token save: Firebase Messaging is not supported on this platform.',
      );
      return;
    }

    try {
      final token = await FirebaseMessaging.instance.getToken();
      final currentUserId =
          firebase_auth.FirebaseAuth.instance.currentUser?.uid;

      if (token == null || currentUserId == null) {
        debugPrint(
          'Unable to save FCM token: token or current user ID is null.',
        );
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUserId)
          .set({
            'fcmToken': token,
            'lastUpdatedToken': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      debugPrint('FCM token saved for user: $currentUserId');
    } on MissingPluginException catch (e) {
      debugPrint('Firebase Messaging plugin is unavailable: $e');
    } catch (e, stackTrace) {
      debugPrint('Error saving FCM token to Firestore: $e');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  Future<void> checkAndUpdateStreak(String userId) async {
    final today = _dateOnly(DateTime.now());
    final todayString = _formatLoginDate(today);
    final yesterdayString = _formatLoginDate(
      today.subtract(const Duration(days: 1)),
    );
    final userRef = _firestore.collection('users').doc(userId);

    await _firestore.runTransaction((transaction) async {
      final snapshot = await transaction.get(userRef);
      final data = snapshot.data();
      final update = calculateStreakUpdate(
        data: data,
        todayString: todayString,
        yesterdayString: yesterdayString,
      );
      final currentStreak = _readInt(
        update?['currentStreak'] ?? data?['currentStreak'],
        fallback: _readInt(data?['streak']),
      );
      final unlockedIds = mergedUnlockedAchievementIds(
        existingIds: _readStringList(data?['achievementsUnlocked']),
        tasksCompleted: _readInt(data?['tasksCompleted']),
        currentStreak: currentStreak,
        groupTasksCompleted: _readInt(data?['groupTasksCompleted']),
        memberGroupTasksCompleted: _readInt(data?['memberGroupTasksCompleted']),
        leaderGroupTasksCompleted: _readInt(data?['leaderGroupTasksCompleted']),
        currentLevel: _readInt(data?['currentLevel'], fallback: 1),
      );

      transaction.set(userRef, {
        ...?update,
        'achievementsUnlocked': unlockedIds,
      }, SetOptions(merge: true));
    });
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static String _formatLoginDate(DateTime date) {
    return DateFormat('yyyy-MM-dd').format(date);
  }

  // Actual Google Sign In
  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // สิ่งที่ต้องทำเพิ่มใน v7: ต้องทำการ initialize() 1 ครั้งก่อนใช้งาน
      if (!_isGoogleSignInInitialized) {
        await _googleSignIn.initialize();
        _isGoogleSignInInitialized = true;
      }

      // แก้ไข 2: ใช้ .authenticate() แทน .signIn() ใน v7+ (คืนค่าเป็น Non-nullable)
      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();

      // ใน v7+ หากผู้ใช้ยกเลิก ระบบจะ Throw Exception แทนการคืนค่า null
      // ดังนั้นเราไม่จำเป็นต้องเช็ค googleUser == null แล้ว

      // แก้ไข 3: ใน v7+ .authentication เป็น Synchronous ไม่ต้องใส่ await
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // แก้ไข 4: Firebase ต้องการแค่ idToken อย่างเดียวก็สามารถล็อกอินได้
      // accessToken ถูกย้ายไปอยู่ใน authorizationClient สำหรับสิทธิ์เสริม
      final firebase_auth.AuthCredential credential = firebase_auth
          .GoogleAuthProvider.credential(idToken: googleAuth.idToken);

      // Step 4: Sign in to Firebase with the credential
      final firebase_auth.UserCredential userCredential = await _auth
          .signInWithCredential(credential);
      final firebase_auth.User? fbUser = userCredential.user;

      if (fbUser != null) {
        final userDoc = _firestore.collection('users').doc(fbUser.uid);
        final snapshot = await userDoc.get();

        if (snapshot.exists && snapshot.data() != null) {
          _currentUser = User.fromMap(snapshot.data()!, snapshot.id).copyWith(
            isOnline: true,
            name: snapshot.data()!['name'] ?? fbUser.displayName ?? 'New User',
            email: snapshot.data()!['email'] ?? fbUser.email ?? '',
            avatarUrl: snapshot.data()!['avatarUrl'] ?? fbUser.photoURL ?? '',
          );
        } else {
          _currentUser = User(
            id: fbUser.uid,
            name: fbUser.displayName ?? 'New User',
            email: fbUser.email ?? '',
            avatarUrl: fbUser.photoURL ?? 'https://i.pravatar.cc/150?img=1',
            joinedAt: DateTime.now(),
            isOnline: true,
          );
        }

        await userDoc.set(_currentUser!.toMap(), SetOptions(merge: true));
        await saveDeviceTokenToFirestore();
        await checkAndUpdateStreak(fbUser.uid);
        _listenToCurrentUser(fbUser.uid);
        _isLoggedIn = true;
        _isAuthInitialized = true;
        _isLoading = false;
        notifyListeners();
        return true;
      }
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Error signing in with Google: $e');
    }

    _isLoading = false;
    notifyListeners();
    return false;
  }

  // Sign Out
  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _googleSignIn.signOut();
      await _userSubscription?.cancel();
      _userSubscription = null;
      if (_currentUser != null) {
        await _firestore.collection('users').doc(_currentUser!.id).set({
          'isOnline': false,
        }, SetOptions(merge: true));
      }
      await _auth.signOut();
      _currentUser = null;
      _isLoggedIn = false;
    } catch (e) {
      debugPrint('Error signing out: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  // Update Online Status
  Future<void> setOnlineStatus(bool isOnline) async {
    if (_currentUser == null) return;
    try {
      await _firestore.collection('users').doc(_currentUser!.id).set({
        'isOnline': isOnline,
      }, SetOptions(merge: true));
      _currentUser = _currentUser!.copyWith(isOnline: isOnline);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating online status: $e');
    }
  }

  // Update User Profile
  void updateUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  Future<void> updateProfileInfo({
    required String name,
    String? avatarUrl,
  }) async {
    final user = _currentUser;
    if (user == null) return;

    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw ArgumentError.value(name, 'name', 'Name cannot be empty.');
    }

    final nextAvatarUrl = avatarUrl ?? user.avatarUrl;

    try {
      await _firestore.collection('users').doc(user.id).set({
        'name': trimmedName,
        'avatarUrl': nextAvatarUrl,
      }, SetOptions(merge: true));

      _currentUser = user.copyWith(name: trimmedName, avatarUrl: nextAvatarUrl);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating profile info: $e');
      rethrow;
    }
  }

  // Toggle Notification Setting
  Future<void> toggleNotification(bool value) async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(isNotificationEnabled: value);
    notifyListeners();
    try {
      await _firestore.collection('users').doc(_currentUser!.id).set({
        'isNotificationEnabled': value,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error toggling notification: $e');
    }
  }

  Future<void> toggleSound(bool value) async {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(isSoundEnabled: value);
    notifyListeners();
    try {
      await _firestore.collection('users').doc(_currentUser!.id).set({
        'isSoundEnabled': value,
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error toggling sound: $e');
    }
  }

  Future<void> addXp(int xpAmount) async {
    final user = _currentUser;
    if (user == null || xpAmount == 0) return;

    // Check if already at max level, if so do nothing
    final currentLevelCheck = calculateLevelProgress(user.totalXP).currentLevel;
    if (currentLevelCheck >= AppConstants.maxLevel) {
      return;
    }

    final userRef = _firestore.collection('users').doc(user.id);

    try {
      final updatedUser = await _firestore.runTransaction<User>((
        transaction,
      ) async {
        final snapshot = await transaction.get(userRef);
        final data = snapshot.data();
        final currentTotalXP = _readInt(
          data?['totalXP'],
          fallback: user.totalXP,
        );
        final oldLevel = calculateLevelProgress(currentTotalXP).currentLevel;

        int newTotalXP = currentTotalXP + xpAmount < 0
            ? 0
            : currentTotalXP + xpAmount;

        // Cap newTotalXP to max XP
        if (newTotalXP > AppConstants.maxXp) {
          newTotalXP = AppConstants.maxXp;
        }
        final newLevel = calculateLevelProgress(newTotalXP).currentLevel;
        final unlockedItems = _readStringList(
          data?['unlockedItems'] ?? user.unlockedItems,
        );
        final rewardIds = milestoneRewardIdsForLevelUp(oldLevel, newLevel);
        final unlockedIds = mergedUnlockedAchievementIds(
          existingIds: _readStringList(
            data?['achievementsUnlocked'] ?? user.achievementsUnlocked,
          ),
          tasksCompleted: _readInt(
            data?['tasksCompleted'],
            fallback: user.tasksCompleted,
          ),
          currentStreak: _readInt(
            data?['currentStreak'],
            fallback: user.currentStreak,
          ),
          groupTasksCompleted: _readInt(
            data?['groupTasksCompleted'],
            fallback: user.groupTasksCompleted,
          ),
          memberGroupTasksCompleted: _readInt(
            data?['memberGroupTasksCompleted'],
            fallback: user.memberGroupTasksCompleted,
          ),
          leaderGroupTasksCompleted: _readInt(
            data?['leaderGroupTasksCompleted'],
            fallback: user.leaderGroupTasksCompleted,
          ),
          currentLevel: newLevel,
        );

        final updateData = <String, dynamic>{
          'totalXP': newTotalXP,
          'currentLevel': newLevel,
          'equippedFrame': data?['equippedFrame'] ?? user.equippedFrame,
          'equippedTitle': data?['equippedTitle'] ?? user.equippedTitle,
          'achievementsUnlocked': unlockedIds,
        };

        if (rewardIds.isEmpty) {
          updateData['unlockedItems'] = unlockedItems;
        } else {
          updateData['unlockedItems'] = FieldValue.arrayUnion(rewardIds);
        }

        transaction.set(userRef, updateData, SetOptions(merge: true));

        return user.copyWith(
          totalXP: newTotalXP,
          unlockedItems: {...unlockedItems, ...rewardIds}.toList(),
          equippedFrame: data?['equippedFrame'] ?? user.equippedFrame,
          equippedTitle: data?['equippedTitle'] ?? user.equippedTitle,
          achievementsUnlocked: unlockedIds,
        );
      });

      _currentUser = updatedUser;
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding XP: $e');
    }
  }

  // Backward-compatible wrapper for older call sites.
  void addPoints(int points) {
    unawaited(addXp(points));
  }

  Future<void> equipItem(String fieldToUpdate, String itemId) async {
    final user = _currentUser;
    if (user == null) return;

    if (fieldToUpdate != 'equippedFrame' && fieldToUpdate != 'equippedTitle') {
      throw ArgumentError.value(
        fieldToUpdate,
        'fieldToUpdate',
        'Only equippedFrame and equippedTitle can be updated.',
      );
    }

    try {
      await _firestore.collection('users').doc(user.id).set({
        fieldToUpdate: itemId,
      }, SetOptions(merge: true));

      _currentUser = fieldToUpdate == 'equippedFrame'
          ? user.copyWith(equippedFrame: itemId)
          : user.copyWith(equippedTitle: itemId);
      notifyListeners();
    } catch (e) {
      debugPrint('Error equipping item: $e');
    }
  }

  void _listenToCurrentUser(String uid) {
    _userSubscription?.cancel();
    _userSubscription = _firestore
        .collection('users')
        .doc(uid)
        .snapshots()
        .listen((snapshot) {
          final data = snapshot.data();
          if (data == null) return;

          final newUser = User.fromMap(data, snapshot.id);

          _currentUser = newUser;
          notifyListeners();
        });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _userSubscription?.cancel();
    _tokenRefreshSubscription?.cancel();
    super.dispose();
  }
}

bool get _supportsFirebaseMessaging {
  if (kIsWeb) return true;

  switch (defaultTargetPlatform) {
    case TargetPlatform.android:
    case TargetPlatform.iOS:
    case TargetPlatform.macOS:
      return true;
    case TargetPlatform.fuchsia:
    case TargetPlatform.linux:
    case TargetPlatform.windows:
      return false;
  }
}

Map<String, dynamic>? calculateStreakUpdate({
  required Map<String, dynamic>? data,
  required String todayString,
  required String yesterdayString,
}) {
  final lastLoginDate = data?['lastLoginDate'];
  if (lastLoginDate == todayString) return null;

  final legacyStreak = _readInt(data?['streak']);
  final currentStreak = _readInt(
    data?['currentStreak'],
    fallback: legacyStreak,
  );
  final longestStreak = _readInt(
    data?['longestStreak'],
    fallback: currentStreak,
  );

  final nextCurrentStreak = lastLoginDate == yesterdayString
      ? currentStreak + 1
      : 1;
  final nextLongestStreak = nextCurrentStreak > longestStreak
      ? nextCurrentStreak
      : longestStreak;

  return {
    'currentStreak': nextCurrentStreak,
    'lastLoginDate': todayString,
    'longestStreak': nextLongestStreak,
  };
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
