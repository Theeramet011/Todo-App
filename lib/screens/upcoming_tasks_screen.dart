// UpcomingTasksScreen - หน้าจอรายการงานล่วงหน้า (Upcoming Tasks Screen)
//
// แสดงรายการงานที่จะถึงกำหนดในอนาคต โดยจัดกลุ่มตามช่วงเวลา เช่น วันนี้ สัปดาห์นี้ เดือนนี้
// ช่วยให้ผู้ใช้งานวางแผนและจัดลำดับความสำคัญของงานได้อย่างมีประสิทธิภาพ
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/colors.dart';
import '../config/constants.dart';
import '../models/task.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../services/sound_service.dart';
import '../widgets/custom_drawer.dart';
import '../widgets/create_task_modal.dart';
import '../widgets/fast_completion_warning_dialog.dart';
import '../utils/snack_bar_utils.dart';
import '../widgets/priority_tag.dart';
import 'bin_screen.dart';
import '../providers/connectivity_provider.dart';

class UpcomingTasksScreen extends StatefulWidget {
  const UpcomingTasksScreen({super.key});

  @override
  State<UpcomingTasksScreen> createState() => _UpcomingTasksScreenState();
}

class _UpcomingTasksScreenState extends State<UpcomingTasksScreen> {
  static const _completionExitDuration = Duration(milliseconds: 560);

  final Map<String, Task> _exitingTasks = {};
  final Map<String, Timer> _exitTimers = {};

  @override
  void dispose() {
    for (final timer in _exitTimers.values) {
      timer.cancel();
    }
    super.dispose();
  }

  String _taskSeriesKey(Task task) {
    final cleanTitle = task.title.trim().toLowerCase();
    final creator = task.creatorId;
    final type = task.type.name;
    final project = task.projectId ?? '';
    return '$creator|$type|$project|$cleanTitle';
  }

  Map<_UpcomingSection, List<Task>> _groupUpcomingTasks(List<Task> tasks) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final grouped = {
      _UpcomingSection.tomorrow: <Task>[],
      _UpcomingSection.thisWeek: <Task>[],
      _UpcomingSection.nextWeek: <Task>[],
      _UpcomingSection.later: <Task>[],
    };

    // 1. คัดกรองเฉพาะงานในอนาคตที่ยังไม่เสร็จ (หรือกำลังแอนิเมชันออก)
    final candidateTasks = <Task>[];
    for (final task in tasks) {
      final isExiting = _exitingTasks.containsKey(task.id);
      if (task.isCompleted && !isExiting) continue;

      final dueDate = DateTime(
        task.dateTime.year,
        task.dateTime.month,
        task.dateTime.day,
      );

      if (!dueDate.isAfter(today)) continue;
      candidateTasks.add(task);
    }

    // 2. จัดเรียงตามวันและเวลาที่ใกล้ที่สุดมาก่อน (Ascending)
    candidateTasks.sort((a, b) => a.dateTime.compareTo(b.dateTime));

    // 3. รวมกลุ่มงานซีรีส์เดียวกัน (เช่น งานทำซ้ำหรือชื่องานเดียวกัน) ให้แสดงแค่งานเดียวที่มีเวลาใกล้ที่สุด
    final seenSeries = <String>{};
    for (final task in candidateTasks) {
      final seriesKey = _taskSeriesKey(task);
      if (seenSeries.contains(seriesKey)) {
        continue;
      }
      seenSeries.add(seriesKey);

      final dueDate = DateTime(
        task.dateTime.year,
        task.dateTime.month,
        task.dateTime.day,
      );

      final daysFromToday = dueDate.difference(today).inDays;
      final endOfThisWeek = today.add(
        Duration(days: DateTime.sunday - today.weekday),
      );
      final endOfNextWeek = endOfThisWeek.add(const Duration(days: 7));

      if (daysFromToday == 1) {
        grouped[_UpcomingSection.tomorrow]!.add(task);
      } else if (!dueDate.isAfter(endOfThisWeek)) {
        grouped[_UpcomingSection.thisWeek]!.add(task);
      } else if (!dueDate.isAfter(endOfNextWeek)) {
        grouped[_UpcomingSection.nextWeek]!.add(task);
      } else {
        grouped[_UpcomingSection.later]!.add(task);
      }
    }

    // 4. จัดเรียงงานในแต่ละช่วงเวลาตามลำดับความสำคัญ (Priority) และเวลา
    for (final sectionTasks in grouped.values) {
      sectionTasks.sort((a, b) {
        final priorityComparison = b.priority.index.compareTo(a.priority.index);
        if (priorityComparison != 0) return priorityComparison;
        return a.dateTime.compareTo(b.dateTime);
      });
    }

    return grouped;
  }

  void _showCreateTaskModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateTaskModal(),
    );
  }

  Future<void> _handleCompleteTask(Task task) async {
    final connectivity = context.read<ConnectivityProvider>();
    if (connectivity.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่มีการเชื่อมต่ออินเทอร์เน็ต ไม่สามารถดำเนินการได้'),
        ),
      );
      return;
    }

    final taskProvider = context.read<TaskProvider>();
    final latestTask = taskProvider.tasks.firstWhere(
      (t) => t.id == task.id,
      orElse: () => task,
    );

    if (!latestTask.isCompleted) {
      // 1. ตรวจสอบเงื่อนไขภารกิจกลุ่ม (Group Task)
      if (latestTask.isGroup ||
          latestTask.type == TaskType.group ||
          latestTask.members.isNotEmpty) {
        final currentUserId = context.read<AuthProvider>().currentUser?.id;
        final isLeader = taskProvider.isLeaderForTask(
          latestTask,
          currentUserId,
        );

        if (!isLeader) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final isTablet = MediaQuery.of(context).size.width >= 600;
          if (!mounted) return;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: isDark
                  ? AppColors.stormyDarkSlate
                  : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isTablet ? 22 : 20.0),
              ),
              actionsPadding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 16 : 12,
              ),
              title: Text(
                'ไม่สามารถเสร็จสิ้นภารกิจได้',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isTablet ? 22 : 18,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              content: Text(
                'เฉพาะหัวหน้ากลุ่มเท่านั้นที่สามารถทำเครื่องหมายเสร็จสิ้นภารกิจได้',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14.5,
                  height: 1.5,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.85)
                      : AppColors.stormyDarkSlate.withValues(alpha: 0.85),
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.stormySkyBlue,
                    foregroundColor: isDark
                        ? AppColors.stormyNightBackground
                        : Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 20 : 16,
                      vertical: isTablet ? 12 : 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: Text(
                    'ตกลง',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isTablet ? 16 : 14.5,
                    ),
                  ),
                ),
              ],
            ),
          );
          return;
        }

        final leaderId = taskProvider.leaderIdForTask(latestTask);
        final nonLeaderMembers = latestTask.members
            .where((m) => m.id != leaderId)
            .toList();
        final membersToCheck = nonLeaderMembers.isNotEmpty
            ? nonLeaderMembers
            : latestTask.members;
        final areAllCompleted =
            taskProvider.areAllGroupMembersCompleted(latestTask);

        if (!areAllCompleted) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final isTablet = MediaQuery.of(context).size.width >= 600;
          final incompleteCount = membersToCheck
              .where((m) => m.status != 'completed')
              .length;
          final pendingReviewCount = membersToCheck
              .where((m) => m.status == 'pending')
              .length;

          String message;
          if (latestTask.members.isEmpty) {
            message = 'ยังไม่มีการส่งงานของสมาชิกเข้ามาในภารกิจนี้';
          } else if (pendingReviewCount > 0 &&
              incompleteCount == pendingReviewCount) {
            message =
                'มีงานของสมาชิกที่รอการตรวจสอบและอนุมัติอยู่ $pendingReviewCount คน กรุณาตรวจอนุมัติงานให้ครบก่อนเสร็จสิ้นภารกิจ';
          } else if (pendingReviewCount > 0) {
            message =
                'สมาชิกยังส่งงานไม่ครบถ้วน (และมีงานรอตรวจ $pendingReviewCount คน) กรุณาให้สมาชิกส่งงานและอนุมัติให้ครบก่อนเสร็จสิ้นภารกิจ';
          } else {
            message =
                'สมาชิกในกลุ่มยังส่งงานไม่ครบถ้วน (เหลืออีก $incompleteCount คน) กรุณารอให้สมาชิกทุกคนส่งงานและอนุมัติให้ครบก่อนเสร็จสิ้นภารกิจ';
          }

          if (!mounted) return;
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: isDark
                  ? AppColors.stormyDarkSlate
                  : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isTablet ? 22 : 20.0),
              ),
              actionsPadding: EdgeInsets.symmetric(
                horizontal: isTablet ? 20 : 16,
                vertical: isTablet ? 16 : 12,
              ),
              title: Text(
                'ไม่สามารถเสร็จสิ้นภารกิจได้',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: isTablet ? 22 : 18,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
              content: Text(
                message,
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14.5,
                  height: 1.5,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.85)
                      : AppColors.stormyDarkSlate.withValues(alpha: 0.85),
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.stormySkyBlue,
                    foregroundColor: isDark
                        ? AppColors.stormyNightBackground
                        : Colors.white,
                    elevation: 0,
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 20 : 16,
                      vertical: isTablet ? 12 : 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  child: Text(
                    'ตกลง',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: isTablet ? 16 : 14.5,
                    ),
                  ),
                ),
              ],
            ),
          );
          return;
        }
      }

      // 2. ตรวจสอบภารกิจย่อย (Subtasks)
      if (latestTask.subtasks.isNotEmpty &&
          latestTask.subtasks.any((s) => !s.isDone)) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final isTablet = MediaQuery.of(context).size.width >= 600;
        if (!mounted) return;
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: isDark ? AppColors.stormyDarkSlate : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(isTablet ? 22 : 20.0),
            ),
            actionsPadding: EdgeInsets.symmetric(
              horizontal: isTablet ? 20 : 16,
              vertical: isTablet ? 16 : 12,
            ),
            title: Text(
              'ไม่สามารถเสร็จสิ้นภารกิจได้',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: isTablet ? 22 : 18,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            content: Text(
              'กรุณาทำภารกิจย่อยทั้งหมดให้เสร็จสิ้นก่อนทำการปิดภารกิจหลัก',
              style: TextStyle(
                fontSize: isTablet ? 16 : 14.5,
                height: 1.5,
                color: isDark
                    ? Colors.white.withValues(alpha: 0.85)
                    : AppColors.stormyDarkSlate.withValues(alpha: 0.85),
              ),
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.stormySkyBlue,
                  foregroundColor: isDark
                      ? AppColors.stormyNightBackground
                      : Colors.white,
                  elevation: 0,
                  padding: EdgeInsets.symmetric(
                    horizontal: isTablet ? 20 : 16,
                    vertical: isTablet ? 12 : 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                ),
                child: Text(
                  'ตกลง',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: isTablet ? 16 : 14.5,
                  ),
                ),
              ),
            ],
          ),
        );
        return;
      }
    }

    _stageTaskExit(latestTask);
    _playTaskCompleteSound();

    final result = await taskProvider.completeTaskWithSubtasks(
      latestTask.id,
      true,
    );
    if (!mounted) return;
    await FastCompletionWarningDialog.showCompletionFeedback(context, result);

    if (!mounted) return;
    SnackBarUtils.showUndoSnackBar(
      context,
      message: 'ทำเครื่องหมายเสร็จสิ้นแล้ว',
      onUndo: () async {
        await taskProvider.toggleTaskCompletion(
          latestTask.id,
          updateSubtasks: true,
        );
      },
    );
  }

  void _playTaskCompleteSound() {
    final isSoundEnabled =
        context.read<AuthProvider>().currentUser?.isSoundEnabled ?? true;
    unawaited(
      SoundService.instance.playTaskCompleteSound(
        isSoundEnabled: isSoundEnabled,
      ),
    );
  }

  void _stageTaskExit(Task task) {
    if (_exitingTasks.containsKey(task.id)) return;

    final completedSubtasks = task.subtasks
        .map((subtask) => subtask.copyWith(isDone: true))
        .toList();

    setState(() {
      _exitingTasks[task.id] = task.copyWith(
        status: TaskStatus.completed,
        completedAt: DateTime.now(),
        subtasks: completedSubtasks,
      );
    });

    _exitTimers[task.id]?.cancel();
    _exitTimers[task.id] = Timer(_completionExitDuration, () {
      if (!mounted) return;
      setState(() {
        _exitingTasks.remove(task.id);
        _exitTimers.remove(task.id);
      });
    });
  }

  Map<_UpcomingSection, List<_UpcomingTaskEntry>> _buildUpcomingEntries(
    Map<_UpcomingSection, List<Task>> groupedTasks,
  ) {
    final entries = {
      for (final section in _UpcomingSection.values)
        section: groupedTasks[section]!
            .where((task) => !_exitingTasks.containsKey(task.id))
            .map((task) => _UpcomingTaskEntry(task: task, isExiting: false))
            .toList(),
    };

    for (final task in _exitingTasks.values) {
      final section = _sectionForTask(task);
      if (section == null) continue;
      final sectionEntries = entries[section]!;
      final insertIndex = sectionEntries.indexWhere(
        (entry) => task.dateTime.isBefore(entry.task.dateTime),
      );
      sectionEntries.insert(
        insertIndex < 0 ? sectionEntries.length : insertIndex,
        _UpcomingTaskEntry(task: task, isExiting: true),
      );
    }

    return entries;
  }

  _UpcomingSection? _sectionForTask(Task task) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(
      task.dateTime.year,
      task.dateTime.month,
      task.dateTime.day,
    );

    if (!dueDate.isAfter(today)) return null;

    final daysFromToday = dueDate.difference(today).inDays;
    if (daysFromToday == 1) return _UpcomingSection.tomorrow;

    final endOfThisWeek = today.add(
      Duration(days: DateTime.sunday - today.weekday),
    );
    if (!dueDate.isAfter(endOfThisWeek)) return _UpcomingSection.thisWeek;

    final endOfNextWeek = endOfThisWeek.add(const Duration(days: 7));
    if (!dueDate.isAfter(endOfNextWeek)) return _UpcomingSection.nextWeek;

    return _UpcomingSection.later;
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final groupedTasks = _groupUpcomingTasks(taskProvider.tasks);
    final groupedEntries = _buildUpcomingEntries(groupedTasks);
    final hasTasks = groupedEntries.values.any((tasks) => tasks.isNotEmpty);
    final theme = Theme.of(context);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? AppColors.stormyNightBackground
          : theme.scaffoldBackgroundColor,
      drawer: const CustomDrawer(),
      appBar: AppBar(
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            size: isTablet ? 28 : 24,
            color: theme.brightness == Brightness.dark
                ? AppColors.textWhite
                : theme.colorScheme.onSurface,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'ภารกิจเร็วๆ นี้',
          style: (theme.textTheme.headlineMedium ?? const TextStyle()).copyWith(
            fontSize: isTablet ? 30 : null,
            color: theme.brightness == Brightness.dark
                ? AppColors.textWhite
                : theme.colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: false,
        backgroundColor: theme.brightness == Brightness.dark
            ? AppColors.stormyNightBackground
            : theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: hasTasks
            ? ListView(
                padding: EdgeInsets.fromLTRB(
                  isTablet ? AppConstants.paddingXLarge : AppConstants.paddingLarge,
                  isTablet ? AppConstants.paddingXLarge : AppConstants.paddingLarge,
                  isTablet ? AppConstants.paddingXLarge : AppConstants.paddingLarge,
                  110,
                ),
                children: [
                  for (final section in _UpcomingSection.values)
                    if (groupedEntries[section]!.isNotEmpty)
                      _UpcomingSectionBlock(
                        section: section,
                        entries: groupedEntries[section]!,
                        onCompleteTask: _handleCompleteTask,
                      ),
                ],
              )
            : const _UpcomingEmptyState(),
      ),
      floatingActionButton: Container(
        width: isTablet ? 72 : 62,
        height: isTablet ? 72 : 62,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: theme.brightness == Brightness.dark
                  ? AppColors.stormySkyBlue.withValues(alpha: 0.25)
                  : theme.colorScheme.primary.withValues(alpha: 0.35),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => _showCreateTaskModal(context),
          elevation: 4,
          backgroundColor: AppColors.stormySkyBlue,
          child: Icon(Icons.add, size: isTablet ? 36 : 32, color: Colors.white),
        ),
      ),
    );
  }
}

enum _UpcomingSection { tomorrow, thisWeek, nextWeek, later }

class _UpcomingTaskEntry {
  final Task task;
  final bool isExiting;

  const _UpcomingTaskEntry({required this.task, required this.isExiting});
}

extension _UpcomingSectionText on _UpcomingSection {
  String get title {
    switch (this) {
      case _UpcomingSection.tomorrow:
        return 'พรุ่งนี้';
      case _UpcomingSection.thisWeek:
        return 'สัปดาห์นี้';
      case _UpcomingSection.nextWeek:
        return 'สัปดาห์หน้า';
      case _UpcomingSection.later:
        return 'หลังจากนี้';
    }
  }
}

class _UpcomingSectionBlock extends StatelessWidget {
  final _UpcomingSection section;
  final List<_UpcomingTaskEntry> entries;
  final ValueChanged<Task> onCompleteTask;

  const _UpcomingSectionBlock({
    required this.section,
    required this.entries,
    required this.onCompleteTask,
  });

  static const List<String> _thaiMonths = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];

  String _thaiDate(DateTime date) {
    return '${date.day} ${_thaiMonths[date.month - 1]} ${date.year}';
  }

  String _thaiDateShort(DateTime date) {
    return '${date.day} ${_thaiMonths[date.month - 1]}';
  }

  String _subtitle() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final endOfThisWeek = today.add(
      Duration(days: DateTime.sunday - today.weekday),
    );
    final startOfNextWeek = endOfThisWeek.add(const Duration(days: 1));
    final endOfNextWeek = startOfNextWeek.add(const Duration(days: 6));

    switch (section) {
      case _UpcomingSection.tomorrow:
        return _thaiDate(today.add(const Duration(days: 1)));
      case _UpcomingSection.thisWeek:
        final start = today.add(const Duration(days: 2));
        if (start.isAtSameMomentAs(endOfThisWeek)) {
          return _thaiDate(endOfThisWeek);
        }
        return '${_thaiDateShort(start)} - ${_thaiDate(endOfThisWeek)}';
      case _UpcomingSection.nextWeek:
        final effectiveStart =
            startOfNextWeek.isBefore(today.add(const Duration(days: 2)))
                ? today.add(const Duration(days: 2))
                : startOfNextWeek;
        if (effectiveStart.isAtSameMomentAs(endOfNextWeek)) {
          return _thaiDate(endOfNextWeek);
        }
        return '${_thaiDateShort(effectiveStart)} - ${_thaiDate(endOfNextWeek)}';
      case _UpcomingSection.later:
        final firstDate = entries.first.task.dateTime;
        return '${_thaiDate(firstDate)} เป็นต้นไป';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accentColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.tertiary
        : AppColors.stormySkyBlue;
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Padding(
      padding: EdgeInsets.only(
        bottom: isTablet
            ? AppConstants.paddingXLarge * 1.2
            : AppConstants.paddingXLarge,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.calendar_month_outlined,
                color: accentColor,
                size: isTablet ? 34 : 28,
              ),
              const SizedBox(width: AppConstants.paddingSmall),
              Expanded(
                child: Text(
                  section.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: (theme.textTheme.headlineMedium ?? const TextStyle()).copyWith(
                    fontSize: isTablet ? 28 : null,
                    color: accentColor,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: EdgeInsets.only(left: isTablet ? 46 : 40),
            child: Text(
              _subtitle(),
              style: (theme.textTheme.bodyMedium ?? const TextStyle()).copyWith(
                fontSize: isTablet ? 17 : null,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
              ),
            ),
          ),
          SizedBox(
            height: isTablet ? 18 : AppConstants.paddingMedium,
          ),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index];
              return _CompletingUpcomingListItem(
                key: ValueKey('upcoming-${entry.task.id}-${entry.isExiting}'),
                isExiting: entry.isExiting,
                bottomSpacing: index == entries.length - 1
                    ? 0
                    : (isTablet ? 18 : AppConstants.paddingMedium),
                child: _UpcomingTaskCard(
                  task: entry.task,
                  onCompleteTask: onCompleteTask,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _CompletingUpcomingListItem extends StatefulWidget {
  final bool isExiting;
  final double bottomSpacing;
  final Widget child;

  const _CompletingUpcomingListItem({
    super.key,
    required this.isExiting,
    required this.bottomSpacing,
    required this.child,
  });

  @override
  State<_CompletingUpcomingListItem> createState() =>
      _CompletingUpcomingListItemState();
}

class _CompletingUpcomingListItemState
    extends State<_CompletingUpcomingListItem> {
  static const _holdCompletedDuration = Duration(milliseconds: 160);
  static const _collapseDuration = Duration(milliseconds: 400);

  bool _isVisible = true;

  @override
  void initState() {
    super.initState();
    if (widget.isExiting) {
      Timer(_holdCompletedDuration, () {
        if (mounted) {
          setState(() => _isVisible = false);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedAlign(
        duration: _collapseDuration,
        curve: Curves.easeInOutCubic,
        alignment: Alignment.topCenter,
        heightFactor: _isVisible ? 1 : 0,
        child: AnimatedSlide(
          duration: _collapseDuration,
          curve: Curves.easeInOutCubic,
          offset: _isVisible ? Offset.zero : const Offset(0, -0.08),
          child: AnimatedOpacity(
            duration: _collapseDuration,
            curve: Curves.easeOutCubic,
            opacity: _isVisible ? 1 : 0,
            child: Padding(
              padding: EdgeInsets.only(bottom: widget.bottomSpacing),
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _UpcomingTaskCard extends StatelessWidget {
  final Task task;
  final ValueChanged<Task> onCompleteTask;

  const _UpcomingTaskCard({required this.task, required this.onCompleteTask});

  String get _teamName {
    switch ((task.category ?? '').toLowerCase()) {
      case 'development':
        return 'ทีมพัฒนาแอป';
      case 'marketing':
        return 'ทีมการตลาด';
      case 'design':
        return 'ทีมออกแบบ';
      default:
        return task.isGroup ? 'ภารกิจกลุ่ม' : 'ภารกิจส่วนตัว';
    }
  }

  IconData get _icon {
    switch ((task.category ?? '').toLowerCase()) {
      case 'development':
        return Icons.code;
      case 'marketing':
        return Icons.campaign_outlined;
      case 'design':
        return Icons.palette_outlined;
      case 'documentation':
        return Icons.article_outlined;
      default:
        return Icons.task_alt_outlined;
    }
  }

  static const List<String> _thaiMonths = [
    'ม.ค.',
    'ก.พ.',
    'มี.ค.',
    'เม.ย.',
    'พ.ค.',
    'มิ.ย.',
    'ก.ค.',
    'ส.ค.',
    'ก.ย.',
    'ต.ค.',
    'พ.ย.',
    'ธ.ค.',
  ];

  String _formatDueDateTime(DateTime dateTime) {
    final date =
        '${dateTime.day} ${_thaiMonths[dateTime.month - 1]} ${dateTime.year}';
    final time = DateFormat('HH:mm').format(dateTime);
    return '$date • $time น.';
  }

  Future<void> _openEditTaskModal(BuildContext context) async {
    final taskProvider = context.read<TaskProvider>();
    final authProvider = context.read<AuthProvider>();
    final isGroup = task.isGroup;
    final isLeader = !isGroup ||
        taskProvider.isLeaderForTask(task, authProvider.currentUser?.id);
    if (!isLeader) return;

    await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateTaskModal(task: task),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taskProvider = context.read<TaskProvider>();
    final accentColor = theme.colorScheme.tertiary;
    final softPink = theme.colorScheme.primary;
    final isCompleted = task.isCompleted;
    final authProvider = context.read<AuthProvider>();
    final isGroup = task.isGroup;
    final isLeader = !isGroup ||
        taskProvider.isLeaderForTask(task, authProvider.currentUser?.id);
    final areAllCompleted =
        isGroup ? taskProvider.areAllGroupMembersCompleted(task) : true;
    final canShowComplete =
        !isGroup || (isLeader && (isCompleted || areAllCompleted));
    final iconColor = theme.brightness == Brightness.dark
        ? accentColor
        : AppColors.stormySkyBlue;
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        enableFeedback: false,
        onTap: () async {
          taskProvider.selectTask(task);
          await Navigator.pushNamed(context, '/task-detail');
        },
        borderRadius: BorderRadius.circular(
          isTablet ? 22 : AppConstants.radiusXLarge,
        ),
        child: Container(
          padding: EdgeInsets.all(
            isTablet ? 22 : AppConstants.paddingMedium,
          ),
          decoration: BoxDecoration(
            color: theme.brightness == Brightness.dark
                ? AppColors.stormyDarkSlate
                : theme.cardColor,
            borderRadius: BorderRadius.circular(
              isTablet ? 22 : AppConstants.radiusXLarge,
            ),
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
            ),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withValues(alpha: 0.08),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: isTablet ? 68 : 56,
                height: isTablet ? 68 : 56,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(
                    isTablet ? 18 : AppConstants.radiusMedium,
                  ),
                  border: Border.all(
                    color: iconColor.withValues(alpha: 0.28),
                  ),
                ),
                child: Icon(
                  isCompleted ? Icons.check_circle_outline : _icon,
                  color: iconColor,
                  size: isTablet ? 36 : 30,
                ),
              ),
              SizedBox(
                width: isTablet
                    ? AppConstants.paddingLarge
                    : AppConstants.paddingMedium,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _teamName,
                                style: (theme.textTheme.titleMedium ?? const TextStyle()).copyWith(
                                  fontSize: isTablet ? 18 : null,
                                  color: accentColor,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                task.title,
                                style: (theme.textTheme.titleLarge ?? const TextStyle()).copyWith(
                                  fontSize: isTablet ? 23 : null,
                                  color: isCompleted
                                      ? theme.colorScheme.onSurface.withValues(
                                          alpha: 0.45,
                                        )
                                      : (theme.brightness == Brightness.dark
                                            ? AppColors.textWhite
                                            : softPink),
                                  fontWeight: FontWeight.w800,
                                  decoration: isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (isLeader)
                          PopupMenuButton<String>(
                          onSelected: (value) {
                            switch (value) {
                              case 'edit':
                                _openEditTaskModal(context);
                                break;
                              case 'toggle_complete':
                                onCompleteTask(task);
                                break;
                              case 'delete':
                                _showDeleteConfirmation(
                                  context,
                                  task,
                                  taskProvider,
                                );
                                break;
                            }
                          },
                          icon: Icon(
                            Icons.more_vert,
                            size: isTablet ? 28 : 22,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.55,
                            ),
                          ),
                          itemBuilder: (context) => [
                            PopupMenuItem(
                              value: 'edit',
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.edit_outlined,
                                    color: AppColors.primaryBlue,
                                    size: isTablet ? 24 : 22,
                                  ),
                                  SizedBox(width: isTablet ? 12 : 10),
                                  Text(
                                    'แก้ไข',
                                    style: TextStyle(
                                      color: theme.colorScheme.onSurface,
                                      fontSize: isTablet ? 18 : 16,
                                      fontWeight: FontWeight.normal,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (canShowComplete)
                              PopupMenuItem(
                                value: 'toggle_complete',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline,
                                      color: AppColors.success,
                                      size: isTablet ? 24 : 22,
                                    ),
                                    SizedBox(width: isTablet ? 12 : 10),
                                    Text(
                                      'ทำว่าเสร็จสิ้น',
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
                                    color: AppColors.error,
                                    size: isTablet ? 24 : 22,
                                  ),
                                  SizedBox(width: isTablet ? 12 : 10),
                                  Text(
                                    'ลบ',
                                    style: TextStyle(
                                      color: AppColors.error,
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
                    const SizedBox(height: AppConstants.paddingSmall),
                    Row(
                      children: [
                        Icon(
                          Icons.schedule,
                          size: isTablet ? 22 : 18,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.58,
                          ),
                        ),
                        SizedBox(width: isTablet ? 8 : 6),
                        Expanded(
                          child: Text(
                            _formatDueDateTime(task.dateTime),
                            style: (theme.textTheme.bodySmall ?? const TextStyle()).copyWith(
                              fontSize: isTablet ? 15 : null,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.58,
                              ),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: isTablet ? 16 : AppConstants.paddingMedium,
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _PriorityTags(task: task),
                        const Spacer(),
                        if (!task.isPersonal) _UpcomingAvatars(task: task),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDeleteConfirmation(
    BuildContext parentContext,
    Task task,
    TaskProvider taskProvider,
  ) {
    final isGroup = task.isGroup;
    final isLeader = !isGroup ||
        taskProvider.isLeaderForTask(
          task,
          parentContext.read<AuthProvider>().currentUser?.id,
        );
    if (!isLeader) return;

    final isTablet = MediaQuery.of(parentContext).size.width >= 600;

    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(parentContext).brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : Theme.of(parentContext).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text(
          'ยืนยันการลบภารกิจ',
          style: TextStyle(
            color: AppColors.accentRed,
            fontWeight: FontWeight.bold,
            fontSize: isTablet ? 22 : 18,
          ),
        ),
        content: Text(
          'คุณแน่ใจหรือไม่ว่าต้องการลบ${task.isPersonal ? "ภารกิจส่วนตัว" : "ภารกิจกลุ่ม"}นี้โดยส่งไปที่ถังขยะ?',
          style: TextStyle(
            fontSize: isTablet ? 16 : 14.5,
            color: Theme.of(parentContext).brightness == Brightness.dark
                ? AppColors.stormyIceBlue
                : Theme.of(
                    parentContext,
                  ).colorScheme.onSurface.withValues(alpha: 0.82),
          ),
        ),
        actionsPadding: EdgeInsets.symmetric(
          horizontal: isTablet ? 20 : 16,
          vertical: isTablet ? 16 : 12,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 18 : 14,
                vertical: isTablet ? 12 : 10,
              ),
              foregroundColor:
                  Theme.of(parentContext).brightness == Brightness.dark
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
              final connectivity = parentContext.read<ConnectivityProvider>();
              if (connectivity.isOffline) {
                ScaffoldMessenger.of(parentContext).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'ไม่มีการเชื่อมต่ออินเทอร์เน็ต ไม่สามารถดำเนินการได้',
                    ),
                  ),
                );
                Navigator.pop(dialogContext);
                return;
              }
              final rootNavigator = Navigator.of(
                parentContext,
                rootNavigator: true,
              );
              taskProvider.deleteTask(task.id);
              Navigator.pop(dialogContext);

              if (!parentContext.mounted) return;
              SnackBarUtils.showNavigationSnackBar(
                parentContext,
                message: 'ย้ายไปยังถังขยะแล้ว',
                actionLabel: 'ดูถังขยะ',
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
                  Theme.of(parentContext).brightness == Brightness.dark
                      ? AppColors.stormyNightBackground
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
              'ยืนยันการลบ',
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

class _PriorityTags extends StatelessWidget {
  final Task task;

  const _PriorityTags({required this.task});

  @override
  Widget build(BuildContext context) {
    return PriorityTag(priority: task.priorityLabel);
  }
}

class _UpcomingAvatars extends StatelessWidget {
  final Task task;

  const _UpcomingAvatars({required this.task});

  @override
  Widget build(BuildContext context) {
    final memberIds = task.assigneeIds;
    if (memberIds.isEmpty) return const SizedBox.shrink();

    final visibleMembers = memberIds.take(3).toList();
    final hiddenCount = memberIds.length - visibleMembers.length;
    final isTablet = MediaQuery.of(context).size.width >= 600;
    final avatarSize = isTablet ? 42.0 : 36.0;
    final step = isTablet ? 26.0 : 22.0;
    final width = (visibleMembers.length * (isTablet ? 30.0 : 26.0)) + (hiddenCount > 0 ? 34 : 8);

    return SizedBox(
      width: width,
      height: avatarSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < visibleMembers.length; i++)
            Positioned(
              left: i * step,
              child: _UpcomingAvatar(
                userId: visibleMembers[i],
                size: avatarSize,
              ),
            ),
          if (hiddenCount > 0)
            Positioned(
              left: visibleMembers.length * step,
              child: _MoreAvatar(
                count: hiddenCount,
                size: avatarSize,
              ),
            ),
        ],
      ),
    );
  }
}

class _UpcomingAvatar extends StatelessWidget {
  final String userId;
  final double size;

  const _UpcomingAvatar({required this.userId, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.read<TaskProvider>();
    final user = taskProvider.getUserById(userId);
    final theme = Theme.of(context);
    final initial = user != null && user.name.isNotEmpty
        ? user.name.substring(0, 1)
        : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: theme.cardColor, width: 2),
      ),
      child: CircleAvatar(
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        backgroundImage: user?.avatarUrl.isNotEmpty == true
            ? NetworkImage(user!.avatarUrl)
            : null,
        child: user?.avatarUrl.isNotEmpty == true
            ? null
            : Text(
                initial,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }
}

class _MoreAvatar extends StatelessWidget {
  final int count;
  final double size;

  const _MoreAvatar({required this.count, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.cardColor, width: 2),
      ),
      child: Center(
        child: Text(
          '+$count',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _UpcomingEmptyState extends StatelessWidget {
  const _UpcomingEmptyState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppConstants.paddingXLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available_outlined,
              size: 72,
              color: theme.colorScheme.tertiary,
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            Text(
              'ยังไม่มีภารกิจเร็วๆ นี้',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
