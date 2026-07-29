String thaiCategoryLabel(String value) {
  switch (value.trim().toLowerCase()) {
    case 'general':
    case 'ทั่วไป':
      return 'ทั่วไป';
    case 'personal':
      return 'ภารกิจส่วนตัว';
    case 'design':
      return 'ออกแบบ';
    case 'development':
      return 'พัฒนา';
    case 'marketing':
      return 'การตลาด';
    case 'meeting':
      return 'ประชุม';
    case 'documentation':
      return 'เอกสาร';
    case 'presentation':
      return 'นำเสนอ';
    case 'security':
      return 'ความปลอดภัย';
    case 'analytics':
      return 'วิเคราะห์ข้อมูล';
    default:
      return value;
  }
}

String thaiLevelTitle(int level) {
  if (level < 5) return 'ผู้เริ่มต้น';
  if (level < 10) return 'ระดับกลาง';
  if (level < 20) return 'ขั้นสูง';
  return 'ผู้เชี่ยวชาญ';
}

String thaiProjectStatusLabel(String value) {
  switch (value.trim().toLowerCase()) {
    case 'planning':
      return 'วางแผน';
    case 'active':
      return 'กำลังดำเนินการ';
    case 'on hold':
      return 'พักไว้';
    case 'completed':
      return 'เสร็จสิ้น';
    default:
      return value;
  }
}

String thaiChoiceLabel(String value) {
  switch (value.trim().toLowerCase()) {
    case 'easy':
      return 'ง่าย';
    case 'normal':
      return 'ปกติ';
    case 'hard':
      return 'ยาก';
    case 'small':
      return 'น้อย';
    case 'medium':
      return 'ปานกลาง';
    case 'large':
      return 'มาก';
    case 'none':
      return 'ไม่มี';
    case 'low':
      return 'ต่ำ';
    case 'high':
      return 'สูง';
    default:
      return value;
  }
}

const List<String> _thaiShortMonths = [
  'ม.ค.',
  'ก.พ.',
  'มี.ค.',
  'เม.ย.',
  'พ.ค.',
  'มิ.ย.',
  'ก.ค.',
  'ส.ค.',
  'ก.ย.',
  'ต.ค.',
  'พ.ย.',
  'ธ.ค.',
];

const List<String> _thaiShortWeekdays = [
  'จ.',
  'อ.',
  'พ.',
  'พฤ.',
  'ศ.',
  'ส.',
  'อา.',
];

String thaiShortDate(DateTime dateTime, {bool includeYear = false}) {
  final month = _thaiShortMonths[dateTime.month - 1];
  if (includeYear) {
    return '${dateTime.day} $month ${dateTime.year + 543}';
  }
  return '${dateTime.day} $month';
}

String thaiDateTime(DateTime dateTime) {
  final weekday = _thaiShortWeekdays[dateTime.weekday - 1];
  final date = thaiShortDate(dateTime, includeYear: true);
  final hour = dateTime.hour.toString().padLeft(2, '0');
  final minute = dateTime.minute.toString().padLeft(2, '0');
  return '$weekday $date เวลา $hour:$minute น.';
}

String thaiRelativePast(DateTime dateTime) {
  final difference = DateTime.now().difference(dateTime);
  if (difference.inMinutes < 1) return 'เมื่อสักครู่';
  if (difference.inHours < 1) return '${difference.inMinutes} นาทีที่แล้ว';
  if (difference.inDays < 1) return '${difference.inHours} ชม.ที่แล้ว';
  if (difference.inDays < 7) return '${difference.inDays} วันที่แล้ว';
  return thaiShortDate(dateTime);
}

String thaiRelativeFuture(DateTime dateTime) {
  final difference = dateTime.difference(DateTime.now());
  if (difference.inDays == 0) {
    if (difference.inHours == 0) {
      final minutes = difference.inMinutes <= 0 ? 0 : difference.inMinutes;
      return minutes == 0 ? 'ตอนนี้' : 'อีก $minutes นาที';
    }
    return 'อีก ${difference.inHours} ชม.';
  }
  if (difference.inDays == 1) return 'พรุ่งนี้';
  if (difference.inDays < 7) return 'อีก ${difference.inDays} วัน';
  return thaiShortDate(dateTime);
}

String thaiDueDate(DateTime dueDate) {
  final difference = dueDate.difference(DateTime.now());
  if (difference.inDays < 0) return 'เกินกำหนด';
  if (difference.inDays == 0) return 'วันนี้';
  if (difference.inDays == 1) return 'พรุ่งนี้';
  if (difference.inDays <= 7) return 'ภายใน ${difference.inDays} วัน';
  return thaiShortDate(dueDate, includeYear: true);
}

String thaiNotificationTag(String tag) {
  switch (tag.toLowerCase()) {
    case 'deadline':
      return 'ครบกำหนด';
    case 'follow-up':
      return 'ติดตาม';
    case 'reminder':
      return 'แจ้งเตือน';
    case 'message':
      return 'ข้อความ';
    case 'comment':
      return 'ความคิดเห็น';
    case 'group':
      return 'กลุ่ม';
    case 'submission':
      return 'ส่งงาน';
    case 'approved':
      return 'อนุมัติ';
    case 'rejected':
      return 'ปฏิเสธ';
    case 'friendrequest':
      return 'คำขอเป็นเพื่อน';
    case 'friendaccepted':
      return 'รับเป็นเพื่อน';
    case 'update':
      return 'อัปเดต';
    default:
      return tag;
  }
}
