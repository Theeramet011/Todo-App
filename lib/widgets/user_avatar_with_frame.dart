import 'package:flutter/material.dart';

import '../config/colors.dart';

class UserAvatarWithFrame extends StatelessWidget {
  final String avatarUrl;
  final String frameId;
  final String fallbackName;
  final double size;
  final bool showShadow;

  const UserAvatarWithFrame({
    super.key,
    required this.avatarUrl,
    required this.frameId,
    required this.fallbackName,
    this.size = 80,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final frame = ProfileFrameStyle.fromId(frameId);
    final imageSize = frame.hasFrame ? size * 0.90 : size;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (showShadow && frame.hasFrame)
            Container(
              width: size * 0.92,
              height: size * 0.92,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: frame.colors.first.withValues(
                      alpha: 0.2 + frame.glowIntensity * 0.3,
                    ),
                    blurRadius: size * (0.16 + frame.glowIntensity * 0.14),
                    spreadRadius: 1 + frame.glowIntensity * 3,
                  ),
                ],
              ),
            ),
          Container(
            width: imageSize,
            height: imageSize,
            decoration: BoxDecoration(
              color: AppColors.backgroundWhite,
              shape: BoxShape.circle,
              border: null,
            ),
            clipBehavior: Clip.antiAlias,
            child: avatarUrl.isNotEmpty
                ? Image.network(
                    avatarUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _AvatarFallback(name: fallbackName);
                    },
                  )
                : _AvatarFallback(name: fallbackName),
          ),
          if (frame.hasFrame)
            IgnorePointer(
              child: Transform.scale(
                scale: frame.scale,
                child: Image.asset(
                  'assets/images/profile-frame/${frame.id}.png',
                  width: size,
                  height: size,
                  fit: BoxFit.contain,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ProfileFrameStyle {
  final String id;
  final String label;
  final List<Color> colors;
  final double glowIntensity;
  final double scale;

  const ProfileFrameStyle({
    required this.id,
    required this.label,
    required this.colors,
    this.glowIntensity = 0.0,
    this.scale = 1.38,
  });

  bool get hasFrame => id.isNotEmpty;

  static const none = ProfileFrameStyle(
    id: '',
    label: 'ไม่มีกรอบ',
    colors: [AppColors.backgroundDarkGrey, AppColors.backgroundWhite],
  );

  static const allFrames = <ProfileFrameStyle>[
    ProfileFrameStyle(
      id: 'bronze_frame',
      label: 'วัยรุ่นสร้างตัว',
      colors: [Color(0xFFCD7F32), Color(0xFFFFD29A)],
    ),
    ProfileFrameStyle(
      id: 'master_frame',
      label: 'มหาเทพ',
      colors: [AppColors.primaryPurple, AppColors.primaryBlue],
    ),
    ProfileFrameStyle(
      id: 'ultimate_crown',
      label: 'ราชาไม่หวั่นไหว',
      colors: [AppColors.accentYellow, AppColors.accentOrange],
    ),
    ProfileFrameStyle(
      id: 'diamond_frame',
      label: 'เพชรแท้ไม่มีวันสลาย',
      colors: [Colors.cyanAccent, Color(0xFF4FC3F7), Colors.white],
      glowIntensity: 0.7,
      scale: 1.9,
    ),
    ProfileFrameStyle(
      id: 'mythic_frame',
      label: 'ตำนานที่ยังมีชีวิต',
      colors: [Colors.deepPurpleAccent, Colors.pinkAccent, Colors.orangeAccent],
      glowIntensity: 1.0,
      scale: 1.4,
    ),
  ];

  static ProfileFrameStyle fromId(String id) {
    if (id.isEmpty) return none;
    for (final frame in allFrames) {
      if (frame.id == id) return frame;
    }
    return none;
  }
}

class _AvatarFallback extends StatelessWidget {
  final String name;

  const _AvatarFallback({required this.name});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? '?' : name.trim()[0].toUpperCase();

    return ColoredBox(
      color: AppColors.taskPink,
      child: Center(
        child: Text(
          initial,
          style: const TextStyle(
            color: AppColors.primaryPink,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}
