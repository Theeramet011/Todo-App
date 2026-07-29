import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/connectivity_provider.dart';
import '../services/friend_request_service.dart';

class AddFriendModal extends StatefulWidget {
  const AddFriendModal({super.key});

  @override
  State<AddFriendModal> createState() => _AddFriendModalState();
}

class _AddFriendModalState extends State<AddFriendModal> {
  final TextEditingController _searchController = TextEditingController();
  List<User> _searchResults = [];
  bool _isSearching = false;
  bool _hasSearched = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String currentUserEmail) async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _hasSearched = false;
        _errorMessage = '';
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _hasSearched = true;
      _errorMessage = '';
    });

    try {
      final currentUser = Provider.of<AuthProvider>(
        context,
        listen: false,
      ).currentUser;
      if (currentUser == null) return;

      // ค้นหาจาก email ก่อน
      var snapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: query)
          .get();

      // ถ้าไม่เจอ ค้นหาจาก name
      if (snapshot.docs.isEmpty) {
        snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where('name', isEqualTo: query)
            .get();
      }

      final results = snapshot.docs
          .map((doc) => User.fromMap(doc.data(), doc.id))
          .where((user) => user.id != currentUser.id) // ไม่แสดงตัวเอง
          .toList();

      if (!mounted) return;

      setState(() {
        _searchResults = results;
        _isSearching = false;
        if (results.isEmpty) {
          _errorMessage = 'ไม่พบผู้ใช้ที่ค้นหา';
        }
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isSearching = false;
        _errorMessage = 'เกิดข้อผิดพลาดในการค้นหา';
      });
    }
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() {
      _searchResults = [];
      _hasSearched = false;
      _errorMessage = '';
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final currentUser = Provider.of<AuthProvider>(context).currentUser;
    if (currentUser == null) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingLarge,
            vertical: AppConstants.paddingMedium,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ขีดแดชบอร์ดด้านบนสุดของ Modal
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.brightness == Brightness.dark
                        ? AppColors.stormyMutedBlueGrey
                        : AppColors.backgroundDarkGrey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // หัวข้อ Modal
              Text(
                'เพิ่มเพื่อน',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),

              // ช่องค้นหา (Search TextField)
              TextField(
                controller: _searchController,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.brightness == Brightness.dark
                      ? AppColors.textWhite
                      : theme.colorScheme.onSurface,
                ),
                decoration: InputDecoration(
                  hintText: 'ค้นหาด้วยชื่อ หรือ อีเมล...',
                  hintStyle: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.brightness == Brightness.dark
                        ? AppColors.stormyMutedBlueGrey
                        : theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                  prefixIcon: Icon(
                    Icons.search,
                    color: theme.brightness == Brightness.dark
                        ? AppColors.stormyMutedBlueGrey
                        : theme.colorScheme.onSurface.withValues(alpha: 0.55),
                  ),
                  suffixIcon: _hasSearched
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: _clearSearch,
                        )
                      : null,
                  filled: true,
                  fillColor: theme.brightness == Brightness.dark
                      ? AppColors.stormyNightBackground
                      : AppColors.backgroundLightGrey,
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
                onSubmitted: (_) => _performSearch(currentUser.email),
              ),
              const SizedBox(height: 20),

              // การสลับ UI ระหว่างค้นหา กับ คำขอที่รอดำเนินการ
              _isSearching
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.symmetric(vertical: 30.0),
                        child: CircularProgressIndicator(
                          color: AppColors.stormySkyBlue,
                        ),
                      ),
                    )
                  : _hasSearched
                  ? _buildSearchResults(currentUser)
                  : _buildPendingRequestsSection(currentUser),
            ],
          ),
        ),
      ),
    );
  }

  // ส่วนแสดงผลลัพธ์การค้นหา
  Widget _buildSearchResults(User currentUser) {
    final theme = Theme.of(context);

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 30.0),
          child: Text(
            _errorMessage,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'ผลลัพธ์การค้นหา',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 12),
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _searchResults.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            final searchedUser = _searchResults[index];
            return SearchResultCard(
              searchedUser: searchedUser,
              currentUser: currentUser,
            );
          },
        ),
      ],
    );
  }

  // ส่วนดึงและแสดงคำขอที่รอดำเนินการ
  Widget _buildPendingRequestsSection(User currentUser) {
    final theme = Theme.of(context);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friend_requests')
          .where('toId', isEqualTo: currentUser.id)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: CircularProgressIndicator(color: AppColors.stormySkyBlue),
            ),
          );
        }

        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const SizedBox.shrink(); // ไม่ต้องแสดงอะไรถ้าไม่มีคำขอ
        }

        final requests = snapshot.data!.docs;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.mail_outline_rounded,
                  color: AppColors.stormySkyBlue,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'คำขอเพิ่มเพื่อนของคุณ (${requests.length})',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 250),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: requests.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final requestDoc = requests[index];
                  final requestData = requestDoc.data() as Map<String, dynamic>;
                  final fromId = requestData['fromId'] ?? '';
                  final requestDocId = requestDoc.id;

                  return PendingRequestTile(
                    fromId: fromId,
                    requestDocId: requestDocId,
                    currentUser: currentUser,
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

// วิดเจ็ตการแสดงผลลัพธ์ผู้ใช้จากการค้นหา พร้อมปุ่มดำเนินการ
class SearchResultCard extends StatefulWidget {
  final User searchedUser;
  final User currentUser;

  const SearchResultCard({
    super.key,
    required this.searchedUser,
    required this.currentUser,
  });

  @override
  State<SearchResultCard> createState() => _SearchResultCardState();
}

class _SearchResultCardState extends State<SearchResultCard> {
  bool _isProcessing = false;
  final FriendRequestService _friendRequestService = FriendRequestService();

  Future<void> _sendFriendRequest() async {
    final connectivity = context.read<ConnectivityProvider>();
    if (connectivity.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่มีการเชื่อมต่ออินเทอร์เน็ต ไม่สามารถดำเนินการได้'),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await _friendRequestService.sendFriendRequest(
        fromUser: widget.currentUser,
        toUser: widget.searchedUser,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'ส่งคำขอเพิ่มเพื่อนไปยัง ${widget.searchedUser.name} แล้ว',
            ),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เกิดข้อผิดพลาดในการส่งคำขอเพิ่มเพื่อน'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // เช็คว่าสถานะความสัมพันธ์เป็นอย่างไร
    final isAlreadyFriend = widget.currentUser.friends.contains(
      widget.searchedUser.id,
    );

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('friend_requests')
          .where('fromId', isEqualTo: widget.currentUser.id)
          .where('toId', isEqualTo: widget.searchedUser.id)
          .where('status', isEqualTo: 'pending')
          .snapshots(),
      builder: (context, snapshot) {
        bool hasSentRequest = false;
        if (snapshot.hasData && snapshot.data!.docs.isNotEmpty) {
          hasSentRequest = true;
        }

        return Container(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.light
                ? AppColors.backgroundLightGrey
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: AppConstants.avatarMedium,
                height: AppConstants.avatarMedium,
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: widget.searchedUser.avatarUrl.isNotEmpty
                      ? Image.network(
                          widget.searchedUser.avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.person,
                                color: AppColors.stormySkyBlue,
                              ),
                        )
                      : const Icon(
                          Icons.person,
                          color: AppColors.stormySkyBlue,
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // รายละเอียด
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.searchedUser.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 12,
                          color: AppColors.accentYellow,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Level ${widget.searchedUser.currentLevel}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.65,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ปุ่มดำเนินการ
              _isProcessing
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.stormySkyBlue,
                        ),
                      ),
                    )
                  : isAlreadyFriend
                  ? TextButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.check, size: 16),
                      label: const Text('เป็นเพื่อนแล้ว'),
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.onSurface.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    )
                  : hasSentRequest
                  ? TextButton.icon(
                      onPressed: null,
                      icon: const Icon(Icons.schedule, size: 16),
                      label: const Text('ส่งคำขอแล้ว'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.stormySkyBlue.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    )
                  : ElevatedButton(
                      onPressed: _sendFriendRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.stormySkyBlue,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'เพิ่มเพื่อน',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
            ],
          ),
        );
      },
    );
  }
}

// รายการคำขอที่รอดำเนินการแต่ละรายการ ดึงข้อมูลโปรไฟล์ผู้ส่งแบบ Real-time/Future
class PendingRequestTile extends StatefulWidget {
  final String fromId;
  final String requestDocId;
  final User currentUser;

  const PendingRequestTile({
    super.key,
    required this.fromId,
    required this.requestDocId,
    required this.currentUser,
  });

  @override
  State<PendingRequestTile> createState() => _PendingRequestTileState();
}

class _PendingRequestTileState extends State<PendingRequestTile> {
  bool _isProcessing = false;
  final FriendRequestService _friendRequestService = FriendRequestService();

  // ฟังก์ชันยอมรับคำขอเพิ่มเพื่อน (Accept using Firestore WriteBatch)
  Future<void> _acceptRequest() async {
    final connectivity = context.read<ConnectivityProvider>();
    if (connectivity.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่มีการเชื่อมต่ออินเทอร์เน็ต ไม่สามารถดำเนินการได้'),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await _friendRequestService.acceptFriendRequest(
        requestId: widget.requestDocId,
        requesterId: widget.fromId,
        currentUser: widget.currentUser,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ยอมรับคำขอเพิ่มเพื่อนสำเร็จแล้ว 🎉'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เกิดข้อผิดพลาดในการยอมรับคำขอเพิ่มเพื่อน'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  // ฟังก์ชันปฏิเสธคำขอเพิ่มเพื่อน (Decline using Firestore delete)
  Future<void> _declineRequest() async {
    final connectivity = context.read<ConnectivityProvider>();
    if (connectivity.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่มีการเชื่อมต่ออินเทอร์เน็ต ไม่สามารถดำเนินการได้'),
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      await _friendRequestService.declineFriendRequest(
        requestId: widget.requestDocId,
        recipientId: widget.currentUser.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ปฏิเสธคำขอเพิ่มเพื่อนแล้ว'),
            backgroundColor: AppColors.textSecondary,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('เกิดข้อผิดพลาดในการปฏิเสธคำขอ'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance
          .collection('users')
          .doc(widget.fromId)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 72,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.light
                  ? AppColors.backgroundLightGrey
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            ),
            child: const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.stormySkyBlue,
                ),
              ),
            ),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const SizedBox.shrink();
        }

        final senderData = snapshot.data!.data() as Map<String, dynamic>;
        final user = User.fromMap(senderData, snapshot.data!.id);

        return Container(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.light
                ? AppColors.backgroundLightGrey
                : Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: AppConstants.avatarMedium,
                height: AppConstants.avatarMedium,
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: user.avatarUrl.isNotEmpty
                      ? Image.network(
                          user.avatarUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                Icons.person,
                                color: AppColors.stormySkyBlue,
                              ),
                        )
                      : const Icon(
                          Icons.person,
                          color: AppColors.stormySkyBlue,
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // ข้อมูลผู้ใช้
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(
                          Icons.star,
                          size: 12,
                          color: AppColors.accentYellow,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Level ${user.currentLevel}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.65,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // ปุ่มยอมรับ หรือ ปฏิเสธ
              _isProcessing
                  ? const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 24.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.stormySkyBlue,
                        ),
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // ปุ่มยอมรับ
                        IconButton(
                          icon: const Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.success,
                            size: 28,
                          ),
                          tooltip: 'ยอมรับ',
                          onPressed: _acceptRequest,
                        ),
                        // ปุ่มปฏิเสธ
                        IconButton(
                          icon: const Icon(
                            Icons.cancel_rounded,
                            color: AppColors.error,
                            size: 28,
                          ),
                          tooltip: 'ปฏิเสธ',
                          onPressed: _declineRequest,
                        ),
                      ],
                    ),
            ],
          ),
        );
      },
    );
  }
}
