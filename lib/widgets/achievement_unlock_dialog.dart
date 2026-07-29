import 'dart:async';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../config/colors.dart';
import '../models/achievement.dart';
import '../providers/auth_provider.dart';
import '../services/sound_service.dart';

class AchievementUnlockDialog extends StatefulWidget {
  final Achievement achievement;

  const AchievementUnlockDialog({super.key, required this.achievement});

  /// Helper to show the dialog
  static Future<void> show(
    BuildContext context,
    Achievement achievement,
  ) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AchievementUnlockDialog(achievement: achievement),
    );
  }

  @override
  State<AchievementUnlockDialog> createState() =>
      _AchievementUnlockDialogState();
}

class _AchievementUnlockDialogState extends State<AchievementUnlockDialog> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(
      duration: const Duration(seconds: 3),
    );
    _confettiController.play();

    final isSoundEnabled =
        context.read<AuthProvider>().currentUser?.isSoundEnabled ?? true;
    unawaited(
      SoundService.instance.playLevelUpSound(isSoundEnabled: isSoundEnabled),
    );
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  Widget _buildBadgeImageOrIcon(bool isDark) {
    final imagePath = widget.achievement.unlockedImagePath;

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
              widget.achievement.icon,
              size: 100,
              color: widget.achievement.color,
            );
          },
        );
      }
    } else {
      badgeWidget = Icon(
        widget.achievement.icon,
        size: 100,
        color: widget.achievement.color,
      );
    }

    return Container(
      width: 140,
      height: 140,
      padding: EdgeInsets.zero,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isDark
            ? AppColors.stormyNightBackground
            : AppColors.stormyIceBlue,
        boxShadow: [
          BoxShadow(
            color: widget.achievement.color.withValues(alpha: 0.3),
            blurRadius: 40,
            spreadRadius: 5,
          ),
        ],
      ),
      child: ClipOval(child: Transform.scale(scale: 1.15, child: badgeWidget)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Stack(
      alignment: Alignment.center,
      children: [
        // Confetti
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality: BlastDirectionality.explosive,
          shouldLoop: false,
          emissionFrequency: 0.05,
          numberOfParticles: 40,
          maxBlastForce: 100,
          minBlastForce: 80,
          colors: const [
            Colors.green,
            Colors.blue,
            Colors.pink,
            Colors.orange,
            Colors.purple,
            Colors.yellow,
          ],
        ),

        // Dialog
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 1000),
          curve: Curves.elasticOut,
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                backgroundColor: isDark
                    ? AppColors.stormyDarkSlate
                    : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Title
                      Text(
                        'ปลดล็อคตราความสำเร็จ!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white
                              : AppColors.stormyDarkSlate,
                          letterSpacing: 2,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Badge
                      _buildBadgeImageOrIcon(isDark),
                      const SizedBox(height: 24),

                      // Achievement Title
                      Text(
                        widget.achievement.title,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 20,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Achievement Description
                      Text(
                        widget.achievement.description,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark
                              ? AppColors.stormyIceBlue
                              : AppColors.stormyMutedBlueGrey,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Button
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.stormySkyBlue,
                            foregroundColor: isDark
                                ? AppColors.stormyNightBackground
                                : AppColors.stormyDarkSlate,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'สุดยอดไปเลย!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
        ),
      ],
    );
  }
}
