import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task.dart';
import '../config/colors.dart';

class LatePenaltyDialog extends StatelessWidget {
  final bool isGroupSubmission;

  const LatePenaltyDialog({super.key, this.isGroupSubmission = false});

  /// เช็คเงื่อนไขและแสดง dialog หากจำเป็น
  /// คืนค่า `true` ถ้าให้ทำงานต่อ, `false` ถ้ายกเลิก
  static Future<bool> checkAndShow(
    BuildContext context,
    Task task, {
    bool isGroupSubmission = false,
  }) async {
    // ใช้กับงานส่วนตัวหรืองานกลุ่มที่มีการกำหนดส่งงาน
    if (!task.isPersonal && !isGroupSubmission) return true;

    // ถ้ายกเลิกสถานะสำเร็จ (จากที่เคยสำเร็จแล้ว) ก็ไม่ต้องแสดงการหักคะแนนตอนยกเลิก
    if (task.isCompleted) return true;

    final diffHours = DateTime.now().difference(task.dateTime).inHours;
    // ถ้าไม่เลย 24 ชม. ข้ามไป
    if (diffHours < 24) return true;

    final prefs = await SharedPreferences.getInstance();
    final hasSeen = prefs.getBool('has_seen_late_penalty_warning') ?? false;

    if (hasSeen) return true;

    if (!context.mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) =>
          LatePenaltyDialog(isGroupSubmission: isGroupSubmission),
    );

    return result ?? false; // ถ้าคลิกนอกกรอบจะคืนค่า null ถือว่ายกเลิก
  }

  @override
  Widget build(BuildContext context) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return AlertDialog(
      title: Text(
        isGroupSubmission ? 'ส่งงานเกินกำหนด' : 'เสร็จงานเกินกำหนด',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: isTablet ? 22 : 18,
        ),
      ),
      content: Text(
        isGroupSubmission
            ? 'คุณส่งงานเกินกำหนดไป 24 ชั่วโมงแล้ว คุณจะถูกหักคะแนนส่วนนึงออก'
            : 'คุณเสร็จงานเกินกำหนดไป 24 ชั่วโมงแล้ว คุณจะถูกหักคะแนนส่วนนึงออก',
        style: TextStyle(
          fontSize: isTablet ? 16 : 14.5,
          height: 1.5,
        ),
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(isTablet ? 22 : 16.0),
      ),
      actionsPadding: EdgeInsets.symmetric(
        horizontal: isTablet ? 20 : 16,
        vertical: isTablet ? 16 : 12,
      ),
      actions: [
        TextButton(
          onPressed: () async {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setBool('has_seen_late_penalty_warning', true);
            if (context.mounted) {
              Navigator.of(context).pop(true);
            }
          },
          style: TextButton.styleFrom(
            foregroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppColors.stormySkyBlue
                : AppColors.stormyMutedBlueGrey,
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16,
              vertical: isTablet ? 12 : 10,
            ),
          ),
          child: Text(
            'ไม่ต้องแสดงอีก',
            style: TextStyle(
              fontSize: isTablet ? 16 : 14.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.stormySkyBlue,
            foregroundColor: Theme.of(context).brightness == Brightness.dark
                ? AppColors.stormyNightBackground
                : Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16,
              vertical: isTablet ? 12 : 10,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8.0),
            ),
          ),
          child: Text(
            'ตกลง',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: isTablet ? 16 : 14.5,
            ),
          ),
        ),
      ],
    );
  }
}
