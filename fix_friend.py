# ============================================================================
# ไฟล์สคริปต์นี้เปรียบเสมือน "ช่างซ่อมบำรุงอัตโนมัติ" สำหรับหน้าจอรายละเอียดเพื่อน
# ทำหน้าที่เข้าไปลบโค้ดที่เกินมาหรือไม่ถูกต้อง ในไฟล์ `lib/screens/friend_detail_screen.dart`
# (เช่น การนำเข้าไลบรารีซ้ำซ้อน) เพื่อแก้ปัญหาแอปพังหรือทำงานผิดพลาด
# ============================================================================
with open("lib/screens/friend_detail_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

target = """  Future<void> _confirmRemoveFriend() async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/colors.dart';
import '../config/constants.dart';
import '../models/user.dart';
import '../widgets/user_avatar_with_frame.dart';
import '../providers/auth_provider.dart';
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
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog("""

replacement = """  Future<void> _confirmRemoveFriend() async {
    final shouldRemove = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog("""

content = content.replace(target, replacement)

with open("lib/screens/friend_detail_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
