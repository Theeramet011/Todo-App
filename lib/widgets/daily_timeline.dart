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
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;

    if (tasks.isEmpty) {
      return _buildEmptyState(context, isTablet, isLandscape);
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
                vertical: isLandscape
                    ? 8
                    : (isTablet ? 20 : AppConstants.paddingMedium),
              ),
              child: Row(
                children: [
                  Text(
                    'ตารางเวลา',
                    style: TextStyle(
                      fontSize: isLandscape ? 18 : (isTablet ? 24 : 18),
                      fontWeight: FontWeight.bold,
                      color: theme.brightness == Brightness.dark
                          ? Colors.white
                          : theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(width: AppConstants.paddingSmall),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isLandscape ? 10 : (isTablet ? 16 : 12),
                      vertical: isLandscape ? 4 : (isTablet ? 6 : 4),
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
                        fontSize: isLandscape ? 12 : (isTablet ? 15 : 12),
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
                .map((task) => _buildTimelineItem(context, task, isTablet, isLandscape)),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineItem(
    BuildContext context,
    Task task,
    bool isTablet,
    bool isLandscape,
  ) {
    final theme = Theme.of(context);
    final taskProvider = Provider.of<TaskProvider>(context);
    final color = task.priorityColor;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.paddingLarge,
        vertical: isLandscape ? 4 : (isTablet ? 6 : AppConstants.paddingSmall / 2),
      ),
      child: GestureDetector(
        onTap: () async {
          taskProvider.selectTask(task);
          await Navigator.pushNamed(context, '/task-detail');
        },
        child: Container(
          padding: EdgeInsets.all(
            isLandscape ? 12 : (isTablet ? 20 : AppConstants.paddingMedium),
          ),
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
                    width: isLandscape ? 10 : (isTablet ? 16 : 12),
                    height: isLandscape ? 10 : (isTablet ? 16 : 12),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (tasks.indexOf(task) != tasks.length - 1)
                    Container(
                      width: isTablet ? 3 : 2,
                      height: isLandscape ? 36 : (isTablet ? 48 : 40),
                      color: color.withValues(alpha: 0.3),
                    ),
                ],
              ),
              SizedBox(
                width: isLandscape
                    ? 12
                    : (isTablet
                        ? AppConstants.paddingLarge
                        : AppConstants.paddingMedium),
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
                        fontSize: isLandscape ? 12 : (isTablet ? 15 : 12),
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Title
                    Text(
                      task.title,
                      style: TextStyle(
                        fontSize: isLandscape ? 14 : (isTablet ? 19 : 15),
                        fontWeight: FontWeight.w600,
                        color: task.isCompleted
                            ? AppColors.textLight
                            : (theme.brightness == Brightness.dark
                                ? Colors.white
                                : theme.colorScheme.onSurface),
                        decoration: task.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                        decorationColor: task.isCompleted
                            ? AppColors.primaryGreen
                            : null,
                        decorationThickness: 2.0,
                      ),
                    ),

                    // Category
                    if (task.category != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        task.category!,
                        style: TextStyle(
                          fontSize: isLandscape ? 12 : (isTablet ? 15 : 12),
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
                width: isLandscape ? 8 : (isTablet ? 12 : 8),
                height: isLandscape ? 8 : (isTablet ? 12 : 8),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(
    BuildContext context,
    bool isTablet,
    bool isLandscape,
  ) {
    final theme = Theme.of(context);
    return Center(
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: Padding(
          padding: EdgeInsets.all(
            isLandscape ? 12.0 : AppConstants.paddingXLarge,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: isLandscape ? 52 : (isTablet ? 100 : 80),
                height: isLandscape ? 52 : (isTablet ? 100 : 80),
                decoration: BoxDecoration(
                  color: AppColors.backgroundGrey,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.event_available,
                  size: isLandscape ? 26 : (isTablet ? 50 : 40),
                  color: AppColors.textLight,
                ),
              ),
              SizedBox(height: isLandscape ? 8 : AppConstants.paddingLarge),
              Text(
                'ไม่มีภารกิจสำหรับวันนี้',
                style: TextStyle(
                  fontSize: isLandscape ? 16 : (isTablet ? 22 : 18),
                  fontWeight: FontWeight.w600,
                  color: theme.brightness == Brightness.dark
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: isLandscape ? 4 : AppConstants.paddingSmall),
              Text(
                'พักผ่อนให้สบาย หรือวางแผนล่วงหน้าได้เลย!',
                style: TextStyle(
                  fontSize: isLandscape ? 13 : (isTablet ? 16 : 14),
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
