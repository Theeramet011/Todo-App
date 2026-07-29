// FriendsScreen - หน้าจอจัดการรายชื่อเพื่อน (Friends Management)
//
// แสดงรายการเพื่อน รายการคำขอเป็นเพื่อน (Received/Sent Requests)
// และช่องทางค้นหาเพื่อส่งคำขอเป็นเพื่อนใหม่
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
    if (widget.openAddFriendModal) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => const AddFriendModal(),
        );
      });
    }
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

    // Sort friends by points (leaderboard style)
    final sortedFriends = List<User>.from(friends)
      ..sort((a, b) => b.totalXP.compareTo(a.totalXP));
    final filteredFriends = sortedFriends.where(_matchesSearchQuery).toList();

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? AppColors.stormyNightBackground
          : theme.scaffoldBackgroundColor,
      appBar: AppBar(title: const Text('เพื่อน'), elevation: 0),
      body: Column(
        children: [
          // Header with Stats
          _buildHeaderSection(context, friends),

          // Search Bar
          _buildSearchBar(context),

          // Friends List
          Expanded(
            child: filteredFriends.isEmpty
                ? _buildEmptySearchState(context)
                : ListView.separated(
                    padding: const EdgeInsets.all(AppConstants.paddingMedium),
                    itemCount: filteredFriends.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: AppConstants.paddingSmall),
                    itemBuilder: (context, index) {
                      final friend = filteredFriends[index];
                      final rank =
                          sortedFriends.indexWhere(
                            (sortedFriend) => sortedFriend.id == friend.id,
                          ) +
                          1;

                      return _buildFriendCard(context, friend, rank);
                    },
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

  Widget _buildHeaderSection(BuildContext context, List<User> friends) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUser = context.watch<AuthProvider>().currentUser;
    if (currentUser == null) return const SizedBox.shrink();
    final userRank = _getUserRank(currentUser, friends);

    return Container(
      margin: const EdgeInsets.all(AppConstants.paddingMedium),
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      decoration: BoxDecoration(
        gradient: theme.brightness == Brightness.light
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
        borderRadius: BorderRadius.circular(AppConstants.radiusXLarge),
      ),
      child: Column(
        children: [
          // Current User Stats
          Row(
            children: [
              // Avatar
              UserAvatarWithFrame(
                avatarUrl: currentUser.avatarUrl,
                frameId: currentUser.equippedFrame,
                fallbackName: currentUser.name,
                size: AppConstants.avatarXLarge,
              ),
              const SizedBox(width: AppConstants.paddingLarge),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      currentUser.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textWhite,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 16,
                          color: AppColors.accentYellow,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Level ${currentUser.currentLevel}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textWhite,
                          ),
                        ),
                        const SizedBox(width: AppConstants.paddingMedium),
                        Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: AppColors.textWhite.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${currentUser.totalTasksCompleted} ภารกิจ',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textWhite,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.emoji_events,
                          size: 16,
                          color: AppColors.textWhite.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'อันดับ #$userRank',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textWhite,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      currentUser.levelTitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textWhite.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.paddingLarge),

          // Progress to Next Level
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'ความคืบหน้าไปยัง Level ${currentUser.currentLevel + 1}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      // ignore: deprecated_member_use
                      color: AppColors.textWhite.withValues(alpha: 0.92),
                    ),
                  ),
                  Text(
                    '${currentUser.progressToNextLevel} / ${currentUser.nextLevelPoints} XP',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      // ignore: deprecated_member_use
                      color: AppColors.textWhite.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                child: LinearProgressIndicator(
                  value: currentUser.progressToNextLevelValue,
                  // ignore: deprecated_member_use
                  backgroundColor: isDark
                      ? Colors.white24
                      : AppColors.backgroundWhite.withValues(alpha: 0.3),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? AppColors.stormySkyBlue : AppColors.accentYellow,
                  ),
                  minHeight: 8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
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
            child: Container(
              padding: const EdgeInsets.all(AppConstants.paddingMedium),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? AppColors.stormyDarkSlate
                    : theme.cardColor,
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
              ),
              child: Icon(
                Icons.person_add_alt_1,
                color: theme.brightness == Brightness.dark
                    ? AppColors.stormySkyBlue
                    : (theme.brightness == Brightness.light
                          ? AppColors.stormyDarkSlate
                          : AppColors.primaryPink),
                size: 24,
              ),
            ),
          ),

          const SizedBox(width: 12),

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
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
              decoration: InputDecoration(
                hintText: 'ค้นหา',
                hintStyle: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
                prefixIcon: Icon(
                  Icons.search,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
                ),
                suffixIcon: _searchQuery.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'ล้างคำค้นหา',
                        icon: Icon(
                          Icons.close,
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
                    AppConstants.radiusMedium,
                  ),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingMedium,
                  vertical: AppConstants.paddingMedium,
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

  Widget _buildFriendCard(BuildContext context, User friend, int rank) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isTopThree = rank <= 3;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        enableFeedback: false,
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => FriendDetailScreen(friendUser: friend),
            ),
          );
        },
        child: Ink(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? AppColors.stormyDarkSlate
                : theme.cardColor,
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
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
                width: 40,
                child: Center(
                  child: isTopThree
                      ? Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: _getRankColor(rank),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Icon(
                              Icons.emoji_events,
                              size: 18,
                              color: _getRankIconColor(rank),
                            ),
                          ),
                        )
                      : Text(
                          '#$rank',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.75,
                            ),
                          ),
                        ),
                ),
              ),

              const SizedBox(width: AppConstants.paddingMedium),

              // Avatar
              Stack(
                children: [
                  UserAvatarWithFrame(
                    avatarUrl: friend.avatarUrl,
                    frameId: friend.equippedFrame,
                    fallbackName: friend.name,
                    size: AppConstants.avatarMedium,
                    showShadow: false,
                  ),
                  if (friend.isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: AppColors.success,
                          shape: BoxShape.circle,
                          border: Border.all(color: theme.cardColor, width: 2),
                        ),
                      ),
                    ),
                ],
              ),

              const SizedBox(width: AppConstants.paddingMedium),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            friend.name,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: theme.brightness == Brightness.dark
                                  ? AppColors.textWhite
                                  : theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (friend.isOnline) ...[
                          const SizedBox(width: 6),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.success,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 14,
                          color: AppColors.accentYellow,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Level ${friend.currentLevel}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.65,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppConstants.paddingMedium),
                        Icon(
                          Icons.check_circle_outline,
                          size: 14,
                          color: theme.brightness == Brightness.dark
                              ? AppColors.stormySkyBlue
                              : (theme.brightness == Brightness.light
                                    ? AppColors.stormyDarkSlate
                                    : AppColors.primaryPink),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${friend.totalTasksCompleted} ภารกิจ',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 12,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.65,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      friend.levelTitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11,
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
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontSize: 18,
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
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 11,
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

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700); // Gold
      case 2:
        return const Color(0xFFC0C0C0); // Silver
      case 3:
        return const Color(0xFFCD7F32); // Bronze
      default:
        return AppColors.backgroundGrey;
    }
  }

  Color _getRankIconColor(int rank) {
    switch (rank) {
      case 1:
      case 2:
        return Colors.black87;
      default:
        return AppColors.textWhite;
    }
  }

  int _getUserRank(User currentUser, List<User> friends) {
    final allUsers = [currentUser, ...friends];
    final sorted = List<User>.from(allUsers)
      ..sort((a, b) => b.totalXP.compareTo(a.totalXP));
    return sorted.indexWhere((user) => user.id == currentUser.id) + 1;
  }
}
