// SettingsScreen - หน้าจอตั้งค่าแอปพลิเคชัน (Settings Screen)
//
// ปรับแต่งการใช้งานแอป เช่น เปลี่ยนธีม (Light/Dark Mode) ตั้งค่าเสียง การแจ้งเตือน
// เข้าถึงหน้าแก้ไขโปรไฟล์ ดูไทม์ไลน์รางวัล และเมนูออกจากระบบ
import '../main.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/task_provider.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/rewards_timeline_screen.dart';
import '../utils/thai_display.dart';
import '../widgets/achievement_summary_card.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/user_avatar_with_frame.dart';
import '../widgets/about_app_sheet.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final taskProvider = Provider.of<TaskProvider>(context);
    final user = authProvider.currentUser;
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? AppColors.stormyNightBackground
          : theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(theme, isTablet),

            // Settings Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(
                  isTablet ? AppConstants.paddingLarge : AppConstants.paddingMedium,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Section
                    _buildProfileSection(user, taskProvider, isTablet),

                    SizedBox(
                      height: isTablet
                          ? AppConstants.paddingXLarge
                          : AppConstants.paddingLarge,
                    ),

                    // Stats Section
                    _buildStatsSection(user, taskProvider, theme, isTablet),

                    SizedBox(
                      height: isTablet
                          ? AppConstants.paddingXLarge
                          : AppConstants.paddingLarge,
                    ),

                    if (user != null) ...[
                      AchievementSummaryCard(user: user),
                      SizedBox(
                        height: isTablet
                            ? AppConstants.paddingXLarge
                            : AppConstants.paddingLarge,
                      ),
                    ],

                    // Settings Sections
                    _buildSettingsSection(
                      theme: theme,
                      title: 'การตั้งค่า',
                      isTablet: isTablet,
                      children: [
                        _buildSwitchTile(
                          theme: theme,
                          icon: Icons.notifications_outlined,
                          title: 'การแจ้งเตือน',
                          subtitle: 'รับการแจ้งเตือนภารกิจ',
                          value: user?.isNotificationEnabled ?? true,
                          isTablet: isTablet,
                          onChanged: (value) {
                            authProvider.toggleNotification(value);
                          },
                        ),
                        _buildSwitchTile(
                          theme: theme,
                          icon: Icons.dark_mode_outlined,
                          title: 'โหมดมืด',
                          subtitle: 'เปลี่ยนเป็นธีมมืด',
                          value: themeProvider.isDarkMode,
                          isTablet: isTablet,
                          onChanged: (value) {
                            themeProvider.toggleTheme(value);
                          },
                        ),
                        _buildSwitchTile(
                          theme: theme,
                          icon: Icons.volume_up_outlined,
                          title: 'เสียง',
                          subtitle: 'เปิดเสียงเอฟเฟกต์',
                          value: user?.isSoundEnabled ?? true,
                          isTablet: isTablet,
                          onChanged: (value) {
                            authProvider.toggleSound(value);
                          },
                        ),
                        _buildListTile(
                          theme: theme,
                          icon: Icons.info_outline,
                          title: 'เกี่ยวกับแอป',
                          isTablet: isTablet,
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (context) => const AboutAppSheet(),
                            );
                          },
                        ),
                      ],
                    ),

                    SizedBox(
                      height: isTablet
                          ? AppConstants.paddingXLarge
                          : AppConstants.paddingLarge,
                    ),

                    // Logout Button
                    _buildLogoutButton(authProvider, isTablet),

                    SizedBox(
                      height: isTablet
                          ? AppConstants.paddingXLarge * 1.5
                          : AppConstants.paddingXLarge,
                    ),

                    // App Version
                    Center(
                      child: Text(
                        'เวอร์ชัน 1.0.0',
                        style: TextStyle(
                          fontSize: isTablet ? 14 : 12,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      drawer: const CustomDrawer(),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isTablet) {
    return Padding(
      padding: EdgeInsets.all(
        isTablet ? AppConstants.paddingLarge : AppConstants.paddingMedium,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 16 : 12),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.light
                  ? AppColors.stormySkyBlue
                  : AppColors.stormySkyBlue,
              borderRadius: BorderRadius.circular(
                isTablet ? 18 : AppConstants.radiusMedium,
              ),
              border: theme.brightness == Brightness.dark
                  ? Border.all(color: AppColors.stormySkyBlue, width: 2)
                  : null,
            ),
            child: Icon(
              Icons.settings,
              color: theme.brightness == Brightness.light
                  ? AppColors.textWhite
                  : AppColors.stormyNightBackground,
              size: isTablet ? 30 : 24,
            ),
          ),
          SizedBox(
            width: isTablet
                ? AppConstants.paddingLarge
                : AppConstants.paddingMedium,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ตั้งค่า',
                style: TextStyle(
                  fontSize: isTablet ? 28 : 22,
                  fontWeight: FontWeight.bold,
                  color: theme.brightness == Brightness.dark
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                ),
              ),
              Text(
                'จัดการการตั้งค่าของคุณ',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.normal,
                  color: theme.brightness == Brightness.dark
                      ? AppColors.stormyMutedBlueGrey
                      : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection(
    User? user,
    TaskProvider taskProvider,
    bool isTablet,
  ) {
    final displayLevel = user?.currentLevel ?? taskProvider.currentLevel;
    final displayLevelTitle = user?.levelTitle ?? _levelTitleFor(displayLevel);
    final xpProgress = user == null || user.nextLevelPoints == 0
        ? taskProvider.xpProgress
        : user.progressToNextLevelValue;

    return Stack(
      children: [
        Container(
          padding: EdgeInsets.all(
            isTablet ? 26 : AppConstants.paddingLarge,
          ),
          decoration: BoxDecoration(
            gradient: Theme.of(context).brightness == Brightness.light
                ? const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppColors.stormyDarkSlate,
                      AppColors.stormySkyBlue,
                    ],
                  )
                : const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF101720), Color(0xFF384959)],
                  ),
            borderRadius: BorderRadius.circular(
              isTablet ? 24 : AppConstants.radiusXLarge,
            ),
          ),
          child: Row(
            children: [
              UserAvatarWithFrame(
                avatarUrl: user?.avatarUrl ?? '',
                frameId: user?.equippedFrame ?? '',
                fallbackName: user?.name ?? '',
                size: isTablet ? 96 : AppConstants.avatarXLarge,
                showShadow: false,
              ),
              SizedBox(
                width: isTablet
                    ? AppConstants.paddingXLarge
                    : AppConstants.paddingLarge,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user?.name ?? 'ผู้ใช้',
                      style: TextStyle(
                        fontSize: isTablet ? 26 : 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textWhite,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? '',
                      style: TextStyle(
                        fontSize: isTablet ? 16 : 14,
                        color: Theme.of(context).brightness == Brightness.dark
                            ? AppColors.stormyIceBlue
                            : AppColors.textWhite.withValues(alpha: 0.8),
                      ),
                    ),
                    SizedBox(height: isTablet ? 14 : 10),
                    // XP Progress Bar with Animation — กดเพื่อเปิดเส้นทางรางวัล
                    InkWell(
                      enableFeedback: false,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => RewardsTimelineScreen(
                              currentLevel: displayLevel,
                            ),
                          ),
                        );
                      },
                      borderRadius: BorderRadius.circular(
                        isTablet
                            ? AppConstants.radiusMedium
                            : AppConstants.radiusSmall,
                      ),
                      splashColor: Colors.white24,
                      highlightColor: Colors.white10,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            displayLevel >= AppConstants.maxLevel
                                ? Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      '✨ MAX LEVEL ✨',
                                      style: TextStyle(
                                        color: Colors.amberAccent.shade100,
                                        fontWeight: FontWeight.bold,
                                        fontSize: isTablet ? 18 : 15,
                                        letterSpacing: 1.5,
                                        shadows: const [
                                          Shadow(
                                            color: Colors.amberAccent,
                                            blurRadius: 10,
                                          ),
                                        ],
                                      ),
                                    ),
                                  )
                                : TweenAnimationBuilder<double>(
                                    duration: const Duration(milliseconds: 500),
                                    curve: Curves.easeInOut,
                                    tween: Tween<double>(
                                      begin: 0,
                                      end: xpProgress,
                                    ),
                                    builder: (context, value, child) {
                                      return ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: LinearProgressIndicator(
                                          value: value,
                                          backgroundColor: Colors.white24,
                                          valueColor: AlwaysStoppedAnimation<
                                            Color
                                          >(
                                            Theme.of(context).brightness ==
                                                    Brightness.dark
                                                ? AppColors.stormySkyBlue
                                                : AppColors.stormyDeepBlue,
                                          ),
                                          minHeight: isTablet ? 9 : 6,
                                        ),
                                      );
                                    },
                                  ),
                            SizedBox(height: isTablet ? 14 : 12),
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isTablet ? 16 : 12,
                                    vertical: isTablet ? 6 : 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        Theme.of(context).brightness ==
                                                Brightness.dark
                                            ? Colors.white.withValues(alpha: 0.15)
                                            : AppColors.backgroundWhite.withValues(
                                                alpha: 0.2,
                                              ),
                                    borderRadius: BorderRadius.circular(
                                      isTablet
                                          ? AppConstants.radiusMedium
                                          : AppConstants.radiusSmall,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.star,
                                        size: isTablet ? 18 : 14,
                                        color: AppColors.accentYellow,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Level $displayLevel',
                                        style: TextStyle(
                                          fontSize: isTablet ? 15 : 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textWhite,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  size: isTablet ? 22 : 18,
                                  color: AppColors.textWhite.withValues(
                                    alpha: 0.6,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: isTablet ? 8 : 6),
                            Text(
                              displayLevelTitle,
                              style: TextStyle(
                                fontSize: isTablet ? 15 : 12,
                                fontWeight: FontWeight.w600,
                                color:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppColors.stormyIceBlue
                                        : AppColors.textWhite.withValues(
                                            alpha: 0.86,
                                          ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: 12,
          right: 12,
          child: IconButton(
            tooltip: 'Edit profile',
            icon: Icon(
              Icons.edit,
              color: AppColors.textWhite,
              size: isTablet ? 24 : 20,
            ),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.backgroundWhite.withValues(
                alpha: 0.18,
              ),
              padding: EdgeInsets.all(isTablet ? 12 : 8),
            ),
            onPressed: user == null
                ? null
                : () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const EditProfileScreen(),
                      ),
                    );
                  },
          ),
        ),
      ],
    );
  }

  Widget _buildStatsSection(
    User? user,
    TaskProvider taskProvider,
    ThemeData theme,
    bool isTablet,
  ) {
    return Container(
      padding: EdgeInsets.all(
        isTablet ? 26 : AppConstants.paddingLarge,
      ),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(
          isTablet ? 24 : AppConstants.radiusXLarge,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.light
                ? AppColors.shadowLight
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            theme: theme,
            icon: Icons.task_alt,
            value: '${user?.totalTasksCompleted ?? 0}',
            label: 'ภารกิจที่เสร็จ',
            color: theme.brightness == Brightness.light
                ? AppColors.stormyMutedBlueGrey
                : AppColors.stormySkyBlue,
            isTablet: isTablet,
          ),
          _buildStatItem(
            theme: theme,
            icon: Icons.local_fire_department,
            value: '${user?.streak ?? 0}',
            label: 'วันที่ต่อเนื่อง',
            color: AppColors.accentOrange,
            isTablet: isTablet,
          ),
          _buildStatItem(
            theme: theme,
            icon: Icons.star,
            value: '${user?.totalXP ?? 0}',
            label: 'XP ทั้งหมด',
            color: theme.brightness == Brightness.light
                ? AppColors.stormySkyBlue
                : AppColors.stormySkyBlue,
            isTablet: isTablet,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required ThemeData theme,
    required IconData icon,
    required String value,
    required String label,
    required Color color,
    required bool isTablet,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(isTablet ? 16 : 12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(
              isTablet ? 16 : AppConstants.radiusMedium,
            ),
          ),
          child: Icon(icon, color: color, size: isTablet ? 30 : 24),
        ),
        SizedBox(height: isTablet ? 10 : AppConstants.paddingSmall),
        Text(
          value,
          style: (theme.textTheme.headlineMedium ?? const TextStyle()).copyWith(
            fontSize: isTablet ? 32 : null,
            fontWeight: FontWeight.bold,
            color: theme.brightness == Brightness.dark ? Colors.white : null,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
            fontSize: isTablet ? 15 : null,
            color: theme.brightness == Brightness.dark
                ? AppColors.stormyMutedBlueGrey
                : null,
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection({
    required ThemeData theme,
    required String title,
    required List<Widget> children,
    required bool isTablet,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: (theme.textTheme.titleLarge ?? const TextStyle()).copyWith(
            fontSize: isTablet ? 22 : null,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: isTablet ? 12 : AppConstants.paddingSmall),
        Container(
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? AppColors.stormyDarkSlate
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(
              isTablet ? 22 : AppConstants.radiusLarge,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.brightness == Brightness.light
                    ? AppColors.shadowLight
                    : Colors.black.withValues(alpha: 0.3),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildSwitchTile({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required bool isTablet,
  }) {
    return SwitchListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: isTablet ? 20 : AppConstants.paddingMedium,
        vertical: isTablet ? 8 : AppConstants.paddingSmall / 2,
      ),
      secondary: Container(
        padding: EdgeInsets.all(isTablet ? 12 : 8),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.light
              ? AppColors.backgroundLightGrey
              : AppColors.stormyNightBackground,
          borderRadius: BorderRadius.circular(
            isTablet ? AppConstants.radiusMedium : AppConstants.radiusSmall,
          ),
        ),
        child: Icon(
          icon,
          size: isTablet ? 26 : 20,
          color: theme.brightness == Brightness.dark
              ? AppColors.stormyIceBlue
              : theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
      title: Text(
        title,
        style: (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
          fontSize: isTablet ? 18 : null,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
          fontSize: isTablet ? 14 : null,
        ),
      ),
      value: value,
      onChanged: onChanged,
      activeThumbColor: theme.brightness == Brightness.light
          ? AppColors.stormyOffWhite
          : Colors.white,
      activeTrackColor: theme.brightness == Brightness.light
          ? AppColors.stormyDarkSlate
          : AppColors.stormySkyBlue,
      inactiveThumbColor: theme.brightness == Brightness.light
          ? AppColors.stormyOffWhite
          : AppColors.stormyMutedBlueGrey,
      inactiveTrackColor: theme.brightness == Brightness.light
          ? AppColors.stormyIceBlue
          : AppColors.stormyNightBackground,
      trackOutlineColor: theme.brightness == Brightness.light
          ? WidgetStateProperty.all(Colors.transparent)
          : null,
    );
  }

  Widget _buildListTile({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isTablet,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: isTablet ? 20 : AppConstants.paddingMedium,
        vertical: isTablet ? 8 : AppConstants.paddingSmall / 2,
      ),
      leading: Container(
        padding: EdgeInsets.all(isTablet ? 12 : 8),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.light
              ? AppColors.backgroundLightGrey
              : AppColors.stormyNightBackground,
          borderRadius: BorderRadius.circular(
            isTablet ? AppConstants.radiusMedium : AppConstants.radiusSmall,
          ),
        ),
        child: Icon(
          icon,
          size: isTablet ? 26 : 20,
          color: theme.brightness == Brightness.dark
              ? AppColors.stormyIceBlue
              : theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
      ),
      title: Text(
        title,
        style: (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
          fontSize: isTablet ? 18 : null,
          fontWeight: FontWeight.w600,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        size: isTablet ? 26 : 20,
        color: theme.brightness == Brightness.dark
            ? AppColors.stormyMutedBlueGrey
            : theme.colorScheme.onSurface.withValues(alpha: 0.3),
      ),
      onTap: onTap,
    );
  }

  void _showLogoutConfirmationDialog(
    BuildContext context,
    AuthProvider authProvider,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTablet = MediaQuery.of(context).size.width >= 600;

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: isDark
              ? AppColors.stormyDarkSlate
              : Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isTablet ? 22 : 16),
          ),
          actionsPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 20 : 16,
            vertical: isTablet ? 16 : 12,
          ),
          title: Text(
            'ออกจากระบบ?',
            style: TextStyle(
              color: isDark ? AppColors.textWhite : AppColors.stormyDarkSlate,
              fontWeight: FontWeight.bold,
              fontSize: isTablet ? 22 : 18,
            ),
          ),
          content: Text(
            'คุณแน่ใจหรือไม่ว่าต้องการออกจากบัญชีของคุณ?',
            style: TextStyle(
              color: isDark
                  ? AppColors.stormyIceBlue
                  : AppColors.textSecondary,
              fontSize: isTablet ? 16 : 14.5,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
              },
              style: TextButton.styleFrom(
                foregroundColor: isDark
                    ? AppColors.stormySkyBlue
                    : AppColors.textSecondary,
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isTablet ? 12 : 10,
                ),
              ),
              child: Text(
                'ยกเลิก',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.stormySkyBlue,
                foregroundColor: isDark
                    ? AppColors.stormyNightBackground
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isTablet ? 12 : 10,
                ),
              ),
              onPressed: () async {
                Navigator.pop(dialogContext); // Close dialog
                await authProvider.signOut();
                if (context.mounted) {
                  // ignore: use_build_context_synchronously
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AuthGate()),
                    (route) => false,
                  );
                }
              },
              child: Text(
                'ออกจากระบบ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isTablet ? 16 : 14.5,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLogoutButton(AuthProvider authProvider, bool isTablet) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final primaryColor = isDark
        ? AppColors.stormySkyBlue
        : AppColors.stormyDarkSlate;
    final borderColor = isDark
        ? AppColors.stormySkyBlue.withValues(alpha: 0.3)
        : AppColors.stormyMutedBlueGrey.withValues(alpha: 0.3);
    final backgroundColor = isDark
        ? AppColors.stormyNightBackground.withValues(alpha: 0.6)
        : theme.cardColor;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () {
          _showLogoutConfirmationDialog(context, authProvider);
        },
        icon: Icon(
          Icons.logout_rounded,
          size: isTablet ? 24 : 20,
          color: primaryColor,
        ),
        label: Text(
          'ออกจากระบบ',
          style: TextStyle(
            color: primaryColor,
            fontSize: isTablet ? 18 : 15,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          side: BorderSide(color: borderColor, width: 1.2),
          overlayColor: primaryColor.withValues(alpha: 0.15),
          padding: const EdgeInsets.symmetric(
            vertical: AppConstants.paddingMedium,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          ),
        ),
      ),
    );
  }

  String _levelTitleFor(int level) {
    return thaiLevelTitle(level);
  }
}
