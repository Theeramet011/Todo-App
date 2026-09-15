// FriendDetailScreen - หน้าจอแสดงรายละเอียดข้อมูลของเพื่อน (Friend Detail)
//
// แสดงสถิติการใช้งาน ระดับ (Level) ความสำเร็จ และงานที่มอบหมายร่วมกับเพื่อนรายนั้นๆ
// พร้อมปุ่มโต้ตอบจัดการความสัมพันธ์เพื่อน
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/colors.dart';
import '../config/constants.dart';
import '../models/user.dart';
import '../widgets/user_avatar_with_frame.dart';
import '../providers/auth_provider.dart';
import '../providers/connectivity_provider.dart';
import '../widgets/achievement_summary_card.dart';
import '../widgets/stat_card.dart';
import '../utils/thai_display.dart';

class FriendDetailScreen extends StatefulWidget {
  final User friendUser;

  const FriendDetailScreen({super.key, required this.friendUser});

  @override
  State<FriendDetailScreen> createState() => _FriendDetailScreenState();
}

class _FriendDetailScreenState extends State<FriendDetailScreen> {
  bool _isRemoving = false;

  Future<void> _confirmRemoveFriend() async {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Theme.of(context).brightness == Brightness.dark
              ? AppColors.stormyDarkSlate
              : Theme.of(context).colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(isTablet ? 22 : 16),
          ),
          actionsPadding: EdgeInsets.symmetric(
            horizontal: isTablet ? 20 : 16,
            vertical: isTablet ? 16 : 12,
          ),
          title: Text(
            'ลบเพื่อน',
            style: TextStyle(
              color: AppColors.accentRed,
              fontWeight: FontWeight.bold,
              fontSize: isTablet ? 22 : 18,
            ),
          ),
          content: Text(
            'คุณต้องการลบผู้ใช้นี้ออกจากรายชื่อเพื่อนใช่หรือไม่?',
            style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.stormyIceBlue
                  : Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.82),
              fontSize: isTablet ? 16 : 14.5,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.stormySkyBlue
                    : AppColors.textSecondary,
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isTablet ? 12 : 10,
                ),
              ),
              child: Text(
                'ยกเลิก',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.accentRed,
                foregroundColor:
                    Theme.of(context).brightness == Brightness.dark
                        ? AppColors.stormyNightBackground
                        : Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : 16,
                  vertical: isTablet ? 12 : 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text(
                'ลบ',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isTablet ? 16 : 14.5,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (shouldRemove == true) {
      await _removeFriend();
    }
  }

  Future<void> _removeFriend() async {
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    if (currentUserId == null || currentUserId.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('ไม่พบข้อมูลผู้ใช้ปัจจุบัน')),
      );
      return;
    }

    final connectivity = context.read<ConnectivityProvider>();
    if (connectivity.isOffline) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('ไม่มีการเชื่อมต่ออินเทอร์เน็ต ไม่สามารถดำเนินการได้'),
        ),
      );
      return;
    }

    setState(() => _isRemoving = true);

    try {
      final firestore = FirebaseFirestore.instance;
      final batch = firestore.batch();
      final currentUserRef = firestore.collection('users').doc(currentUserId);
      final friendRef = firestore.collection('users').doc(widget.friendUser.id);

      batch.update(currentUserRef, {
        'friends': FieldValue.arrayRemove([widget.friendUser.id]),
      });
      batch.update(friendRef, {
        'friends': FieldValue.arrayRemove([currentUserId]),
      });

      await batch.commit();

      if (!mounted) return;
      messenger.showSnackBar(
        const SnackBar(content: Text('ลบเพื่อนสำเร็จแล้ว')),
      );
      navigator.pop();
    } catch (error) {
      if (!mounted) return;
      setState(() => _isRemoving = false);
      messenger.showSnackBar(
        const SnackBar(content: Text('ลบเพื่อนไม่สำเร็จ')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final friend = widget.friendUser;
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? AppColors.stormyNightBackground
          : theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(theme, isTablet),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(
                      isTablet ? 24 : AppConstants.paddingMedium,
                    ),
                    child: Column(
                      children: [
                        _buildProfileSection(friend, isTablet),
                        SizedBox(
                          height: isTablet ? 24 : AppConstants.paddingLarge,
                        ),
                        _buildStatsGrid(friend, theme, isTablet),
                        SizedBox(
                          height: isTablet ? 24 : AppConstants.paddingLarge,
                        ),
                        AchievementSummaryCard(user: friend),
                        SizedBox(
                          height: isTablet ? 32 : AppConstants.paddingXLarge,
                        ),
                      ],
                    ),
                  ),
                ),
                _buildRemoveButton(isTablet),
              ],
            ),
            if (_isRemoving)
              Container(
                color: Colors.black.withValues(alpha: 0.35),
                child: const Center(
                  child: CircularProgressIndicator(
                    color: AppColors.stormySkyBlue,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme, bool isTablet) {
    return Padding(
      padding: EdgeInsets.all(isTablet ? 24 : AppConstants.paddingMedium),
      child: Row(
        children: [
          IconButton(
            onPressed: _isRemoving ? null : () => Navigator.of(context).pop(),
            icon: Icon(Icons.arrow_back, size: isTablet ? 28 : 24),
          ),
          SizedBox(width: isTablet ? 12 : AppConstants.paddingSmall),
          Container(
            padding: EdgeInsets.all(isTablet ? 16 : 12),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.light
                  ? AppColors.stormySkyBlue
                  : AppColors.primaryPurple.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(
                isTablet ? 16 : AppConstants.radiusMedium,
              ),
              border: theme.brightness == Brightness.dark
                  ? Border.all(color: AppColors.primaryPurple, width: 2)
                  : null,
            ),
            child: Icon(
              Icons.person,
              color: theme.brightness == Brightness.light
                  ? AppColors.textWhite
                  : AppColors.primaryPurple,
              size: isTablet ? 30 : 24,
            ),
          ),
          SizedBox(width: isTablet ? 18 : AppConstants.paddingMedium),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'รายละเอียดเพื่อน',
                  style: TextStyle(
                    fontSize: isTablet ? 26 : 22,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                Text(
                  'โปรไฟล์และสถิติเกม',
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileSection(User friend, bool isTablet) {
    return Container(
      padding: EdgeInsets.all(isTablet ? 24 : AppConstants.paddingLarge),
      decoration: BoxDecoration(
        gradient: Theme.of(context).brightness == Brightness.light
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.stormyDarkSlate, AppColors.stormySkyBlue],
              )
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF101720), AppColors.stormyDarkSlate],
              ),
        borderRadius: BorderRadius.circular(
          isTablet ? 28 : AppConstants.radiusXLarge,
        ),
      ),
      child: Row(
        children: [
          UserAvatarWithFrame(
            avatarUrl: friend.avatarUrl,
            frameId: friend.equippedFrame,
            fallbackName: friend.name,
            size: isTablet ? 100 : AppConstants.avatarXLarge,
          ),
          SizedBox(width: isTablet ? 24 : AppConstants.paddingLarge),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  friend.name,
                  style: TextStyle(
                    fontSize: isTablet ? 26 : 20,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textWhite,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  friend.email,
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    color: AppColors.textWhite.withValues(alpha: 0.8),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: isTablet ? 14 : 12),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 16 : 12,
                    vertical: isTablet ? 6 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.backgroundWhite.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusSmall,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.star,
                        size: isTablet ? 18 : 14,
                        color: AppColors.accentYellow,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Level ${friend.currentLevel}',
                        style: TextStyle(
                          fontSize: isTablet ? 15 : 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textWhite,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isTablet ? 8 : 6),
                Text(
                  thaiLevelTitle(friend.currentLevel),
                  style: TextStyle(
                    fontSize: isTablet ? 15 : 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textWhite.withValues(alpha: 0.86),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid(User friend, ThemeData theme, bool isTablet) {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: isTablet ? 20 : AppConstants.paddingMedium,
      mainAxisSpacing: isTablet ? 20 : AppConstants.paddingMedium,
      childAspectRatio: isTablet ? 1.35 : 1.28,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        StatCard(
          icon: Icons.star,
          value: '${friend.currentLevel}',
          title: 'Level ปัจจุบัน',
          type: StatType.level,
        ),
        StatCard(
          icon: Icons.stars,
          value: '${friend.totalXP}',
          title: 'XP ทั้งหมด',
          type: StatType.xp,
        ),
        StatCard(
          icon: Icons.task_alt,
          value: '${friend.totalTasksCompleted}',
          title: 'ภารกิจที่สำเร็จ',
          type: StatType.completed,
        ),
        StatCard(
          icon: Icons.local_fire_department,
          value: '${friend.currentStreak} วัน',
          title: 'วันที่ต่อเนื่องปัจจุบัน',
          type: StatType.currentStreak,
        ),
        StatCard(
          icon: Icons.emoji_events,
          value: '${friend.longestStreak} วัน',
          title: 'วันที่ต่อเนื่องสูงสุด',
          type: StatType.maxStreak,
        ),
      ],
    );
  }

  Widget _buildRemoveButton(bool isTablet) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.all(isTablet ? 24 : AppConstants.paddingMedium),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isRemoving ? null : _confirmRemoveFriend,
            style: OutlinedButton.styleFrom(
              foregroundColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFEF9A9A)
                  : const Color(0xFFE57373),
              side: BorderSide(
                color: Theme.of(context).brightness == Brightness.dark
                    ? const Color(0xFFEF9A9A)
                    : const Color(0xFFE57373),
                width: 1.5,
              ),
              backgroundColor: Colors.transparent,
              padding: EdgeInsets.symmetric(
                vertical: isTablet ? 18 : AppConstants.paddingMedium,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                  isTablet ? 16 : AppConstants.radiusMedium,
                ),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.person_remove_alt_1, size: isTablet ? 24 : 20),
                const SizedBox(width: 8),
                Text(
                  'ลบเพื่อน',
                  style: TextStyle(
                    fontSize: isTablet ? 18 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
