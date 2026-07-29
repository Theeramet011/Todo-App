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
    if (tasks.isEmpty) {
      return _buildEmptyState(context);
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
              padding: const EdgeInsets.symmetric(
                horizontal: AppConstants.paddingLarge,
                vertical: AppConstants.paddingMedium,
              ),
              child: Row(
                children: [
                  Text(
                    'ตารางเวลา',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: theme.brightness == Brightness.dark
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: AppConstants.paddingSmall),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.light
                          ? AppColors.stormyIceBlue
                          : AppColors.stormySkyBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusSmall,
                      ),
                    ),
                    child: Text(
                      '${tasks.length} tasks',
                      style: TextStyle(
                        fontSize: 12,
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
                .map((task) => _buildTimelineItem(context, task)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(BuildContext context, Task task) {
    final theme = Theme.of(context);
    final taskProvider = Provider.of<TaskProvider>(context);
    final color = task.priorityColor;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingLarge,
        vertical: AppConstants.paddingSmall / 2,
      ),
      child: GestureDetector(
        onTap: () async {
          taskProvider.selectTask(task);
          await Navigator.pushNamed(context, '/task-detail');
        },
        child: Container(
          padding: const EdgeInsets.all(AppConstants.paddingMedium),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
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
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (tasks.indexOf(task) != tasks.length - 1)
                    Container(
                      width: 2,
                      height: 40,
                      color: color.withValues(alpha: 0.3),
                    ),
                ],
              ),
              const SizedBox(width: AppConstants.paddingMedium),

              // Task Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time
                    Text(
                      DateFormat('h:mm a').format(task.dateTime),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Title
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: 15,
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
                          fontSize: 12,
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
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.backgroundGrey,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.event_available,
                  size: 40,
                  color: AppColors.textLight,
                ),
              ),
              const SizedBox(height: AppConstants.paddingLarge),
              Text(
                'ไม่มีภารกิจสำหรับวันนี้',
                style: TextStyle(
                  fontSize: 18,
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
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
