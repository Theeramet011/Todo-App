import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/colors.dart';
import '../config/constants.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../screens/bin_screen.dart';
import '../screens/completed_tasks_screen.dart';
import '../screens/friends_screen.dart';
import '../widgets/user_avatar_with_frame.dart';
import '../utils/tutorial_service.dart';

class CustomDrawer extends StatelessWidget {
  const CustomDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.currentUser;
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Container(
      width: math.min(
        MediaQuery.of(context).size.width * 0.85,
        isTablet ? 420.0 : 360.0,
      ),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.stormyNightBackground
            : theme.colorScheme.surface,
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(
            isTablet ? 32 : AppConstants.radiusXLarge,
          ),
          bottomRight: Radius.circular(
            isTablet ? 32 : AppConstants.radiusXLarge,
          ),
        ),
      ),
      child: Column(
        children: [
          _buildHeader(context, user, isTablet),
          Expanded(
            child: SafeArea(
              top: false,
              child: ListView(
                padding: EdgeInsets.symmetric(
                  vertical: isTablet ? 20 : AppConstants.paddingMedium,
                ),
                children: [
                  _buildMenuItem(
                    context,
                    icon: Icons.calendar_today,
                    title: 'ภารกิจเร็วๆนี้',
                    isTablet: isTablet,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.pushNamed(context, '/upcoming');
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.people_outline,
                    title: 'เพื่อน',
                    isTablet: isTablet,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FriendsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.check_circle_outline,
                    title: 'ภารกิจที่เสร็จแล้ว',
                    isTablet: isTablet,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const CompletedTasksScreen(),
                        ),
                      );
                    },
                  ),
                  _buildMenuItem(
                    context,
                    icon: Icons.delete_outline,
                    title: 'ถังขยะ',
                    isTablet: isTablet,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const BinScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context, User? user, bool isTablet) {
    final topPadding = MediaQuery.of(context).padding.top;
    final taskProvider = context.watch<TaskProvider>();

    final displayLevel = user?.currentLevel ?? taskProvider.currentLevel;
    final xpProgress = user == null || user.nextLevelPoints == 0
        ? taskProvider.xpProgress
        : user.progressToNextLevelValue;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(
        isTablet ? 28 : AppConstants.paddingLarge,
        topPadding + (isTablet ? 24 : AppConstants.paddingMedium),
        isTablet ? 28 : AppConstants.paddingLarge,
        isTablet ? 24 : AppConstants.paddingLarge,
      ),
      decoration: BoxDecoration(
        gradient: Theme.of(context).brightness == Brightness.light
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.stormyDarkSlate, AppColors.stormySkyBlue],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF101720), AppColors.stormyDarkSlate],
              ),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(AppConstants.radiusXLarge),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: UserAvatarWithFrame(
              avatarUrl: user?.avatarUrl ?? '',
              frameId: user?.equippedFrame ?? '',
              fallbackName: user?.name ?? 'Guest User',
              size: isTablet ? 96 : AppConstants.avatarXLarge,
            ),
          ),
          SizedBox(height: isTablet ? 20 : AppConstants.paddingMedium),
          Text(
            user?.name ?? 'Guest User',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isTablet ? 24 : 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textWhite,
            ),
          ),
          SizedBox(height: isTablet ? 6 : 4),
          Text(
            user?.email ?? '',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isTablet ? 15 : 12,
              color: AppColors.textWhite.withValues(alpha: 0.8),
            ),
          ),
          SizedBox(height: isTablet ? 16 : 12),
          Container(
            key: TutorialService.levelKey,
            child: displayLevel >= AppConstants.maxLevel
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    alignment: Alignment.center,
                    child: Text(
                      '✨ MAX LEVEL ✨',
                      style: TextStyle(
                        color: Colors.amberAccent.shade100,
                        fontWeight: FontWeight.bold,
                        fontSize: isTablet ? 18 : 15,
                        letterSpacing: 1.5,
                        shadows: const [
                          Shadow(color: Colors.amberAccent, blurRadius: 10),
                        ],
                      ),
                    ),
                  )
                : TweenAnimationBuilder<double>(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeOutCubic,
                    tween: Tween<double>(begin: 0, end: xpProgress),
                    builder: (context, value, child) {
                      return SizedBox(
                        width: double.infinity,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: LinearProgressIndicator(
                            value: value,
                            backgroundColor: Colors.white24,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.stormySkyBlue
                                  : AppColors.stormyDeepBlue,
                            ),
                            minHeight: isTablet ? 10 : 8,
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(height: isTablet ? 10 : 8),
          Center(
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : 12,
                vertical: isTablet ? 6 : 4,
              ),
              decoration: BoxDecoration(
                color: AppColors.backgroundWhite.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
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
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    required bool isTablet,
  }) {
    final theme = Theme.of(context);

    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: isTablet ? 24 : 16,
        vertical: isTablet ? 4 : 0,
      ),
      leading: Container(
        padding: EdgeInsets.all(isTablet ? 12 : 8),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.light
              ? AppColors.backgroundLightGrey
              : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(
            isTablet ? 12 : AppConstants.radiusSmall,
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
        style: TextStyle(
          fontSize: isTablet ? 18 : 15,
          fontWeight: FontWeight.w500,
          color: theme.brightness == Brightness.dark
              ? AppColors.textWhite
              : theme.colorScheme.onSurface,
        ),
      ),
      trailing: Icon(
        Icons.chevron_right,
        size: isTablet ? 26 : 22,
        color: theme.brightness == Brightness.dark
            ? AppColors.stormyIceBlue.withValues(alpha: 0.5)
            : theme.colorScheme.onSurface.withValues(alpha: 0.3),
      ),
      onTap: onTap,
    );
  }
}
