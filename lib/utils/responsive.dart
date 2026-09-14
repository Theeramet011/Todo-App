import 'package:flutter/material.dart';

enum ScreenType { mobile, tablet, desktop }

class Responsive {
  static double screenWidth(BuildContext context) =>
      MediaQuery.of(context).size.width;
  static double screenHeight(BuildContext context) =>
      MediaQuery.of(context).size.height;

  // Screen Type Classification
  static ScreenType getScreenType(BuildContext context) {
    final width = screenWidth(context);
    if (width < 600) return ScreenType.mobile;
    if (width < 1200) return ScreenType.tablet;
    return ScreenType.desktop;
  }

  static bool isMobile(BuildContext context) =>
      getScreenType(context) == ScreenType.mobile;
  static bool isTablet(BuildContext context) =>
      getScreenType(context) == ScreenType.tablet;
  static bool isDesktop(BuildContext context) =>
      getScreenType(context) == ScreenType.desktop;

  // Responsive Padding
  static double responsivePadding(BuildContext context) {
    final type = getScreenType(context);
    switch (type) {
      case ScreenType.mobile:
        return 12.0;
      case ScreenType.tablet:
        return 16.0;
      case ScreenType.desktop:
        return 24.0;
    }
  }

  // Responsive Font Size
  static double responsiveFontSize(
    BuildContext context, {
    double baseSize = 16.0,
  }) {
    final type = getScreenType(context);
    switch (type) {
      case ScreenType.mobile:
        return baseSize * 0.9;
      case ScreenType.tablet:
        return baseSize;
      case ScreenType.desktop:
        return baseSize * 1.1;
    }
  }

  // Responsive Radius
  static double responsiveRadius(
    BuildContext context, {
    double baseRadius = 12.0,
  }) {
    final type = getScreenType(context);
    switch (type) {
      case ScreenType.mobile:
        return baseRadius;
      case ScreenType.tablet:
        return baseRadius * 1.1;
      case ScreenType.desktop:
        return baseRadius * 1.2;
    }
  }

  // Max Content Width for Desktop
  static double maxContentWidth(BuildContext context) {
    final type = getScreenType(context);
    switch (type) {
      case ScreenType.mobile:
        return screenWidth(context);
      case ScreenType.tablet:
        return double.infinity;
      case ScreenType.desktop:
        return 900.0;
    }
  }

  // Card Max Width
  static double cardMaxWidth(BuildContext context) {
    final type = getScreenType(context);
    switch (type) {
      case ScreenType.mobile:
        return double.infinity;
      case ScreenType.tablet:
        return 500.0;
      case ScreenType.desktop:
        return 600.0;
    }
  }

  // Navigation Rail Width
  static double navigationRailWidth(BuildContext context) {
    final type = getScreenType(context);
    switch (type) {
      case ScreenType.desktop:
        return 200.0;
      case ScreenType.tablet:
        return 180.0;
      default:
        return 0.0;
    }
  }

  // Cross Axis Count for Grids
  static int crossAxisCount(BuildContext context) {
    final type = getScreenType(context);
    switch (type) {
      case ScreenType.mobile:
        return 1;
      case ScreenType.tablet:
        return 2;
      case ScreenType.desktop:
        return 3;
    }
  }

  // Should use Navigation Rail
  static bool useNavigationRail(BuildContext context) {
    return isTablet(context) || isDesktop(context);
  }

  // Should use Drawer
  static bool useDrawer(BuildContext context) {
    return true;
  }

  // Responsive Builder
  static Widget responsiveBuilder(
    BuildContext context, {
    required Widget mobile,
    Widget? tablet,
    Widget? desktop,
  }) {
    final type = getScreenType(context);
    switch (type) {
      case ScreenType.mobile:
        return mobile;
      case ScreenType.tablet:
        return tablet ?? mobile;
      case ScreenType.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }

  // Center Content for Large Screens
  static Widget centerContent(BuildContext context, Widget child) {
    final type = getScreenType(context);
    if (type == ScreenType.mobile || type == ScreenType.tablet) {
      return child;
    }
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxContentWidth(context)),
        child: child,
      ),
    );
  }
}
