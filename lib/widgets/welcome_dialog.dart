import 'package:flutter/material.dart';
import '../config/colors.dart';

class WelcomeDialog extends StatelessWidget {
  const WelcomeDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Dialog(
      backgroundColor: theme.brightness == Brightness.dark
          ? AppColors.stormyDarkSlate
          : theme.cardColor,
      insetPadding: EdgeInsets.symmetric(
        horizontal: isTablet ? 36 : 28,
        vertical: isTablet ? 32 : 24,
      ),
      // Match the rounded corners of existing dialogs
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isTablet ? 28 : 24),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          isTablet ? 28 : 24,
          isTablet ? 28 : 24,
          isTablet ? 28 : 24,
          isTablet ? 22 : 18,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Centered Icon with circular amber background
            Container(
              width: isTablet ? 64 : 56,
              height: isTablet ? 64 : 56,
              decoration: BoxDecoration(
                color: const Color.fromARGB(
                  255,
                  51,
                  237,
                  224,
                ).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Image.asset(
                  'assets/images/icons/rocket.png',
                  width: isTablet ? 38 : 32,
                  height: isTablet ? 38 : 32,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            SizedBox(height: isTablet ? 20 : 18),

            // Title
            Text(
              'ยินดีต้อนรับสู่ QuestLife!',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: isTablet ? 24 : 20,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: isTablet ? 12 : 10),

            // Message
            Text(
              'มาเริ่มภารกิจพิชิตชีวิตให้เป็นเกมกันเถอะ! กดเริ่มลุยเพื่อดูวิธีใช้เครื่องมือปั๊ม XP ให้ชีวิตคุณกัน ถ้าพร้อมแล้วไปลุยกันเลย!',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: isTablet ? 16 : 14.5,
                height: 1.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            SizedBox(height: isTablet ? 26 : 22),

            // Primary Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(true);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.stormySkyBlue,
                  foregroundColor:
                      Theme.of(context).brightness == Brightness.dark
                          ? AppColors.stormyNightBackground
                          : Colors.white,
                  padding: EdgeInsets.symmetric(
                    vertical: isTablet ? 16 : 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isTablet ? 16 : 14),
                  ),
                ),
                child: Text(
                  'ไปลุยกันเลย!',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),

            SizedBox(height: isTablet ? 10 : 8),

            // Secondary Button
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.onSurface.withValues(
                    alpha: 0.6,
                  ),
                  padding: EdgeInsets.symmetric(
                    vertical: isTablet ? 14 : 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isTablet ? 16 : 14),
                  ),
                ),
                child: Text(
                  'ข้ามไปก่อน',
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
