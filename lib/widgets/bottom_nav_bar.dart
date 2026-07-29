import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../config/constants.dart';

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.light
                ? AppColors.shadowLight
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingMedium,
          vertical: AppConstants.paddingSmall,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(
              context: context,
              icon: Icons.home_outlined,
              activeIcon: Icons.home,
              label: 'ภารกิจ',
              labelThai: '',
              index: 0,
            ),
            _buildNavItem(
              context: context,
              icon: Icons.calendar_month_outlined,
              activeIcon: Icons.calendar_month,
              label: 'ปฏิทิน',
              labelThai: '',
              index: 1,
            ),
            _buildNavItem(
              context: context,
              icon: Icons.settings_outlined,
              activeIcon: Icons.settings,
              label: 'ตั้งค่า',
              labelThai: '',
              index: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String labelThai,
    required int index,
  }) {
    final theme = Theme.of(context);
    final isSelected = currentIndex == index;
    final color = isSelected
        ? AppColors.primaryPink
        : theme.colorScheme.onSurface.withValues(alpha: 0.5);

    return Expanded(
      child: InkWell(
        enableFeedback: false,
        onTap: () => onTap(index),
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingMedium,
            vertical: AppConstants.paddingSmall,
          ),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primaryPink.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isSelected ? activeIcon : icon, size: 24, color: color),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: color,
                ),
              ),
              if (labelThai.isNotEmpty)
                Text(
                  labelThai,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: isSelected
                        ? FontWeight.w500
                        : FontWeight.normal,
                    color: isSelected
                        ? AppColors.primaryPink.withValues(alpha: 0.8)
                        : AppColors.textLight,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
