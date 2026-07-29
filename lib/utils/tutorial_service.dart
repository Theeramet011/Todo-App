import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../config/colors.dart';

class TutorialService {
  // GlobalKeys to attach to your target UI elements
  static final GlobalKey fabKey = GlobalKey();
  static final GlobalKey switcherKey = GlobalKey();
  static final GlobalKey navKey = GlobalKey();
  static final GlobalKey levelKey = GlobalKey();
  static final GlobalKey streakKey = GlobalKey();

  /// Call this function to start the guided tour.
  static void showTutorial(BuildContext context) {
    _showPart1(context);
  }

  static Widget _buildSkipWidget(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isLight
            ? Colors.white.withValues(alpha: 0.95)
            : const Color(0xFF2A2A2A).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isLight ? AppColors.stormySkyBlue : const Color(0xFF8A5CF5),
          width: 1.5,
        ),
      ),
      child: Text(
        'ข้าม',
        style: TextStyle(
          color: isLight ? AppColors.stormyDarkSlate : Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  static void _showPart1(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    late TutorialCoachMark tutorialCoachMark;
    tutorialCoachMark = TutorialCoachMark(
      targets: _createPart1Targets(),
      colorShadow: isLight
          ? AppColors.stormyDarkSlate
          : const Color(0xFF1A2530), // Adaptive shadow
      paddingFocus: 10,
      opacityShadow: 0.9,
      imageFilter: null,
      skipWidget: _buildSkipWidget(context),
      onClickOverlay: (target) {
        tutorialCoachMark.next();
      },
      onFinish: () {
        // Open drawer for the next part
        Scaffold.of(context).openDrawer();
        Future.delayed(const Duration(milliseconds: 400), () {
          if (context.mounted) {
            _showPart2(context);
          }
        });
      },
      onSkip: () => true,
    );
    tutorialCoachMark.show(context: context);
  }

  static void _showPart2(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    late TutorialCoachMark tutorialCoachMark;
    tutorialCoachMark = TutorialCoachMark(
      targets: _createPart2Targets(),
      colorShadow: isLight
          ? AppColors.stormyDarkSlate
          : const Color(0xFF1A2530),
      paddingFocus: 10,
      opacityShadow: 0.9,
      imageFilter: null,
      skipWidget: _buildSkipWidget(context),
      onClickOverlay: (target) {
        tutorialCoachMark.next();
      },
      onFinish: () {
        // Close drawer to return to home screen
        Scaffold.of(context).closeDrawer();
        Future.delayed(const Duration(milliseconds: 400), () {
          if (context.mounted) {
            _showPart3(context);
          }
        });
      },
      onSkip: () {
        Scaffold.of(context).closeDrawer();
        return true;
      },
    );
    tutorialCoachMark.show(context: context);
  }

  static void _showPart3(BuildContext context) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    late TutorialCoachMark tutorialCoachMark;
    tutorialCoachMark = TutorialCoachMark(
      targets: _createPart3Targets(),
      colorShadow: isLight
          ? AppColors.stormyDarkSlate
          : const Color(0xFF1A2530),
      paddingFocus: 10,
      opacityShadow: 0.9,
      imageFilter: null,
      skipWidget: _buildSkipWidget(context),
      onClickOverlay: (target) {
        tutorialCoachMark.next();
      },
      onFinish: () {
        debugPrint("Tutorial fully finished");
      },
      onSkip: () => true,
    );
    tutorialCoachMark.show(context: context);
  }

  static List<TargetFocus> _createPart1Targets() {
    return [
      TargetFocus(
        identify: "fabTarget",
        keyTarget: fabKey,
        enableOverlayTab: true,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTooltipContent(
                context: context,
                title: "เริ่มต้นการผจญภัย!",
                description:
                    "กดที่นี่เพื่อสร้างภารกิจใหม่ แล้วรับค่า EXP ทันทีที่ทำสำเร็จ",
                iconPath: 'assets/images/icons/swords.png',
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "switcherTarget",
        keyTarget: switcherKey,
        enableOverlayTab: true,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildTooltipContent(
                context: context,
                title: "สลับโหมดได้ดั่งใจ!",
                description:
                    "จะจัดการภารกิจส่วนตัวหรือลุยภารกิจกลุ่มกับเพื่อนก็ทำได้ที่นี่",
                iconPath: 'assets/images/icons/costumer.png',
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "navTarget",
        keyTarget: navKey,
        enableOverlayTab: true,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 16,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return _buildTooltipContent(
                context: context,
                title: "เมนูหลัก",
                description:
                    "ตรวจเช็คตารางย้อนหลังและตั้งค่าต่างๆ ได้จากเมนูหลักตรงนี้",
                iconPath: 'assets/images/icons/done.png',
              );
            },
          ),
        ],
      ),
    ];
  }

  static List<TargetFocus> _createPart2Targets() {
    return [
      TargetFocus(
        identify: "levelTarget",
        keyTarget: levelKey,
        enableOverlayTab: true,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.RRect,
        radius: 12,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildTooltipContent(
                context: context,
                title: "อัปเลเวลและพัฒนาตัวละคร!",
                description:
                    "ทุกภารกิจที่คุณทำสำเร็จจะเปลี่ยนเป็น EXP เพื่ออัปเลเวลและพัฒนาตัวละครของคุณ!",
                iconPath: 'assets/images/icons/star.png',
              );
            },
          ),
        ],
      ),
    ];
  }

  static List<TargetFocus> _createPart3Targets() {
    return [
      TargetFocus(
        identify: "streakTarget",
        keyTarget: streakKey,
        enableOverlayTab: true,
        alignSkip: Alignment.topRight,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return _buildTooltipContent(
                context: context,
                title: "รักษาความต่อเนื่อง!",
                description:
                    "ยิ่งคุณทำภารกิจทุกวัน Streak จะยิ่งพุ่งและปลดล็อกตราพิเศษ",
                iconPath: 'assets/images/icons/fire.png',
              );
            },
          ),
        ],
      ),
    ];
  }

  static Widget _buildTooltipContent({
    required BuildContext context,
    required String title,
    required String description,
    required String iconPath,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isLight ? Colors.white : const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: isLight ? AppColors.stormySkyBlue : const Color(0xFF8A5CF5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: isLight
                ? AppColors.stormySkyBlue.withValues(alpha: 0.15)
                : const Color(0xFF8A5CF5).withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(
                iconPath,
                width: 28,
                height: 28,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.star,
                    color: isLight ? AppColors.stormySkyBlue : Colors.amber,
                    size: 28,
                  );
                },
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isLight ? AppColors.stormyDarkSlate : Colors.white,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: TextStyle(
              color: isLight ? AppColors.stormyMutedBlueGrey : Colors.white70,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
