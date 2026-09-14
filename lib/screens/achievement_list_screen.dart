// AchievementListScreen - หน้าจอแสดงรายการความสำเร็จ (Achievements) ของผู้ใช้
//
// แสดงรายการความสำเร็จทั้งหมด แบ่งตามสถานะปลดล็อก (Unlocked) และยังไม่ปลดล็อก (Locked)
// พร้อมรายละเอียดเงื่อนไข ระดับ และความคืบหน้าในการสะสมความสำเร็จ
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config/colors.dart';
import '../config/constants.dart';
import '../models/achievement.dart';
import '../models/user.dart';

class AchievementListScreen extends StatelessWidget {
  final User user;

  const AchievementListScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final unlockedAchievements = availableAchievements
        .where((achievement) => isAchievementUnlocked(user, achievement))
        .toList();
    final lockedAchievements = availableAchievements
        .where((achievement) => !isAchievementUnlocked(user, achievement))
        .toList();

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? AppColors.stormyNightBackground
          : theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Screen Header
            SliverToBoxAdapter(child: _buildHeader(context, theme, isTablet)),

            // Section 1: Unlocked Achievements
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 24 : AppConstants.paddingMedium,
              ),
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppConstants.paddingSmall,
                  ),
                  child: _buildSectionTitle(
                    theme,
                    'ปลดล็อกแล้ว',
                    '${unlockedAchievements.length} รายการ',
                    isTablet,
                  ),
                ),
              ),
            ),

            if (unlockedAchievements.isEmpty)
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 24 : AppConstants.paddingMedium,
                ),
                sliver: SliverToBoxAdapter(
                  child: _buildEmptyUnlockedCard(theme),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 24 : AppConstants.paddingMedium,
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: isTablet ? 20 : 16,
                    crossAxisSpacing: isTablet ? 20 : 16,
                    childAspectRatio: isTablet ? 0.92 : 0.70,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return _AchievementCard(
                      user: user,
                      achievement: unlockedAchievements[index],
                      isUnlocked: true,
                    );
                  }, childCount: unlockedAchievements.length),
                ),
              ),

            // Spacing between sections
            SliverToBoxAdapter(
              child: SizedBox(height: isTablet ? 28 : AppConstants.paddingLarge),
            ),

            // Section 2: Locked Achievements
            SliverPadding(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 24 : AppConstants.paddingMedium,
              ),
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(
                    bottom: AppConstants.paddingSmall,
                  ),
                  child: _buildSectionTitle(
                    theme,
                    'ยังไม่ปลดล็อก',
                    '${lockedAchievements.length} รายการ',
                    isTablet,
                  ),
                ),
              ),
            ),

            if (lockedAchievements.isEmpty)
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 24 : AppConstants.paddingMedium,
                ),
                sliver: SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AppConstants.paddingLarge),
                      child: Text(
                        'ปลดล็อกครบหมดทุกตราแล้ว! 🎉',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: AppColors.success,
                        ),
                      ),
                    ),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 24 : AppConstants.paddingMedium,
                ),
                sliver: SliverGrid(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: isTablet ? 20 : 16,
                    crossAxisSpacing: isTablet ? 20 : 16,
                    childAspectRatio: isTablet ? 0.92 : 0.70,
                  ),
                  delegate: SliverChildBuilderDelegate((context, index) {
                    return _AchievementCard(
                      user: user,
                      achievement: lockedAchievements[index],
                      isUnlocked: false,
                    );
                  }, childCount: lockedAchievements.length),
                ),
              ),

            // Safe bottom spacing
            const SliverToBoxAdapter(
              child: SizedBox(height: AppConstants.paddingLarge),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, bool isTablet) {
    return Padding(
      padding: EdgeInsets.all(isTablet ? 24 : AppConstants.paddingMedium),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back, size: isTablet ? 28 : 24),
          ),
          SizedBox(width: isTablet ? 12 : AppConstants.paddingSmall),
          Container(
            padding: EdgeInsets.all(isTablet ? 16 : 12),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.light
                  ? AppColors.stormySkyBlue
                  : AppColors.primaryPurple.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(
                isTablet ? 16 : AppConstants.radiusMedium,
              ),
              border: theme.brightness == Brightness.dark
                  ? Border.all(color: AppColors.primaryPurple, width: 2)
                  : null,
            ),
            child: Icon(
              Icons.workspace_premium,
              color: theme.brightness == Brightness.light
                  ? AppColors.textWhite
                  : AppColors.primaryPurple,
              size: isTablet ? 30 : 24,
            ),
          ),
          SizedBox(width: isTablet ? 18 : AppConstants.paddingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ตราความสำเร็จ',
                  style: TextStyle(
                    fontSize: isTablet ? 26 : 22,
                    fontWeight: FontWeight.bold,
                    color: theme.brightness == Brightness.dark
                        ? Colors.white
                        : theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  user.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    color: theme.brightness == Brightness.dark
                        ? AppColors.stormyIceBlue
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(
    ThemeData theme,
    String title,
    String countText,
    bool isTablet,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              fontSize: isTablet ? 22 : 18,
              color: theme.brightness == Brightness.dark ? Colors.white : null,
            ),
          ),
        ),
        Text(
          countText,
          style: theme.textTheme.bodySmall?.copyWith(
            fontSize: isTablet ? 15 : 12,
            color: theme.brightness == Brightness.dark
                ? AppColors.stormyIceBlue
                : theme.colorScheme.onSurface.withValues(alpha: 0.58),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyUnlockedCard(ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
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
      child: Text(
        'ยังไม่มีตราที่ปลดล็อก',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.62),
        ),
      ),
    );
  }
}

class _AchievementCard extends StatelessWidget {
  final User user;
  final Achievement achievement;
  final bool isUnlocked;

  const _AchievementCard({
    required this.user,
    required this.achievement,
    required this.isUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final progress = achievementProgressValue(user, achievement);
    final cappedProgress = progress.clamp(0, achievement.targetValue).toInt();
    final progressValue = achievement.targetValue == 0
        ? 0.0
        : cappedProgress / achievement.targetValue;
    final unit = achievementProgressUnit(achievement);
    final foregroundColor = isUnlocked
        ? achievement.color
        : theme.colorScheme.onSurface.withValues(alpha: 0.38);

    final isDark = theme.brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        enableFeedback: false,
        borderRadius: BorderRadius.circular(
          isTablet ? 24 : AppConstants.radiusLarge,
        ),
        onTap: () => _showAchievementDetailDialog(
          context,
          achievement: achievement,
          isUnlocked: isUnlocked,
          cappedProgress: cappedProgress,
          progressValue: progressValue,
          unit: unit,
        ),
        child: Container(
          padding: EdgeInsets.all(isTablet ? 18 : 12),
          decoration: BoxDecoration(
            color: isDark
                ? (isUnlocked ? AppColors.stormyDarkSlate : Colors.transparent)
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(
              isTablet ? 24 : AppConstants.radiusLarge,
            ),
            border: isDark && isUnlocked
                ? null
                : Border.all(
                    color: isDark
                        ? (isUnlocked
                              ? Colors.transparent
                              : AppColors.stormyMutedBlueGrey)
                        : (isUnlocked
                              ? achievement.color.withValues(alpha: 0.15)
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.06,
                                )),
                    width: isDark ? 1 : 1.5,
                  ),
            boxShadow: [
              if (!isDark)
                BoxShadow(
                  color: AppColors.shadowLight,
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              if (isDark && isUnlocked)
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Badge Image
              Container(
                width: isTablet ? 130 : 92,
                height: isTablet ? 130 : 92,
                decoration: BoxDecoration(
                  color:
                      (isUnlocked && achievement.unlockedImagePath != null) ||
                          (!isUnlocked && achievement.lockedImagePath != null)
                      ? Colors.transparent
                      : foregroundColor.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                padding:
                    (isUnlocked && achievement.unlockedImagePath != null) ||
                        (!isUnlocked && achievement.lockedImagePath != null)
                    ? EdgeInsets.zero
                    : EdgeInsets.all(isTablet ? 22 : 16),
                child: _buildBadgeImageOrIcon(foregroundColor, isTablet),
              ),
              SizedBox(height: isTablet ? 14 : 10),
              // Achievement Title
              Text(
                achievement.title,
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isTablet ? 18 : 14,
                  color: isDark
                      ? (isUnlocked ? Colors.white : AppColors.stormyIceBlue)
                      : null,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: isTablet ? 14 : 12),
              // Bottom Progress/Status Area
              if (isUnlocked)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.check_circle,
                      size: isTablet ? 18 : 12,
                      color: isDark
                          ? const Color(0xFF81C784)
                          : AppColors.success,
                    ),
                    SizedBox(width: isTablet ? 6 : 4),
                    Text(
                      'สำเร็จแล้ว',
                      style: TextStyle(
                        fontSize: isTablet ? 15 : 11,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? const Color(0xFF81C784)
                            : AppColors.success,
                      ),
                    ),
                  ],
                )
              else ...[
                // Progress Indicator
                ClipRRect(
                  borderRadius: BorderRadius.circular(isTablet ? 4 : 2),
                  child: LinearProgressIndicator(
                    value: progressValue,
                    minHeight: isTablet ? 6 : 4,
                    backgroundColor: isDark
                        ? AppColors.stormyDarkSlate
                        : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isDark ? AppColors.stormySkyBlue : achievement.color,
                    ),
                  ),
                ),
                SizedBox(height: isTablet ? 6 : 4),
                Text(
                  '$cappedProgress/${achievement.targetValue} $unit',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: isTablet ? 13 : 10,
                    fontWeight: FontWeight.w600,
                    color: isDark
                        ? AppColors.stormyMutedBlueGrey
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadgeImageOrIcon(Color foregroundColor, bool isTablet) {
    final imagePath = isUnlocked
        ? achievement.unlockedImagePath
        : achievement.lockedImagePath;

    Widget badgeWidget;
    if (imagePath != null && imagePath.isNotEmpty) {
      if (imagePath.endsWith('.svg')) {
        badgeWidget = SvgPicture.asset(imagePath, fit: BoxFit.contain);
      } else {
        badgeWidget = Image.asset(
          imagePath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              isUnlocked ? achievement.icon : Icons.lock_outline,
              color: foregroundColor,
              size: isTablet ? 52 : 32,
            );
          },
        );
      }
    } else {
      badgeWidget = Icon(
        isUnlocked ? achievement.icon : Icons.lock_outline,
        color: foregroundColor,
        size: isTablet ? 52 : 32,
      );
    }

    if (!isUnlocked) {
      // Grayscale Filter + 0.4 Opacity for locked state
      badgeWidget = ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0.2126,
          0.7152,
          0.0722,
          0,
          0,
          0,
          0,
          0,
          1,
          0,
        ]),
        child: Opacity(opacity: 0.4, child: badgeWidget),
      );
    }

    // Scale up other badges to match the max_level badge's visual size
    if (imagePath != null &&
        imagePath.isNotEmpty &&
        achievement.id != 'max_level') {
      return Transform.scale(scale: 1.5, child: badgeWidget);
    }

    return badgeWidget;
  }
}

// Dialog helper to show full achievement description
void _showAchievementDetailDialog(
  BuildContext context, {
  required Achievement achievement,
  required bool isUnlocked,
  required int cappedProgress,
  required double progressValue,
  required String unit,
}) {
  final theme = Theme.of(context);
  final isTablet = MediaQuery.of(context).size.width >= 600;

  showDialog(
    context: context,
    builder: (context) {
      final isDark = theme.brightness == Brightness.dark;
      return Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
            isTablet ? 28 : AppConstants.radiusXLarge,
          ),
        ),
        elevation: 16,
        backgroundColor: isDark
            ? AppColors.stormyDarkSlate
            : theme.colorScheme.surface,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: isTablet ? 480 : double.infinity,
          ),
          child: Container(
            padding: EdgeInsets.all(isTablet ? 28 : AppConstants.paddingLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Badge Image in Dialog (Circular frame)
                Container(
                  width: isTablet ? 150 : 120,
                  height: isTablet ? 150 : 120,
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.stormyNightBackground
                        : (isUnlocked
                              ? achievement.color.withValues(alpha: 0.1)
                              : theme.colorScheme.onSurface.withValues(
                                  alpha: 0.05,
                                )),
                    shape: BoxShape.circle,
                  ),
                  padding:
                      (isUnlocked && achievement.unlockedImagePath != null) ||
                          (!isUnlocked && achievement.lockedImagePath != null)
                      ? EdgeInsets.zero
                      : EdgeInsets.all(isTablet ? 26 : 20),
                  child: _buildBadgeImageOrIconForDialog(achievement, isUnlocked),
                ),
                SizedBox(height: isTablet ? 20 : AppConstants.paddingMedium),
                // Title
                Text(
                  achievement.title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: isTablet ? 26 : null,
                    color: isDark ? Colors.white : theme.colorScheme.onSurface,
                  ),
                ),
                SizedBox(height: isTablet ? 14 : AppConstants.paddingMedium),
                // Description
                Text(
                  achievement.description,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontSize: isTablet ? 16 : null,
                    color: isDark
                        ? AppColors.stormyIceBlue
                        : theme.colorScheme.onSurface.withValues(alpha: 0.75),
                    height: 1.4,
                  ),
                ),
                SizedBox(height: isTablet ? 24 : AppConstants.paddingLarge),
                // Progress or Unlocked Banner
                if (isUnlocked)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(
                      isTablet ? 18 : AppConstants.paddingMedium,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF81C784).withValues(alpha: 0.15)
                          : AppColors.success.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(
                        isTablet ? 16 : AppConstants.radiusMedium,
                      ),
                      border: isDark
                          ? null
                          : Border.all(
                              color: AppColors.success.withValues(alpha: 0.2),
                              width: 1,
                            ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: isTablet ? 24 : 20,
                          color: isDark
                              ? const Color(0xFF81C784)
                              : AppColors.success,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            'ปลดล็อกความสำเร็จเรียบร้อยแล้ว!',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontSize: isTablet ? 16 : null,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? const Color(0xFF81C784)
                                  : AppColors.success,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else ...[
                  // Locked progress UI
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'ความคืบหน้าการปลดล็อก: $cappedProgress/${achievement.targetValue} $unit',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: isTablet ? 14 : null,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ),
                  SizedBox(height: isTablet ? 10 : 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(
                      isTablet ? 6 : AppConstants.radiusSmall,
                    ),
                    child: LinearProgressIndicator(
                      value: progressValue,
                      minHeight: isTablet ? 10 : 8,
                      backgroundColor: theme.colorScheme.onSurface.withValues(
                        alpha: 0.08,
                      ),
                      valueColor: AlwaysStoppedAnimation<Color>(
                        achievement.color,
                      ),
                    ),
                  ),
                  SizedBox(height: isTablet ? 14 : 12),
                  //ต้องแก้ส่วนปลดล๊อกเลเวลสูงสุดแยกกัน
                  Text(
                    achievement.type == 'level'
                        ? 'เหลืออีก ${achievement.targetValue - cappedProgress} Level เพื่อปลดล็อกตรานี้'
                        : 'ทำอีกเพียง ${achievement.targetValue - cappedProgress} $unit เพื่อปลดล็อกตรานี้',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: isTablet ? 14 : null,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
                SizedBox(height: isTablet ? 24 : AppConstants.paddingLarge),
                // Close Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.stormySkyBlue,
                      foregroundColor: isDark
                          ? AppColors.stormyNightBackground
                          : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          isTablet ? 16 : AppConstants.radiusMedium,
                        ),
                      ),
                      padding: EdgeInsets.symmetric(
                        vertical: isTablet ? 18 : 14,
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'ปิด',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: isTablet ? 17 : 15,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Widget _buildBadgeImageOrIconForDialog(
  Achievement achievement,
  bool isUnlocked,
) {
  final imagePath = isUnlocked
      ? achievement.unlockedImagePath
      : achievement.lockedImagePath;

  Widget badgeWidget;
  if (imagePath != null && imagePath.isNotEmpty) {
    if (imagePath.endsWith('.svg')) {
      badgeWidget = SvgPicture.asset(imagePath, fit: BoxFit.contain);
    } else {
      badgeWidget = Image.asset(
        imagePath,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Icon(
            isUnlocked ? achievement.icon : Icons.lock_outline,
            color: isUnlocked ? achievement.color : Colors.grey,
            size: 48,
          );
        },
      );
    }
  } else {
    badgeWidget = Icon(
      isUnlocked ? achievement.icon : Icons.lock_outline,
      color: isUnlocked ? achievement.color : Colors.grey,
      size: 48,
    );
  }

  if (!isUnlocked) {
    // Return locked version with grayscale inside the dialog as well for consistency
    badgeWidget = ColorFiltered(
      colorFilter: const ColorFilter.matrix(<double>[
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0.2126,
        0.7152,
        0.0722,
        0,
        0,
        0,
        0,
        0,
        1,
        0,
      ]),
      child: Opacity(opacity: 0.4, child: badgeWidget),
    );
  }

  // Scale up other badges to match the max_level badge's visual size
  if (imagePath != null &&
      imagePath.isNotEmpty &&
      achievement.id != 'max_level') {
    return Transform.scale(scale: 1.5, child: badgeWidget);
  }

  return badgeWidget;
}
