import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/colors.dart';
import '../config/constants.dart';
import '../models/user.dart';
import '../providers/auth_provider.dart';
import '../providers/connectivity_provider.dart';
import 'user_avatar_with_frame.dart';

class FramePickerWidget extends StatefulWidget {
  final User user;

  const FramePickerWidget({super.key, required this.user});

  @override
  State<FramePickerWidget> createState() => _FramePickerWidgetState();
}

class _FramePickerWidgetState extends State<FramePickerWidget> {
  late String previewFrameId;
  bool _isApplying = false;

  @override
  void initState() {
    super.initState();
    previewFrameId = widget.user.equippedFrame;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final unlockedItems = widget.user.unlockedItems.toSet();
    final frameOptions = [
      ProfileFrameStyle.none,
      ...ProfileFrameStyle.allFrames,
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppConstants.paddingLarge,
          AppConstants.paddingMedium,
          AppConstants.paddingLarge,
          AppConstants.paddingLarge,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            Text(
              'เลือกกรอบโปรไฟล์',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: isDark ? Colors.white : null,
              ),
            ),
            const SizedBox(height: 40),
            UserAvatarWithFrame(
              avatarUrl: widget.user.avatarUrl,
              frameId: previewFrameId,
              fallbackName: widget.user.name,
              size: 132,
            ),
            const SizedBox(height: 16),
            Text(
              ProfileFrameStyle.fromId(previewFrameId).label,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : AppColors.textWhite,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: frameOptions.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: AppConstants.paddingMedium,
                crossAxisSpacing: AppConstants.paddingMedium,
                childAspectRatio: 0.88,
              ),
              itemBuilder: (context, index) {
                final frame = frameOptions[index];
                final isUnlocked =
                    frame.id.isEmpty || unlockedItems.contains(frame.id);
                final isSelected = previewFrameId == frame.id;

                return _FrameOptionTile(
                  frame: frame,
                  user: widget.user,
                  isUnlocked: isUnlocked,
                  isSelected: isSelected,
                  onTap: () {
                    setState(() {
                      previewFrameId = frame.id;
                    });
                  },
                );
              },
            ),
            const SizedBox(height: AppConstants.paddingLarge),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isApplying ? null : _applySelectedFrame,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.stormySkyBlue,
                  foregroundColor: isDark
                      ? AppColors.stormyNightBackground
                      : AppColors.textWhite,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusMedium,
                    ),
                  ),
                ),
                child: _isApplying
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.textWhite,
                        ),
                      )
                    : const Text('นำไปใช้'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _applySelectedFrame() async {
    final connectivity = context.read<ConnectivityProvider>();
    if (connectivity.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่มีการเชื่อมต่ออินเทอร์เน็ต ไม่สามารถดำเนินการได้'),
        ),
      );
      return;
    }

    if (!_isFrameUnlocked(previewFrameId)) {
      _showLockedFrameSnackBar();
      return;
    }

    setState(() {
      _isApplying = true;
    });

    try {
      await context.read<AuthProvider>().equipItem(
        'equippedFrame',
        previewFrameId,
      );

      if (mounted) {
        Navigator.of(context).pop();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isApplying = false;
        });
      }
    }
  }

  bool _isFrameUnlocked(String frameId) {
    return frameId.isEmpty || widget.user.unlockedItems.contains(frameId);
  }

  void _showLockedFrameSnackBar() {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => _TopNotificationOverlay(
        message: 'ไม่สามารถใช้ได้ Level ยังไม่ถึงที่กำหนด',
        onDismiss: () {
          if (entry.mounted) entry.remove();
        },
      ),
    );

    overlay.insert(entry);
  }
}

class _TopNotificationOverlay extends StatefulWidget {
  final String message;
  final VoidCallback onDismiss;

  const _TopNotificationOverlay({
    required this.message,
    required this.onDismiss,
  });

  @override
  State<_TopNotificationOverlay> createState() =>
      _TopNotificationOverlayState();
}

class _TopNotificationOverlayState extends State<_TopNotificationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 320),
      reverseDuration: const Duration(milliseconds: 240),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _fadeAnimation = CurvedAnimation(parent: _controller, curve: Curves.easeIn);

    _controller.forward();

    Future.delayed(const Duration(milliseconds: 2500), _dismiss);
  }

  void _dismiss() {
    if (!mounted) return;
    _controller.reverse().then((_) {
      if (mounted) widget.onDismiss();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);

    return Positioned(
      top: mediaQuery.padding.top + 12,
      left: AppConstants.paddingMedium,
      right: AppConstants.paddingMedium,
      child: SlideTransition(
        position: _slideAnimation,
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Material(
            color: Colors.transparent,
            child: GestureDetector(
              onTap: _dismiss,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppConstants.paddingMedium,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  color: AppColors.error,
                  borderRadius: BorderRadius.circular(
                    AppConstants.radiusMedium,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.error.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_outline_rounded,
                      color: AppColors.textWhite,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: const TextStyle(
                          color: AppColors.textWhite,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _FrameOptionTile extends StatelessWidget {
  final ProfileFrameStyle frame;
  final User user;
  final bool isUnlocked;
  final bool isSelected;
  final VoidCallback? onTap;

  const _FrameOptionTile({
    required this.frame,
    required this.user,
    required this.isUnlocked,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      enableFeedback: false,
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.stormySkyBlue.withValues(alpha: 0.15)
              : (isDark
                    ? AppColors.stormyDarkSlate
                    : theme.colorScheme.surface),
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(
            color: isSelected
                ? AppColors.stormySkyBlue
                : (isDark
                      ? Colors.transparent
                      : theme.colorScheme.outline.withValues(alpha: 0.16)),
            width: isSelected ? 2 : (isDark ? 0 : 1),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Opacity(
                    opacity: isUnlocked ? 1 : 0.32,
                    child: UserAvatarWithFrame(
                      avatarUrl: user.avatarUrl,
                      frameId: frame.id,
                      fallbackName: user.name,
                      size: 58,
                      showShadow: false,
                    ),
                  ),
                  if (!isUnlocked)
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.transparent
                            : Colors.black.withValues(alpha: 0.62),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock,
                        color: isDark
                            ? AppColors.stormyMutedBlueGrey
                            : AppColors.textWhite,
                        size: 18,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            Text(
              frame.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isDark
                    ? (isSelected
                          ? AppColors.stormySkyBlue
                          : AppColors.stormyMutedBlueGrey)
                    : (isUnlocked
                          ? theme.colorScheme.onSurface
                          : theme.colorScheme.onSurface.withValues(
                              alpha: 0.45,
                            )),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
