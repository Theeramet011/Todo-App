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
            color: theme.colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppConstants.paddingMedium,
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
    return Container(
      margin: const EdgeInsets.all(AppConstants.paddingMedium),
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
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
        borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
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
            padding: const EdgeInsets.all(12),
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
              size: 32,
            ),
          ),
          const SizedBox(width: AppConstants.paddingMedium),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'ทั้งหมดที่ทำเสร็จ',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '$count ภารกิจ',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppConstants.paddingSmall,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
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
                      child: const Text(
                        'คืนค่า',
                        style: TextStyle(
                          fontSize: 13,
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
                      child: const Text(
                        'ล้างทุกภารกิจ',
                        style: TextStyle(
                          fontSize: 13,
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
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'คืนค่า',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textWhite
                : Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.bold,
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
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.stormySkyBlue
                  : AppColors.textSecondary,
            ),
            child: const Text('ยกเลิก'),
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
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'คืนค่า',
              style: TextStyle(fontWeight: FontWeight.bold),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'ล้างทุกภารกิจ',
          style: TextStyle(
            color: AppColors.accentRed,
            fontWeight: FontWeight.bold,
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
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.stormySkyBlue
                  : AppColors.textSecondary,
            ),
            child: const Text('ยกเลิก'),
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
              foregroundColor: Colors.white,
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          Text(
            'ไม่มีภารกิจที่เสร็จสิ้น',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  List<_TaskGroup> _groupTasksByCompletionDate(List<Task> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1));

    final grouped = <_TaskGroup>[];
    final todayTasks = <Task>[];
    final yesterdayTasks = <Task>[];
    final thisWeekTasks = <Task>[];
    final olderTasks = <Task>[];

    for (final task in tasks) {
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

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => TaskDetailScreen(task: task)),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: AppConstants.paddingSmall),
        padding: const EdgeInsets.all(AppConstants.paddingMedium),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? AppColors.stormyDarkSlate
              : theme.cardColor,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
          border: Border.all(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
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
                size: 20,
              ),
            ),
            const SizedBox(width: AppConstants.paddingMedium),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: theme.textTheme.titleMedium?.copyWith(
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
                  await taskProvider.toggleTaskCompletion(task.id);
                } else if (value == 'delete') {
                  _showDeleteDialog(context, taskProvider);
                }
              },
              icon: Icon(
                Icons.more_vert,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'undo',
                  child: Row(
                    children: [
                      Icon(Icons.undo, size: 20),
                      SizedBox(width: 8),
                      Text('เลิกทำเสร็จสิ้น'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete_outline, size: 20, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        'ส่งไปที่ถังขยะ',
                        style: TextStyle(color: Colors.red),
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'ส่งไปที่ถังขยะ',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textWhite
                : AppColors.accentRed,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'คุณแน่ใจหรือไม่ว่าต้องการส่งงานนี้ไปที่ถังขยะ?',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.stormyIceBlue
                : Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.82),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.stormySkyBlue
                  : AppColors.textSecondary,
            ),
            child: const Text('ยกเลิก'),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'ส่งไปที่ถังขยะ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
