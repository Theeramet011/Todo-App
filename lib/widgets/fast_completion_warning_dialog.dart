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

    return Dialog(
      backgroundColor: theme.brightness == Brightness.dark
          ? AppColors.stormyDarkSlate
          : theme.cardColor,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.warning.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.warning_amber_rounded,
                color: AppColors.warning,
                size: 32,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'ไม่ได้รับคะแนนภารกิจ',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                height: 1.45,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 22),
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
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'เข้าใจแล้ว T_T',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
