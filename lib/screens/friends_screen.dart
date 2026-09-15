// FriendsScreen - หน้าจอจัดการรายชื่อเพื่อน (Friends Management)
//
// แสดงรายการเพื่อน รายการคำขอเป็นเพื่อน (Received/Sent Requests)
// และช่องทางค้นหาเพื่อส่งคำขอเป็นเพื่อนใหม่
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../widgets/add_friend_modal.dart';
import '../widgets/user_avatar_with_frame.dart';
import 'friend_detail_screen.dart';

class FriendsScreen extends StatefulWidget {
  final bool openAddFriendModal;

  const FriendsScreen({super.key, this.openAddFriendModal = false});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TaskProvider>().loadFriends();
      if (widget.openAddFriendModal) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const AddFriendModal(),
        );
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final currentUser = context.watch<AuthProvider>().currentUser;
    final friendIds = currentUser?.friends.toSet() ?? <String>{};
    final friends = taskProvider.friends
        .where((user) => friendIds.contains(user.id))
        .toList();
    final theme = Theme.of(context);

    // เช็คหากมีเพื่อนใหม่ใน currentUser.friends ที่ยังไม่ได้ถูกโหลดลงใน taskProvider.friends
    final loadedIds = taskProvider.friends.map((u) => u.id).toSet();
    final hasMissingFriends = friendIds.any((id) => !loadedIds.contains(id));
    if (hasMissingFriends) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<TaskProvider>().loadFriends();
        }
      });
    }

    // Combine current user with friends into leaderboard
    final allLeaderboardUsers = <User>[
      ?currentUser,
      ...friends,
    ];

    // Sort all users by totalXP (leaderboard style)
    final sortedUsers = List<User>.from(allLeaderboardUsers)
      ..sort((a, b) => b.totalXP.compareTo(a.totalXP));
    final filteredUsers = sortedUsers.where(_matchesSearchQuery).toList();

    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? AppColors.stormyNightBackground
          : theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'เพื่อน',
          style: (theme.textTheme.headlineMedium ?? const TextStyle()).copyWith(
            fontSize: isTablet ? 26 : 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Search Bar
          _buildSearchBar(context, isTablet),

          // Total Friends Count (Position 2)
          Padding(
            padding: EdgeInsets.fromLTRB(
              isTablet
                  ? AppConstants.paddingLarge
                  : AppConstants.paddingMedium,
              isTablet ? 4.0 : 2.0,
              isTablet
                  ? AppConstants.paddingLarge
                  : AppConstants.paddingMedium,
              isTablet ? 4.0 : 2.0,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _searchQuery.trim().isNotEmpty
                    ? 'ผลการค้นหา (${filteredUsers.length} คน)'
                    : 'เพื่อนทั้งหมด ${friends.length} คน',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 13.5,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ),
          ),

          // Friends & User Leaderboard List
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => context.read<TaskProvider>().loadFriends(),
              color: AppColors.stormySkyBlue,
              backgroundColor: theme.brightness == Brightness.dark
                  ? AppColors.stormyDarkSlate
                  : Colors.white,
              child: filteredUsers.isEmpty
                  ? SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: SizedBox(
                        height: MediaQuery.of(context).size.height * 0.45,
                        child: _buildEmptySearchState(context),
                      ),
                    )
                  : ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: EdgeInsets.fromLTRB(
                        isTablet
                            ? AppConstants.paddingLarge
                            : AppConstants.paddingMedium,
                        isTablet ? 10 : 8,
                        isTablet
                            ? AppConstants.paddingLarge
                            : AppConstants.paddingMedium,
                        isTablet
                            ? AppConstants.paddingLarge
                            : AppConstants.paddingMedium,
                      ),
                      itemCount: filteredUsers.length +
                          (friends.isEmpty && _searchQuery.isEmpty ? 1 : 0),
                      separatorBuilder: (context, index) => SizedBox(
                        height: isTablet ? 14 : AppConstants.paddingSmall,
                      ),
                      itemBuilder: (context, index) {
                        if (friends.isEmpty &&
                            _searchQuery.isEmpty &&
                            index == 1) {
                          return Padding(
                            padding: const EdgeInsets.only(top: 24.0),
                            child: _buildEmptySearchState(context),
                          );
                        }
                        final user = filteredUsers[index];
                        final rank =
                            sortedUsers.indexWhere(
                              (u) => u.id == user.id,
                            ) +
                            1;

                        return _buildFriendCard(
                          context,
                          user,
                          rank,
                          isTablet,
                          currentUser: currentUser,
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  bool _matchesSearchQuery(User friend) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    final searchableText = [
      friend.name,
      friend.email,
      friend.levelTitle,
      'Level ${friend.currentLevel}',
      '${friend.totalXP}',
      '${friend.totalTasksCompleted}',
    ].join(' ').toLowerCase();

    return searchableText.contains(query);
  }

  Widget _buildSearchBar(BuildContext context, bool isTablet) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUserId = context.watch<AuthProvider>().currentUser?.id;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        isTablet
            ? AppConstants.paddingLarge
            : AppConstants.paddingMedium,
        isTablet ? 18 : 14,
        isTablet
            ? AppConstants.paddingLarge
            : AppConstants.paddingMedium,
        isTablet ? 12 : 8,
      ),
      child: Row(
        children: [
          // Add Friend Button
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (context) => const AddFriendModal(),
              );
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  padding: EdgeInsets.all(
                    isTablet ? 16 : AppConstants.paddingMedium,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? AppColors.stormyDarkSlate
                        : theme.cardColor,
                    borderRadius: BorderRadius.circular(
                      isTablet ? 16 : AppConstants.radiusMedium,
                    ),
                  ),
                  child: Icon(
                    Icons.person_add_alt_1,
                    color: isDark
                        ? AppColors.stormySkyBlue
                        : (theme.brightness == Brightness.light
                              ? AppColors.stormyDarkSlate
                              : AppColors.primaryPink),
                    size: isTablet ? 28 : 24,
                  ),
                ),
                if (currentUserId != null)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('friend_requests')
                        .where('toId', isEqualTo: currentUserId)
                        .where('status', isEqualTo: 'pending')
                        .limit(1)
                        .snapshots(),
                    builder: (context, snapshot) {
                      final hasPending =
                          snapshot.hasData && snapshot.data!.docs.isNotEmpty;
                      if (!hasPending) return const SizedBox.shrink();

                      return Positioned(
                        top: -2,
                        right: -2,
                        child: Container(
                          width: isTablet ? 12 : 10,
                          height: isTablet ? 12 : 10,
                          decoration: BoxDecoration(
                            color: AppColors.error,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? AppColors.stormyNightBackground
                                  : theme.scaffoldBackgroundColor,
                              width: 1.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),

          SizedBox(width: isTablet ? 16 : 12),

          // Search Bar
          Expanded(
            child: TextField(
              controller: _searchController,
              textInputAction: TextInputAction.search,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
              style: (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
                fontSize: isTablet ? 17 : null,
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'ค้นหา',
                hintStyle: (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
                  fontSize: isTablet ? 17 : null,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  size: isTablet ? 28 : 24,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'ล้างคำค้นหา',
                        icon: Icon(
                          Icons.close,
                          size: isTablet ? 28 : 24,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.55,
                          ),
                        ),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      ),
                filled: true,
                fillColor: theme.brightness == Brightness.dark
                    ? AppColors.stormyDarkSlate
                    : theme.cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(
                    isTablet ? 16 : AppConstants.radiusMedium,
                  ),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 20 : AppConstants.paddingMedium,
                  vertical: isTablet ? 18 : AppConstants.paddingMedium,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySearchState(BuildContext context) {
    final theme = Theme.of(context);
    final hasQuery = _searchQuery.trim().isNotEmpty;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              hasQuery ? Icons.search_off : Icons.people_outline,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Text(
              hasQuery ? 'ยังไม่พบเพื่อน' : 'ยังไม่มีเพื่อน',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              hasQuery
                  ? 'ลองค้นหาด้วยชื่อ, อีเมล, ระดับ, หรือคะแนน'
                  : 'เพิ่มเพื่อนเพื่อดูที่นี่',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFriendCard(
    BuildContext context,
    User friend,
    int rank,
    bool isTablet, {
    User? currentUser,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isMe = currentUser != null && friend.id == currentUser.id;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        enableFeedback: false,
        borderRadius: BorderRadius.circular(
          isTablet ? 20 : AppConstants.radiusLarge,
        ),
        onTap: isMe
            ? null
            : () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (context) => FriendDetailScreen(friendUser: friend),
                  ),
                );
              },
        child: Ink(
          padding: EdgeInsets.all(
            isTablet ? 20 : AppConstants.paddingMedium,
          ),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? AppColors.stormyDarkSlate
                : theme.cardColor,
            borderRadius: BorderRadius.circular(
              isTablet ? 20 : AppConstants.radiusLarge,
            ),
            border: isMe
                ? Border.all(
                    color: AppColors.stormySkyBlue.withValues(alpha: 0.5),
                    width: 1.5,
                  )
                : null,
            boxShadow: isDark
                ? null
                : [
                    BoxShadow(
                      color: AppColors.shadowLight,
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Rank
              SizedBox(
                width: isTablet ? 50 : 40,
                child: Center(
                  child: Container(
                    width: isTablet ? 42 : 32,
                    height: isTablet ? 42 : 32,
                    decoration: BoxDecoration(
                      color: _getRankColor(rank, isDark),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Text(
                            '$rank',
                            style: TextStyle(
                              fontSize: isTablet ? 20 : 16,
                              fontWeight: FontWeight.bold,
                              color: _getRankTextColor(rank, isDark),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              SizedBox(
                width: isTablet
                    ? AppConstants.paddingLarge
                    : AppConstants.paddingMedium,
              ),

              // Avatar
              Stack(
                children: [
                  UserAvatarWithFrame(
                    avatarUrl: friend.avatarUrl,
                    frameId: friend.equippedFrame,
                    fallbackName: friend.name,
                    size: isTablet ? 60 : AppConstants.avatarMedium,
                    showShadow: false,
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: isTablet ? 18 : 14,
                      height: isTablet ? 18 : 14,
                      decoration: BoxDecoration(
                        color: (isMe || friend.isOnline)
                            ? AppColors.success
                            : (theme.brightness == Brightness.dark
                                  ? Colors.grey.shade600
                                  : Colors.grey.shade400),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: theme.cardColor,
                          width: isTablet ? 2.5 : 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              SizedBox(
                width: isTablet
                    ? AppConstants.paddingLarge
                    : AppConstants.paddingMedium,
              ),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            friend.name,
                            style: (theme.textTheme.bodyLarge ?? const TextStyle()).copyWith(
                              fontSize: isTablet ? 20 : 16,
                              fontWeight: FontWeight.w600,
                              color: theme.brightness == Brightness.dark
                                  ? AppColors.textWhite
                                  : theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isMe) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: isTablet ? 10 : 8,
                              vertical: isTablet ? 3 : 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.stormySkyBlue.withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.stormySkyBlue.withValues(alpha: 0.5),
                                width: 1,
                              ),
                            ),
                            child: Text(
                              'คุณ',
                              style: TextStyle(
                                fontSize: isTablet ? 13 : 11,
                                fontWeight: FontWeight.bold,
                                color: AppColors.stormySkyBlue,
                              ),
                            ),
                          ),
                        ] else ...[
                          const SizedBox(width: 6),
                          Container(
                            width: isTablet ? 10 : 8,
                            height: isTablet ? 10 : 8,
                            decoration: BoxDecoration(
                              color: friend.isOnline
                                  ? AppColors.success
                                  : (theme.brightness == Brightness.dark
                                        ? Colors.grey.shade600
                                        : Colors.grey.shade400),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.star,
                          size: isTablet ? 18 : 14,
                          color: AppColors.accentYellow,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Level ${friend.currentLevel}',
                          style: (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
                            fontSize: isTablet ? 15 : 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.65,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: isTablet
                              ? AppConstants.paddingLarge
                              : AppConstants.paddingMedium,
                        ),
                        Icon(
                          Icons.check_circle_outline,
                          size: isTablet ? 18 : 14,
                          color: theme.brightness == Brightness.dark
                              ? AppColors.stormySkyBlue
                              : (theme.brightness == Brightness.light
                                    ? AppColors.stormyDarkSlate
                                    : AppColors.primaryPink),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${friend.totalTasksCompleted} ภารกิจ',
                          style: (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
                            fontSize: isTablet ? 15 : 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.65,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      friend.levelTitle,
                      style: (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
                        fontSize: isTablet ? 14 : 11,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Points
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${friend.totalXP}',
                    style: (theme.textTheme.headlineMedium ?? const TextStyle()).copyWith(
                      fontSize: isTablet ? 24 : 18,
                      fontWeight: FontWeight.bold,
                      color: theme.brightness == Brightness.dark
                          ? AppColors.stormySkyBlue
                          : (theme.brightness == Brightness.light
                                ? AppColors.stormyDarkSlate
                                : AppColors.primaryPink),
                    ),
                  ),
                  Text(
                    'XP',
                    style: (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
                      fontSize: isTablet ? 14 : 11,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Color _getRankColor(int rank, bool isDark) {
    if (rank == 1) {
      return const Color(0xFFFFD700); // Yellow / Gold
    }
    return isDark ? const Color(0xFF64748B) : const Color(0xFFCBD5E1); // Grey
  }

  Color _getRankTextColor(int rank, bool isDark) {
    if (rank == 1) {
      return Colors.black87;
    }
    return isDark ? Colors.white : const Color(0xFF334155);
  }
}

