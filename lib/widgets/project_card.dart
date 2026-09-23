// [DEPRECATED / UNUSED] ProjectCard - วิดเจ็ตการ์ดโปรเจกต์เดิม (ไม่ได้ใช้งานในหน้าจอจริง)
//
// หมายเหตุ: หน้าจอจริงใช้ 'GroupProjectCard' (group_project_card.dart) ซึ่งทำงานร่วมกับโมเดล 'Task'
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../models/project.dart';
import '../providers/task_provider.dart';
import '../utils/thai_display.dart';
import '../utils/mock_data.dart';
import '../utils/responsive.dart';

class ProjectCard extends StatelessWidget {
  final Project project;
  final VoidCallback? onTap;

  const ProjectCard({super.key, required this.project, this.onTap});

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);

    return GestureDetector(
      onTap:
          onTap ??
          () {
            taskProvider.selectProject(project);
            // Navigate to project detail
          },
      child: Container(
        constraints: BoxConstraints(maxWidth: Responsive.cardMaxWidth(context)),
        margin: const EdgeInsets.only(bottom: AppConstants.paddingMedium),
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: AppColors.backgroundWhite,
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowLight,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with Color Indicator & Status
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: project.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppConstants.paddingSmall),
                Expanded(
                  child: Text(
                    project.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: project.statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusSmall,
                    ),
                  ),
                  child: Text(
                    project.statusLabel,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: project.statusColor,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppConstants.paddingSmall),

            // Description
            if (project.description.isNotEmpty)
              Text(
                project.description,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

            const SizedBox(height: AppConstants.paddingMedium),

            // Members
            Row(
              children: [
                Expanded(
                  child: SizedBox(
                    height: AppConstants.avatarMedium,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        for (
                          int i = 0;
                          i <
                              (project.memberIds.length > 4
                                  ? 4
                                  : project.memberIds.length);
                          i++
                        )
                          Positioned(
                            left: i * 24.0,
                            child: _buildMemberAvatar(
                              context,
                              project.memberIds[i],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                if (project.memberIds.length > 4) ...[
                  const SizedBox(width: 4),
                  Container(
                    width: AppConstants.avatarMedium - 8,
                    height: AppConstants.avatarMedium - 8,
                    decoration: BoxDecoration(
                      color: AppColors.backgroundGrey,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: AppColors.backgroundWhite,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '+${project.memberIds.length - 4}',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                // Task Count
                Text(
                  '${project.completedTasks}/${project.totalTasks} ภารกิจ',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppConstants.paddingMedium),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
              child: LinearProgressIndicator(
                value: project.progress,
                backgroundColor: AppColors.backgroundGrey,
                valueColor: AlwaysStoppedAnimation<Color>(project.color),
                minHeight: 6,
              ),
            ),

            const SizedBox(height: AppConstants.paddingSmall),

            // Due Date
            if (project.dueDate != null)
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 14,
                    color: AppColors.textLight,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'กำหนด ${_formatDueDate(project.dueDate!)}',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMemberAvatar(BuildContext context, String userId) {
    final user = MockData.getUserById(userId);
    final avatarUrl = user?.avatarUrl;

    return Container(
      width: AppConstants.avatarMedium - 8,
      height: AppConstants.avatarMedium - 8,
      decoration: BoxDecoration(
        color: AppColors.backgroundWhite,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.backgroundWhite, width: 2),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadowLight,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipOval(
        child: avatarUrl != null
            ? Image.network(
                avatarUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.person,
                    size: 16,
                    color: AppColors.stormySkyBlue,
                  );
                },
              )
            : const Icon(
                Icons.person,
                size: 16,
                color: AppColors.stormySkyBlue,
              ),
      ),
    );
  }

  String _formatDueDate(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now);

    if (difference.isNegative) {
      return 'เกินกำหนด';
    } else if (difference.inDays == 0) {
      return 'วันนี้';
    } else if (difference.inDays == 1) {
      return 'พรุ่งนี้';
    } else if (difference.inDays <= 7) {
      return 'ภายใน ${difference.inDays} วัน';
    } else {
      return thaiShortDate(dueDate, includeYear: true);
    }
  }
}
