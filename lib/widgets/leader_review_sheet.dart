import 'package:flutter/material.dart';
import '../models/group_task.dart';
import '../config/colors.dart';
import '../config/constants.dart';

class LeaderReviewSheet extends StatefulWidget {
  final GroupTask project;

  const LeaderReviewSheet({super.key, required this.project});

  @override
  State<LeaderReviewSheet> createState() => _LeaderReviewSheetState();
}

class _LeaderReviewSheetState extends State<LeaderReviewSheet> {
  final TextEditingController _commentController = TextEditingController();
  final Map<String, bool> _approvals = {};

  @override
  void initState() {
    super.initState();
    for (var subtask in widget.project.subTasks) {
      if (subtask.assignedToId != null) {
        _approvals[subtask.assignedToId!] = subtask.isCompleted;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: AppColors.backgroundLightGrey,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          _buildHeader(),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppConstants.paddingLarge),
              children: [
                _buildPendingCount(),
                const SizedBox(height: 20),
                ...widget.project.subTasks.map(
                  (subtask) => _buildAssigneeCard(subtask),
                ),
                const SizedBox(height: 20),
                _buildCommentsSection(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 12),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.backgroundDarkGrey,
          borderRadius: BorderRadius.circular(10),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.project.title,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const CircleAvatar(
                    radius: 12,
                    backgroundColor: AppColors.taskPurple,
                    child: Icon(
                      Icons.person,
                      size: 16,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'หัวหน้า: Nina',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  Widget _buildPendingCount() {
    final pending = widget.project.subTasks.where((t) => !t.isCompleted).length;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.taskBlue.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline,
            color: AppColors.primaryBlue,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            '$pending Pending Approvals',
            style: const TextStyle(
              color: AppColors.primaryBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssigneeCard(GroupSubTask subtask) {
    final member = widget.project.members.firstWhere(
      (m) => m.id == subtask.assignedToId,
      orElse: () =>
          GroupMember(id: '', name: 'ไม่ทราบชื่อ', avatarUrl: '', role: ''),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 25,
                backgroundColor: AppColors.backgroundGrey,
                backgroundImage: NetworkImage(
                  member.avatarUrl.isNotEmpty
                      ? member.avatarUrl
                      : 'https://i.pravatar.cc/150?u=${member.id}',
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      member.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      subtask.title,
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: AppColors.taskPurple.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${subtask.score} คะแนน',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryPurple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          if (subtask.submissionLink != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.backgroundLightGrey,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.insert_drive_file_outlined,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      subtask.submissionLink!,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.primaryBlue,
                        decoration: TextDecoration.underline,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 15),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: subtask.isLate
                      ? AppColors.taskPink.withValues(alpha: 0.5)
                      : AppColors.taskGreen.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  subtask.isLate ? 'ส่งช้า' : 'ตรงเวลา',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: subtask.isLate
                        ? AppColors.accentRed
                        : AppColors.primaryGreen,
                  ),
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  _buildActionButton(
                    'ปฏิเสธ',
                    AppColors.accentRed,
                    () => setState(() => _approvals[member.id] = false),
                    !(_approvals[member.id] ?? false),
                  ),
                  const SizedBox(width: 8),
                  _buildActionButton(
                    'อนุมัติ',
                    AppColors.primaryGreen,
                    () => setState(() => _approvals[member.id] = true),
                    _approvals[member.id] ?? false,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(
    String label,
    Color color,
    VoidCallback onTap,
    bool isActive,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: isActive
            ? color
            : (isDark
                ? AppColors.stormyDarkSlate
                : AppColors.backgroundLightGrey),
        foregroundColor: isActive
            ? Colors.white
            : (isDark ? Colors.white70 : AppColors.textSecondary),
        elevation: isActive ? 2 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildCommentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ความคิดเห็น',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.backgroundWhite,
            borderRadius: BorderRadius.circular(15),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: const InputDecoration(
                    hintText: 'เพิ่มความคิดเห็น...',
                    border: InputBorder.none,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.send, color: AppColors.stormySkyBlue),
                onPressed: () {
                  // Handle send comment
                  _commentController.clear();
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
