import 'package:flutter/material.dart';

class PriorityTag extends StatelessWidget {
  final String priority;

  const PriorityTag({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    Color backgroundColor;
    Color textColor;

    final normalizedPriority = priority.toLowerCase().trim();

    if (normalizedPriority == "ต่ำ" || normalizedPriority == "low") {
      backgroundColor = const Color(0xFFE0F2F1);
      textColor = const Color(0xFF00695C);
    } else if (normalizedPriority == "ปานกลาง" ||
        normalizedPriority == "medium") {
      backgroundColor = const Color(0xFFBDDDFC);
      textColor = const Color(0xFF384959);
    } else if (normalizedPriority == "สูง" || normalizedPriority == "high") {
      backgroundColor = const Color(0xFFFFF3E0);
      textColor = const Color(0xFFE65100);
    } else if (normalizedPriority == "ด่วน" || normalizedPriority == "urgent") {
      backgroundColor = const Color(0xFFFFEBEE);
      textColor = const Color(0xFFC62828);
    } else {
      backgroundColor = Colors.grey.shade200;
      textColor = Colors.grey.shade800;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        priority,
        style: TextStyle(
          color: textColor,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      ),
    );
  }
}
