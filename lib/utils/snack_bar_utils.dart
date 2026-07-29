import 'package:flutter/material.dart';
import '../config/colors.dart';

class SnackBarUtils {
  static void _showCustomSnackBar(
    BuildContext context, {
    required String message,
    required String actionLabel,
    required VoidCallback onActionPressed,
    double bottomMargin = 16.0,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final snackBar = SnackBar(
      backgroundColor: isDark ? AppColors.stormyDarkSlate : Colors.white,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: EdgeInsets.only(left: 16, right: 16, bottom: bottomMargin),
      duration: const Duration(seconds: 4),
      elevation: 4,
      dismissDirection: DismissDirection.horizontal,
      content: Text(
        message,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
      action: SnackBarAction(
        label: actionLabel,
        textColor: isDark ? AppColors.stormySkyBlue : theme.colorScheme.primary,
        onPressed: onActionPressed,
      ),
    );

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    final controller = messenger.showSnackBar(snackBar);

    // Force the SnackBar to close after 5 seconds to bypass any system accessibility overrides
    Future.delayed(const Duration(seconds: 5), () {
      try {
        controller.close();
      } catch (_) {
        // Ignored if already closed
      }
    });
  }

  static void showUndoSnackBar(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
    double bottomMargin = 16.0,
  }) {
    _showCustomSnackBar(
      context,
      message: message,
      actionLabel: 'เลิกทำ',
      onActionPressed: onUndo,
      bottomMargin: bottomMargin,
    );
  }

  static void showNavigationSnackBar(
    BuildContext context, {
    required String message,
    required String actionLabel,
    required VoidCallback onNavigate,
    double bottomMargin = 16.0,
  }) {
    _showCustomSnackBar(
      context,
      message: message,
      actionLabel: '$actionLabel >',
      onActionPressed: onNavigate,
      bottomMargin: bottomMargin,
    );
  }
}
