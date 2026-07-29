import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../config/colors.dart';
import '../config/constants.dart';
import '../models/achievement.dart';
import '../models/user.dart';
import '../screens/achievement_list_screen.dart';

class AchievementSummaryCard extends StatelessWidget {
  final User user;

  const AchievementSummaryCard({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final evaluation = evaluateAchievements(user);
    final unlockedCount = evaluation.unlockedCount;
    final totalCount = evaluation.totalCount;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        enableFeedback: false,
        borderRadius: BorderRadius.circular(AppConstants.radiusXLarge),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => AchievementListScreen(user: user),
            ),
          );
        },
        child: Ink(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? AppColors.stormyDarkSlate
                : theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(AppConstants.radiusXLarge),
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '🏅 ตราความสำเร็จ',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.brightness == Brightness.dark
                            ? Colors.white
                            : null,
                      ),
                    ),
                  ),
                  Text(
                    '$unlockedCount/$totalCount',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.brightness == Brightness.dark
                          ? AppColors.stormySkyBlue
                          : AppColors.stormyDarkSlate,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.paddingMedium),
              if (evaluation.unlocked.isEmpty)
                Text('ยังไม่มีตราที่ปลดล็อก', style: theme.textTheme.bodySmall)
              else
                Row(
                  children: evaluation.unlocked.take(4).map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(
                        right: AppConstants.paddingSmall,
                      ),
                      child: _AchievementPreviewIcon(
                        achievement: item.achievement,
                        isUnlocked: true,
                      ),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AchievementPreviewIcon extends StatelessWidget {
  final Achievement achievement;
  final bool isUnlocked;

  const _AchievementPreviewIcon({
    required this.achievement,
    required this.isUnlocked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final foregroundColor = isUnlocked
        ? achievement.color
        : theme.colorScheme.onSurface.withValues(alpha: 0.34);

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color:
            (isUnlocked && achievement.unlockedImagePath != null) ||
                (!isUnlocked && achievement.lockedImagePath != null)
            ? Colors.transparent
            : isUnlocked
            ? achievement.color.withValues(alpha: 0.12)
            : theme.colorScheme.onSurface.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: _buildPreviewImageOrIcon(foregroundColor),
    );
  }

  Widget _buildPreviewImageOrIcon(Color foregroundColor) {
    final imagePath = isUnlocked
        ? achievement.unlockedImagePath
        : achievement.lockedImagePath;

    if (imagePath != null && imagePath.isNotEmpty) {
      if (imagePath.endsWith('.svg')) {
        return SvgPicture.asset(
          imagePath,
          fit: BoxFit.contain,
          colorFilter: isUnlocked
              ? null
              : ColorFilter.mode(foregroundColor, BlendMode.srcIn),
        );
      } else {
        return Image.asset(
          imagePath,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return Icon(
              isUnlocked ? achievement.icon : Icons.lock_outline,
              color: foregroundColor,
              size: 22,
            );
          },
        );
      }
    }

    return Icon(
      isUnlocked ? achievement.icon : Icons.lock_outline,
      color: foregroundColor,
      size: 22,
    );
  }
}
