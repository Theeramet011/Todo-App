import 'dart:convert';
import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// 🔥 1. เพิ่ม Import สำหรับตัวสร้างแจ้งเตือนใน Android
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:todo_app/screens/friends_screen.dart';
import 'firebase_options.dart';
import 'config/theme.dart';
import 'config/constants.dart';
import 'config/colors.dart';
import 'providers/auth_provider.dart';
import 'providers/task_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/connectivity_provider.dart';
import 'models/task.dart' show Task;
import 'screens/splash_to_login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/task_detail_screen.dart';
import 'screens/upcoming_tasks_screen.dart';
import 'widgets/level_up_dialog.dart';
import 'widgets/achievement_unlock_dialog.dart';
import 'models/achievement.dart';

final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

// 🔥 2. สร้างฟังก์ชันดักรับแจ้งเตือนตอนพับจอ (Background Handler) *ต้องอยู่นอกสุด*
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  DartPluginRegistrant.ensureInitialized();
  debugPrint(
    "📬 ได้รับแจ้งเตือนหลังบ้าน (Background): ${_notificationTitleFromMessage(message)}",
  );
  // หากมี payload notification จากระบบปฏิบัติการ Android OS จะเป็นผู้วาดใน Status Bar ให้อัตโนมัติ
  // จึงเรียก _showTaskReminderNotification เฉพาะเมื่อเป็นข้อความ data-only เพื่อป้องกันการแจ้งเตือนซ้ำ 2 อัน
  if (message.notification == null) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    await _initializeLocalNotifications();
    await _showTaskReminderNotification(message);
  }
}

const String taskReminderChannelId = 'task_reminder_alerts_v3';
const String taskCommentChannelId = 'task_comment_alerts_v2';

// 🔥 3. สร้างท่อสัญญาณ (Channel) สำหรับ Android ที่ใช้เสียงแจ้งเตือนแบบกำหนดเอง (notification.wav)
final AndroidNotificationChannel channel = AndroidNotificationChannel(
  taskReminderChannelId,
  'Task Reminder Alerts',
  description: 'Time-sensitive task reminder notifications with custom sound.',
  importance: Importance.max,
  playSound: true,
  sound: const RawResourceAndroidNotificationSound('notification'),
  enableVibration: true,
  vibrationPattern: Int64List.fromList(<int>[0, 700, 250, 700]),
  audioAttributesUsage: AudioAttributesUsage.alarm,
);

final AndroidNotificationChannel commentChannel = AndroidNotificationChannel(
  taskCommentChannelId,
  'Task Comment Alerts',
  description: 'High priority alerts when someone comments on your tasks with custom sound.',
  importance: Importance.max,
  playSound: true,
  sound: const RawResourceAndroidNotificationSound('notification'),
  enableVibration: true,
  vibrationPattern: Int64List.fromList(<int>[0, 350, 150, 350, 150, 550]),
  audioAttributesUsage: AudioAttributesUsage.notificationRingtone,
);

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('th_TH', null);

  // 🔥 4. ลงทะเบียนฟังก์ชัน Background
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 🔥 5. ตั้งค่าป๊อปอัปแจ้งเตือนสำหรับเครื่อง Android
  await _initializeLocalNotifications();

  // บังคับให้แจ้งเตือนเด้งโชว์หน้าจอเสมอแม้เปิดแอปค้างไว้ (สำหรับ iOS)
  if (!kIsWeb) {
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
  }

  await requestNotificationPermission();

  // 🔥 6. เรียกใช้ฟังก์ชันดึง Token และดักรับข้อความตอนเปิดแอป
  await setupFCMListener();

  runApp(const MyApp());
}

// 🔥 7. ฟังก์ชันพระเอก: ดึง Token และรอรับข้อความ
Future<void> setupFCMListener() async {
  if (kIsWeb) return; // ข้ามการทำงานถ้าเป็นเว็บ

  final messaging = FirebaseMessaging.instance;

  // 🔑 ดึงรหัส Token ของเครื่องนี้ (สำคัญมาก!)
  try {
    String? token = await messaging.getToken();
    debugPrint('====================================');
    debugPrint('🔑 FCM TOKEN เครื่องนี้คือ: $token');
    debugPrint('====================================');
  } catch (e) {
    debugPrint('ดึง Token ไม่สำเร็จ: $e');
  }

  // 🔔 ดักจับข้อความตอนกำลังเปิดแอปใช้งานอยู่ (Foreground)
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    await _showTaskReminderNotification(message);
  });

  FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationNavigation);

  final initialMessage = await messaging.getInitialMessage();
  if (initialMessage != null) {
    _handleNotificationNavigation(initialMessage);
  }
}

Future<void> _initializeLocalNotifications() async {
  if (kIsWeb) return;

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(channel);
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >()
      ?.createNotificationChannel(commentChannel);

  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('ic_stat_noti_photoroom');
  const InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
  );
  await flutterLocalNotificationsPlugin.initialize(
    settings: initializationSettings,
    onDidReceiveNotificationResponse: (response) {
      _handleNotificationPayload(response.payload);
    },
  );

  final launchDetails =
      await flutterLocalNotificationsPlugin.getNotificationAppLaunchDetails();
  if (launchDetails?.didNotificationLaunchApp == true &&
      launchDetails?.notificationResponse?.payload != null) {
    _handleNotificationPayload(launchDetails!.notificationResponse!.payload);
  }
}

Future<void> _showTaskReminderNotification(RemoteMessage message) async {
  if (kIsWeb) return;

  final notificationKey = _notificationKeyFromMessage(message);
  final localNotificationId = _notificationIdFromKey(notificationKey);
  final title = AppConstants.sanitizeThaiDisplay(
    _notificationTitleFromMessage(message),
  );
  final body = AppConstants.sanitizeThaiDisplay(
    _notificationBodyFromMessage(message),
  );
  final androidChannel = _androidChannelFromMessage(message);

  if (title.isEmpty && body.isEmpty) return;

  await flutterLocalNotificationsPlugin.show(
    id: localNotificationId,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        androidChannel.id,
        androidChannel.name,
        channelDescription: androidChannel.description,
        icon: 'ic_stat_noti_photoroom',
        importance: Importance.max,
        priority: Priority.max,
        playSound: true,
        sound: const RawResourceAndroidNotificationSound('notification'),
        enableVibration: true,
        vibrationPattern: Int64List.fromList(
          _notificationVibrationPattern(message),
        ),
        category: _androidCategoryFromMessage(message),
        visibility: NotificationVisibility.public,
        audioAttributesUsage: _audioUsageFromMessage(message),
        ticker: title,
        tag: notificationKey,
      ),
    ),
    payload: jsonEncode(message.data),
  );
}

String _notificationKeyFromMessage(RemoteMessage message) {
  if (_isCommentNotification(message)) {
    final taskId = message.data['taskId']?.toString().trim();
    if (taskId != null && taskId.isNotEmpty) {
      return 'task-comment-$taskId';
    }
    return 'task-comment-latest';
  }
  return message.data['notificationKey'] ??
      message.messageId ??
      DateTime.now().microsecondsSinceEpoch.toString();
}

String? _notificationTitleFromMessage(RemoteMessage message) {
  return message.notification?.title ??
      message.data['title'] ??
      message.data['notificationTitle'];
}

String? _notificationBodyFromMessage(RemoteMessage message) {
  return message.notification?.body ??
      message.data['body'] ??
      message.data['notificationBody'];
}

int _notificationIdFromKey(String notificationKey) {
  return notificationKey.hashCode & 0x7fffffff;
}

AndroidNotificationChannel _androidChannelFromMessage(RemoteMessage message) {
  return _isCommentNotification(message) ? commentChannel : channel;
}

bool _isCommentNotificationData(Map<String, dynamic> data) {
  final type = (data['notificationType'] ?? data['type'] ?? '').toString().toLowerCase();
  final stage = (data['notificationStage'] ?? '').toString().toLowerCase();
  return type == 'comment' || stage == 'commentadded';
}

bool _isCommentNotification(RemoteMessage message) {
  return _isCommentNotificationData(message.data);
}

AndroidNotificationCategory _androidCategoryFromMessage(RemoteMessage message) {
  return _isCommentNotification(message)
      ? AndroidNotificationCategory.message
      : AndroidNotificationCategory.reminder;
}

AudioAttributesUsage _audioUsageFromMessage(RemoteMessage message) {
  return _isCommentNotification(message)
      ? AudioAttributesUsage.notificationRingtone
      : AudioAttributesUsage.alarm;
}

List<int> _notificationVibrationPattern(RemoteMessage message) {
  if (_isCommentNotification(message)) {
    return <int>[0, 350, 150, 350, 150, 550];
  }
  return <int>[0, 700, 250, 700];
}

Map<String, dynamic>? _pendingNotificationData;

void checkAndRoutePendingNotification() {
  final data = _pendingNotificationData;
  if (data == null) return;
  final context = appNavigatorKey.currentContext;
  if (context == null) return;

  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  if (!authProvider.isLoggedIn || authProvider.currentUser == null) return;

  _pendingNotificationData = null;
  debugPrint('🚀 [Notification Navigation] Triggering pending notification route: $data');
  _handleNotificationData(data);
}

void _handleNotificationNavigation(RemoteMessage message) {
  debugPrint('🔔 [FCM Notification] _handleNotificationNavigation: messageId=${message.messageId}, data=${message.data}');
  _handleNotificationData(message.data);
}

void _handleNotificationPayload(String? payload) {
  debugPrint('🔔 [Local Notification] _handleNotificationPayload: $payload');
  if (payload == null || payload.trim().isEmpty) return;

  try {
    final decoded = jsonDecode(payload);
    if (decoded is Map) {
      _handleNotificationData(
        decoded.map((key, value) => MapEntry(key.toString(), value.toString())),
      );
    }
  } catch (error) {
    debugPrint('❌ [Notification] Unable to parse payload: $error');
  }
}

String? _lastNavigatedNotificationKey;
DateTime? _lastNavigatedNotificationTime;

bool _isDuplicateNavigation(String key) {
  final now = DateTime.now();
  if (_lastNavigatedNotificationKey == key &&
      _lastNavigatedNotificationTime != null &&
      now.difference(_lastNavigatedNotificationTime!).inMilliseconds < 1500) {
    return true;
  }
  _lastNavigatedNotificationKey = key;
  _lastNavigatedNotificationTime = now;
  return false;
}

void _handleNotificationData(Map<String, dynamic> data) {
  debugPrint('🔔 [Notification Navigation] _handleNotificationData: $data');
  if (data.isEmpty) return;

  Map<String, dynamic> resolvedData = Map<String, dynamic>.from(data);
  if (resolvedData['data'] is Map) {
    resolvedData.addAll(Map<String, dynamic>.from(resolvedData['data'] as Map));
  }

  // If Navigator/Auth is not ready yet, keep in _pendingNotificationData
  final context = appNavigatorKey.currentContext;
  if (context == null) {
    debugPrint('⏳ [Notification Navigation] Context is null, saving to _pendingNotificationData');
    _pendingNotificationData = resolvedData;
  } else {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (!authProvider.isLoggedIn || authProvider.currentUser == null) {
      debugPrint('⏳ [Notification Navigation] User not logged in yet, saving to _pendingNotificationData');
      _pendingNotificationData = resolvedData;
    }
  }

  final type = (resolvedData['notificationType'] ?? resolvedData['type'] ?? '').toString().toLowerCase();
  final stage = (resolvedData['notificationStage'] ?? '').toString().toLowerCase();

  if (type == 'friendrequest' ||
      type == 'friendaccepted' ||
      stage.startsWith('friendrequest')) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _openFriendsScreenFromNotification();
    });
    return;
  }

  final taskId = (resolvedData['taskId'] ?? resolvedData['task_id'] ?? resolvedData['id'])?.toString().trim();
  if (taskId == null || taskId.isEmpty) {
    debugPrint('⚠️ [Notification Navigation] No valid taskId found in: $resolvedData');
    return;
  }

  final isComment = _isCommentNotificationData(resolvedData);

  WidgetsBinding.instance.addPostFrameCallback((_) {
    _openTaskFromNotification(taskId, scrollToComments: isComment);
  });
}

Future<void> _openFriendsScreenFromNotification({int attempt = 0}) async {
  final navigator = appNavigatorKey.currentState;
  final context = appNavigatorKey.currentContext;

  if (navigator == null || context == null) {
    if (attempt < 40) {
      await Future.delayed(const Duration(milliseconds: 250));
      return _openFriendsScreenFromNotification(attempt: attempt + 1);
    }
    debugPrint('❌ [Notification Navigation] Timed out waiting to open FriendsScreen.');
    return;
  }

  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  if (!authProvider.isLoggedIn || authProvider.currentUser == null) {
    if (attempt < 40) {
      await Future.delayed(const Duration(milliseconds: 250));
      return _openFriendsScreenFromNotification(attempt: attempt + 1);
    }
    debugPrint('❌ [Notification Navigation] Timed out waiting for AuthProvider to open FriendsScreen.');
    return;
  }

  if (_isDuplicateNavigation('friends-screen')) {
    debugPrint('ℹ️ [Notification Navigation] Duplicate FriendsScreen navigation skipped.');
    return;
  }

  debugPrint('🚀 [Notification Navigation] Navigating to FriendsScreen');
  navigator.push(
    MaterialPageRoute(
      builder: (_) => const FriendsScreen(openAddFriendModal: true),
    ),
  );
}

Future<void> _openTaskFromNotification(
  String taskId, {
  bool scrollToComments = false,
  int attempt = 0,
}) async {
  debugPrint('🔔 [Notification Navigation] _openTaskFromNotification: taskId=$taskId, scrollToComments=$scrollToComments, attempt=$attempt');
  final navigator = appNavigatorKey.currentState;
  final context = appNavigatorKey.currentContext;

  if (navigator == null || context == null) {
    if (attempt < 40) {
      await Future.delayed(const Duration(milliseconds: 250));
      return _openTaskFromNotification(
        taskId,
        scrollToComments: scrollToComments,
        attempt: attempt + 1,
      );
    }
    debugPrint('❌ [Notification Navigation] Timed out waiting for navigator or context.');
    return;
  }

  final authProvider = Provider.of<AuthProvider>(context, listen: false);
  if (!authProvider.isLoggedIn || authProvider.currentUser == null) {
    if (attempt < 40) {
      await Future.delayed(const Duration(milliseconds: 250));
      return _openTaskFromNotification(
        taskId,
        scrollToComments: scrollToComments,
        attempt: attempt + 1,
      );
    }
    debugPrint('❌ [Notification Navigation] Timed out waiting for AuthProvider login.');
    return;
  }

  final taskProvider = Provider.of<TaskProvider>(context, listen: false);
  Task? task = _taskFromProvider(taskProvider, taskId);

  if (task == null) {
    debugPrint('🔍 [Notification Navigation] Task not in provider cache, fetching from Firestore: $taskId');
    try {
      final snap = await FirebaseFirestore.instance
          .collection('tasks')
          .doc(taskId)
          .get();
      final data = snap.data();
      if (snap.exists && data != null) {
        task = Task.fromMap(data, snap.id);
        debugPrint('✅ [Notification Navigation] Fetched task successfully: ${task.title}');
      } else {
        debugPrint('⚠️ [Notification Navigation] Task doc does not exist in Firestore: $taskId');
      }
    } catch (error) {
      debugPrint('❌ [Notification Navigation] Failed to fetch task $taskId: $error');
    }
  }

  if (task == null) {
    debugPrint('❌ [Notification Navigation] Could not find task $taskId anywhere.');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่พบภารกิจนี้ หรือภารกิจอาจถูกลบไปแล้ว'),
          backgroundColor: AppColors.accentRed,
          duration: Duration(seconds: 3),
        ),
      );
    }
    return;
  }

  final navigationKey = 'task-$taskId-comment-$scrollToComments';
  if (_isDuplicateNavigation(navigationKey)) {
    debugPrint('ℹ️ [Notification Navigation] Duplicate navigation skipped for $navigationKey');
    return;
  }

  taskProvider.selectTask(task);
  debugPrint('🚀 [Notification Navigation] Navigating to TaskDetailScreen for "${task.title}" (scrollToComments=$scrollToComments)');
  await navigator.push(
    MaterialPageRoute(
      builder: (_) => TaskDetailScreen(
        task: task,
        scrollToComments: scrollToComments,
      ),
    ),
  );
}

Task? _taskFromProvider(TaskProvider taskProvider, String taskId) {
  try {
    return taskProvider.tasks.firstWhere((task) => task.id == taskId);
  } catch (_) {
    final selectedTask = taskProvider.selectedTask;
    if (selectedTask?.id == taskId) return selectedTask;
    return null;
  }
}

Future<void> requestNotificationPermission() async {
  if (!_supportsFirebaseMessaging) {
    debugPrint(
      'Skipping notification permission: Firebase Messaging is not supported on this platform.',
    );
    return;
  }

  try {
    final messaging = FirebaseMessaging.instance;

    final settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      debugPrint('Notification permission authorized.');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      debugPrint('Notification permission provisionally authorized.');
    } else {
      debugPrint('Notification permission denied.');
    }
  } on MissingPluginException catch (e) {
    debugPrint('Firebase Messaging plugin is unavailable: $e');
  } catch (e, stackTrace) {
    debugPrint('Error requesting notification permission: $e');
    debugPrintStack(stackTrace: stackTrace);
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

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TaskProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => ConnectivityProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            navigatorKey: appNavigatorKey,
            title: 'QuestLife',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeProvider.themeMode,
            locale: const Locale('th', 'TH'),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('th', 'TH'), Locale('en', 'US')],
            builder: (context, child) {
              final mediaQueryData = MediaQuery.of(context);
              return MediaQuery(
                data: mediaQueryData.copyWith(alwaysUse24HourFormat: false),
                child: _AppLifecycleObserver(
                  child: _AchievementUnlockListener(
                    child: _LevelUpListener(
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                ),
              );
            },
            home: const AuthGate(),
            routes: {
              '/task-detail': (context) => TaskDetailScreen(),
              '/login': (context) => const SplashToLoginScreen(),
              '/friends': (context) => const FriendsScreen(),
              '/upcoming': (context) => const UpcomingTasksScreen(),
            },
          );
        },
      ),
    );
  }
}

class _LevelUpListener extends StatefulWidget {
  final Widget child;

  const _LevelUpListener({required this.child});

  @override
  State<_LevelUpListener> createState() => _LevelUpListenerState();
}

class _LevelUpListenerState extends State<_LevelUpListener> {
  int? _lastObservedLevel;
  int? _pendingLevel;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        final currentLevel = authProvider.currentUser?.currentLevel;
        if (currentLevel != null) {
          final previousLevel = _lastObservedLevel;
          if (previousLevel == null || currentLevel <= previousLevel) {
            _lastObservedLevel = currentLevel;
          } else if (_pendingLevel != currentLevel) {
            _pendingLevel = currentLevel;
            _lastObservedLevel = currentLevel;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _showLevelUpDialog(currentLevel);
            });
          }
        } else {
          _lastObservedLevel = null;
          _pendingLevel = null;
        }

        return widget.child;
      },
    );
  }

  Future<void> _showLevelUpDialog(int level, {int attempt = 0}) async {
    if (!mounted) return;
    final navigatorContext = appNavigatorKey.currentContext;
    if (navigatorContext == null) {
      if (attempt < 8) {
        await Future.delayed(const Duration(milliseconds: 150));
        return _showLevelUpDialog(level, attempt: attempt + 1);
      }
      _pendingLevel = null;
      return;
    }

    await showDialog<void>(
      context: navigatorContext,
      barrierDismissible: false,
      builder: (context) => LevelUpDialog(newLevel: level),
    );
    if (mounted && _pendingLevel == level) {
      _pendingLevel = null;
    }
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, _) {
        if (authProvider.isLoggedIn && authProvider.currentUser != null) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            checkAndRoutePendingNotification();
          });
          return const HomeScreen();
        }
        return const SplashToLoginScreen();
      },
    );
  }
}

class _AchievementUnlockListener extends StatefulWidget {
  final Widget child;

  const _AchievementUnlockListener({required this.child});

  @override
  State<_AchievementUnlockListener> createState() =>
      _AchievementUnlockListenerState();
}

class _AchievementUnlockListenerState
    extends State<_AchievementUnlockListener> {
  Set<String>? _lastObservedAchievements;
  final List<String> _pendingAchievements = [];
  bool _isShowingDialog = false;

  @override
  Widget build(BuildContext context) {
    return Consumer<AuthProvider>(
      builder: (context, authProvider, child) {
        final currentAchievements =
            authProvider.currentUser?.achievementsUnlocked;

        if (currentAchievements != null) {
          final currentSet = currentAchievements.toSet();

          if (_lastObservedAchievements == null) {
            // First time loading, just record the state
            _lastObservedAchievements = currentSet;
          } else {
            // Find newly unlocked achievements
            final newAchievements = currentSet.difference(
              _lastObservedAchievements!,
            );

            if (newAchievements.isNotEmpty) {
              _pendingAchievements.addAll(newAchievements);
              _lastObservedAchievements = currentSet;

              if (!_isShowingDialog) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _processPendingAchievements();
                });
              }
            }
          }
        } else {
          _lastObservedAchievements = null;
        }

        return child!;
      },
      child: widget.child,
    );
  }

  Future<void> _processPendingAchievements({int attempt = 0}) async {
    if (!mounted || _pendingAchievements.isEmpty) return;

    final navigatorContext = appNavigatorKey.currentContext;
    if (navigatorContext == null) {
      if (attempt < 8) {
        await Future.delayed(const Duration(milliseconds: 150));
        return _processPendingAchievements(attempt: attempt + 1);
      }
      _pendingAchievements.clear();
      _isShowingDialog = false;
      return;
    }

    _isShowingDialog = true;

    // Wait a bit to ensure screen transitions (e.g. login -> home) are fully completed
    await Future.delayed(const Duration(milliseconds: 1500));

    while (_pendingAchievements.isNotEmpty && mounted) {
      final achievementId = _pendingAchievements.removeAt(0);
      final achievement = availableAchievements.firstWhere(
        (a) => a.id == achievementId,
        orElse: () => availableAchievements.first,
      );

      if (!navigatorContext.mounted) break;
      await AchievementUnlockDialog.show(navigatorContext, achievement);

      // Add a small delay between dialogs if there are multiple
      if (_pendingAchievements.isNotEmpty && mounted) {
        await Future.delayed(const Duration(milliseconds: 300));
      }
    }

    if (mounted) {
      _isShowingDialog = false;
    }
  }
}

class _AppLifecycleObserver extends StatefulWidget {
  final Widget child;

  const _AppLifecycleObserver({required this.child});

  @override
  State<_AppLifecycleObserver> createState() => _AppLifecycleObserverState();
}

class _AppLifecycleObserverState extends State<_AppLifecycleObserver>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (state == AppLifecycleState.resumed) {
      authProvider.setOnlineStatus(true);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      authProvider.setOnlineStatus(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
