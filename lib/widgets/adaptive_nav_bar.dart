import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../utils/responsive.dart';

class AdaptiveNavBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback? onFabPressed;

  const AdaptiveNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.onFabPressed,
  });

  @override
  Widget build(BuildContext context) {
    final screenType = Responsive.getScreenType(context);

    if (screenType == ScreenType.desktop || screenType == ScreenType.tablet) {
      return _buildNavigationRail(context);
    } else {
      return _buildBottomNavigationBar(context);
    }
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.stormyNightBackground
            : theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.dark
                ? AppColors.stormyDarkSlate
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingMedium,
            vertical: AppConstants.paddingSmall,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              // Drawer Menu Button
              Material(
                color: Colors.transparent,
                child: InkWell(
                  enableFeedback: false,
                  onTap: () => Scaffold.of(context).openDrawer(),
                  borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Icon(
                      Icons.menu,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      size: 24,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final double tabWidth = constraints.maxWidth / 3;
                    return Stack(
                      children: [
                        // The Sliding Background Pill
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeInOut,
                          left: currentIndex * tabWidth,
                          top: 0,
                          bottom: 0,
                          child: Container(
                            width: tabWidth,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4.0,
                            ),
                            child: Container(
                              decoration: BoxDecoration(
                                color: theme.brightness == Brightness.light
                                    ? AppColors.stormyIceBlue
                                    : AppColors.stormySkyBlue.withValues(
                                        alpha: 0.15,
                                      ),
                                borderRadius: BorderRadius.circular(
                                  AppConstants.radiusLarge,
                                ),
                              ),
                            ),
                          ),
                        ),

                        // The Icons and Labels
                        Row(
                          children: [
                            _buildNavItem(
                              context,
                              icon: Icons.home_outlined,
                              activeIcon: Icons.home,
                              label: 'ภารกิจ',
                              labelThai: '',
                              index: 0,
                            ),
                            _buildNavItem(
                              context,
                              icon: Icons.calendar_month_outlined,
                              activeIcon: Icons.calendar_month,
                              label: 'ปฏิทิน',
                              labelThai: '',
                              index: 1,
                            ),
                            _buildNavItem(
                              context,
                              icon: Icons.settings_outlined,
                              activeIcon: Icons.settings,
                              label: 'ตั้งค่า',
                              labelThai: '',
                              index: 2,
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationRail(BuildContext context) {
    final theme = Theme.of(context);
    return NavigationRail(
      extended: Responsive.isDesktop(context),
      minWidth: 80,
      backgroundColor: theme.colorScheme.surface,
      elevation: 2,
      selectedIndex: currentIndex,
      onDestinationSelected: onTap,
      leading: Expanded(
        child: Column(
          children: [
            const SizedBox(height: 16),
            IconButton(
              icon: Icon(Icons.menu, color: theme.colorScheme.onSurface),
              onPressed: () => Scaffold.of(context).openDrawer(),
            ),
            const SizedBox(height: 16),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.check,
                color: AppColors.textWhite,
                size: 28,
              ),
            ),
            if (Responsive.isDesktop(context)) ...[
              const SizedBox(height: 8),
              Text(
                'ตัวจัดการ\nภารกิจ',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ],
        ),
      ),
      trailing: Responsive.isDesktop(context) && onFabPressed != null
          ? Expanded(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: FloatingActionButton(
                    onPressed: onFabPressed,
                    backgroundColor: AppColors.primaryPink,
                    child: const Icon(Icons.add),
                  ),
                ),
              ),
            )
          : null,
      destinations: [
        _buildNavDestination(
          icon: Icons.home_outlined,
          activeIcon: Icons.home,
          label: 'ภารกิจ',
          labelThai: '',
        ),
        _buildNavDestination(
          icon: Icons.calendar_month_outlined,
          activeIcon: Icons.calendar_month,
          label: 'ปฏิทิน',
          labelThai: '',
        ),
        _buildNavDestination(
          icon: Icons.settings_outlined,
          activeIcon: Icons.settings,
          label: 'ตั้งค่า',
          labelThai: '',
        ),
      ],
    );
  }

  NavigationRailDestination _buildNavDestination({
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String labelThai,
  }) {
    return NavigationRailDestination(
      icon: Icon(icon, size: 24),
      selectedIcon: Icon(activeIcon, size: 24),
      label: Column(
        children: [
          Text(label),
          if (labelThai.isNotEmpty)
            Text(labelThai, style: const TextStyle(fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    BuildContext context, {
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required String labelThai,
    required int index,
  }) {
    final theme = Theme.of(context);
    final isSelected = currentIndex == index;
    final isLight = theme.brightness == Brightness.light;
    final color = isSelected
        ? (isLight ? AppColors.stormyDarkSlate : AppColors.stormySkyBlue)
        : (isLight
              ? AppColors.stormyMutedBlueGrey
              : AppColors.stormyMutedBlueGrey);

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onTap(index),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingMedium,
            vertical: AppConstants.paddingSmall,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
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
                        ? (isLight
                              ? AppColors.stormyDarkSlate.withValues(alpha: 0.8)
                              : AppColors.primaryPink.withValues(alpha: 0.8))
                        : (isLight
                              ? AppColors.stormyMutedBlueGrey.withValues(
                                  alpha: 0.7,
                                )
                              : AppColors.textLight),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
