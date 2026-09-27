// HomeScreen - หน้าจอหลักของแอปพลิเคชัน (Home Screen / Dashboard)
//
// ศูนย์รวมข้อมูลสำคัญ เช่น สรุปงานประจำวัน (Today Tasks) แถบเมนูลัด สถิติผู้ใช้งาน
// แถบการนำทาง (Navigation Bar) และการแจ้งเตือนต่างๆ ในระบบ
import 'package:flutter/material.dart';
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/connectivity_provider.dart';
import '../services/friend_request_service.dart';
import '../services/sound_service.dart';
import '../widgets/adaptive_nav_bar.dart';
import '../utils/tutorial_service.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/create_task_modal.dart';
import '../widgets/fast_completion_warning_dialog.dart';
import '../widgets/late_penalty_dialog.dart';
import '../widgets/welcome_dialog.dart';
import '../utils/responsive.dart';
import '../utils/thai_display.dart';
import 'calendar_screen.dart';
import 'settings_screen.dart';
import 'task_detail_screen.dart';
import 'task_search_delegate.dart';
import '../widgets/group_project_card.dart';
import '../widgets/priority_tag.dart';
import '../utils/snack_bar_utils.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'bin_screen.dart';
import 'friends_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  void _showXPLimitDialog(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final theme = Theme.of(context);
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isTablet ? 28 : 24),
          ),
          elevation: 10,
          backgroundColor: theme.colorScheme.surface,
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 30.0 : 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: EdgeInsets.all(isTablet ? 18 : 16),
                  decoration: BoxDecoration(
                    color: AppColors.accentOrange.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.accentOrange,
                    size: isTablet ? 54 : 48,
                  ),
                ),
                SizedBox(height: isTablet ? 24 : 20),
                Text(
                  'Daily XP Cap Reached',
                  style: TextStyle(
                    fontSize: isTablet ? 22 : 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: isTablet ? 14 : 12),
                Text(
                  'ขณะนี้ท่านมีคะแนนที่ได้จากภารกิจกลุ่มต่อเนื่องถึง 270 แต้มแล้วการสร้างภารกิจหลังจากนี้ท่านจะไม่ได้รับแต้มอีก',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14.5,
                    height: 1.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                SizedBox(height: isTablet ? 28 : 24),
                SizedBox(
                  width: double.infinity,
                  height: isTablet ? 58 : 54,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.stormySkyBlue,
                      foregroundColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? AppColors.stormyNightBackground
                              : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isTablet ? 16 : 14),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'รับทราบ',
                      style: TextStyle(
                        fontSize: isTablet ? 20 : 18,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCreateTaskModal({TaskType? initialType}) {
    final connectivityProvider = Provider.of<ConnectivityProvider>(
      context,
      listen: false,
    );
    if (connectivityProvider.isOffline) {
      _showOfflineDialog(context);
      return;
    }

    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final type =
        initialType ??
        (_currentIndex == 0
            ? (taskProvider.activeSubTabIndex == 0
                  ? TaskType.personal
                  : TaskType.group)
            : TaskType.personal);
    final initialDate = _currentIndex == 1 ? taskProvider.selectedDate : null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          CreateTaskModal(initialType: type, initialDate: initialDate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);

    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? false;
    if (taskProvider.showXPCapAlert && isCurrentRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showXPLimitDialog(context);
        taskProvider.dismissXPCapAlert();
      });
    }

    final useRail = Responsive.useNavigationRail(context);
    final useDrawer = Responsive.useDrawer(context);

    return Scaffold(
      key: TutorialService.scaffoldKey,
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.stormyNightBackground
          : null,
      extendBody: false,
      body: Column(
        children: [
          Consumer<ConnectivityProvider>(
            builder: (context, connectivity, child) {
              if (!connectivity.isOffline) return const SizedBox.shrink();
              return Container(
                width: double.infinity,
                color: Colors.redAccent.withValues(alpha: 0.8),
                padding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 16,
                ),
                child: const Text(
                  'ไม่ได้เชื่อมต่ออินเทอร์เน็ต (Offline Mode)',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              );
            },
          ),
          Expanded(
            child: Row(
              children: [
                // Navigation Rail for Tablet/Desktop
                if (useRail)
                  AdaptiveNavBar(
                    currentIndex: _currentIndex,
                    onTap: (index) {
                      setState(() => _currentIndex = index);
                    },
                    onFabPressed: _currentIndex != 2
                        ? () => _showCreateTaskModal()
                        : null,
                  ),
                Expanded(
                  child: IndexedStack(
                    index: _currentIndex,
                    children: _buildScreens(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      // FAB for Mobile, Tablet, and Desktop (always shown at bottom right)
      floatingActionButton: (_currentIndex != 2)
          ? SizedBox(
              width: (Responsive.isTablet(context) ||
                      Responsive.isDesktop(context))
                  ? 76
                  : 64,
              height: (Responsive.isTablet(context) ||
                      Responsive.isDesktop(context))
                  ? 76
                  : 64,
              child: FloatingActionButton(
                key: TutorialService.fabKey,
                onPressed: () => _showCreateTaskModal(),
                backgroundColor: AppColors.stormySkyBlue,
                elevation: 4,
                shape: const CircleBorder(),
                child: Icon(
                  Icons.add,
                  size: (Responsive.isTablet(context) ||
                          Responsive.isDesktop(context))
                      ? 38
                      : 32,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? AppColors.stormyDarkSlate
                      : Colors.white,
                ),
              ),
            )
          : null,
      // Drawer for Mobile and Tablet
      drawer: useDrawer ? const CustomDrawer() : null,
      bottomNavigationBar: useRail
          ? null
          : AdaptiveNavBar(
              currentIndex: _currentIndex,
              onTap: (index) {
                setState(() => _currentIndex = index);
              },
              onFabPressed: _currentIndex != 2
                  ? () => _showCreateTaskModal()
                  : null,
            ),
    );
  }

  List<Widget> _buildScreens() {
    return [
      _TasksTab(onCreateTask: _showCreateTaskModal),
      const CalendarScreen(),
      const SettingsScreen(),
    ];
  }

  void _showOfflineDialog(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'ไม่มีการเชื่อมต่ออินเทอร์เน็ต',
          style: TextStyle(
            fontSize: isTablet ? 22 : 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'กรุณาเชื่อมต่ออินเทอร์เน็ตเพื่อดำเนินการนี้',
          style: TextStyle(fontSize: isTablet ? 16 : 14.5),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.stormySkyBlue,
              foregroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.stormyNightBackground
                  : Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 22 : 18,
                vertical: isTablet ? 12 : 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10.0),
              ),
            ),
            child: Text(
              'ตกลง',
              style: TextStyle(
                fontSize: isTablet ? 16 : 14.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TasksTab extends StatefulWidget {
  final Function({TaskType? initialType}) onCreateTask;
  const _TasksTab({required this.onCreateTask});

  @override
  State<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends State<_TasksTab>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        if (mounted) {
          context.read<TaskProvider>().setActiveSubTabIndex(
            _tabController.index,
          );
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _checkAndShowTutorial(),
    );
  }

  Future<void> _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final hasSeenTutorial = prefs.getBool('has_seen_tutorial') ?? false;

    if (!hasSeenTutorial && mounted) {
      final startTour = await showDialog<bool>(
        context: context,
        builder: (context) => const WelcomeDialog(),
      );

      if (!mounted) return;

      await prefs.setBool('has_seen_tutorial', true);

      if (startTour == true) {
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          TutorialService.showTutorial(context);
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'สวัสดียามเช้า,';
    if (hour >= 12 && hour < 17) return 'สวัสดีตอนบ่าย,';
    if (hour >= 17 && hour < 21) return 'สวัสดีตอนเย็น,';
    return 'ราตรีสวัสดิ์,';
  }

  String _getFirstName(String? fullName) {
    if (fullName == null || fullName.isEmpty) return 'User';
    return fullName.split(' ')[0];
  }

  Widget _buildHeader() {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final firstName = _getFirstName(user?.name);
    final greeting = _getGreeting();
    final formattedDate = DateFormat('dd/MM/yyyy').format(DateTime.now());
    final theme = Theme.of(context);
    final isTablet = Responsive.isTablet(context);

    return Padding(
      padding: EdgeInsets.all(
        isTablet ? 24.0 : AppConstants.paddingMedium,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Column (Text)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: greeting,
                        style: TextStyle(
                          fontSize: isTablet ? 17 : 14,
                          color: theme.brightness == Brightness.dark
                              ? Colors.white
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                        ),
                      ),
                      const TextSpan(text: ' '),
                      TextSpan(
                        text: firstName,
                        style: TextStyle(
                          fontSize: isTablet ? 17 : 14,
                          fontWeight: FontWeight.w500,
                          color: theme.brightness == Brightness.dark
                              ? Colors.white
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'วันนี้',
                  style: TextStyle(
                    fontSize: isTablet ? 34 : 28,
                    fontWeight: FontWeight.bold,
                    color: theme.brightness == Brightness.dark
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  formattedDate,
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    color: theme.brightness == Brightness.dark
                        ? Colors.white
                        : theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ),

          // Middle: Fire Streak (Centered between text and icons)
          Container(
            key: TutorialService.streakKey,
            child: Row(
              children: [
                Text('🔥', style: TextStyle(fontSize: isTablet ? 28 : 24)),
                const SizedBox(width: 4),
                Text(
                  '${user?.currentStreak ?? 0}',
                  style: TextStyle(
                    fontSize: isTablet ? 28 : 24,
                    fontWeight: FontWeight.bold,
                    color: theme.brightness == Brightness.light
                        ? theme.colorScheme.onSurface
                        : Colors.white,
                  ),
                ),
              ],
            ),
          ),

          // Right Row (Icons)
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Search Icon
                IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    Icons.search,
                    color: theme.brightness == Brightness.light
                        ? Colors.teal
                        : AppColors.stormySkyBlue,
                    size: isTablet ? 36 : 32,
                  ),
                  onPressed: () {
                    showSearch(
                      context: context,
                      delegate: TaskSearchDelegate(),
                    );
                  },
                ),
                SizedBox(width: isTablet ? 20 : 16),
                // Notification Icon
                _NotificationBellButton(
                  color: theme.brightness == Brightness.light
                      ? theme.colorScheme.onSurface
                      : Colors.white,
                  size: isTablet ? 36 : 32,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [_PersonalTasksList(), _GroupProjectsList()],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final theme = Theme.of(context);
    final isTablet = Responsive.isTablet(context);
    final isLandscape = Responsive.isLandscape(context);

    final tabBarWidget = Container(
      margin: EdgeInsets.symmetric(
        horizontal: isTablet ? 24.0 : AppConstants.paddingMedium,
      ),
      padding: EdgeInsets.all(isTablet ? 6 : 4),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light
            ? AppColors.stormyIceBlue
            : AppColors.stormyNightBackground,
        borderRadius: BorderRadius.circular(
          isTablet ? AppConstants.radiusLarge + 4 : AppConstants.radiusLarge,
        ),
        border: theme.brightness == Brightness.dark
            ? Border.all(color: AppColors.stormyDarkSlate, width: 2)
            : null,
      ),
      child: TabBar(
        key: TutorialService.switcherKey,
        controller: _tabController,
        dividerColor: Colors.transparent,
        dividerHeight: 0,
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed) ||
              states.contains(WidgetState.hovered) ||
              states.contains(WidgetState.focused)) {
            return AppColors.stormySkyBlue.withValues(alpha: 0.1);
          }
          return Colors.transparent;
        }),
        indicator: BoxDecoration(
          color: theme.brightness == Brightness.light
              ? AppColors.backgroundWhite
              : AppColors.stormyDarkSlate,
          borderRadius: BorderRadius.circular(
            isTablet ? AppConstants.radiusMedium + 2 : AppConstants.radiusMedium,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.brightness == Brightness.light
                  ? AppColors.shadowLight
                  : Colors.black.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        labelColor: theme.brightness == Brightness.light
            ? AppColors.stormySkyBlue
            : Colors.white,
        unselectedLabelColor: theme.brightness == Brightness.light
            ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
            : AppColors.stormyMutedBlueGrey,
        labelStyle: TextStyle(
          fontSize: isTablet ? 17 : 14,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: isTablet ? 17 : 14,
          fontWeight: FontWeight.w500,
        ),
        tabs: [
          Tab(
            height: isTablet ? 46 : null,
            text: 'ภารกิจส่วนตัว',
          ),
          Tab(
            height: isTablet ? 46 : null,
            text: 'ภารกิจกลุ่ม',
          ),
        ],
      ),
    );

    if (isLandscape && (isTablet || Responsive.isDesktop(context))) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: tabBarWidget,
        ),
      );
    }

    return tabBarWidget;
  }
}

// --- Notification Bottom Sheet Components ---

class _NotificationBellButton extends StatelessWidget {
  final Color color;
  final double size;
  final EdgeInsetsGeometry? padding;
  final BoxConstraints? constraints;

  const _NotificationBellButton({
    required this.color,
    this.size = 24,
    this.padding,
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    final userId = context.watch<AuthProvider>().currentUser?.id;
    final stream = userId == null || userId.isEmpty
        ? null
        : FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('notifications')
              .where('isRead', isEqualTo: false)
              .limit(20)
              .snapshots();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        final hasUnread =
            snapshot.hasData &&
            snapshot.data!.docs.any((doc) {
              final data = doc.data();
              return data['deletedAt'] == null && data['isRead'] == false;
            });

        return IconButton(
          padding: padding,
          constraints: constraints,
          icon: Stack(
            clipBehavior: Clip.none,
            children: [
              Icon(Icons.notifications_none_outlined, color: color, size: size),
              if (hasUnread)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: AppColors.error,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Theme.of(context).scaffoldBackgroundColor,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          onPressed: () => showNotificationBottomSheet(context),
        );
      },
    );
  }
}

class NotificationItem {
  final String id;
  final String sender;
  final String message;
  final String tag;
  final Color tagColor;
  final bool isUnread;
  final DateTime createdAt;
  final String? taskId;
  final String? actorId;
  final String? friendRequestId;
  final String? actorAvatarUrl;
  final String? actorName;
  final String? notificationKey;
  final List<String> duplicateDocIds;
  bool isRemoving;

  NotificationItem({
    required this.id,
    required this.sender,
    required this.message,
    required this.tag,
    required this.tagColor,
    DateTime? createdAt,
    this.taskId,
    this.actorId,
    this.friendRequestId,
    this.actorAvatarUrl,
    this.actorName,
    this.notificationKey,
    List<String>? duplicateDocIds,
    this.isUnread = false,
    this.isRemoving = false,
  })  : createdAt = createdAt ?? DateTime.now(),
        duplicateDocIds = duplicateDocIds ?? [];

  bool get showsAvatar {
    final normalizedTag = tag.toLowerCase();
    return normalizedTag == 'comment' ||
        normalizedTag == 'group' ||
        normalizedTag == 'submission' ||
        normalizedTag == 'approved' ||
        normalizedTag == 'rejected' ||
        normalizedTag == 'friendrequest' ||
        normalizedTag == 'friendaccepted';
  }

  bool get isFriendRequest => tag.toLowerCase() == 'friendrequest';

  factory NotificationItem.fromDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    Set<String> removingIds,
  ) {
    final data = doc.data();
    final createdAtValue = data['createdAt'];
    final createdAt = createdAtValue is Timestamp
        ? createdAtValue.toDate()
        : DateTime.now();
    final tag = (data['type'] ?? 'Update').toString();

    return NotificationItem(
      id: doc.id,
      sender: AppConstants.sanitizeThaiDisplay(
        (data['title'] ?? 'Task Reminder').toString(),
      ),
      message: AppConstants.sanitizeThaiDisplay(
        (data['body'] ?? '').toString(),
      ),
      tag: tag,
      tagColor: _notificationTagColor(tag),
      createdAt: createdAt,
      taskId: data['taskId']?.toString(),
      actorId: data['actorId']?.toString(),
      friendRequestId: data['friendRequestId']?.toString(),
      actorAvatarUrl: data['actorAvatarUrl']?.toString(),
      actorName: data['actorName']?.toString(),
      notificationKey: data['notificationKey']?.toString(),
      isUnread: data['isRead'] != true,
      isRemoving: removingIds.contains(doc.id),
    );
  }
}

Color _notificationTagColor(String tag) {
  switch (tag.toLowerCase()) {
    case 'approved':
      return const Color(0xFF00C896); // Emerald Green
    case 'rejected':
      return const Color(0xFFFF5252); // Coral Red
    case 'deadline':
      return const Color(0xFFFF6B00); // Vibrant Orange
    case 'follow-up':
      return const Color(0xFF6366F1); // Indigo / Deep Violet (#6366F1)
    case 'group':
      return AppColors.stormyDeepBlue; // Royal Blue / Indigo (#3877EE)
    case 'submission':
      return const Color(0xFF06B6D4); // Cyan / Teal
    case 'friendrequest':
      return const Color(0xFF8B5CF6); // Purple / Violet
    case 'friendaccepted':
      return const Color(0xFF10B981); // Mint Green
    case 'reminder':
      return AppColors.stormySkyBlue; // Sky Blue (#88BDF2)
    case 'message':
    case 'comment':
      return const Color(0xFFEC4899); // Vibrant Pink / Rose (#EC4899)
    case 'update':
    default:
      return AppColors.stormySkyBlue;
  }
}

void showNotificationBottomSheet(BuildContext context, {bool isEmpty = false}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    // ส่วนสำคัญ: อนุญาตให้ปิดได้เมื่อกดพื้นที่ว่าง (Barrier)
    isDismissible: true,
    backgroundColor: Colors.transparent,
    builder: (context) => NotificationPanel(isEmpty: isEmpty),
  );
}

class NotificationPanel extends StatefulWidget {
  final bool isEmpty;

  const NotificationPanel({super.key, this.isEmpty = false});

  @override
  State<NotificationPanel> createState() => _NotificationPanelState();
}

class _NotificationPanelState extends State<NotificationPanel> {
  bool _isClearingAll = false;
  bool _showClearAllUndoBanner = false;
  Timer? _clearAllTimer;
  final FriendRequestService _friendRequestService = FriendRequestService();
  List<NotificationItem> _clearAllBackup = const [];
  final Set<String> _clearAllAnimatingIds = {};
  final List<Timer> _clearAllAnimationTimers = [];
  final Set<String> _removingNotificationIds = {};
  final Set<String> _friendActionNotificationIds = {};
  final Map<String, Timer> _removeTimers = {};

  String? _cachedUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAllUnreadAsRead();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId != null && userId.isNotEmpty) {
      _cachedUserId = userId;
      _markAllUnreadAsRead();
    }
  }

  Future<void> _markAllUnreadAsRead() async {
    final userId = _cachedUserId ?? context.read<AuthProvider>().currentUser?.id;
    if (userId == null || userId.isEmpty) return;

    try {
      final unreadSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('notifications')
          .where('isRead', isEqualTo: false)
          .get();

      if (unreadSnap.docs.isNotEmpty) {
        final batch = FirebaseFirestore.instance.batch();
        for (final doc in unreadSnap.docs) {
          batch.set(doc.reference, {
            'isRead': true,
            'readAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
        await batch.commit();
      }
    } catch (e) {
      debugPrint('Error marking all notifications read: $e');
    }
  }

  CollectionReference<Map<String, dynamic>>? _notificationsRef() {
    if (_cachedUserId == null || _cachedUserId!.isEmpty) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(_cachedUserId)
        .collection('notifications');
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>? _notificationsStream() {
    return _notificationsRef()
        ?.orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots();
  }

  @override
  void dispose() {
    if (_removingNotificationIds.isNotEmpty && _cachedUserId != null) {
      final ref = FirebaseFirestore.instance
          .collection('users')
          .doc(_cachedUserId)
          .collection('notifications');

      final batch = FirebaseFirestore.instance.batch();
      final deletedAt = FieldValue.serverTimestamp();
      final expireAt = Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 7)),
      );
      for (final id in _removingNotificationIds) {
        batch.set(ref.doc(id), {
          'isRead': true,
          'deletedAt': deletedAt,
          'expireAt': expireAt,
        }, SetOptions(merge: true));
      }
      // Fire and forget
      batch.commit().catchError(
        (e) => debugPrint('Dispose batch delete failed: $e'),
      );
    }

    for (final timer in _removeTimers.values) {
      timer.cancel();
    }
    for (final timer in _clearAllAnimationTimers) {
      timer.cancel();
    }
    _clearAllTimer?.cancel();
    super.dispose();
  }

  Future<void> _confirmClearAll(List<NotificationItem> notifications) async {
    final connectivity = context.read<ConnectivityProvider>();
    if (connectivity.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่มีการเชื่อมต่ออินเทอร์เน็ต ไม่สามารถดำเนินการได้'),
        ),
      );
      return;
    }
    if (_isClearingAll || notifications.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final isDark = theme.brightness == Brightness.dark;
        final isTablet = MediaQuery.of(dialogContext).size.width >= 600;
        return AlertDialog(
          backgroundColor: isDark ? AppColors.stormyDarkSlate : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(
            'ลบการแจ้งเตือนทั้งหมด?',
            style: TextStyle(
              color: AppColors.error,
              fontWeight: FontWeight.w800,
              fontSize: isTablet ? 22 : 18,
            ),
          ),
          content: Text(
            'คุณต้องการลบการแจ้งเตือนทั้งหมดไหม',
            style: TextStyle(
              fontSize: isTablet ? 16 : 14.5,
              color: isDark
                  ? AppColors.stormyIceBlue
                  : theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          actionsPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 20 : 16,
            vertical: isTablet ? 16 : 12,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 18 : 14,
                  vertical: isTablet ? 12 : 10,
                ),
                foregroundColor: isDark
                    ? AppColors.stormySkyBlue
                    : AppColors.stormyMutedBlueGrey,
              ),
              child: Text(
                'ยกเลิก',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isTablet ? 12 : 10,
                ),
                foregroundColor: AppColors.error,
                backgroundColor: AppColors.error.withValues(alpha: 0.15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'ลบทั้งหมด',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;
    await _clearAll(notifications);
  }

  Future<void> _clearAll(List<NotificationItem> notifications) async {
    if (_isClearingAll || notifications.isEmpty) return;

    final itemsToClear = List<NotificationItem>.from(notifications);
    _clearAllTimer?.cancel();
    for (final timer in _clearAllAnimationTimers) {
      timer.cancel();
    }
    _clearAllAnimationTimers.clear();

    setState(() {
      _clearAllBackup = itemsToClear;
      _isClearingAll = true;
      _showClearAllUndoBanner = false;
      _clearAllAnimatingIds.clear();
    });

    const stagger = Duration(milliseconds: 85);
    const slideDuration = Duration(milliseconds: 360);
    for (var i = 0; i < itemsToClear.length; i++) {
      final item = itemsToClear[i];
      _clearAllAnimationTimers.add(
        Timer(stagger * i, () {
          if (!mounted) return;
          setState(() {
            _clearAllAnimatingIds.add(item.id);
          });
        }),
      );
    }

    final totalAnimationDuration =
        stagger * (itemsToClear.length - 1) + slideDuration;
    await Future<void>.delayed(totalAnimationDuration);
    if (!mounted || !_isClearingAll) return;

    await _softDeleteNotifications(itemsToClear);
    if (!mounted || !_isClearingAll) return;

    setState(() {
      _clearAllAnimatingIds.clear();
      _showClearAllUndoBanner = true;
    });

    _clearAllTimer = Timer(const Duration(seconds: 5), () {
      if (!mounted) return;
      setState(() {
        _isClearingAll = false;
        _showClearAllUndoBanner = false;
        _clearAllBackup = const [];
      });
    });
  }

  Future<void> _softDeleteNotifications(List<NotificationItem> items) async {
    final ref = _notificationsRef();
    if (ref == null || items.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    final deletedAt = FieldValue.serverTimestamp();
    final expireAt = Timestamp.fromDate(
      DateTime.now().add(const Duration(days: 7)),
    );
    for (final item in items.take(500)) {
      final allIds = [item.id, ...item.duplicateDocIds];
      for (final docId in allIds) {
        batch.set(ref.doc(docId), {
          'isRead': true,
          'deletedAt': deletedAt,
          'expireAt': expireAt,
        }, SetOptions(merge: true));
      }
    }

    try {
      await batch.commit();
      await _markAllUnreadAsRead();
    } catch (error) {
      debugPrint('Failed to clear notifications: $error');
    }
  }

  Future<void> _markVisibleNotificationsRead(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) async {
    final unreadDocs = docs.where((doc) {
      final data = doc.data();
      return data['isRead'] != true && !_removingNotificationIds.contains(doc.id);
    }).take(50).toList();
    final ref = _notificationsRef();
    if (ref == null || unreadDocs.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in unreadDocs) {
      batch.set(doc.reference, {
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }

    try {
      await batch.commit();
    } catch (error) {
      debugPrint('Failed to mark notifications read: $error');
    }
  }

  void _scheduleMarkRead(List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) {
    if (docs.any((doc) => doc.data()['isRead'] != true && !_removingNotificationIds.contains(doc.id))) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _markVisibleNotificationsRead(docs);
        }
      });
    }
  }

  List<NotificationItem> _itemsFromSnapshot(
    QuerySnapshot<Map<String, dynamic>> snapshot,
  ) {
    final items = snapshot.docs
        .where((doc) => doc.data()['deletedAt'] == null)
        .map(
          (doc) => NotificationItem.fromDocument(doc, _removingNotificationIds),
        )
        .toList();
    items.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    final deduped = <NotificationItem>[];
    for (final item in items) {
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

    return deduped;
  }

  void _undoClearAll() {
    _clearAllTimer?.cancel();
    for (final timer in _clearAllAnimationTimers) {
      timer.cancel();
    }
    _clearAllAnimationTimers.clear();
    final itemsToRestore = List<NotificationItem>.from(_clearAllBackup);
    setState(() {
      _isClearingAll = false;
      _showClearAllUndoBanner = false;
      _clearAllAnimatingIds.clear();
      _clearAllBackup = const [];
    });
    _restoreClearedNotifications(itemsToRestore);
  }

  Future<void> _restoreClearedNotifications(
    List<NotificationItem> items,
  ) async {
    final ref = _notificationsRef();
    if (ref == null || items.isEmpty) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final item in items.take(500)) {
      batch.set(ref.doc(item.id), {
        'deletedAt': FieldValue.delete(),
      }, SetOptions(merge: true));
    }

    try {
      await batch.commit();
    } catch (error) {
      debugPrint('Failed to undo clear notifications: $error');
    }
  }

  void _removeItem(NotificationItem item) {
    final connectivity = context.read<ConnectivityProvider>();
    if (connectivity.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่มีการเชื่อมต่ออินเทอร์เน็ต ไม่สามารถดำเนินการได้'),
        ),
      );
      return;
    }
    final allIds = [item.id, ...item.duplicateDocIds];
    if (_removingNotificationIds.contains(item.id)) return;

    setState(() {
      _removingNotificationIds.addAll(allIds);
    });

    _removeTimers[item.id] = Timer(const Duration(seconds: 5), () async {
      final ref = _notificationsRef();
      if (ref != null) {
        try {
          final batch = FirebaseFirestore.instance.batch();
          final deletedAt = FieldValue.serverTimestamp();
          final expireAt = Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 7)),
          );
          for (final docId in allIds) {
            batch.set(ref.doc(docId), {
              'isRead': true,
              'deletedAt': deletedAt,
              'expireAt': expireAt,
            }, SetOptions(merge: true));
          }
          await batch.commit();
        } catch (error) {
          debugPrint('Failed to remove notification ${item.id}: $error');
        }
      }
      if (!mounted) return;
      setState(() {
        _removingNotificationIds.removeAll(allIds);
        _removeTimers.remove(item.id);
      });
    });
  }

  void _undoRemoveItem(NotificationItem item) {
    _removeTimers.remove(item.id)?.cancel();
    final allIds = [item.id, ...item.duplicateDocIds];
    setState(() {
      _removingNotificationIds.removeAll(allIds);
    });
  }

  Future<void> _markNotificationRead(NotificationItem item) async {
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    if (currentUserId == null) return;

    final allIds = [item.id, ...item.duplicateDocIds];
    final batch = FirebaseFirestore.instance.batch();
    for (final docId in allIds) {
      batch.set(
        FirebaseFirestore.instance
            .collection('users')
            .doc(currentUserId)
            .collection('notifications')
            .doc(docId),
        {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
          'deletedAt': FieldValue.serverTimestamp(),
          'expireAt': Timestamp.fromDate(
            DateTime.now().add(const Duration(days: 7)),
          ),
        },
        SetOptions(merge: true),
      );
    }
    try {
      await batch.commit();
    } catch (e) {
      debugPrint('Failed to mark notification read: $e');
    }
  }

  Future<void> _acceptFriendRequestNotification(NotificationItem item) async {
    final currentUser = context.read<AuthProvider>().currentUser;
    final requesterId = item.actorId;
    final requestId = item.friendRequestId;
    if (currentUser == null || requesterId == null || requestId == null) return;

    setState(() {
      _friendActionNotificationIds.add(item.id);
    });

    try {
      await _friendRequestService.acceptFriendRequest(
        requestId: requestId,
        requesterId: requesterId,
        currentUser: currentUser,
        requesterName: item.actorName ?? item.sender,
        requesterAvatarUrl: item.actorAvatarUrl,
      );
      await _markNotificationRead(item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ยอมรับคำขอเป็นเพื่อนแล้ว'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ยอมรับคำขอเป็นเพื่อนไม่สำเร็จ'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _friendActionNotificationIds.remove(item.id);
        });
      }
    }
  }

  Future<void> _declineFriendRequestNotification(NotificationItem item) async {
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    final requestId = item.friendRequestId;
    if (currentUserId == null || requestId == null) return;

    setState(() {
      _friendActionNotificationIds.add(item.id);
    });

    try {
      await _friendRequestService.declineFriendRequest(
        requestId: requestId,
        recipientId: currentUserId,
      );
      await _markNotificationRead(item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ปฏิเสธคำขอเป็นเพื่อนแล้ว'),
          backgroundColor: (Theme.of(context).brightness == Brightness.light
              ? AppColors.stormyMutedBlueGrey
              : AppColors.textSecondary),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ปฏิเสธคำขอเป็นเพื่อนไม่สำเร็จ'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _friendActionNotificationIds.remove(item.id);
        });
      }
    }
  }

  Future<void> _openNotificationTask(NotificationItem item) async {
    _markNotificationRead(item);
    final taskId = item.taskId;
    if (taskId == null || taskId.isEmpty) return;

    final taskProvider = context.read<TaskProvider>();
    Task? task;
    try {
      task = taskProvider.tasks.firstWhere((task) => task.id == taskId);
    } catch (_) {
      try {
        final snap = await FirebaseFirestore.instance
            .collection('tasks')
            .doc(taskId)
            .get();
        final data = snap.data();
        if (snap.exists && data != null) {
          task = Task.fromMap(data, snap.id);
        }
      } catch (error) {
        debugPrint('Failed to open notification task $taskId: $error');
      }
    }

    if (!mounted || task == null) return;
    taskProvider.selectTask(task);
    final isComment = item.tag.toLowerCase() == 'comment';
    Navigator.pop(context);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => TaskDetailScreen(
          task: task,
          scrollToComments: isComment,
        ),
      ),
    );
  }

  String _formatRelativeTime(DateTime createdAt) {
    return thaiRelativePast(createdAt);
  }

  Widget _buildLoadingState(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: CircularProgressIndicator(color: AppColors.stormySkyBlue),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Text(
        'Unable to load notifications right now.',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final stream = _notificationsStream();

    return Container(
      margin: const EdgeInsets.only(top: 80), // Ensure top barrier is reachable
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.stormyNightBackground
            : theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
              alpha: theme.brightness == Brightness.light ? 0.08 : 0.4,
            ),
            blurRadius: 15,
            spreadRadius: 5,
          ),
        ],
      ),
      child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: stream,
        builder: (context, snapshot) {
          final notifications = snapshot.hasData
              ? _itemsFromSnapshot(snapshot.data!)
              : <NotificationItem>[];
          if (snapshot.hasData) {
            _scheduleMarkRead(snapshot.data!.docs);
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Center(
                        child: Container(
                          margin: const EdgeInsets.only(top: 12),
                          width: isTablet ? 56 : 40,
                          height: isTablet ? 5 : 4,
                          decoration: BoxDecoration(
                            color: theme.brightness == Brightness.light
                                ? (Theme.of(context).brightness ==
                                          Brightness.light
                                      ? AppColors.stormyMutedBlueGrey
                                      : AppColors.backgroundDarkGrey)
                                : Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'การแจ้งเตือน',
                              style: TextStyle(
                                fontSize: isTablet ? 26 : 22,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.onSurface,
                              ),
                            ),
                            if (notifications.isNotEmpty && !_isClearingAll)
                              Padding(
                                padding: EdgeInsets.only(right: isTablet ? 40 : 32),
                                child: TextButton(
                                  onPressed: () =>
                                      _confirmClearAll(notifications),
                                  child: Text(
                                    'ลบทั้งหมด',
                                    style: TextStyle(
                                      color: AppColors.stormySkyBlue,
                                      fontSize: isTablet ? 17 : 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Center(
                          child: Text(
                            'ข้อความแจ้งเตือนจะถูกลบถาวรโดยอัตโนมัติหลังจาก 30 วัน',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: isTablet ? 14 : 12.5,
                              color: theme.brightness == Brightness.dark
                                  ? AppColors.stormyMutedBlueGrey
                                  : AppColors.textSecondary.withValues(alpha: 0.75),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                  Positioned(
                    top: isTablet ? 18 : 15,
                    right: isTablet ? 18 : 15,
                    child: IconButton(
                      icon: Icon(
                        Icons.close,
                        size: isTablet ? 26 : 22,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ],
              ),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (stream == null || widget.isEmpty)
                        _buildEmptyStateView(context)
                      else if (snapshot.hasError)
                        _buildErrorState(context)
                      else if (!snapshot.hasData)
                        _buildLoadingState(context)
                      else if (notifications.isEmpty && !_isClearingAll)
                        _buildEmptyStateView(context)
                      else
                        _buildPopulatedStateView(notifications),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildEmptyStateView(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 30 : 25),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.dark
                  ? AppColors.stormyDarkSlate
                  : AppColors.stormyIceBlue.withValues(alpha: 0.7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_none_outlined,
              size: isTablet ? 96 : 80,
              color: AppColors.stormySkyBlue,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            "คุณตามทันทุกการแจ้งเตือนแล้ว",
            style: TextStyle(
              fontSize: isTablet ? 24 : 20,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "ไม่มีการแจ้งเตือนใหม่ในขณะนี้",
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const SizedBox(height: 40),
          SizedBox(
            width: isTablet ? 160 : 140,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.stormySkyBlue,
                foregroundColor: theme.brightness == Brightness.dark
                    ? AppColors.stormyNightBackground
                    : Colors.white,
                elevation: 0,
                padding: EdgeInsets.symmetric(vertical: isTablet ? 18 : 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: Text(
                'ตกลง',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isTablet ? 18 : 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPopulatedStateView(List<NotificationItem> items) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      itemCount: items.length + (_showClearAllUndoBanner ? 1 : 0),
      itemBuilder: (context, index) {
        if (_showClearAllUndoBanner && index == 0) {
          return _buildClearAllUndoBanner();
        }

        final actualIndex = _showClearAllUndoBanner ? index - 1 : index;
        final item = items[actualIndex];

        if (item.isRemoving) {
          return _buildUndoPlaceholderCard(item);
        }

        final isClearingThisItem = _clearAllAnimatingIds.contains(item.id);
        return AnimatedSlide(
          duration: const Duration(milliseconds: 360),
          curve: Curves.easeInOutCubic,
          offset: isClearingThisItem ? const Offset(1.18, 0) : Offset.zero,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOutCubic,
            opacity: isClearingThisItem ? 0 : 1,
            child: Dismissible(
              key: ObjectKey(item),
              direction: _isClearingAll
                  ? DismissDirection.none
                  : DismissDirection.endToStart,
              background: Container(
                margin: const EdgeInsets.only(bottom: 16),
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: const Icon(Icons.delete_outline, color: Colors.white),
              ),
              onDismissed: (direction) {
                _removeItem(item);
              },
              child: _buildNotificationCard(item),
            ),
          ),
        );
      },
    );
  }

  Widget _buildClearAllUndoBanner() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : 20,
        vertical: isTablet ? 14 : 12,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : (Theme.of(context).brightness == Brightness.light
                      ? AppColors.stormyIceBlue
                      : AppColors.backgroundDarkGrey)
                  .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'ลบการแจ้งเตือนทั้งหมดแล้ว',
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              color: isDark
                  ? Colors.white
                  : (Theme.of(context).brightness == Brightness.light
                        ? AppColors.stormyDarkSlate
                        : AppColors.textPrimary),
              fontWeight: FontWeight.w500,
            ),
          ),
          TextButton(
            onPressed: _undoClearAll,
            child: Text(
              'เลิกทำ',
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: isDark
                    ? AppColors.stormySkyBlue
                    : AppColors.stormyDarkSlate,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUndoPlaceholderCard(NotificationItem item) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Container(
      height: isTablet ? 100 : 90, // Roughly the same height as a normal card
      margin: const EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.symmetric(horizontal: isTablet ? 24 : 20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : (Theme.of(context).brightness == Brightness.light
                      ? AppColors.stormyIceBlue
                      : AppColors.backgroundGrey)
                  .withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'ลบการแจ้งเตือนแล้ว',
            style: TextStyle(
              fontSize: isTablet ? 16 : 14,
              color: isDark
                  ? Colors.white70
                  : (Theme.of(context).brightness == Brightness.light
                        ? AppColors.stormyMutedBlueGrey
                        : AppColors.textSecondary),
              fontWeight: isDark ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          TextButton(
            onPressed: () => _undoRemoveItem(item),
            child: Text(
              'เลิกทำ',
              style: TextStyle(
                fontSize: isTablet ? 16 : 14,
                color: isDark
                    ? AppColors.stormySkyBlue
                    : AppColors.stormyDarkSlate,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationCard(NotificationItem item) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final avatarUrl = item.actorAvatarUrl ?? '';
    final avatarName = (item.actorName?.isNotEmpty ?? false)
        ? item.actorName!
        : item.sender;

    return InkWell(
      enableFeedback: false,
      borderRadius: BorderRadius.circular(30),
      onTap: () {
        if (item.tag.toLowerCase() == 'friendaccepted') {
          Navigator.pop(context);
          Navigator.of(context).push(
            MaterialPageRoute(builder: (context) => const FriendsScreen()),
          );
        } else if (item.taskId != null) {
          _openNotificationTask(item);
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: EdgeInsets.all(isTablet ? 20 : 16),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? AppColors.stormyDarkSlate
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: theme.brightness == Brightness.light ? 0.04 : 0.4,
              ),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
          border: theme.brightness == Brightness.dark
              ? Border.all(color: Colors.white.withValues(alpha: 0.1))
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (item.showsAvatar) ...[
              Container(
                width: isTablet ? 54 : 50,
                height: isTablet ? 54 : 50,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.stormySkyBlue.withValues(alpha: 0.12),
                ),
                child: ClipOval(
                  child: avatarUrl.isNotEmpty
                      ? Image.network(
                          avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Center(
                              child: Text(
                                avatarName.isEmpty ? '?' : avatarName[0],
                                style: TextStyle(
                                  color: AppColors.stormySkyBlue,
                                  fontSize: isTablet ? 20 : 16,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            );
                          },
                        )
                      : Center(
                          child: Text(
                            avatarName.isEmpty ? '?' : avatarName[0],
                            style: TextStyle(
                              color: AppColors.stormySkyBlue,
                              fontSize: isTablet ? 20 : 16,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                ),
              ),
              SizedBox(width: isTablet ? 16 : 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.sender,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: isTablet ? 18 : 16,
                            color: theme.colorScheme.onSurface,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item.isUnread) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: isTablet ? 10 : 8,
                          height: isTablet ? 10 : 8,
                          decoration: const BoxDecoration(
                            color: AppColors.stormySkyBlue,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.message,
                    style: TextStyle(
                      fontSize: isTablet ? 15 : 13.5,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (item.isFriendRequest) ...[
                    const SizedBox(height: 12),
                    if (_friendActionNotificationIds.contains(item.id))
                      const SizedBox(
                        height: 34,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.stormySkyBlue,
                            ),
                          ),
                        ),
                      )
                    else
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () =>
                                  _acceptFriendRequestNotification(item),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.stormySkyBlue,
                                foregroundColor:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppColors.stormyNightBackground
                                        : Colors.white,
                                elevation: 0,
                                padding: EdgeInsets.symmetric(
                                  vertical: isTablet ? 10 : 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'ยอมรับ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: isTablet ? 15 : 13,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () =>
                                  _declineFriendRequestNotification(item),
                              style: OutlinedButton.styleFrom(
                                foregroundColor:
                                    (Theme.of(context).brightness ==
                                        Brightness.light
                                    ? AppColors.stormyMutedBlueGrey
                                    : AppColors.textSecondary),
                                side: BorderSide(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.14,
                                  ),
                                ),
                                padding: EdgeInsets.symmetric(
                                  vertical: isTablet ? 10 : 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(
                                'ปฏิเสธ',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: isTablet ? 15 : 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  _formatRelativeTime(item.createdAt),
                  style: TextStyle(
                    fontSize: isTablet ? 13 : 11.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 10 : 8,
                    vertical: isTablet ? 5 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: item.tagColor.withValues(
                      alpha: theme.brightness == Brightness.dark ? 0.20 : 0.12,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    thaiNotificationTag(item.tag),
                    style: TextStyle(
                      color: item.tagColor,
                      fontSize: isTablet ? 13 : 11.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (item.taskId != null) ...[
                  const SizedBox(height: 10),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: isTablet ? 22 : 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonalTasksList extends StatefulWidget {
  const _PersonalTasksList();

  @override
  State<_PersonalTasksList> createState() => _PersonalTasksListState();
}

class _PersonalTasksListState extends State<_PersonalTasksList> {
  static const _completionExitDuration = Duration(milliseconds: 560);

  final Map<String, Task> _exitingTasks = {};
  final Map<String, int> _exitingTaskIndexes = {};
  final Set<String> _exitingOverdueTaskIds = {};
  final Map<String, Timer> _exitTimers = {};

  @override
  void dispose() {
    for (final timer in _exitTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  Future<void> _handleToggleComplete(
    Task task, {
    required bool isOverdue,
    Future<CompletionRewardResult?>? pendingResult,
  }) async {
    final connectivity = context.read<ConnectivityProvider>();
    if (connectivity.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่มีการเชื่อมต่ออินเทอร์เน็ต ไม่สามารถดำเนินการได้'),
        ),
      );
      return;
    }
    final taskProvider = context.read<TaskProvider>();
    final nextState = !task.isCompleted;

    final latestTask = taskProvider.tasks.firstWhere(
      (t) => t.id == task.id,
      orElse: () => task,
    );

    if (nextState) {
      if (pendingResult == null &&
          latestTask.subtasks.isNotEmpty &&
          latestTask.subtasks.any((s) => !s.isDone)) {
        final isTablet = MediaQuery.of(context).size.width >= 600;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(
              'ไม่สามารถเสร็จสิ้นภารกิจได้',
              style: TextStyle(
                fontSize: isTablet ? 22 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'กรุณาทำภารกิจย่อยทั้งหมดให้เสร็จสิ้นก่อนทำการปิดภารกิจหลัก',
              style: TextStyle(fontSize: isTablet ? 16 : 14.5),
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18.0),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.stormySkyBlue,
                  foregroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? AppColors.stormyNightBackground
                      : Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 22 : 18,
                    vertical: isTablet ? 12 : 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                child: Text(
                  'ตกลง',
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
        return;
      }

      final shouldProceed = await LatePenaltyDialog.checkAndShow(context, task);
      if (!shouldProceed) return;
      if (!context.mounted) return;

      _stageTaskExit(task, isOverdue: isOverdue);
      _playTaskCompleteSound();

      CompletionRewardResult result;
      if (pendingResult != null) {
        final res = await pendingResult;
        if (res == null || res.status == CompletionRewardStatus.noChange) {
          _cancelTaskExit(task.id);
          return;
        }
        result = res;
      } else {
        result = await taskProvider.completeTaskWithSubtasks(task.id, true);
      }
      if (!mounted) return;
      await FastCompletionWarningDialog.showCompletionFeedback(context, result);

      if (!mounted) return;
      SnackBarUtils.showUndoSnackBar(
        context,
        message: 'ทำเครื่องหมายเสร็จสิ้นแล้ว',
        onUndo: () async {
          await taskProvider.toggleTaskCompletion(
            task.id,
            updateSubtasks: true,
          );
        },
      );
    } else {
      _cancelTaskExit(task.id);
      await taskProvider.toggleTaskCompletion(task.id, updateSubtasks: true);
    }
  }

  void _playTaskCompleteSound() {
    final isSoundEnabled =
        context.read<AuthProvider>().currentUser?.isSoundEnabled ?? true;
    unawaited(
      SoundService.instance.playTaskCompleteSound(
        isSoundEnabled: isSoundEnabled,
      ),
    );
  }

  void _stageTaskExit(Task task, {required bool isOverdue}) {
    if (_exitingTasks.containsKey(task.id)) return;

    final pendingTasks = _sortedPendingTasks(
      isOverdue
          ? context.read<TaskProvider>().overduePersonalTasks
          : context.read<TaskProvider>().todayPersonalTasks,
    );
    final visualIndex = pendingTasks.indexWhere((item) => item.id == task.id);
    final completedSubtasks = task.subtasks
        .map((subtask) => subtask.copyWith(isDone: true))
        .toList();

    setState(() {
      _exitingTasks[task.id] = task.copyWith(
        status: TaskStatus.completed,
        completedAt: DateTime.now(),
        subtasks: completedSubtasks,
      );
      _exitingTaskIndexes[task.id] = visualIndex < 0 ? 0 : visualIndex;
      if (isOverdue) {
        _exitingOverdueTaskIds.add(task.id);
      } else {
        _exitingOverdueTaskIds.remove(task.id);
      }
    });

    _exitTimers[task.id]?.cancel();
    _exitTimers[task.id] = Timer(_completionExitDuration, () {
      if (!mounted) return;
      setState(() {
        _exitingTasks.remove(task.id);
        _exitingTaskIndexes.remove(task.id);
        _exitingOverdueTaskIds.remove(task.id);
        _exitTimers.remove(task.id);
      });
    });
  }

  void _cancelTaskExit(String taskId) {
    final timer = _exitTimers.remove(taskId);
    timer?.cancel();
    if (!_exitingTasks.containsKey(taskId)) return;

    setState(() {
      _exitingTasks.remove(taskId);
      _exitingTaskIndexes.remove(taskId);
      _exitingOverdueTaskIds.remove(taskId);
    });
  }

  List<Task> _sortedPendingTasks(List<Task> tasks) {
    return tasks.where((task) => !task.isCompleted).toList()..sort((a, b) {
      final priorityComparison = b.priority.index.compareTo(a.priority.index);
      if (priorityComparison != 0) return priorityComparison;
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  List<_TodayTaskListEntry> _buildTaskEntries(
    List<Task> pendingTasks, {
    required bool isOverdue,
  }) {
    final entries = pendingTasks
        .where((task) => !_exitingTasks.containsKey(task.id))
        .map(
          (task) => _TodayTaskListEntry(
            task: task,
            isExiting: false,
            isOverdue: isOverdue,
          ),
        )
        .toList();
    final exitingEntries =
        _exitingTasks.values
            .where(
              (task) => _exitingOverdueTaskIds.contains(task.id) == isOverdue,
            )
            .toList()
          ..sort((a, b) {
            final aIndex = _exitingTaskIndexes[a.id] ?? 0;
            final bIndex = _exitingTaskIndexes[b.id] ?? 0;
            return aIndex.compareTo(bIndex);
          });

    for (final task in exitingEntries) {
      final insertIndex = (_exitingTaskIndexes[task.id] ?? entries.length)
          .clamp(0, entries.length)
          .toInt();
      entries.insert(
        insertIndex,
        _TodayTaskListEntry(task: task, isExiting: true, isOverdue: isOverdue),
      );
    }

    return entries;
  }

  Widget _buildTaskItemWidget(
    _TodayTaskListEntry entry, {
    double bottomSpacing = AppConstants.paddingMedium,
  }) {
    return _CompletingTaskListItem(
      key: ValueKey(
        'personal-${entry.task.id}-${entry.isExiting}-${entry.isOverdue}',
      ),
      isExiting: entry.isExiting,
      bottomSpacing: bottomSpacing,
      child: _TodayTaskCard(
        task: entry.task,
        onToggleComplete: (task, {pendingResult}) => _handleToggleComplete(
          task,
          isOverdue: entry.isOverdue,
          pendingResult: pendingResult,
        ),
        isCompleted: entry.task.isCompleted,
        isOverdue: entry.isOverdue,
      ),
    );
  }

  List<Widget> _buildDashboardItems({
    required List<_TodayTaskListEntry> todayEntries,
    required List<_TodayTaskListEntry> overdueEntries,
  }) {
    final hasTodayTasks = todayEntries.isNotEmpty;
    final items = <Widget>[];

    void addTaskEntry(_TodayTaskListEntry entry, bool isLast) {
      items.add(
        _buildTaskItemWidget(
          entry,
          bottomSpacing: isLast ? 0 : AppConstants.paddingMedium,
        ),
      );
    }

    for (var i = 0; i < todayEntries.length; i++) {
      final isLast = i == todayEntries.length - 1 && overdueEntries.isEmpty;
      addTaskEntry(todayEntries[i], isLast);
    }

    if (hasTodayTasks && overdueEntries.isNotEmpty) {
      items.add(const Divider(height: 30, thickness: 1));
      items.add(const _OverdueSectionHeader());
      items.add(const SizedBox(height: AppConstants.paddingMedium));
    }

    for (var i = 0; i < overdueEntries.length; i++) {
      addTaskEntry(overdueEntries[i], i == overdueEntries.length - 1);
    }

    return items;
  }

  Widget _buildLandscapeLayout({
    required BuildContext context,
    required List<_TodayTaskListEntry> todayEntries,
    required List<_TodayTaskListEntry> overdueEntries,
    required ThemeData theme,
  }) {
    final hasToday = todayEntries.isNotEmpty;
    final hasOverdue = overdueEntries.isNotEmpty;

    if (!hasToday && !hasOverdue) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text(
            'สิ่งที่ต้องทำวันนี้',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 24,
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          const SizedBox(
            height: 300,
            child: _TodayEmptyState(),
          ),
        ],
      );
    }

    // กรณีมีทั้งงานวันนี้และงานค้าง -> แบ่งซ้ายขวา 50:50
    if (hasToday && hasOverdue) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ฝั่งซ้าย: สิ่งที่ต้องทำวันนี้
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'สิ่งที่ต้องทำวันนี้',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 22,
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.stormySkyBlue.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${todayEntries.length}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.stormySkyBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                Expanded(
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(
                      bottom: AppConstants.paddingXLarge,
                    ),
                    itemCount: todayEntries.length,
                    itemBuilder: (context, index) => _buildTaskItemWidget(
                      todayEntries[index],
                      bottomSpacing: index == todayEntries.length - 1
                          ? 0
                          : AppConstants.paddingMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // ฝั่งขวา: ภารกิจที่ยังไม่เสร็จ
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'ภารกิจที่ยังไม่เสร็จ',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 22,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${overdueEntries.length}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                Expanded(
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(
                      bottom: AppConstants.paddingXLarge,
                    ),
                    itemCount: overdueEntries.length,
                    itemBuilder: (context, index) => _buildTaskItemWidget(
                      overdueEntries[index],
                      bottomSpacing: index == overdueEntries.length - 1
                          ? 0
                          : AppConstants.paddingMedium,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // กรณีมีแต่งานวันนี้ (ไม่มีงานค้าง) -> แสดงการ์ดงานวันนี้เป็น 2 คอลัมน์คู่
    if (hasToday) {
      final rowCount = (todayEntries.length / 2).ceil();
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          bottom: AppConstants.paddingXLarge,
        ),
        itemCount: rowCount + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(
                bottom: AppConstants.paddingMedium,
              ),
              child: Text(
                'สิ่งที่ต้องทำวันนี้',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 24,
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }

          final rowIndex = index - 1;
          final leftIndex = rowIndex * 2;
          final rightIndex = leftIndex + 1;
          final leftEntry = todayEntries[leftIndex];
          final rightEntry = rightIndex < todayEntries.length
              ? todayEntries[rightIndex]
              : null;

          return Padding(
            padding: const EdgeInsets.only(
              bottom: AppConstants.paddingMedium,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildTaskItemWidget(leftEntry, bottomSpacing: 0),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: rightEntry != null
                      ? _buildTaskItemWidget(rightEntry, bottomSpacing: 0)
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          );
        },
      );
    }

    // กรณีมีแต่งานค้าง (ไม่มีงานวันนี้) -> แสดงการ์ดงานค้างเป็น 2 คอลัมน์คู่
    final rowCount = (overdueEntries.length / 2).ceil();
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(
        bottom: AppConstants.paddingXLarge,
      ),
      itemCount: rowCount + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(
              bottom: AppConstants.paddingMedium,
            ),
            child: Text(
              'ภารกิจที่ยังไม่เสร็จ',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 24,
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        final rowIndex = index - 1;
        final leftIndex = rowIndex * 2;
        final rightIndex = leftIndex + 1;
        final leftEntry = overdueEntries[leftIndex];
        final rightEntry = rightIndex < overdueEntries.length
            ? overdueEntries[rightIndex]
            : null;

        return Padding(
          padding: const EdgeInsets.only(
            bottom: AppConstants.paddingMedium,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildTaskItemWidget(leftEntry, bottomSpacing: 0),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: rightEntry != null
                    ? _buildTaskItemWidget(rightEntry, bottomSpacing: 0)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final pendingTodayTasks = _sortedPendingTasks(
      taskProvider.todayPersonalTasks,
    );
    final pendingOverdueTasks = _sortedPendingTasks(
      taskProvider.overduePersonalTasks,
    );
    final todayEntries = _buildTaskEntries(pendingTodayTasks, isOverdue: false);
    final overdueEntries = _buildTaskEntries(
      pendingOverdueTasks,
      isOverdue: true,
    );
    final dashboardItems = _buildDashboardItems(
      todayEntries: todayEntries,
      overdueEntries: overdueEntries,
    );
    final hasTodayTasks = todayEntries.isNotEmpty;
    final showOverdueOnlyHeader = !hasTodayTasks && overdueEntries.isNotEmpty;

    final theme = Theme.of(context);
    final isTablet = Responsive.isTablet(context);
    final isLandscape = Responsive.isLandscape(context);
    final isTabletOrLarge = isTablet || Responsive.isDesktop(context);

    Widget content;
    if (isLandscape && isTabletOrLarge) {
      content = _buildLandscapeLayout(
        context: context,
        todayEntries: todayEntries,
        overdueEntries: overdueEntries,
        theme: theme,
      );
    } else {
      content = dashboardItems.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Text(
                  showOverdueOnlyHeader
                      ? 'ภารกิจที่ยังไม่เสร็จ'
                      : 'สิ่งที่ต้องทำวันนี้',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: isTablet ? 24 : null,
                    color: showOverdueOnlyHeader
                        ? Colors.redAccent
                        : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                const SizedBox(
                  height: 300,
                  child: _TodayEmptyState(),
                ),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(
                bottom: AppConstants.paddingXLarge,
              ),
              children: [
                Text(
                  showOverdueOnlyHeader
                      ? 'ภารกิจที่ยังไม่เสร็จ'
                      : 'สิ่งที่ต้องทำวันนี้',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: isTablet ? 24 : null,
                    color: showOverdueOnlyHeader
                        ? Colors.redAccent
                        : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                ...dashboardItems,
              ],
            );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isTablet ? 24.0 : AppConstants.paddingMedium,
        isTablet ? 20.0 : AppConstants.paddingMedium,
        isTablet ? 24.0 : AppConstants.paddingMedium,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: RefreshIndicator(
              color: AppColors.stormySkyBlue,
              backgroundColor: theme.brightness == Brightness.dark
                  ? AppColors.stormyNightBackground
                  : AppColors.backgroundWhite,
              onRefresh: () async {
                final connectivity = context.read<ConnectivityProvider>();
                if (connectivity.isOffline) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ไม่ได้เชื่อมต่ออินเทอร์เน็ต'),
                    ),
                  );
                  return;
                }
                await Future.delayed(const Duration(seconds: 1));
              },
              child: content,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayTaskListEntry {
  final Task task;
  final bool isExiting;
  final bool isOverdue;

  const _TodayTaskListEntry({
    required this.task,
    required this.isExiting,
    required this.isOverdue,
  });
}

class _OverdueSectionHeader extends StatelessWidget {
  const _OverdueSectionHeader();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = Responsive.isTablet(context);

    return Text(
      'ภารกิจที่ยังไม่เสร็จ',
      style: theme.textTheme.headlineMedium?.copyWith(
        fontSize: isTablet ? 24 : null,
        color: Colors.redAccent,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}

class _CompletingTaskListItem extends StatefulWidget {
  final bool isExiting;
  final double bottomSpacing;
  final Widget child;

  const _CompletingTaskListItem({
    super.key,
    required this.isExiting,
    required this.bottomSpacing,
    required this.child,
  });

  @override
  State<_CompletingTaskListItem> createState() =>
      _CompletingTaskListItemState();
}

class _CompletingTaskListItemState extends State<_CompletingTaskListItem> {
  static const _holdCompletedDuration = Duration(milliseconds: 160);
  static const _collapseDuration = Duration(milliseconds: 400);

  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    if (widget.isExiting) {
      Timer(_holdCompletedDuration, () {
        if (mounted) {
          setState(() => _isVisible = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedAlign(
        duration: _collapseDuration,
        curve: Curves.easeInOutCubic,
        alignment: Alignment.topCenter,
        heightFactor: _isVisible ? 1 : 0,
        child: AnimatedSlide(
          duration: _collapseDuration,
          curve: Curves.easeInOutCubic,
          offset: _isVisible ? Offset.zero : const Offset(0, -0.08),
          child: AnimatedOpacity(
            duration: _collapseDuration,
            curve: Curves.easeOutCubic,
            opacity: _isVisible ? 1 : 0,
            child: Padding(
              padding: EdgeInsets.only(bottom: widget.bottomSpacing),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

// =========================================================================
// 3.4.3 (2.3) โค้ดคอมโพเนนต์การ์ดแสดงผลภาระงานส่วนบุคคลและงานย่อย (_TodayTaskCard)
// =========================================================================
class _TodayTaskCard extends StatelessWidget {
  final Task task;
  final void Function(Task, {Future<CompletionRewardResult?>? pendingResult})
  onToggleComplete;
  final bool isCompleted;
  final bool isOverdue;

  const _TodayTaskCard({
    required this.task,
    required this.onToggleComplete,
    required this.isCompleted,
    this.isOverdue = false,
  });

  Future<void> _openEditTaskModal(BuildContext context, Task task) async {
    await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateTaskModal(task: task),
    );
  }

  void _showDeleteConfirmation(
    BuildContext parentContext,
    TaskProvider taskProvider,
    Task task,
  ) {
    final isTablet = MediaQuery.of(parentContext).size.width >= 600;
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(parentContext).brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : Theme.of(parentContext).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'ยืนยันการลบภารกิจ',
          style: TextStyle(
            color: AppColors.accentRed,
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 22 : 18,
          ),
        ),
        content: Text(
          'คุณแน่ใจหรือไม่ว่าต้องการลบภารกิจนี้โดยส่งไปที่ถังขยะ?',
          style: TextStyle(
            fontSize: isTablet ? 16 : 14.5,
            color: Theme.of(parentContext).brightness == Brightness.dark
                ? AppColors.stormyIceBlue
                : Theme.of(
                    parentContext,
                  ).colorScheme.onSurface.withValues(alpha: 0.82),
          ),
        ),
        actionsPadding: EdgeInsets.symmetric(
          horizontal: isTablet ? 20 : 16,
          vertical: isTablet ? 16 : 12,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 18 : 14,
                vertical: isTablet ? 12 : 10,
              ),
              foregroundColor:
                  Theme.of(parentContext).brightness == Brightness.dark
                  ? AppColors.stormySkyBlue
                  : AppColors.textSecondary,
            ),
            child: Text(
              'ยกเลิก',
              style: TextStyle(
                fontSize: isTablet ? 16 : 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final connectivity = parentContext.read<ConnectivityProvider>();
              if (connectivity.isOffline) {
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'ไม่มีการเชื่อมต่ออินเทอร์เน็ต ไม่สามารถดำเนินการได้',
                    ),
                  ),
                );
                Navigator.pop(dialogContext);
                return;
              }
              final rootNavigator = Navigator.of(
                parentContext,
                rootNavigator: true,
              );
              taskProvider.deleteTask(task.id);
              Navigator.pop(dialogContext);

              if (!parentContext.mounted) return;
              SnackBarUtils.showNavigationSnackBar(
                parentContext,
                message: 'ย้ายไปยังถังขยะแล้ว',
                actionLabel: 'ดูถังขยะ',
                onNavigate: () {
                  rootNavigator.push(
                    MaterialPageRoute(builder: (ctx) => const BinScreen()),
                  );
                },
              );
            },
            style: TextButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor:
                  Theme.of(parentContext).brightness == Brightness.dark
                      ? AppColors.stormyNightBackground
                      : Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 12 : 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'ยืนยันการลบ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isTablet ? 16 : 14.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.read<TaskProvider>();
    final theme = Theme.of(context);
    final isTablet = Responsive.isTablet(context);
    final mutedColor = theme.colorScheme.onSurface.withValues(alpha: 0.62);
    final tagColor = theme.colorScheme.tertiary;

    return Material(
      color: theme.brightness == Brightness.dark
          ? AppColors.stormyDarkSlate
          : theme.cardColor,
      borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
      child: InkWell(
        enableFeedback: false,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        onTap: () async {
          taskProvider.selectTask(task);
          await Navigator.pushNamed(context, '/task-detail');
        },
        child: Container(
          padding: EdgeInsets.all(
            isTablet ? 20.0 : AppConstants.paddingMedium,
          ),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? AppColors.stormyDarkSlate
                : theme.cardColor,
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            border: Border.all(
              // ปรับเส้นขอบเป็นสีแดงเตือนสายตาเมื่องานเลยกำหนดส่ง (isOverdue)
              color: isOverdue
                  ? Colors.redAccent
                  : theme.colorScheme.onSurface.withValues(alpha: 0.08),
              width: isOverdue ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.08),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // แสดง Checkbox เฉพาะกรณีที่ไม่มีภารกิจย่อย (หากมีงานย่อยให้เช็กผ่านงานย่อยแทน)
                  if (task.subtasks.isEmpty) ...[
                    _TodayCompletionCheckbox(
                      task: task,
                      onToggle: () => onToggleComplete(task),
                      isCompleted: isCompleted,
                    ),
                    SizedBox(
                      width: isTablet ? 18.0 : AppConstants.paddingMedium,
                    ),
                  ],
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontSize: isTablet ? 22 : 18,
                            color: isCompleted
                                ? theme.colorScheme.onSurface.withValues(
                                    alpha: 0.45,
                                  )
                                : theme.colorScheme.onSurface,
                            fontWeight: FontWeight.bold,
                            // ขีดฆ่าข้อความอัตโนมัติเมื่องานเสร็จสิ้น (TextDecoration.lineThrough)
                            decoration: isCompleted
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                        if (task.description.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            task.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontSize: isTablet ? 15 : null,
                              color: isCompleted
                                  ? mutedColor.withValues(alpha: 0.55)
                                  : mutedColor,
                              height: 1.35,
                              decoration: isCompleted
                                  ? TextDecoration.lineThrough
                                  : null,
                            ),
                          ),
                        ],
                        if (task.subtasks.isNotEmpty) ...[
                          const SizedBox(height: AppConstants.paddingSmall),
                          Padding(
                            padding: const EdgeInsets.only(
                              left: AppConstants.paddingSmall,
                            ),
                            child: _TodaySubtasks(
                              task: task,
                              onToggleComplete: onToggleComplete,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: AppConstants.paddingSmall),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _TimeLabel(dateTime: task.dateTime),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          switch (value) {
                            case 'edit':
                              _openEditTaskModal(context, task);
                              break;
                            case 'toggle_complete':
                              onToggleComplete(task);
                              break;
                            case 'delete':
                              _showDeleteConfirmation(
                                context,
                                taskProvider,
                                task,
                              );
                              break;
                          }
                        },
                        icon: Icon(
                          Icons.more_vert,
                          size: isTablet ? 28 : 22,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.6,
                          ),
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        itemBuilder: (context) => [
                          PopupMenuItem(
                            value: 'edit',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  color: AppColors.stormySkyBlue,
                                  size: isTablet ? 24 : 22,
                                ),
                                SizedBox(width: isTablet ? 12 : 10),
                                Text(
                                  'แก้ไข',
                                  style: TextStyle(
                                    color: theme.colorScheme.onSurface,
                                    fontSize: isTablet ? 18 : 16,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  color: Colors.red,
                                  size: isTablet ? 24 : 22,
                                ),
                                SizedBox(width: isTablet ? 12 : 10),
                                Text(
                                  'ลบ',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: isTablet ? 18 : 16,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
              if (task.subtasks.isNotEmpty) ...[
                const SizedBox(height: AppConstants.paddingMedium),
                Padding(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${task.completedCount}/${task.subtasks.length} ภารกิจ',
                            style: TextStyle(
                              fontSize: isTablet ? 14 : 12,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value: task.progress,
                          backgroundColor: theme.colorScheme.onSurface
                              .withValues(alpha: 0.08),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.stormySkyBlue,
                          ),
                          minHeight: isTablet ? 8 : 6,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: AppConstants.paddingMedium),
              Padding(
                padding: EdgeInsets.only(
                  left: task.subtasks.isNotEmpty ? 0 : (isTablet ? 46 : 40),
                ),
                child: Wrap(
                  spacing: AppConstants.paddingSmall,
                  runSpacing: AppConstants.paddingSmall,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    PriorityTag(priority: task.priorityLabel),
                    if (task.category != null)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 14 : 10,
                          vertical: isTablet ? 7 : 5,
                        ),
                        decoration: BoxDecoration(
                          color: theme.brightness == Brightness.dark
                              ? AppColors.stormyNightBackground
                              : tagColor.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(
                            isTablet
                                ? AppConstants.radiusMedium
                                : AppConstants.radiusSmall,
                          ),
                        ),
                        child: Text(
                          thaiCategoryLabel(task.category!),
                          style: theme.textTheme.labelSmall?.copyWith(
                            fontSize: isTablet ? 14 : null,
                            color: theme.brightness == Brightness.dark
                                ? AppColors.stormyIceBlue
                                : tagColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (!task.isPersonal && task.assigneeIds.isNotEmpty) ...[
                const SizedBox(height: AppConstants.paddingMedium),
                Padding(
                  padding: EdgeInsets.only(
                    left: isTablet ? 46 : 40,
                  ),
                  child: _AssigneeAvatars(task: task),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeLabel extends StatelessWidget {
  final DateTime dateTime;

  const _TimeLabel({required this.dateTime});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.tertiary;
    final isTablet = Responsive.isTablet(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isTablet ? 14 : 10,
        vertical: isTablet ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(
          isTablet ? AppConstants.radiusMedium : AppConstants.radiusSmall,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: isTablet ? 16 : 14, color: accentColor),
          SizedBox(width: isTablet ? 6 : 4),
          Text(
            DateFormat('HH:mm น.').format(dateTime),
            style: theme.textTheme.labelSmall?.copyWith(
              fontSize: isTablet ? 14 : null,
              color: accentColor,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayCompletionCheckbox extends StatelessWidget {
  final Task task;
  final Function() onToggle;
  final bool isCompleted;

  const _TodayCompletionCheckbox({
    required this.task,
    required this.onToggle,
    required this.isCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = Responsive.isTablet(context);
    final boxSize = isTablet ? 28.0 : 24.0;
    final iconSize = isTablet ? 19.0 : 16.0;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        enableFeedback: false,
        borderRadius: BorderRadius.circular(isTablet ? 8 : 6),
        onTap: onToggle,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: boxSize,
          height: boxSize,
          decoration: BoxDecoration(
            color: isCompleted
                ? (theme.brightness == Brightness.dark
                      ? AppColors.stormySkyBlue
                      : theme.colorScheme.primary)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(isTablet ? 8 : 6),
            border: Border.all(
              color: isCompleted
                  ? (theme.brightness == Brightness.dark
                        ? AppColors.stormySkyBlue
                        : theme.colorScheme.primary)
                  : theme.colorScheme.onSurface.withValues(alpha: 0.18),
              width: 2,
            ),
          ),
          child: isCompleted
              ? Icon(
                  Icons.check,
                  size: iconSize,
                  color: theme.brightness == Brightness.dark
                      ? AppColors.stormyNightBackground
                      : theme.colorScheme.onPrimary,
                )
              : null,
        ),
      ),
    );
  }
}

class _TodaySubtasks extends StatefulWidget {
  final Task task;
  final void Function(Task, {Future<CompletionRewardResult?>? pendingResult})
  onToggleComplete;

  const _TodaySubtasks({required this.task, required this.onToggleComplete});

  @override
  State<_TodaySubtasks> createState() => _TodaySubtasksState();
}

class _TodaySubtasksState extends State<_TodaySubtasks> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = Responsive.isTablet(context);
    final taskProvider = context.read<TaskProvider>();
    const maxInitial = 3;
    final subtasks = widget.task.subtasks;
    final hasMore = subtasks.length > maxInitial;
    final displayedEntries = _isExpanded
        ? subtasks.asMap().entries.toList()
        : subtasks.take(maxInitial).toList().asMap().entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in displayedEntries)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: InkWell(
              enableFeedback: false,
              borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
              onTap: () async {
                final connectivity = context.read<ConnectivityProvider>();
                if (connectivity.isOffline) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'ไม่มีการเชื่อมต่ออินเทอร์เน็ต ไม่สามารถดำเนินการได้',
                      ),
                    ),
                  );
                  return;
                }
                final isCheckingLast =
                    !entry.value.isDone &&
                    widget.task.subtasks.where((s) => !s.isDone).length == 1;

                if (isCheckingLast && !widget.task.isCompleted) {
                  final futureResult = taskProvider.toggleSubtask(
                    widget.task.id,
                    entry.key,
                  );
                  widget.onToggleComplete(
                    widget.task,
                    pendingResult: futureResult,
                  );
                } else {
                  await taskProvider.toggleSubtask(widget.task.id, entry.key);
                }
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TodaySubtaskCheckbox(isDone: entry.value.isDone),
                  SizedBox(
                    width: isTablet ? 12 : AppConstants.paddingSmall,
                  ),
                  Flexible(
                    child: Text(
                      entry.value.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: isTablet ? 15 : null,
                        color: entry.value.isDone
                            ? theme.colorScheme.onSurface.withValues(alpha: 0.4)
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.72,
                              ),
                        decoration: entry.value.isDone
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (hasMore)
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
              child: Text(
                _isExpanded
                    ? 'ย่อภารกิจย่อย'
                    : '+ อีก ${subtasks.length - maxInitial} ภารกิจย่อย',
                style: TextStyle(
                  fontSize: isTablet ? 13 : 11,
                  fontWeight: FontWeight.w600,
                  color: (theme.brightness == Brightness.dark
                      ? AppColors.stormySkyBlue
                      : theme.colorScheme.primary),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TodaySubtaskCheckbox extends StatelessWidget {
  final bool isDone;

  const _TodaySubtaskCheckbox({required this.isDone});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = Responsive.isTablet(context);
    final boxSize = isTablet ? 22.0 : 18.0;
    final iconSize = isTablet ? 15.0 : 12.0;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: boxSize,
      height: boxSize,
      decoration: BoxDecoration(
        color: isDone
            ? (theme.brightness == Brightness.dark
                  ? AppColors.stormySkyBlue
                  : theme.colorScheme.primary)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(isTablet ? 6 : 4),
        border: Border.all(
          color: isDone
              ? (theme.brightness == Brightness.dark
                    ? AppColors.stormySkyBlue
                    : theme.colorScheme.primary)
              : theme.colorScheme.onSurface.withValues(alpha: 0.22),
          width: 2,
        ),
      ),
      child: isDone
          ? Icon(
              Icons.check,
              size: iconSize,
              color: theme.brightness == Brightness.dark
                  ? AppColors.stormyNightBackground
                  : theme.colorScheme.onPrimary,
            )
          : null,
    );
  }
}

class _AssigneeAvatars extends StatelessWidget {
  final Task task;

  const _AssigneeAvatars({required this.task});

  @override
  Widget build(BuildContext context) {
    final visibleAssignees = task.assigneeIds.take(4).toList();

    return SizedBox(
      height: AppConstants.avatarSmall,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < visibleAssignees.length; i++)
            Positioned(
              left: i * 20,
              child: _AssigneeAvatar(userId: visibleAssignees[i]),
            ),
          if (task.assigneeIds.length > visibleAssignees.length)
            Positioned(
              left: visibleAssignees.length * 20,
              child: _MoreAssigneesBadge(
                count: task.assigneeIds.length - visibleAssignees.length,
              ),
            ),
        ],
      ),
    );
  }
}

class _AssigneeAvatar extends StatelessWidget {
  final String userId;

  const _AssigneeAvatar({required this.userId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = context.read<TaskProvider>().getUserById(userId);
    final avatar = user?.avatarUrl;
    final initial = (user?.name.isNotEmpty ?? false) ? user!.name[0] : '?';

    return Container(
      width: AppConstants.avatarSmall,
      height: AppConstants.avatarSmall,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.cardColor, width: 2),
      ),
      child: ClipOval(
        child: avatar != null && avatar.isNotEmpty
            ? Image.network(
                avatar,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _AvatarInitial(initial: initial);
                },
              )
            : _AvatarInitial(initial: initial),
      ),
    );
  }
}

class _AvatarInitial extends StatelessWidget {
  final String initial;

  const _AvatarInitial({required this.initial});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Text(
        initial,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _MoreAssigneesBadge extends StatelessWidget {
  final int count;

  const _MoreAssigneesBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: AppConstants.avatarSmall,
      height: AppConstants.avatarSmall,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.cardColor, width: 2),
      ),
      child: Center(
        child: Text(
          '+$count',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

class _TodayEmptyState extends StatelessWidget {
  const _TodayEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.colorScheme.tertiary;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingXLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.self_improvement_outlined,
                size: 46,
                color: accentColor,
              ),
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            Text(
              'วันนี้ไม่มีภารกิจค้าง!',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              'พักผ่อนให้เต็มที่',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupProjectsList extends StatefulWidget {
  const _GroupProjectsList();

  @override
  State<_GroupProjectsList> createState() => _GroupProjectsListState();
}

class _GroupProjectsListState extends State<_GroupProjectsList> {
  static const _completionExitDuration = Duration(milliseconds: 560);

  final Map<String, Task> _exitingProjects = {};
  final Map<String, int> _exitingProjectIndexes = {};
  final Set<String> _exitingOverdueProjectIds = {};
  final Map<String, Timer> _exitTimers = {};

  @override
  void dispose() {
    for (final timer in _exitTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  Future<void> _handleToggleComplete(
    Task project, {
    required bool isOverdue,
  }) async {
    final connectivity = context.read<ConnectivityProvider>();
    if (connectivity.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่มีการเชื่อมต่ออินเทอร์เน็ต ไม่สามารถดำเนินการได้'),
        ),
      );
      return;
    }
    final taskProvider = context.read<TaskProvider>();
    final nextState = !project.isCompleted;

    final latestProject = taskProvider.tasks.firstWhere(
      (t) => t.id == project.id,
      orElse: () => project,
    );

    if (nextState) {
      final isLeader = taskProvider.isLeaderForTask(
        latestProject,
        context.read<AuthProvider>().currentUser?.id,
      );
      if (isLeader &&
          (latestProject.type == TaskType.group ||
              latestProject.members.isNotEmpty)) {
        final leaderId = taskProvider.leaderIdForTask(latestProject);
        final nonLeaderMembers = latestProject.members
            .where((m) => m.id != leaderId)
            .toList();
        final membersToCheck = nonLeaderMembers.isNotEmpty
            ? nonLeaderMembers
            : latestProject.members;
        final areAllCompleted =
            taskProvider.areAllGroupMembersCompleted(latestProject);

        if (!areAllCompleted) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final incompleteCount = membersToCheck
              .where((m) => m.status != 'completed')
              .length;
          final pendingReviewCount = membersToCheck
              .where((m) => m.status == 'pending')
              .length;

          String message;
          if (latestProject.members.isEmpty) {
            message = 'ยังไม่มีการส่งงานของสมาชิกเข้ามาในภารกิจนี้';
          } else if (pendingReviewCount > 0 &&
              incompleteCount == pendingReviewCount) {
            message =
                'มีงานของสมาชิกที่รอการตรวจสอบและอนุมัติอยู่ $pendingReviewCount คน กรุณาตรวจอนุมัติงานให้ครบก่อนเสร็จสิ้นภารกิจ';
          } else if (pendingReviewCount > 0) {
            message =
                'สมาชิกยังส่งงานไม่ครบถ้วน (และมีงานรอตรวจ $pendingReviewCount คน) กรุณาให้สมาชิกส่งงานและอนุมัติให้ครบก่อนเสร็จสิ้นภารกิจ';
          } else {
            message =
                'สมาชิกในกลุ่มยังส่งงานไม่ครบถ้วน (เหลืออีก $incompleteCount คน) กรุณารอให้สมาชิกทุกคนส่งงานและอนุมัติให้ครบก่อนเสร็จสิ้นภารกิจ';
          }

          final isTablet = MediaQuery.of(context).size.width >= 600;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: isDark
                  ? AppColors.stormyDarkSlate
                  : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
              ),
              title: Text(
                'ไม่สามารถเสร็จสิ้นภารกิจได้',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isTablet ? 22 : 18,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              content: Text(
                message,
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14.5,
                  height: 1.5,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.85)
                      : AppColors.stormyDarkSlate.withValues(alpha: 0.85),
                ),
              ),
              actionsPadding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 16 : 12,
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDark
                        ? AppColors.stormySkyBlue
                        : AppColors.stormySkyBlue,
                    foregroundColor: isDark
                        ? AppColors.stormyNightBackground
                        : Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 24 : 20,
                      vertical: isTablet ? 12 : 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: Text(
                    'ตกลง',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isTablet ? 16 : 14.5,
                    ),
                  ),
                ),
              ],
            ),
          );
          return;
        }
      }

      if (latestProject.subtasks.isNotEmpty &&
          latestProject.subtasks.any((s) => !s.isDone)) {
        final isTablet = MediaQuery.of(context).size.width >= 600;
        final isDark = Theme.of(context).brightness == Brightness.dark;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: isDark
                ? AppColors.stormyDarkSlate
                : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18.0),
            ),
            title: Text(
              'ไม่สามารถเสร็จสิ้นภารกิจได้',
              style: TextStyle(
                fontSize: isTablet ? 22 : 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Text(
              'กรุณาทำภารกิจย่อยทั้งหมดให้เสร็จสิ้นก่อนทำการปิดภารกิจหลัก',
              style: TextStyle(fontSize: isTablet ? 16 : 14.5),
            ),
            actionsPadding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16,
              vertical: isTablet ? 16 : 12,
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.stormySkyBlue,
                  foregroundColor:
                      Theme.of(context).brightness == Brightness.dark
                      ? AppColors.stormyNightBackground
                      : Colors.white,
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 24 : 20,
                    vertical: isTablet ? 12 : 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                  ),
                ),
                child: Text(
                  'ตกลง',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isTablet ? 16 : 14.5,
                  ),
                ),
              ),
            ],
          ),
        );
        return;
      }

      _stageProjectExit(project, isOverdue: isOverdue);
      _playTaskCompleteSound();
      final result = await taskProvider.completeTaskWithSubtasks(
        project.id,
        true,
      );
      if (!mounted) return;
      await FastCompletionWarningDialog.showCompletionFeedback(context, result);

      if (!mounted) return;
      SnackBarUtils.showUndoSnackBar(
        context,
        message: 'ทำเครื่องหมายเสร็จสิ้นแล้ว',
        onUndo: () async {
          await taskProvider.toggleTaskCompletion(
            project.id,
            updateSubtasks: true,
          );
        },
      );
    } else {
      _cancelProjectExit(project.id);
      await taskProvider.toggleTaskCompletion(project.id, updateSubtasks: true);
    }
  }

  void _playTaskCompleteSound() {
    final isSoundEnabled =
        context.read<AuthProvider>().currentUser?.isSoundEnabled ?? true;
    unawaited(
      SoundService.instance.playTaskCompleteSound(
        isSoundEnabled: isSoundEnabled,
      ),
    );
  }

  void _stageProjectExit(Task project, {required bool isOverdue}) {
    if (_exitingProjects.containsKey(project.id)) return;

    final pendingProjects = _sortedPendingProjects(
      isOverdue
          ? context.read<TaskProvider>().overdueGroupTasks
          : context.read<TaskProvider>().todayGroupTasks,
    );
    final visualIndex = pendingProjects.indexWhere(
      (item) => item.id == project.id,
    );
    final completedSubtasks = project.subtasks
        .map((subtask) => subtask.copyWith(isDone: true))
        .toList();

    setState(() {
      _exitingProjects[project.id] = project.copyWith(
        status: TaskStatus.completed,
        completedAt: DateTime.now(),
        subtasks: completedSubtasks,
      );
      _exitingProjectIndexes[project.id] = visualIndex < 0 ? 0 : visualIndex;
      if (isOverdue) {
        _exitingOverdueProjectIds.add(project.id);
      } else {
        _exitingOverdueProjectIds.remove(project.id);
      }
    });

    _exitTimers[project.id]?.cancel();
    _exitTimers[project.id] = Timer(_completionExitDuration, () {
      if (!mounted) return;
      setState(() {
        _exitingProjects.remove(project.id);
        _exitingProjectIndexes.remove(project.id);
        _exitingOverdueProjectIds.remove(project.id);
        _exitTimers.remove(project.id);
      });
    });
  }

  void _cancelProjectExit(String projectId) {
    final timer = _exitTimers.remove(projectId);
    timer?.cancel();
    if (!_exitingProjects.containsKey(projectId)) return;

    setState(() {
      _exitingProjects.remove(projectId);
      _exitingProjectIndexes.remove(projectId);
      _exitingOverdueProjectIds.remove(projectId);
    });
  }

  List<Task> _sortedPendingProjects(List<Task> projects) {
    return projects.where((project) => !project.isCompleted).toList()
      ..sort((a, b) {
        final priorityComparison = b.priority.index.compareTo(a.priority.index);
        if (priorityComparison != 0) return priorityComparison;
        return b.createdAt.compareTo(a.createdAt);
      });
  }

  List<_TodayTaskListEntry> _buildProjectEntries(
    List<Task> pendingProjects, {
    required bool isOverdue,
  }) {
    final entries = pendingProjects
        .where((project) => !_exitingProjects.containsKey(project.id))
        .map(
          (project) => _TodayTaskListEntry(
            task: project,
            isExiting: false,
            isOverdue: isOverdue,
          ),
        )
        .toList();
    final exitingEntries =
        _exitingProjects.values
            .where(
              (project) =>
                  _exitingOverdueProjectIds.contains(project.id) == isOverdue,
            )
            .toList()
          ..sort((a, b) {
            final aIndex = _exitingProjectIndexes[a.id] ?? 0;
            final bIndex = _exitingProjectIndexes[b.id] ?? 0;
            return aIndex.compareTo(bIndex);
          });

    for (final project in exitingEntries) {
      final insertIndex = (_exitingProjectIndexes[project.id] ?? entries.length)
          .clamp(0, entries.length)
          .toInt();
      entries.insert(
        insertIndex,
        _TodayTaskListEntry(
          task: project,
          isExiting: true,
          isOverdue: isOverdue,
        ),
      );
    }

    return entries;
  }

  Widget _buildProjectItemWidget(
    _TodayTaskListEntry entry,
    TaskProvider taskProvider, {
    double bottomSpacing = 20,
  }) {
    return _CompletingTaskListItem(
      key: ValueKey(
        'group-${entry.task.id}-${entry.isExiting}-${entry.isOverdue}',
      ),
      isExiting: entry.isExiting,
      bottomSpacing: bottomSpacing,
      child: GroupProjectCard(
        project: entry.task,
        onDelete: (id) => taskProvider.deleteGroupProjectTask(id),
        onToggleComplete: (project) =>
            _handleToggleComplete(project, isOverdue: entry.isOverdue),
        isCompletedOverride: entry.task.isCompleted,
        isOverdue: entry.isOverdue,
      ),
    );
  }

  List<Widget> _buildDashboardItems({
    required List<_TodayTaskListEntry> todayEntries,
    required List<_TodayTaskListEntry> overdueEntries,
    required TaskProvider taskProvider,
  }) {
    final hasTodayTasks = todayEntries.isNotEmpty;
    final items = <Widget>[];

    void addProjectEntry(_TodayTaskListEntry entry, bool isLast) {
      items.add(
        _buildProjectItemWidget(
          entry,
          taskProvider,
          bottomSpacing: isLast ? 0 : 20,
        ),
      );
    }

    for (var i = 0; i < todayEntries.length; i++) {
      final isLast = i == todayEntries.length - 1 && overdueEntries.isEmpty;
      addProjectEntry(todayEntries[i], isLast);
    }

    if (hasTodayTasks && overdueEntries.isNotEmpty) {
      items.add(const Divider(height: 30, thickness: 1));
      items.add(const _OverdueSectionHeader());
      items.add(const SizedBox(height: AppConstants.paddingMedium));
    }

    for (var i = 0; i < overdueEntries.length; i++) {
      addProjectEntry(overdueEntries[i], i == overdueEntries.length - 1);
    }

    return items;
  }

  Widget _buildLandscapeLayout({
    required BuildContext context,
    required List<_TodayTaskListEntry> todayEntries,
    required List<_TodayTaskListEntry> overdueEntries,
    required TaskProvider taskProvider,
    required ThemeData theme,
  }) {
    final hasToday = todayEntries.isNotEmpty;
    final hasOverdue = overdueEntries.isNotEmpty;

    if (!hasToday && !hasOverdue) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          Text(
            'สิ่งที่ต้องทำวันนี้',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 24,
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          const SizedBox(
            height: 300,
            child: _TodayGroupEmptyState(),
          ),
        ],
      );
    }

    // กรณีมีทั้งงานวันนี้และงานค้าง -> แบ่งซ้ายขวา 50:50
    if (hasToday && hasOverdue) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ฝั่งซ้าย: สิ่งที่ต้องทำวันนี้
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'สิ่งที่ต้องทำวันนี้',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 22,
                        color: theme.colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.stormySkyBlue.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${todayEntries.length}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.stormySkyBlue,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                Expanded(
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(
                      bottom: AppConstants.paddingXLarge,
                    ),
                    itemCount: todayEntries.length,
                    itemBuilder: (context, index) => _buildProjectItemWidget(
                      todayEntries[index],
                      taskProvider,
                      bottomSpacing: index == todayEntries.length - 1 ? 0 : 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 20),
          // ฝั่งขวา: ภารกิจที่ยังไม่เสร็จ
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'ภารกิจที่ยังไม่เสร็จ',
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontSize: 22,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${overdueEntries.length}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                Expanded(
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(
                      bottom: AppConstants.paddingXLarge,
                    ),
                    itemCount: overdueEntries.length,
                    itemBuilder: (context, index) => _buildProjectItemWidget(
                      overdueEntries[index],
                      taskProvider,
                      bottomSpacing: index == overdueEntries.length - 1 ? 0 : 20,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // กรณีมีแต่งานวันนี้ (ไม่มีงานค้าง) -> แสดงการ์ดงานวันนี้เป็น 2 คอลัมน์คู่
    if (hasToday) {
      final rowCount = (todayEntries.length / 2).ceil();
      return ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(
          bottom: AppConstants.paddingXLarge,
        ),
        itemCount: rowCount + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(
                bottom: AppConstants.paddingMedium,
              ),
              child: Text(
                'สิ่งที่ต้องทำวันนี้',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontSize: 24,
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }

          final rowIndex = index - 1;
          final leftIndex = rowIndex * 2;
          final rightIndex = leftIndex + 1;
          final leftEntry = todayEntries[leftIndex];
          final rightEntry = rightIndex < todayEntries.length
              ? todayEntries[rightIndex]
              : null;

          return Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _buildProjectItemWidget(
                    leftEntry,
                    taskProvider,
                    bottomSpacing: 0,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: rightEntry != null
                      ? _buildProjectItemWidget(
                          rightEntry,
                          taskProvider,
                          bottomSpacing: 0,
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          );
        },
      );
    }

    // กรณีมีแต่งานค้าง (ไม่มีงานวันนี้) -> แสดงการ์ดงานค้างเป็น 2 คอลัมน์คู่
    final rowCount = (overdueEntries.length / 2).ceil();
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(
        bottom: AppConstants.paddingXLarge,
      ),
      itemCount: rowCount + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(
              bottom: AppConstants.paddingMedium,
            ),
            child: Text(
              'ภารกิจที่ยังไม่เสร็จ',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontSize: 24,
                color: Colors.redAccent,
                fontWeight: FontWeight.w700,
              ),
            ),
          );
        }

        final rowIndex = index - 1;
        final leftIndex = rowIndex * 2;
        final rightIndex = leftIndex + 1;
        final leftEntry = overdueEntries[leftIndex];
        final rightEntry = rightIndex < overdueEntries.length
            ? overdueEntries[rightIndex]
            : null;

        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _buildProjectItemWidget(
                  leftEntry,
                  taskProvider,
                  bottomSpacing: 0,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: rightEntry != null
                    ? _buildProjectItemWidget(
                        rightEntry,
                        taskProvider,
                        bottomSpacing: 0,
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final pendingTodayProjects = _sortedPendingProjects(
      taskProvider.todayGroupTasks,
    );
    final pendingOverdueProjects = _sortedPendingProjects(
      taskProvider.overdueGroupTasks,
    );
    final todayEntries = _buildProjectEntries(
      pendingTodayProjects,
      isOverdue: false,
    );
    final overdueEntries = _buildProjectEntries(
      pendingOverdueProjects,
      isOverdue: true,
    );
    final dashboardItems = _buildDashboardItems(
      todayEntries: todayEntries,
      overdueEntries: overdueEntries,
      taskProvider: taskProvider,
    );
    final hasTodayTasks = todayEntries.isNotEmpty;
    final showOverdueOnlyHeader = !hasTodayTasks && overdueEntries.isNotEmpty;
    final theme = Theme.of(context);
    final isTablet = Responsive.isTablet(context);
    final isLandscape = Responsive.isLandscape(context);
    final isTabletOrLarge = isTablet || Responsive.isDesktop(context);

    Widget content;
    if (isLandscape && isTabletOrLarge) {
      content = _buildLandscapeLayout(
        context: context,
        todayEntries: todayEntries,
        overdueEntries: overdueEntries,
        taskProvider: taskProvider,
        theme: theme,
      );
    } else {
      content = dashboardItems.isEmpty
          ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Text(
                  showOverdueOnlyHeader
                      ? 'ภารกิจที่ยังไม่เสร็จ'
                      : 'สิ่งที่ต้องทำวันนี้',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: isTablet ? 24 : null,
                    color: showOverdueOnlyHeader
                        ? Colors.redAccent
                        : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                const SizedBox(
                  height: 300,
                  child: _TodayGroupEmptyState(),
                ),
              ],
            )
          : ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.only(
                bottom: AppConstants.paddingXLarge,
              ),
              children: [
                Text(
                  showOverdueOnlyHeader
                      ? 'ภารกิจที่ยังไม่เสร็จ'
                      : 'สิ่งที่ต้องทำวันนี้',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontSize: isTablet ? 24 : null,
                    color: showOverdueOnlyHeader
                        ? Colors.redAccent
                        : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppConstants.paddingMedium),
                ...dashboardItems,
              ],
            );
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isTablet ? 24.0 : AppConstants.paddingMedium,
        isTablet ? 20.0 : AppConstants.paddingMedium,
        isTablet ? 24.0 : AppConstants.paddingMedium,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: RefreshIndicator(
              color: AppColors.stormySkyBlue,
              backgroundColor: theme.brightness == Brightness.dark
                  ? AppColors.stormyNightBackground
                  : AppColors.backgroundWhite,
              onRefresh: () async {
                final connectivity = context.read<ConnectivityProvider>();
                if (connectivity.isOffline) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('ไม่ได้เชื่อมต่ออินเทอร์เน็ต'),
                    ),
                  );
                  return;
                }
                await Future.delayed(const Duration(seconds: 1));
              },
              child: content,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayGroupEmptyState extends StatelessWidget {
  const _TodayGroupEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingXLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.groups_2_outlined,
                size: 46,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            Text(
              'ไม่มีภารกิจกลุ่มสำหรับวันนี้',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ignore: unused_element
Widget _buildEmptyState(
  BuildContext context,
  String title,
  String subtitle,
  IconData icon,
) {
  final theme = Theme.of(context);
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(AppConstants.paddingXLarge),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.light
                  ? (Theme.of(context).brightness == Brightness.light
                        ? AppColors.stormyIceBlue
                        : AppColors.backgroundGrey)
                  : Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 50,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
          ),
          const SizedBox(height: AppConstants.paddingLarge),
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppConstants.paddingSmall),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ),
  );
}
