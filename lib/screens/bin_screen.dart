import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/colors.dart';
import '../config/constants.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../utils/thai_display.dart';
import 'task_detail_screen.dart';
import '../providers/connectivity_provider.dart';

class BinScreen extends StatelessWidget {
  const BinScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final deletedTasks = taskProvider.deletedTasks;

    // จัดกลุ่มงานที่ถูกลบ (Consolidate) โดยเฉพาะงานทำซ้ำให้อยู่เป็นรายการเดียว
    // เพื่อไม่ให้หน้าถังขยะดูรกเกินไปจากการที่มีงานชื่อเดียวกันเรียงต่อกันหลายๆ วัน
    final groupedTasks = <_GroupedDeletedTask>[];
    for (final task in deletedTasks) {
      if (task.isRecurring) {
        // ค้นหาว่าในกลุ่มที่เราจัดไว้ มีงานทำซ้ำซีรีส์เดียวกันนี้อยู่แล้วหรือไม่
        // (อิงจากชื่อ, ผู้สร้าง, และประเภทการทำซ้ำ)
        final existingGroupIndex = groupedTasks.indexWhere(
          (g) =>
              g.displayTask.isRecurring &&
              g.displayTask.title == task.title &&
              g.displayTask.creatorId == task.creatorId &&
              g.displayTask.recurringType == task.recurringType,
        );

        if (existingGroupIndex != -1) {
          // ถ้ามีกลุ่มอยู่แล้ว ให้เพิ่ม ID ของงานใบนี้เข้าไปในกลุ่มนั้นด้วย
          // เวลาที่กดกู้คืน (Restore) หรือลบถาวร (Permanent Delete) จะได้ทำรวดเดียวครบทุกใบ
          groupedTasks[existingGroupIndex].allIds.add(task.id);

          // เลือกงานที่มีวันที่เริ่มต้นเก่าที่สุดให้เป็น "ตัวแทน (Display Task)" ในการแสดงผลบนการ์ด
          if (task.dateTime.isBefore(
            groupedTasks[existingGroupIndex].displayTask.dateTime,
          )) {
            groupedTasks[existingGroupIndex] = _GroupedDeletedTask(
              displayTask: task,
              allIds: groupedTasks[existingGroupIndex].allIds,
            );
          }
        } else {
          // ถ้ายังไม่มีกลุ่มของซีรีส์นี้ ให้สร้างกลุ่มใหม่
          groupedTasks.add(
            _GroupedDeletedTask(displayTask: task, allIds: [task.id]),
          );
        }
      } else {
        // สำหรับงานธรรมดาที่ไม่ใช่การทำซ้ำ ก็ใส่เข้าไปเป็น 1 กลุ่มเดี่ยวๆ เลย
        groupedTasks.add(
          _GroupedDeletedTask(displayTask: task, allIds: [task.id]),
        );
      }
    }

    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? AppColors.stormyNightBackground
          : theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'ถังขยะ',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (deletedTasks.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => _showRestoreAllConfirmation(
                    context,
                    taskProvider,
                    deletedTasks,
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
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton(
                  onPressed: () =>
                      _showEmptyBinConfirmation(context, taskProvider),
                  style: TextButton.styleFrom(
                    foregroundColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFFEF9A9A)
                        : AppColors.error,
                  ),
                  child: const Text(
                    'ล้างถังขยะ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildInfoBanner(context),
            Expanded(
              child: deletedTasks.isEmpty
                  ? _buildEmptyState(context)
                  : ListView.builder(
                      padding: const EdgeInsets.all(AppConstants.paddingMedium),
                      itemCount: groupedTasks.length,
                      itemBuilder: (context, index) {
                        final groupedTask = groupedTasks[index];
                        return _DeletedTaskCard(groupedTask: groupedTask);
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBanner(BuildContext context) {
    final theme = Theme.of(context);
    final warningColor = theme.brightness == Brightness.dark
        ? const Color(0xFFFFCC80)
        : Colors.orange.shade800;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: AppConstants.paddingSmall,
        horizontal: AppConstants.paddingMedium,
      ),
      color: theme.brightness == Brightness.dark
          ? AppColors.stormyDarkSlate
          : warningColor.withValues(alpha: 0.12),
      child: Text(
        'ภารกิจในถังขยะจะถูกลบถาวรโดยอัตโนมัติหลังจาก 30 วัน',
        style: TextStyle(
          color: warningColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        textAlign: TextAlign.center,
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
            Icons.delete_sweep_outlined,
            size: 80,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.24),
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          Text(
            'ถังขยะว่างเปล่า',
            style: TextStyle(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  void _showRestoreAllConfirmation(
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
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).brightness == Brightness.dark
                  ? AppColors.stormySkyBlue
                  : AppColors.textSecondary,
            ),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () {
              final taskIds = tasks.map((task) => task.id).toList();
              taskProvider.restoreTasks(taskIds);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.stormySkyBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
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

  void _showEmptyBinConfirmation(
    BuildContext context,
    TaskProvider taskProvider,
  ) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'ล้างถังขยะ',
          style: TextStyle(
            color: AppColors.accentRed,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'ต้องการล้างทุกภารกิจในถังขยะใช่หรือไม่?',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.stormyIceBlue
                : theme.colorScheme.onSurface.withValues(alpha: 0.82),
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
              taskProvider.emptyBin();
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'ล้างถังขยะ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeletedTaskCard extends StatelessWidget {
  final _GroupedDeletedTask groupedTask;

  const _DeletedTaskCard({required this.groupedTask});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taskProvider = context.read<TaskProvider>();
    final titleOpacity = theme.brightness == Brightness.dark ? 0.78 : 0.68;
    final subtitleOpacity = theme.brightness == Brightness.dark ? 0.62 : 0.52;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) =>
                TaskDetailScreen(task: groupedTask.displayTask),
          ),
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
            color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
          ),
        ),
        child: Row(
          children: [
            IconButton(
              icon: Icon(
                Icons.restore,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.stormyMutedBlueGrey
                    : (Theme.of(context).brightness == Brightness.light
                          ? AppColors.stormySkyBlue
                          : AppColors.primaryPink),
              ),
              onPressed: () {
                taskProvider.restoreTasks(groupedTask.allIds);
              },
            ),
            const SizedBox(width: AppConstants.paddingSmall),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    groupedTask.displayTask.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.brightness == Brightness.dark
                          ? AppColors.textWhite
                          : theme.colorScheme.onSurface.withValues(
                              alpha: titleOpacity,
                            ),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (groupedTask.displayTask.category != null)
                    Text(
                      thaiCategoryLabel(groupedTask.displayTask.category!),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.brightness == Brightness.dark
                            ? AppColors.stormyMutedBlueGrey
                            : theme.colorScheme.onSurface.withValues(
                                alpha: subtitleOpacity,
                              ),
                      ),
                    ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'restore') {
                  taskProvider.restoreTasks(groupedTask.allIds);
                } else if (value == 'delete') {
                  _showDeleteDialog(context, taskProvider, groupedTask.allIds);
                }
              },
              icon: Icon(
                Icons.more_vert,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.55),
              ),
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: 'restore',
                  child: Row(
                    children: [
                      Icon(Icons.restore, size: 20),
                      SizedBox(width: 8),
                      Text('คืนค่า'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(
                        Icons.delete_forever,
                        size: 20,
                        color: AppColors.error,
                      ),
                      SizedBox(width: 8),
                      Text('ลบถาวร', style: TextStyle(color: AppColors.error)),
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

  void _showDeleteDialog(
    BuildContext context,
    TaskProvider taskProvider,
    List<String> allIds,
  ) {
    final theme = Theme.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'ลบถาวร',
          style: TextStyle(
            color: AppColors.accentRed,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'คุณแน่ใจหรือไม่ว่าต้องการลบภารกิจนี้ถาวร?',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.stormyIceBlue
                : theme.colorScheme.onSurface.withValues(alpha: 0.82),
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
              taskProvider.permanentlyDeleteTasks(allIds);
              Navigator.pop(context);
            },
            style: TextButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'ลบ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupedDeletedTask {
  final Task displayTask;
  final List<String> allIds;

  _GroupedDeletedTask({required this.displayTask, required this.allIds});
}
