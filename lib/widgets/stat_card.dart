import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../config/constants.dart';

enum StatType { level, xp, completed, currentStreak, maxStreak }

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final StatType type;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Color bg;
    Color iconColor;

    switch (type) {
      case StatType.level:
        bg = isDark
            ? const Color(0xFFFFE082).withValues(alpha: 0.15)
            : const Color(0xFFFFF8E1);
        iconColor = isDark ? const Color(0xFFFFE082) : const Color(0xFFFFB300);
        break;
      case StatType.xp:
        bg = isDark
            ? const Color(0xFFCE93D8).withValues(alpha: 0.15)
            : const Color(0xFFF3E5F5);
        iconColor = isDark ? const Color(0xFFCE93D8) : const Color(0xFFAB47BC);
        break;
      case StatType.completed:
        bg = isDark
            ? const Color(0xFF81C784).withValues(alpha: 0.15)
            : const Color(0xFFE8F5E9);
        iconColor = isDark ? const Color(0xFF81C784) : const Color(0xFF4CAF50);
        break;
      case StatType.currentStreak:
        bg = isDark
            ? const Color(0xFFFF8A65).withValues(alpha: 0.15)
            : const Color(0xFFFBE9E7);
        iconColor = isDark ? const Color(0xFFFF8A65) : const Color(0xFFFF7043);
        break;
      case StatType.maxStreak:
        bg = isDark
            ? const Color(0xFF4DD0E1).withValues(alpha: 0.15)
            : const Color(0xFFE0F7FA);
        iconColor = isDark ? const Color(0xFF4DD0E1) : const Color(0xFF00ACC1);
        break;
    }

    return Container(
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: isDark ? AppColors.stormyDarkSlate : Colors.white,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        border: isDark ? null : Border.all(color: AppColors.stormyIceBlue),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: AppColors.shadowLight,
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, color: iconColor, size: 24),
          ),
          const SizedBox(height: AppConstants.paddingSmall),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : AppColors.stormyDarkSlate,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: isDark
                  ? Colors.white70
                  : AppColors.stormyDarkSlate.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}
