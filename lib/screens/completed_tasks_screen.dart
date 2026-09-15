// CompletedTasksScreen - หน้าจอแสดงรายการงานที่เสร็จสิ้นแล้ว (Completed Tasks)
//
// จัดเก็บและแสดงผลรายการงานที่ทำเสร็จสมบูรณ์ รองรับการค้นหา กรองข้อมูลตามช่วงเวลา
// การเปลี่ยนสถานะกลับเป็นยังไม่เสร็จ หรือการย้ายงานไปยังถังขยะ
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../utils/snack_bar_utils.dart';
import 'bin_screen.dart';
import 'task_detail_screen.dart';
import '../providers/connectivity_provider.dart';

class CompletedTasksScreen extends StatelessWidget {
  const CompletedTasksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final completedTasks = taskProvider.completedTasks;
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    // Grouping logic
    final groupedTasks = _groupTasksByCompletionDate(completedTasks);

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? AppColors.stormyNightBackground
          : theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'ภารกิจที่เสร็จสมบูรณ์',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 26 : null,
            color: theme.colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: theme.colorScheme.onSurface,
            size: isTablet ? 28 : 24,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSummaryCard(context, completedTasks.length),
            Expanded(
              child: completedTasks.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.builder(
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 24 : AppConstants.paddingMedium,
                      ),
                      itemCount: groupedTasks.length,
                      itemBuilder: (context, index) {
                        final section = groupedTasks[index];
                        return _buildSection(
                          context,
                          section.title,
                          section.tasks,
                          completedTasks,
                          index == 0,
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, int count) {
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return Container(
      margin: EdgeInsets.all(isTablet ? 24 : AppConstants.paddingMedium),
      padding: EdgeInsets.all(isTablet ? 24 : AppConstants.paddingLarge),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : null,
        gradient: Theme.of(context).brightness == Brightness.light
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AppColors.stormyDarkSlate, AppColors.stormySkyBlue],
              )
            : null,
        borderRadius: BorderRadius.circular(
          isTablet ? 24 : AppConstants.radiusLarge,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).brightness == Brightness.light
                ? AppColors.stormySkyBlue.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 16 : 12),
            decoration: BoxDecoration(
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF81C784).withValues(alpha: 0.15)
                  : Colors.white.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.check_circle,
              color: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFF81C784)
                  : Colors.white,
              size: isTablet ? 40 : 32,
            ),
          ),
          SizedBox(width: isTablet ? 20 : AppConstants.paddingMedium),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ทั้งหมดที่ทำเสร็จ',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: isTablet ? 16 : 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$count ภารกิจ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isTablet ? 30 : 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    BuildContext context,
    String title,
    List<Task> tasks,
    List<Task> allCompletedTasks,
    bool showBulkActions,
  ) {
    final theme = Theme.of(context);
    final taskProvider = context.read<TaskProvider>();
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(
            vertical: isTablet ? 12 : AppConstants.paddingSmall,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: isTablet ? 20 : 16,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
              if (showBulkActions)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => _showRestoreAllConfirmation(
                        context,
                        taskProvider,
                        allCompletedTasks,
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).brightness == Brightness.dark
                            ? AppColors.stormySkyBlue
                            : (Theme.of(context).brightness == Brightness.light
                                  ? AppColors.stormySkyBlue
                                  : AppColors.primaryPink),
                      ),
                      child: Text(
                        'คืนค่า',
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => _showClearAllConfirmation(
                        context,
                        taskProvider,
                        allCompletedTasks,
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFFEF9A9A)
                            : Colors.red,
                      ),
                      child: Text(
                        'ล้างทุกภารกิจ',
                        style: TextStyle(
                          fontSize: isTablet ? 16 : 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
        ...tasks.map((task) => _CompletedTaskCard(task: task)),
      ],
    );
  }

  void _showRestoreAllConfirmation(
    BuildContext context,
    TaskProvider taskProvider,
    List<Task> tasks,
  ) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isTablet ? 22 : 16),
        ),
        actionsPadding: EdgeInsets.symmetric(
          horizontal: isTablet ? 20 : 16,
          vertical: isTablet ? 16 : 12,
        ),
        title: Text(
          'คืนค่า',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textWhite
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 22 : 18,
          ),
        ),
        content: Text(
          'ต้องการคืนค่าภารกิจทั้งหมดใช่หรือไม่?',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.stormyIceBlue
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.82),
            fontSize: isTablet ? 16 : 14.5,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.stormySkyBlue
                  : AppColors.textSecondary,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 12 : 10,
              ),
            ),
            child: Text(
              'ยกเลิก',
              style: TextStyle(
                fontSize: isTablet ? 16 : 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              final blockedTasks = tasks
                  .where(
                    (task) =>
                        !taskProvider.canCurrentUserRestoreCompletedTask(task),
                  )
                  .toList();
              final taskIds = tasks
                  .where(taskProvider.canCurrentUserRestoreCompletedTask)
                  .map((task) => task.id)
                  .toList();
              taskProvider.restoreCompletedTasks(taskIds);
              Navigator.pop(dialogContext);
              if (blockedTasks.isNotEmpty) {
                _showGroupRestoreBlockedSnackBar(context);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.stormySkyBlue,
              foregroundColor:
                  Theme.of(context).brightness == Brightness.dark
                      ? AppColors.stormyNightBackground
                      : Colors.white,
              elevation: 0,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 12 : 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'คืนค่า',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isTablet ? 16 : 14.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showClearAllConfirmation(
    BuildContext context,
    TaskProvider taskProvider,
    List<Task> tasks,
  ) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isTablet ? 22 : 16),
        ),
        actionsPadding: EdgeInsets.symmetric(
          horizontal: isTablet ? 20 : 16,
          vertical: isTablet ? 16 : 12,
        ),
        title: Text(
          'ล้างทุกภารกิจ',
          style: TextStyle(
            color: AppColors.accentRed,
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 22 : 18,
          ),
        ),
        content: Text(
          'ต้องการล้างทุกภารกิจที่เสร็จแล้วใช่หรือไม่?',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.stormyIceBlue
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.82),
            fontSize: isTablet ? 16 : 14.5,
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.stormySkyBlue
                  : AppColors.textSecondary,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 12 : 10,
              ),
            ),
            child: Text(
              'ยกเลิก',
              style: TextStyle(
                fontSize: isTablet ? 16 : 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final connectivity = context.read<ConnectivityProvider>();
              if (connectivity.isOffline) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'ไม่มีการเชื่อมต่ออินเทอร์เน็ต ไม่สามารถดำเนินการได้',
                    ),
                  ),
                );
                Navigator.pop(context);
                return;
              }
              final taskIds = tasks.map((t) => t.id).toList();
              taskProvider.deleteTasks(taskIds);

              final parentContext = context;
              final rootNavigator = Navigator.of(context, rootNavigator: true);
              Navigator.pop(context); // close dialog

              if (!parentContext.mounted) return;
              SnackBarUtils.showNavigationSnackBar(
                parentContext,
                message: 'ย้ายไปยังถังขยะแล้ว',
                actionLabel: 'ดูถังขยะ',
                bottomMargin:
                    90.0, // Push SnackBar up to match the height on screens with a FAB
                onNavigate: () {
                  rootNavigator.push(
                    MaterialPageRoute(builder: (ctx) => const BinScreen()),
                  );
                },
              );
            },
            style: TextButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor:
                  Theme.of(context).brightness == Brightness.dark
                      ? AppColors.stormyNightBackground
                      : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'ล้าง',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: isTablet ? 110 : 80,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
          ),
          SizedBox(height: isTablet ? 24 : AppConstants.paddingMedium),
          Text(
            'ไม่มีภารกิจที่เสร็จสิ้น',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              fontSize: isTablet ? 20 : 16,
            ),
          ),
        ],
      ),
    );
  }

  List<_TaskGroup> _groupTasksByCompletionDate(List<Task> tasks) {
    final sortedTasks = List<Task>.from(tasks);
    sortedTasks.sort((a, b) {
      final aTime = a.completedAt ?? a.dateTime;
      final bTime = b.completedAt ?? b.dateTime;
      final timeComp = bTime.compareTo(aTime);
      if (timeComp != 0) return timeComp;
      return b.createdAt.compareTo(a.createdAt);
    });

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

    final grouped = <_TaskGroup>[];
    final todayTasks = <Task>[];
    final yesterdayTasks = <Task>[];
    final thisWeekTasks = <Task>[];
    final olderTasks = <Task>[];

    for (final task in sortedTasks) {
      final completedAt = task.completedAt ?? task.dateTime;
      final date = DateTime(
        completedAt.year,
        completedAt.month,
        completedAt.day,
      );

      if (date == today) {
        todayTasks.add(task);
      } else if (date == yesterday) {
        yesterdayTasks.add(task);
      } else if (date.isAfter(
        startOfWeek.subtract(const Duration(seconds: 1)),
      )) {
        thisWeekTasks.add(task);
      } else {
        olderTasks.add(task);
      }
    }

    if (todayTasks.isNotEmpty) grouped.add(_TaskGroup('วันนี้', todayTasks));
    if (yesterdayTasks.isNotEmpty) {
      grouped.add(_TaskGroup('เมื่อวาน', yesterdayTasks));
    }
    if (thisWeekTasks.isNotEmpty) {
      grouped.add(_TaskGroup('สัปดาห์นี้', thisWeekTasks));
    }
    if (olderTasks.isNotEmpty) {
      grouped.add(_TaskGroup('ก่อนหน้านี้', olderTasks));
    }

    return grouped;
  }
}

class _TaskGroup {
  final String title;
  final List<Task> tasks;
  _TaskGroup(this.title, this.tasks);
}

void _showGroupRestoreBlockedSnackBar(BuildContext context) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text('สมาชิกกลุ่มไม่สามารถคืนค่าภารกิจที่เสร็จสิ้นไปแล้วได้'),
        behavior: SnackBarBehavior.floating,
      ),
    );
}

class _CompletedTaskCard extends StatelessWidget {
  final Task task;

  const _CompletedTaskCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taskProvider = context.read<TaskProvider>();
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => TaskDetailScreen(task: task)),
        );
      },
      child: Container(
        margin: EdgeInsets.only(
          bottom: isTablet ? 12 : AppConstants.paddingSmall,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isTablet ? 20 : AppConstants.paddingMedium,
          vertical: isTablet ? 16 : AppConstants.paddingMedium,
        ),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? AppColors.stormyDarkSlate
              : theme.cardColor,
          borderRadius: BorderRadius.circular(
            isTablet ? 18 : AppConstants.radiusMedium,
          ),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isTablet ? 6 : 4),
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF81C784).withValues(alpha: 0.15)
                    : Colors.teal.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check,
                color: theme.brightness == Brightness.dark
                    ? const Color(0xFF81C784)
                    : Colors.teal,
                size: isTablet ? 26 : 20,
              ),
            ),
            SizedBox(width: isTablet ? 18 : AppConstants.paddingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontSize: isTablet ? 18 : 16,
                      color: theme.brightness == Brightness.dark
                          ? AppColors.stormyMutedBlueGrey
                          : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.lineThrough,
                    ),
                  ),
                  if (task.completedAt != null)
                    Text(
                      'เสร็จเมื่อ ${DateFormat('HH:mm').format(task.completedAt!)}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: isTablet ? 14 : 12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) async {
                if (value == 'undo') {
                  if (!taskProvider.canCurrentUserRestoreCompletedTask(task)) {
                    _showGroupRestoreBlockedSnackBar(context);
                    return;
                  }
                  await taskProvider.toggleTaskCompletion(task.id, updateSubtasks: true);
                } else if (value == 'delete') {
                  _showDeleteDialog(context, taskProvider);
                }
              },
              icon: Icon(
                Icons.more_vert,
                size: isTablet ? 28 : 22,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'undo',
                  child: Row(
                    children: [
                      Icon(Icons.undo, size: isTablet ? 24 : 22),
                      SizedBox(width: isTablet ? 12 : 10),
                      Text(
                        'เลิกทำเสร็จสิ้น',
                        style: TextStyle(
                          color: theme.colorScheme.onSurface,
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_outline,
                        size: isTablet ? 24 : 22,
                        color: Colors.red,
                      ),
                      SizedBox(width: isTablet ? 12 : 10),
                      Text(
                        'ส่งไปที่ถังขยะ',
                        style: TextStyle(
                          color: Colors.red,
                          fontSize: isTablet ? 18 : 16,
                          fontWeight: FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDeleteDialog(BuildContext context, TaskProvider taskProvider) {
    final isTablet = MediaQuery.of(context).size.width >= 600;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'ส่งไปที่ถังขยะ',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textWhite
                : AppColors.accentRed,
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 22 : 18,
          ),
        ),
        content: Text(
          'คุณแน่ใจหรือไม่ว่าต้องการส่งงานนี้ไปที่ถังขยะ?',
          style: TextStyle(
            fontSize: isTablet ? 16 : 14.5,
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.stormyIceBlue
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.82),
          ),
        ),
        actionsPadding: EdgeInsets.symmetric(
          horizontal: isTablet ? 20 : 16,
          vertical: isTablet ? 16 : 12,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 18 : 14,
                vertical: isTablet ? 12 : 10,
              ),
              foregroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.stormySkyBlue
                  : AppColors.textSecondary,
            ),
            child: Text(
              'ยกเลิก',
              style: TextStyle(
                fontSize: isTablet ? 16 : 14.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: () {
              final connectivity = context.read<ConnectivityProvider>();
              if (connectivity.isOffline) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'ไม่มีการเชื่อมต่ออินเทอร์เน็ต ไม่สามารถดำเนินการได้',
                    ),
                  ),
                );
                Navigator.pop(context);
                return;
              }
              taskProvider.deleteTask(task.id);

              final parentContext = context;
              final rootNavigator = Navigator.of(context, rootNavigator: true);
              Navigator.pop(context); // close dialog

              if (!parentContext.mounted) return;
              SnackBarUtils.showNavigationSnackBar(
                parentContext,
                message: 'ย้ายไปยังถังขยะแล้ว',
                actionLabel: 'ดูถังขยะ',
                bottomMargin:
                    90.0, // Push SnackBar up to match the height on screens with a FAB
                onNavigate: () {
                  rootNavigator.push(
                    MaterialPageRoute(builder: (ctx) => const BinScreen()),
                  );
                },
              );
            },
            style: TextButton.styleFrom(
              backgroundColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFEF9A9A).withValues(alpha: 0.15)
                  : AppColors.error,
              foregroundColor: Theme.of(context).brightness == Brightness.dark
                  ? const Color(0xFFEF9A9A)
                  : Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 12 : 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(
              'ส่งไปที่ถังขยะ',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isTablet ? 16 : 14.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
