// RewardsTimelineScreen - หน้าจอไทม์ไลน์รางวัลและความคืบหน้า (Rewards Timeline)
//
// แสดงไทม์ไลน์ระดับเลเวล (Level Milestones) รางวัลกรอบรูปโปรไฟล์ที่สามารถปลดล็อกได้
// และระดับประสบการณ์ (XP) ของผู้ใช้งาน
import 'package:flutter/material.dart';

import '../config/colors.dart';
import '../config/constants.dart';

// ─── ข้อมูล Milestone ทุก 5 Level ──────────────────────────────────────────
class _MilestoneReward {
  final String frameId;
  final String label;
  final IconData icon;
  final List<Color> colors;

  const _MilestoneReward({
    required this.frameId,
    required this.label,
    required this.icon,
    required this.colors,
  });
}

const _milestoneRewards = <int, _MilestoneReward>{
  5: _MilestoneReward(
    frameId: 'bronze_frame',
    label: 'กรอบ "วัยรุ่นสร้างตัว"',
    icon: Icons.shield_outlined,
    colors: [Color(0xFFCD7F32), Color(0xFFFFD29A)],
  ),
  10: _MilestoneReward(
    frameId: 'master_frame',
    label: 'กรอบ "ขั้นเทพ"',
    icon: Icons.auto_awesome,
    colors: [AppColors.primaryPurple, AppColors.primaryBlue],
  ),
  15: _MilestoneReward(
    frameId: 'ultimate_crown',
    label: 'กรอบ "ราชาไม่หวั่นไหว"',
    icon: Icons.workspace_premium,
    colors: [AppColors.accentYellow, AppColors.accentOrange],
  ),
  20: _MilestoneReward(
    frameId: 'diamond_frame',
    label: 'กรอบ "เพชรแท้ไม่มีวันสลาย"',
    icon: Icons.diamond_outlined,
    colors: [Color(0xFF4FC3F7), Colors.cyanAccent],
  ),
  25: _MilestoneReward(
    frameId: 'mythic_frame',
    label: 'กรอบ "ตำนานที่ยังมีชีวิต"',
    icon: Icons.local_fire_department,
    colors: [Colors.deepPurpleAccent, Colors.pinkAccent],
  ),
};

// ─── สถานะของแต่ละ Node ────────────────────────────────────────────────────
enum _NodeStatus { claimed, current, locked }

// ═══════════════════════════════════════════════════════════════════════════════
//  RewardsTimelineScreen — หน้า Battle Pass
// ═══════════════════════════════════════════════════════════════════════════════
class RewardsTimelineScreen extends StatefulWidget {
  final int currentLevel;

  const RewardsTimelineScreen({super.key, required this.currentLevel});

  @override
  State<RewardsTimelineScreen> createState() => _RewardsTimelineScreenState();
}

class _RewardsTimelineScreenState extends State<RewardsTimelineScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final ScrollController _scrollController;

  static const int _totalLevels = 25;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _scrollController = ScrollController();

    // เลื่อนไปยัง Node ปัจจุบันอัตโนมัติ
    _scrollToCurrentLevel();
  }

  void _scrollToCurrentLevel() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      // ประมาณความสูงของไอเทม (Regular ~80px, Milestone ~160px)
      // เพื่อความแม่นยำสูงสุดในหน้านี้ เราจะใช้ค่าเฉลี่ยหรือคำนวณตามจริง
      double offset = 0.0;
      for (int i = 0; i < widget.currentLevel - 1 && i < _totalLevels; i++) {
        final level = i + 1;
        offset += (level % 5 == 0) ? 180.0 : 88.0; // item height
      }

      // Bonus: ปรับให้เลื่อนมาอยู่ตรงกลางจอพอดี
      final screenHeight = MediaQuery.of(context).size.height;
      offset -= (screenHeight / 3); // ขยับลงมาให้อยู่ระยะสายตาพอดี

      if (offset < 0) offset = 0.0;

      _scrollController.animateTo(
        offset,
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  _NodeStatus _statusForLevel(int level) {
    if (level <= widget.currentLevel) return _NodeStatus.claimed;
    if (level == widget.currentLevel + 1) return _NodeStatus.current;
    return _NodeStatus.locked;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: isDark ? false : true,
      backgroundColor: isDark
          ? AppColors.stormyNightBackground
          : Colors.transparent,
      appBar: AppBar(
        title: const Text(
          'เส้นทางรางวัล',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        centerTitle: true,
        backgroundColor: isDark
            ? AppColors.stormyNightBackground
            : Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
      ),
      body: Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.stormyNightBackground : null,
          gradient: isDark
              ? null
              : LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.stormyDarkSlate,
                    AppColors.stormyIceBlue,
                    Colors.white,
                  ],
                  stops: const [0.0, 0.4, 1.0],
                ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ─── Progress Summary ────────────────────────────────────
              _buildProgressHeader(theme, isDark),
              const SizedBox(height: 4),
              // ─── Timeline ────────────────────────────────────────────
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  itemCount: _totalLevels,
                  itemBuilder: (context, index) {
                    final level = index + 1;
                    final status = _statusForLevel(level);
                    final isMilestone = level % 5 == 0;
                    final isFirst = index == 0;
                    final isLast = index == _totalLevels - 1;

                    if (isMilestone) {
                      return _MilestoneNode(
                        level: level,
                        status: status,
                        isHighestClaimed: level == widget.currentLevel,
                        reward: _milestoneRewards[level]!,
                        pulseAnimation: _pulseController,
                        showTopLine: !isFirst,
                        showBottomLine: !isLast,
                        isDark: isDark,
                      );
                    }

                    return _RegularNode(
                      level: level,
                      status: status,
                      isHighestClaimed: level == widget.currentLevel,
                      pulseAnimation: _pulseController,
                      showTopLine: !isFirst,
                      showBottomLine: !isLast,
                      isDark: isDark,
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

  Widget _buildProgressHeader(ThemeData theme, bool isDark) {
    final claimedLevels = (widget.currentLevel).clamp(0, _totalLevels);
    final progress = claimedLevels / _totalLevels;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Level ${widget.currentLevel}',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: isDark ? Colors.white : Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.stormyDarkSlate
                      : AppColors.stormyDarkSlate,
                  gradient: isDark ? null : null,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '$claimedLevels / $_totalLevels',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: isDark
                  ? const Color(0xFF101720)
                  : AppColors.stormyIceBlue,
              valueColor: AlwaysStoppedAnimation<Color>(
                isDark ? AppColors.stormySkyBlue : AppColors.stormySkyBlue,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Regular Node — Levelธรรมดา (ไม่ใช่ Milestone)
// ═══════════════════════════════════════════════════════════════════════════════
class _RegularNode extends StatelessWidget {
  final int level;
  final _NodeStatus status;
  final bool isHighestClaimed;
  final AnimationController pulseAnimation;
  final bool showTopLine;
  final bool showBottomLine;
  final bool isDark;

  const _RegularNode({
    required this.level,
    required this.status,
    required this.isHighestClaimed,
    required this.pulseAnimation,
    required this.showTopLine,
    required this.showBottomLine,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 80,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── เส้น Timeline + จุดกลม ───────────────────────────────
          SizedBox(
            width: 56,
            child: _TimelineConnector(
              status: status,
              isHighestClaimed: isHighestClaimed,
              showTopLine: showTopLine,
              showBottomLine: showBottomLine,
              nodeSize: 28,
              pulseAnimation: pulseAnimation,
              isDark: isDark,
              child: _buildNodeDot(),
            ),
          ),
          const SizedBox(width: 12),
          // ─── เนื้อหา ──────────────────────────────────────────────
          Expanded(child: _buildContent(context)),
        ],
      ),
    );
  }

  Widget _buildNodeDot() {
    switch (status) {
      case _NodeStatus.claimed:
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isDark ? null : null,
            color: isDark ? AppColors.stormySkyBlue : AppColors.stormySkyBlue,
            boxShadow: isDark ? null : null,
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 16),
        );
      case _NodeStatus.current:
        return AnimatedBuilder(
          animation: pulseAnimation,
          builder: (context, child) {
            final scale = 1.0 + pulseAnimation.value * 0.15;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isDark ? null : null,
                  color: isDark
                      ? AppColors.stormySkyBlue
                      : AppColors.stormySkyBlue,
                  boxShadow: isDark
                      ? [
                          BoxShadow(
                            color: AppColors.stormySkyBlue.withValues(
                              alpha: 0.3 + pulseAnimation.value * 0.3,
                            ),
                            blurRadius: 10 + pulseAnimation.value * 6,
                            spreadRadius: 1 + pulseAnimation.value * 2,
                          ),
                        ]
                      : null,
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            );
          },
        );
      case _NodeStatus.locked:
        return Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark
                ? Colors.white.withValues(alpha: 0.08)
                : AppColors.backgroundGrey,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.12)
                  : AppColors.textLight.withValues(alpha: 0.4),
              width: 1.5,
            ),
          ),
          child: Icon(
            Icons.lock_outline,
            color: isDark
                ? Colors.white.withValues(alpha: 0.25)
                : AppColors.textLight,
            size: 14,
          ),
        );
    }
  }

  Widget _buildContent(BuildContext context) {
    final theme = Theme.of(context);

    final Color textColor;
    final Color subtitleColor;
    final Color cardColor;
    final Color borderColor;

    switch (status) {
      case _NodeStatus.claimed:
        textColor = isDark
            ? Colors.white
            : (isHighestClaimed ? Colors.white : AppColors.stormyDarkSlate);
        subtitleColor = isDark
            ? AppColors.stormyIceBlue
            : (isHighestClaimed
                  ? AppColors.stormyIceBlue
                  : AppColors.stormyMutedBlueGrey);
        cardColor = isDark
            ? AppColors.stormyDarkSlate
            : (isHighestClaimed ? AppColors.stormyDarkSlate : Colors.white);
        borderColor = isDark
            ? (isHighestClaimed ? AppColors.stormySkyBlue : Colors.transparent)
            : (isHighestClaimed ? Colors.transparent : AppColors.stormyIceBlue);
        break;
      case _NodeStatus.current:
        textColor = isDark ? Colors.white : AppColors.stormyDarkSlate;
        subtitleColor = isDark
            ? AppColors.stormyIceBlue
            : AppColors.stormySkyBlue;
        cardColor = isDark ? Colors.transparent : Colors.transparent;
        borderColor = isDark
            ? AppColors.stormyMutedBlueGrey
            : AppColors.stormySkyBlue;
        break;
      case _NodeStatus.locked:
        textColor = isDark
            ? Colors.white.withValues(alpha: 0.35)
            : AppColors.textLight;
        subtitleColor = isDark
            ? Colors.white.withValues(alpha: 0.2)
            : AppColors.textLight.withValues(alpha: 0.7);
        cardColor = isDark
            ? Colors.white.withValues(alpha: 0.03)
            : Colors.white;
        borderColor = isDark
            ? Colors.white.withValues(alpha: 0.05)
            : AppColors.stormyMutedBlueGrey.withValues(alpha: 0.3);
        break;
    }

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(
            color: borderColor,
            width:
                (isDark && status == _NodeStatus.claimed && isHighestClaimed) ||
                    (!isDark && status == _NodeStatus.current)
                ? 1.5
                : 1.0,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Level $level',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      if (status == _NodeStatus.current ||
                          (status == _NodeStatus.claimed &&
                              isHighestClaimed)) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            gradient: isDark ? null : null,
                            color: isDark
                                ? (status == _NodeStatus.current
                                      ? AppColors.stormyDarkSlate
                                      : AppColors.stormySkyBlue)
                                : AppColors.stormyIceBlue,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            status == _NodeStatus.current ? 'ถัดไป' : 'ตอนนี้',
                            style: TextStyle(
                              color: isDark
                                  ? (status == _NodeStatus.current
                                        ? AppColors.stormySkyBlue
                                        : AppColors.stormyNightBackground)
                                  : AppColors.stormyDarkSlate,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  if (level > 1) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          '+50 XP',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: subtitleColor,
                          ),
                        ),
                        if (status == _NodeStatus.claimed &&
                            isHighestClaimed) ...[
                          const SizedBox(width: 4),
                          Text(
                            'ปลดล็อกแล้ว ✨',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark
                                  ? AppColors.stormySkyBlue
                                  : AppColors.stormyIceBlue,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (status == _NodeStatus.claimed)
              Icon(
                Icons.check_circle,
                color: isDark
                    ? AppColors.stormySkyBlue
                    : AppColors.stormySkyBlue,
                size: 20,
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Milestone Node — Levelพิเศษ (ทุก 5 Level)
// ═══════════════════════════════════════════════════════════════════════════════
class _MilestoneNode extends StatelessWidget {
  final int level;
  final _NodeStatus status;
  final bool isHighestClaimed;
  final _MilestoneReward reward;
  final AnimationController pulseAnimation;
  final bool showTopLine;
  final bool showBottomLine;
  final bool isDark;

  const _MilestoneNode({
    required this.level,
    required this.status,
    required this.isHighestClaimed,
    required this.reward,
    required this.pulseAnimation,
    required this.showTopLine,
    required this.showBottomLine,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── เส้น Timeline + จุดกลม ───────────────────────────────
          SizedBox(
            width: 56,
            child: _TimelineConnector(
              status: status,
              isHighestClaimed: isHighestClaimed,
              showTopLine: showTopLine,
              showBottomLine: showBottomLine,
              nodeSize: 44,
              pulseAnimation: pulseAnimation,
              isDark: isDark,
              child: _buildMilestoneIcon(),
            ),
          ),
          const SizedBox(width: 12),
          // ─── การ์ดรางวัล ──────────────────────────────────────────
          Expanded(child: _buildRewardCard(context)),
        ],
      ),
    );
  }

  Widget _buildMilestoneIcon() {
    final goldColor = const Color(0xFFFFB300);

    switch (status) {
      case _NodeStatus.claimed:
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: isDark ? null : LinearGradient(colors: reward.colors),
            color: isDark ? goldColor : null,
            boxShadow: [
              BoxShadow(
                color: (isDark ? goldColor : reward.colors.first).withValues(
                  alpha: 0.4,
                ),
                blurRadius: 12,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Icon(Icons.check, color: Colors.white, size: 22),
        );
      case _NodeStatus.current:
        return AnimatedBuilder(
          animation: pulseAnimation,
          builder: (context, child) {
            final scale = 1.0 + pulseAnimation.value * 0.12;
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: isDark
                      ? null
                      : LinearGradient(colors: reward.colors),
                  color: isDark ? goldColor : null,
                  boxShadow: [
                    BoxShadow(
                      color: (isDark ? goldColor : reward.colors.first)
                          .withValues(alpha: 0.3 + pulseAnimation.value * 0.35),
                      blurRadius: 14 + pulseAnimation.value * 8,
                      spreadRadius: 2 + pulseAnimation.value * 3,
                    ),
                  ],
                ),
                child: Icon(reward.icon, color: Colors.white, size: 22),
              ),
            );
          },
        );
      case _NodeStatus.locked:
        return Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isDark ? Colors.white.withValues(alpha: 0.06) : Colors.white,
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1)
                  : AppColors.stormyMutedBlueGrey.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          child: Icon(
            Icons.lock_outline,
            color: isDark
                ? Colors.white.withValues(alpha: 0.2)
                : AppColors.stormyMutedBlueGrey,
            size: 20,
          ),
        );
    }
  }

  Widget _buildRewardCard(BuildContext context) {
    final theme = Theme.of(context);
    final goldColor = const Color(0xFFFFB300);

    switch (status) {
      case _NodeStatus.claimed:
        return Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? AppColors.stormyDarkSlate : Colors.white,
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              border: Border.all(
                color: isDark
                    ? goldColor.withValues(alpha: 0.3)
                    : AppColors.stormyIceBlue,
                width: 1.5,
              ),
              boxShadow: [
                if (isDark)
                  BoxShadow(
                    color: goldColor.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
              ],
            ),
            child: Row(
              children: [
                _RewardFramePreview(
                  frameId: reward.frameId,
                  icon: reward.icon,
                  colors: isDark ? [goldColor, goldColor] : reward.colors,
                  isLocked: false,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          ShaderMask(
                            shaderCallback: (bounds) => LinearGradient(
                              colors: isDark
                                  ? [goldColor, goldColor]
                                  : reward.colors,
                            ).createShader(bounds),
                            child: Text(
                              'Level $level',
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Icon(
                            Icons.check_circle,
                            color: isDark ? goldColor : AppColors.primaryGreen,
                            size: 16,
                          ),
                          if (status == _NodeStatus.claimed &&
                              isHighestClaimed) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [
                                    AppColors.primaryGreen,
                                    Color(0xFF00E5B0),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'ตอนนี้',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reward.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white
                              : AppColors.stormyDarkSlate,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ปลดล็อกแล้ว ✨',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark ? goldColor : reward.colors.first,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );

      case _NodeStatus.current:
        return Center(
          child: AnimatedBuilder(
            animation: pulseAnimation,
            builder: (context, child) {
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.stormyDarkSlate : null,
                  gradient: isDark
                      ? null
                      : LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            reward.colors.first.withValues(alpha: 0.12),
                            reward.colors.last.withValues(alpha: 0.05),
                          ],
                        ),
                  borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
                  border: Border.all(
                    color: (isDark ? goldColor : reward.colors.first)
                        .withValues(alpha: 0.5 + pulseAnimation.value * 0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    if (!isDark)
                      BoxShadow(
                        color: reward.colors.first.withValues(
                          alpha: 0.15 + pulseAnimation.value * 0.15,
                        ),
                        blurRadius: 16 + pulseAnimation.value * 8,
                        spreadRadius: pulseAnimation.value * 2,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Row(
                  children: [
                    _RewardFramePreview(
                      frameId: reward.frameId,
                      icon: reward.icon,
                      colors: isDark ? [goldColor, goldColor] : reward.colors,
                      isLocked: false,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              ShaderMask(
                                shaderCallback: (bounds) => LinearGradient(
                                  colors: isDark
                                      ? [goldColor, goldColor]
                                      : reward.colors,
                                ).createShader(bounds),
                                child: Text(
                                  'Level $level',
                                  style: theme.textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isDark
                                        ? [goldColor, goldColor]
                                        : reward.colors,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Text(
                                  'ถัดไป',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            reward.label,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: isDark
                                  ? Colors.white
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'เพิ่ม Level เพื่อปลดล็อก!',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: isDark ? goldColor : reward.colors.first,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );

      case _NodeStatus.locked:
        return Center(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.03)
                  : Colors.white,
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.06)
                    : AppColors.stormyMutedBlueGrey.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                _RewardFramePreview(
                  frameId: reward.frameId,
                  icon: reward.icon,
                  colors: isDark ? [goldColor, goldColor] : reward.colors,
                  isLocked: true,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Level $level',
                        style: theme.textTheme.labelMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.3)
                              : AppColors.stormyMutedBlueGrey,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reward.label,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.2)
                              : AppColors.stormyMutedBlueGrey.withValues(
                                  alpha: 0.7,
                                ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'ยังล็อกอยู่',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.15)
                              : AppColors.stormyMutedBlueGrey.withValues(
                                  alpha: 0.6,
                                ),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.lock_outline,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.15)
                      : AppColors.stormyMutedBlueGrey.withValues(alpha: 0.5),
                  size: 22,
                ),
              ],
            ),
          ),
        );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Reward Frame Preview — ตัวอย่างเฟรมใน Milestone
// ═══════════════════════════════════════════════════════════════════════════════
class _RewardFramePreview extends StatelessWidget {
  final String frameId;
  final IconData icon;
  final List<Color> colors;
  final bool isLocked;

  const _RewardFramePreview({
    required this.frameId,
    required this.icon,
    required this.colors,
    required this.isLocked,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isLocked ? 0.3 : 1.0,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(colors: colors),
          boxShadow: isLocked
              ? null
              : [
                  BoxShadow(
                    color: colors.first.withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 28),
            if (isLocked)
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withValues(alpha: 0.4),
                ),
                child: const Icon(Icons.lock, color: Colors.white70, size: 20),
              ),
          ],
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Timeline Connector — เส้นเชื่อมแนวตั้ง + Node ตรงกลาง
// ═══════════════════════════════════════════════════════════════════════════════
class _TimelineConnector extends StatelessWidget {
  final _NodeStatus status;
  final bool showTopLine;
  final bool showBottomLine;
  final double nodeSize;
  final AnimationController pulseAnimation;
  final bool isDark;
  final Widget child;

  final bool isHighestClaimed; // Added to handle line states

  const _TimelineConnector({
    required this.status,
    this.isHighestClaimed = false,
    required this.showTopLine,
    required this.showBottomLine,
    required this.nodeSize,
    required this.pulseAnimation,
    required this.isDark,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final bool isLineSolidTop = status == _NodeStatus.claimed;
    final bool isLineSolidBottom =
        status == _NodeStatus.claimed && !isHighestClaimed;

    Widget buildLine(bool show, bool isSolid) {
      if (!show) return const SizedBox.shrink();

      if (isSolid) {
        final color = AppColors.stormySkyBlue;
        return Center(
          child: Container(
            width: 2,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        );
      } else {
        return Center(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final height = constraints.maxHeight;
              if (height <= 0 || height == double.infinity) {
                return const SizedBox();
              }
              int count = (height / 6).floor();
              return Flex(
                direction: Axis.vertical,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                mainAxisSize: MainAxisSize.max,
                children: List.generate(
                  count,
                  (index) => Container(
                    width: 2,
                    height: 3,
                    color: isDark
                        ? AppColors.stormyMutedBlueGrey
                        : AppColors.stormyIceBlue,
                  ),
                ),
              );
            },
          ),
        );
      }
    }

    return Column(
      children: [
        // เส้นด้านบน
        Expanded(child: buildLine(showTopLine, isLineSolidTop)),
        // Node
        child,
        // เส้นด้านล่าง
        Expanded(child: buildLine(showBottomLine, isLineSolidBottom)),
      ],
    );
  }
}
