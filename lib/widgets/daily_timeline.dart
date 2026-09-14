import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import 'package:intl/intl.dart';

class DailyTimeline extends StatelessWidget {
  final List<Task> tasks;
  final DateTime date;

  const DailyTimeline({super.key, required this.tasks, required this.date});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    if (tasks.isEmpty) {
      return _buildEmptyState(context, isTablet);
    }

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 80),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Date Header
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: AppConstants.paddingLarge,
                vertical: isTablet ? 20 : AppConstants.paddingMedium,
              ),
              child: Row(
                children: [
                  Text(
                    'ตารางเวลา',
                    style: TextStyle(
                      fontSize: isTablet ? 24 : 18,
                      fontWeight: FontWeight.bold,
                      color: theme.brightness == Brightness.dark
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: AppConstants.paddingSmall),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 16 : 12,
                      vertical: isTablet ? 6 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.light
                          ? AppColors.stormyIceBlue
                          : AppColors.stormySkyBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(
                        isTablet ? AppConstants.radiusMedium : AppConstants.radiusSmall,
                      ),
                    ),
                    child: Text(
                      '${tasks.length} ภารกิจ',
                      style: TextStyle(
                        fontSize: isTablet ? 15 : 12,
                        fontWeight: FontWeight.w600,
                        color: theme.brightness == Brightness.light
                            ? AppColors.stormyDarkSlate
                            : AppColors.stormySkyBlue,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Timeline Items
            ...([...tasks]..sort((a, b) {
                  final priorityComparison = b.priority.index.compareTo(
                    a.priority.index,
                  );
                  if (priorityComparison != 0) return priorityComparison;
                  return a.dateTime.compareTo(b.dateTime);
                }))
                .map((task) => _buildTimelineItem(context, task, isTablet)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, Task task, bool isTablet) {
    final theme = Theme.of(context);
    final taskProvider = Provider.of<TaskProvider>(context);
    final color = task.priorityColor;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.paddingLarge,
        vertical: isTablet ? 6 : AppConstants.paddingSmall / 2,
      ),
      child: GestureDetector(
        onTap: () async {
          taskProvider.selectTask(task);
          await Navigator.pushNamed(context, '/task-detail');
        },
        child: Container(
          padding: EdgeInsets.all(isTablet ? 20 : AppConstants.paddingMedium),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(
              isTablet ? 18 : AppConstants.radiusLarge,
            ),
            border: Border.all(
              color: color.withValues(alpha: 0.3),
              width: theme.brightness == Brightness.dark ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              // Time Indicator
              Column(
                children: [
                  Container(
                    width: isTablet ? 16 : 12,
                    height: isTablet ? 16 : 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (tasks.indexOf(task) != tasks.length - 1)
                    Container(
                      width: isTablet ? 3 : 2,
                      height: isTablet ? 48 : 40,
                      color: color.withValues(alpha: 0.3),
                    ),
                ],
              ),
              SizedBox(
                width: isTablet
                    ? AppConstants.paddingLarge
                    : AppConstants.paddingMedium,
              ),

              // Task Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time
                    Text(
                      DateFormat('h:mm a').format(task.dateTime),
                      style: TextStyle(
                        fontSize: isTablet ? 15 : 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Title
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: isTablet ? 19 : 15,
                        fontWeight: FontWeight.w600,
                        color: task.isCompleted
                            ? AppColors.textLight
                            : (theme.brightness == Brightness.dark
                                  ? Colors.white
                                  : theme.colorScheme.onSurface),
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),

                    // Category
                    if (task.category != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.category!,
                        style: TextStyle(
                          fontSize: isTablet ? 15 : 12,
                          color: color,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Priority Dot
              Container(
                width: isTablet ? 12 : 8,
                height: isTablet ? 12 : 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isTablet) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.paddingXLarge),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: isTablet ? 100 : 80,
                height: isTablet ? 100 : 80,
                decoration: BoxDecoration(
                  color: AppColors.backgroundGrey,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.event_available,
                  size: isTablet ? 50 : 40,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: AppConstants.paddingLarge),
              Text(
                'ไม่มีภารกิจสำหรับวันนี้',
                style: TextStyle(
                  fontSize: isTablet ? 22 : 18,
                  fontWeight: FontWeight.w600,
                  color: theme.brightness == Brightness.dark
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppConstants.paddingSmall),
              Text(
                'พักผ่อนให้สบาย หรือวางแผนล่วงหน้าได้เลย!',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
