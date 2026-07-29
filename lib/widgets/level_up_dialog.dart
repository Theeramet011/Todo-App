import '../config/constants.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../models/xp_system.dart';
import '../providers/auth_provider.dart';
import '../services/sound_service.dart';
import 'user_avatar_with_frame.dart';

class LevelUpDialog extends StatefulWidget {
  final int newLevel;
  final int bonusXp;
  final String? unlockedItemName;
  final VoidCallback? onEquip;

  const LevelUpDialog({
    super.key,
    required this.newLevel,
    this.bonusXp = 50,
    this.unlockedItemName,
    this.onEquip,
  });

  /// ตัวอย่างการเรียกใช้งาน: LevelUpDialog.show(context, 5);
  static void show(
    BuildContext context,
    int level, {
    int bonusXp = 50,
    String? unlockedItemName,
    VoidCallback? onEquip,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => LevelUpDialog(
        newLevel: level,
        bonusXp: bonusXp,
        unlockedItemName: unlockedItemName,
        onEquip: onEquip,
      ),
    );
  }

  @override
  State<LevelUpDialog> createState() => _LevelUpDialogState();
}

class _LevelUpDialogState extends State<LevelUpDialog> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    // ตั้งค่าเวลาสำหรับพลุกระดาษและให้เริ่มเล่นทันที
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Stack(
      alignment: Alignment.center,
      children: [
        // พลุกระดาษกระจายจากตรงกลางหน้าจอ
        ConfettiWidget(
          confettiController: _confettiController,
          blastDirectionality:
              BlastDirectionality.explosive, // ระเบิดออกทุกทิศทาง
          shouldLoop: false,
          emissionFrequency: 0.05, // เพิ่มความถี่ในการยิง (ค่าเริ่มต้น 0.02)
          numberOfParticles: 40, // เพิ่มจำนวนพลุต่อครั้งที่ยิง (ค่าเริ่มต้น 10)
          maxBlastForce: 100, // ความแรงในการกระจายตัวสูงสุด
          minBlastForce: 80, // ความแรงในการกระจายตัวต่ำสุด
          colors: const [
            Colors.green,
            Colors.blue,
            Colors.pink,
            Colors.orange,
            Colors.purple,
            Colors.yellow,
          ],
        ),

        // ตัวหน้าต่าง Dialog พร้อมแอนิเมชันเด้ง (ElasticOut)
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
                backgroundColor: theme.brightness == Brightness.dark
                    ? AppColors.stormyDarkSlate
                    : Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ข้อความ "LEVEL UP!"
                      Text(
                        'LEVEL UP!',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: theme.brightness == Brightness.dark
                              ? Colors.white
                              : AppColors.stormyDarkSlate,
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Rewards Section
                      Builder(
                        builder: (context) {
                          final rewardId = milestoneRewards[widget.newLevel];
                          final isFrame =
                              rewardId != null &&
                              ProfileFrameStyle.fromId(rewardId).hasFrame;

                          final String? displayName;
                          if (widget.unlockedItemName != null) {
                            displayName = widget.unlockedItemName;
                          } else if (isFrame) {
                            displayName =
                                'ปลดล็อก: กรอบ "${ProfileFrameStyle.fromId(rewardId).label}"';
                          } else if (rewardId != null) {
                            displayName = rewardId
                                .split('_')
                                .map(
                                  (w) => w.isNotEmpty
                                      ? w[0].toUpperCase() + w.substring(1)
                                      : '',
                                )
                                .join(' ');
                          } else {
                            displayName = null;
                          }

                          if (displayName != null) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 24,
                                horizontal: 16,
                              ),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.stormySkyBlue.withValues(
                                  alpha: 0.05,
                                ),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: AppColors.stormySkyBlue.withValues(
                                    alpha: 0.2,
                                  ),
                                ),
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  _buildRewardIcon(context, rewardId),
                                  const SizedBox(height: 16),
                                  const Text(
                                    '✨ ปลดล็อกรางวัลใหม่',
                                    style: TextStyle(
                                      color: AppColors.stormySkyBlue,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    displayName,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: theme.colorScheme.onSurface,
                                      height: 1.5,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  _buildXpBadge(),
                                ],
                              ),
                            );
                          } else {
                            return Column(
                              children: [
                                _buildRewardIcon(context, null),
                                const SizedBox(height: 16),
                                _buildXpBadge(),
                              ],
                            );
                          }
                        },
                      ),
                      const SizedBox(height: 24),

                      // ข้อความแสดงความยินดี
                      Text(
                        'ยินดีด้วย! คุณเลื่อนขั้นเป็น Level ${widget.newLevel} แล้ว จงพยายามต่อไปเพื่อความสำเร็จที่ยิ่งใหญ่กว่าเดิม!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 16,
                          color: theme.brightness == Brightness.dark
                              ? AppColors.stormyIceBlue
                              : AppColors.stormyMutedBlueGrey,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // ปุ่มกดยืนยัน
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.stormySkyBlue,
                            foregroundColor: theme.brightness == Brightness.dark
                                ? AppColors.stormyNightBackground
                                : AppColors.stormyDarkSlate,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'ลุยภารกิจต่อไป!',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                      // ปุ่มสวมใส่ทันที (กรณีปลดล็อกไอเทม)
                      Builder(
                        builder: (context) {
                          final rewardId = milestoneRewards[widget.newLevel];
                          final hasReward =
                              widget.unlockedItemName != null ||
                              rewardId != null;

                          if (hasReward) {
                            return Padding(
                              padding: const EdgeInsets.only(top: 8.0),
                              child: TextButton(
                                onPressed: () {
                                  if (widget.onEquip != null) {
                                    widget.onEquip!();
                                  } else if (rewardId != null) {
                                    final auth = context.read<AuthProvider>();
                                    if (ProfileFrameStyle.fromId(
                                      rewardId,
                                    ).hasFrame) {
                                      auth.equipItem('equippedFrame', rewardId);
                                    } else {
                                      auth.equipItem('equippedTitle', rewardId);
                                    }
                                  }
                                  Navigator.pop(context);
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.primaryBlue,
                                ),
                                child: const Text(
                                  'สวมใส่ทันที',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            );
                          }
                          return const SizedBox.shrink();
                        },
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

  Widget _buildRewardIcon(BuildContext context, String? rewardId) {
    final user = context.watch<AuthProvider>().currentUser;
    final isFrameReward =
        rewardId != null && ProfileFrameStyle.fromId(rewardId).hasFrame;

    final hasReward = widget.unlockedItemName != null || rewardId != null;

    if (isFrameReward) {
      return UserAvatarWithFrame(
        avatarUrl: user?.avatarUrl ?? '',
        frameId: rewardId,
        fallbackName: user?.name ?? '?',
        size: hasReward ? 80 : 100,
      );
    }

    return Container(
      padding: EdgeInsets.all(hasReward ? 8 : 16),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.stormySkyBlue.withValues(alpha: 0.1),
        boxShadow: hasReward
            ? null
            : [
                BoxShadow(
                  color: AppColors.stormySkyBlue.withValues(alpha: 0.4),
                  blurRadius: 40,
                  spreadRadius: 5,
                ),
              ],
      ),
      child: Icon(
        hasReward ? Icons.workspace_premium_rounded : Icons.star_rounded,
        size: hasReward ? 40 : 80,
        color: AppColors.stormySkyBlue,
      ),
    );
  }

  Widget _buildXpBadge() {
    if (widget.bonusXp <= 0 || widget.newLevel >= AppConstants.maxLevel) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.stormySkyBlue.withValues(alpha: 0.15)
            : AppColors.stormyIceBlue,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '+${widget.bonusXp} XP',
        style: TextStyle(
          color: isDark ? AppColors.stormySkyBlue : AppColors.stormyDarkSlate,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}
