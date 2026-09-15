import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/colors.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../services/sound_service.dart';

class FastCompletionWarningDialog extends StatelessWidget {
  const FastCompletionWarningDialog({super.key});

  static const message =
      'เราพบว่าคุณกดเสร็จสิ้นภารกิจเร็วผิดปกติ จึงไม่ได้รับ XP ในภารกิจนี้ ดังนั้นจะบันทึกสถิติงานไว้อย่างเดียว';

  static Future<void> showIfBlocked(
    BuildContext context,
    CompletionRewardResult result,
  ) async {
    if (result.status != CompletionRewardStatus.blockedFastCompletion) return;
    if (!context.mounted) return;

    final isSoundEnabled =
        context.read<AuthProvider>().currentUser?.isSoundEnabled ?? true;
    unawaited(
      SoundService.instance.playFastCompletionFailSound(
        isSoundEnabled: isSoundEnabled,
      ),
    );

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const FastCompletionWarningDialog(),
    );
  }

  static Future<void> showCompletionFeedback(
    BuildContext context,
    CompletionRewardResult result,
  ) async {
    await showIfBlocked(context, result);
  }

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
            Container(
              width: isTablet ? 64 : 56,
              height: isTablet ? 64 : 56,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: isTablet ? 38 : 32,
              ),
            ),
            SizedBox(height: isTablet ? 20 : 18),
            Text(
              'ไม่ได้รับคะแนนภารกิจ',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: isTablet ? 22 : 18,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            SizedBox(height: isTablet ? 12 : 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                fontSize: isTablet ? 16 : 14.5,
                height: 1.5,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            SizedBox(height: isTablet ? 26 : 22),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
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
                  'เข้าใจแล้ว T_T',
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14.5,
                    fontWeight: FontWeight.w700,
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
