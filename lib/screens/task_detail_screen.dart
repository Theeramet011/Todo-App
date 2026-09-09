// TaskDetailScreen - หน้าจอแสดงและแก้ไขรายละเอียดงาน (Task Detail Screen)
//
// หน้าจัดการข้อมูลงานแบบเจาะลึก เช่น การแก้ไขชื่อ รายละเอียด กำหนดเวลา งานย่อย (Subtasks)
// ไฟล์แนบ หมวดหมู่ ความสำคัญ และการมอบหมายงานให้เพื่อน
import 'dart:async';
import 'dart:io';

import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/connectivity_provider.dart';
import 'package:todo_app/screens/member_assignment_detail_screen.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../providers/task_provider.dart';
import '../providers/auth_provider.dart';
import '../services/sound_service.dart';
import '../utils/thai_display.dart';

import '../widgets/create_task_modal.dart';
import '../widgets/fast_completion_warning_dialog.dart';
import '../widgets/late_penalty_dialog.dart';
import '../widgets/user_avatar_with_frame.dart';
import '../utils/snack_bar_utils.dart';
import '../widgets/priority_tag.dart';
import 'bin_screen.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task? task;
  final bool scrollToComments;

  const TaskDetailScreen({
    super.key,
    this.task,
    this.scrollToComments = false,
  });

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  final _pageScrollController = ScrollController();
  final _commentController = TextEditingController();
  final _mainCommentFocusNode = FocusNode();
  final _sheetCommentFocusNode = FocusNode();
  final _mainCommentsScrollController = ScrollController();
  final _submissionController = TextEditingController();
  Task? _task;
  bool _isUploading = false;
  final List<TaskAttachment> _commentAttachments = [];
  bool _isUploadingCommentAttachment = false;
  int _lastMainCommentsCount = 0;
  bool _didInitialMainScroll = false;
  OverlayEntry? _toastEntry;

  @override
  void initState() {
    super.initState();
    _task = widget.task;
    _mainCommentFocusNode.addListener(() {
      if (_mainCommentFocusNode.hasFocus) {
        _scrollMainCommentsToLatest(animated: true);
      }
    });

    if (widget.scrollToComments) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollToCommentsSection();
      });
    }
  }

  void _scrollToCommentsSection() {
    void doScroll() {
      if (!mounted) return;
      if (_pageScrollController.hasClients) {
        _pageScrollController.animateTo(
          _pageScrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeOutCubic,
        );
      }
    }

    Future.delayed(const Duration(milliseconds: 300), doScroll);
    Future.delayed(const Duration(milliseconds: 600), doScroll);
  }

  @override
  void didUpdateWidget(covariant TaskDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.task?.id != widget.task?.id) {
      _task = widget.task;
    }
  }

  @override
  void dispose() {
    _toastEntry?.remove();
    _toastEntry = null;
    _pageScrollController.dispose();
    _mainCommentsScrollController.dispose();
    _mainCommentFocusNode.dispose();
    _sheetCommentFocusNode.dispose();
    _commentController.dispose();
    _submissionController.dispose();
    super.dispose();
  }

  void _showXPLimitDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        final theme = Theme.of(context);
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          elevation: 10,
          backgroundColor: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accentOrange.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: AppColors.accentOrange,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Daily XP Cap Reached',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'ขณะนี้ท่านมีคะแนนที่ได้จากภารกิจกลุ่มต่อเนื่องถึง 270 แต้มแล้วการสร้างภารกิจหลังจากนี้ท่านจะไม่ได้รับแต้มอีก',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    height: 1.5,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          (Theme.of(context).brightness == Brightness.light
                          ? AppColors.stormySkyBlue
                          : AppColors.primaryPink),
                      foregroundColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? AppColors.stormyNightBackground
                              : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'รับทราบ',
                      style: TextStyle(
                        fontSize: 18,
                        height: 1.1,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final isCurrentRoute = ModalRoute.of(context)?.isCurrent ?? false;
    if (taskProvider.showXPCapAlert && isCurrentRoute) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showXPLimitDialog(context);
        taskProvider.dismissXPCapAlert();
      });
    }

    final authProvider = Provider.of<AuthProvider>(context);
    var task = _task ?? taskProvider.selectedTask;

    if (task != null) {
      task = _latestTaskFromProvider(taskProvider, task.id) ?? task;
    }

    if (task == null) {
      return const Scaffold(body: Center(child: Text('ยังไม่ได้เลือกภารกิจ')));
    }
    final currentTask = task;
    final currentUserId = authProvider.currentUser?.id ??
        firebase_auth.FirebaseAuth.instance.currentUser?.uid ??
        '';
    final isLeader = taskProvider.isLeaderForTask(
      currentTask,
      authProvider.currentUser?.id,
    );
    final leaderId = currentTask.isGroup
        ? taskProvider.leaderIdForTask(currentTask)
        : '';
    final myMember = currentTask.isGroup
        ? currentTask.members.where((m) => m.id == currentUserId).firstOrNull
        : null;
    final canMemberDelete = currentTask.isGroup &&
        !isLeader &&
        (currentTask.isCompleted || _areAllMembersCompleted(currentTask, leaderId));

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.stormyNightBackground
          : Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.stormyNightBackground
            : Theme.of(context).appBarTheme.backgroundColor,
        iconTheme: IconThemeData(
          color: Theme.of(context).brightness == Brightness.dark
              ? AppColors.textWhite
              : Theme.of(context).colorScheme.onSurface,
        ),
        title: Text(
          'รายละเอียดภารกิจ',
          style: TextStyle(
            color: Theme.of(context).brightness == Brightness.dark
                ? AppColors.textWhite
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        actions: [
          if (isLeader || canMemberDelete)
            IconButton(
              icon: Icon(
                Icons.more_vert,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.textWhite
                    : null,
              ),
              onPressed: () {
                _showOptionsMenu(context, currentTask, isLeader: isLeader);
              },
            ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: SingleChildScrollView(
          controller: _pageScrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              _buildHeaderSection(currentTask),

              // Sub-tasks Progress Section
              _buildSubtasksSection(currentTask, taskProvider),

              // Task Info Section
              _buildTaskInfoSection(currentTask),

              if (currentTask.isDeleted) _buildDeletedTaskCard(),

              // Task Leader Card (Member View) — แสดงก่อนส่วนส่งงาน
              if (currentTask.isGroup && !isLeader)
                _buildTaskLeaderCard(
                  currentTask,
                  taskProvider,
                  taskProvider.leaderIdForTask(currentTask),
                ),

              if (currentTask.isGroup)
                _buildSubmissionReviewSection(
                  currentTask,
                  taskProvider,
                  currentUserId,
                  isLeader,
                ),

              // Assignees / Leader Review Section / Team Members
              _buildLeaderReviewSection(currentTask, taskProvider, authProvider),

              // Attachments Section
              if (!isLeader) _buildAttachmentsSection(currentTask, taskProvider, myMember: myMember),

              // Comments Section
              if (!currentTask.isPersonal)
                _buildCommentsSection(currentTask, taskProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSection(Task task) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.all(AppConstants.paddingMedium),
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : theme.cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusXLarge),
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.light
                ? AppColors.shadowLight
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status & Priority Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: theme.brightness == Brightness.dark
                      ? const Color(0xFF101720)
                      : (task.isCompleted
                            ? AppColors.success.withValues(alpha: 0.1)
                            : AppColors.warning.withValues(alpha: 0.1)),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      task.isCompleted ? Icons.check_circle : Icons.schedule,
                      size: 14,
                      color: theme.brightness == Brightness.dark
                          ? (task.isCompleted
                                ? const Color(0xFFA5D6A7)
                                : const Color(0xFFFFF59D))
                          : (task.isCompleted
                                ? AppColors.success
                                : AppColors.warning),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      task.isCompleted ? 'เสร็จสิ้น' : 'กำลังดำเนินการ',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.brightness == Brightness.dark
                            ? (task.isCompleted
                                  ? const Color(0xFFA5D6A7)
                                  : const Color(0xFFFFF59D))
                            : (task.isCompleted
                                  ? AppColors.success
                                  : AppColors.warning),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppConstants.paddingSmall),
              PriorityTag(priority: task.priorityLabel),
              const Spacer(),
              // Type Badge
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color:
                      (task.isPersonal
                              ? AppColors.primaryBlue
                              : AppColors.primaryPurple)
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                ),
                child: Icon(
                  task.isPersonal ? Icons.person : Icons.people,
                  size: 16,
                  color: task.isPersonal
                      ? AppColors.primaryBlue
                      : AppColors.primaryPurple,
                ),
              ),
            ],
          ),

          const SizedBox(height: AppConstants.paddingMedium),

          // Task Title
          Text(
            task.title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),

          if (task.description.isNotEmpty) ...[
            const SizedBox(height: AppConstants.paddingSmall),
            Text(
              task.description,
              style: TextStyle(
                fontSize: 15,
                color: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.stormyIceBlue
                    : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.5,
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _areAllMembersCompleted(Task task, String leaderId) {
    if (task.members.isEmpty) {
      final hasText =
          task.submissionText != null && task.submissionText!.trim().isNotEmpty;
      final hasFiles = task.attachments.isNotEmpty;
      final hasSubmitter =
          task.submittedBy != null && task.submittedBy!.isNotEmpty;
      final isPending = task.status == TaskStatus.pending;
      final isDone = task.status == TaskStatus.completed;
      return isDone || hasText || hasFiles || hasSubmitter || isPending;
    }

    final nonLeaderMembers = task.members
        .where((m) => m.id != leaderId)
        .toList();
    final membersToCheck = nonLeaderMembers.isNotEmpty
        ? nonLeaderMembers
        : task.members;

    return membersToCheck.every((m) => m.status == 'completed');
  }

  void _showIncompleteMembersAlert(
    BuildContext context,
    Task task,
    String leaderId,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final nonLeaderMembers = task.members
        .where((m) => m.id != leaderId)
        .toList();
    final membersToCheck = nonLeaderMembers.isNotEmpty
        ? nonLeaderMembers
        : task.members;
    final incompleteCount = membersToCheck
        .where((m) => m.status != 'completed')
        .length;
    final pendingReviewCount = membersToCheck
        .where((m) => m.status == 'pending')
        .length;

    String message;
    if (task.members.isEmpty) {
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

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? AppColors.stormyDarkSlate : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20.0),
        ),
        title: Text(
          'ไม่สามารถเสร็จสิ้นภารกิจได้',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
            color: theme.colorScheme.onSurface,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            fontSize: 14,
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
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            child: const Text(
              'ตกลง',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubtasksSection(Task task, TaskProvider taskProvider) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;
    final leaderId = taskProvider.leaderIdForTask(task);
    final isLeader = currentUserId != null && currentUserId == leaderId;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Check if current user is an assigned group member
    Member? myMember;
    if (task.isGroup && currentUserId != null) {
      myMember = task.members.where((m) => m.id == currentUserId).firstOrNull;
    }

    final bool showMyAssignedCard = task.isGroup &&
        myMember != null &&
        (!isLeader ||
            (myMember.taskTitle?.trim().isNotEmpty == true ||
                myMember.subTasks.isNotEmpty));
    final bool hasGeneralSubtasks = task.subtasks.isNotEmpty;

    if (!showMyAssignedCard && !hasGeneralSubtasks) {
      return const SizedBox.shrink();
    }

    Widget? generalSubtasksWidget;
    if (hasGeneralSubtasks) {
      generalSubtasksWidget = Container(
        margin: const EdgeInsets.symmetric(
          horizontal: AppConstants.paddingMedium,
          vertical: AppConstants.paddingSmall,
        ),
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        decoration: BoxDecoration(
          color: isDark ? AppColors.stormyDarkSlate : theme.cardColor,
          borderRadius: BorderRadius.circular(AppConstants.radiusXLarge),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.3)
                  : AppColors.shadowLight,
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  task.isGroup
                      ? 'ความคืบหน้าภารกิจย่อยงานหลัก'
                      : 'ความคืบหน้าภารกิจย่อย',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.stormySkyBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${task.subtasks.where((s) => s.isDone).length}/${task.subtasks.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.stormySkyBlue,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppConstants.paddingMedium),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: task.subtasks.length,
              itemBuilder: (context, index) {
                final subtask = task.subtasks[index];
                return GestureDetector(
                  onTap: () async {
                    if (task.isDeleted) return;
                    final connectivity = context.read<ConnectivityProvider>();
                    if (connectivity.isOffline) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'ไม่มีการเชื่อมต่ออินเทอร์เน็ต ไม่สามารถดำเนินการได้',
                          ),
                        ),
                      );
                      return;
                    }

                    if (task.isGroup && !isLeader) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'เฉพาะหัวหน้าภารกิจเท่านั้นที่สามารถอัปเดตภารกิจย่อยหลักได้',
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );
                      return;
                    }

                    final isCheckingLast =
                        !task.isGroup &&
                        !subtask.isDone &&
                        task.subtasks.where((s) => !s.isDone).length == 1;

                    if (isCheckingLast && !task.isCompleted) {
                      final shouldProceed =
                          await LatePenaltyDialog.checkAndShow(
                            context,
                            task,
                          );
                      if (!shouldProceed) return;
                      if (!context.mounted) return;
                    }

                    final result = await taskProvider.toggleSubtask(
                      task.id,
                      index,
                    );

                    if (isCheckingLast && !task.isCompleted && result != null) {
                      if (!context.mounted) return;

                      if (result.status != CompletionRewardStatus.noChange) {
                        final isSoundEnabled =
                            context
                                .read<AuthProvider>()
                                .currentUser
                                ?.isSoundEnabled ??
                            true;
                        unawaited(
                          SoundService.instance.playTaskCompleteSound(
                            isSoundEnabled: isSoundEnabled,
                          ),
                        );
                        await FastCompletionWarningDialog
                            .showCompletionFeedback(context, result);
                        if (!context.mounted) return;
                        SnackBarUtils.showUndoSnackBar(
                          context,
                          message: 'ทำเครื่องหมายเสร็จสิ้นแล้ว',
                          onUndo: () async {
                            await taskProvider.toggleTaskCompletion(
                              task.id,
                              updateSubtasks: true,
                            );
                          },
                        );
                      }
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: subtask.isDone
                          ? (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : AppColors.stormyOffWhite.withValues(
                                  alpha: 0.5,
                                ))
                          : AppColors.stormySkyBlue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: subtask.isDone
                            ? (isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : AppColors.stormyMutedBlueGrey)
                            : AppColors.stormySkyBlue.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          subtask.isDone
                              ? Icons.check_circle
                              : Icons.radio_button_unchecked,
                          size: 20,
                          color: subtask.isDone
                              ? AppColors.success
                              : AppColors.stormySkyBlue,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            subtask.title,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: subtask.isDone
                                  ? FontWeight.normal
                                  : FontWeight.w500,
                              color: subtask.isDone
                                  ? theme.colorScheme.onSurface.withValues(
                                      alpha: 0.5,
                                    )
                                  : theme.colorScheme.onSurface,
                              decoration: subtask.isDone
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                        ),
                        if (task.isGroup && !isLeader)
                          Padding(
                            padding: const EdgeInsets.only(left: 6),
                            child: Icon(
                              Icons.lock_outline_rounded,
                              size: 16,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.35,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    }

    Widget? myAssignedTaskWidget;
    if (showMyAssignedCard) {
      myAssignedTaskWidget = _buildMyAssignedTaskCard(
        task,
        myMember,
        taskProvider,
        isDark,
        theme,
      );
    }

    if (myAssignedTaskWidget != null && generalSubtasksWidget != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          myAssignedTaskWidget,
          generalSubtasksWidget,
        ],
      );
    }

    return myAssignedTaskWidget ??
        generalSubtasksWidget ??
        const SizedBox.shrink();
  }

  /// การ์ดแสดงงานที่ได้รับมอบหมายของสมาชิก พร้อมรายละเอียดครบถ้วน
  Widget _buildMyAssignedTaskCard(
    Task task,
    Member myMember,
    TaskProvider taskProvider,
    bool isDark,
    ThemeData theme,
  ) {
    final statusInfo = _getMemberStatusInfo(myMember, task);
    final memberSubtasks = myMember.subTasks;
    final completedCount = myMember.completedSubTasks
        .where((c) => memberSubtasks.any((st) => st.trim() == c.trim()))
        .length;
    final totalCount = memberSubtasks.length;

    // รายชื่อผู้รับผิดชอบร่วมกันที่มีชื่องานเหมือนกัน
    final coAssignees = task.members
        .where(
          (m) =>
              m.id != myMember.id &&
              m.taskTitle != null &&
              m.taskTitle!.trim().isNotEmpty &&
              m.taskTitle!.trim() == myMember.taskTitle?.trim(),
        )
        .toList();

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
        vertical: AppConstants.paddingSmall,
      ),
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      decoration: BoxDecoration(
        color: isDark ? AppColors.stormyDarkSlate : theme.cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusXLarge),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ส่วนหัว: ไอคอน + ข้อความหัวข้อ + Status Badge
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.stormySkyBlue.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.assignment_ind_rounded,
                  color: AppColors.stormySkyBlue,
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'งานที่คุณได้รับมอบหมาย',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: statusInfo.backgroundColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  statusInfo.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: statusInfo.textColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // ชื่องานมอบหมาย
          Text(
            myMember.taskTitle != null && myMember.taskTitle!.trim().isNotEmpty
                ? myMember.taskTitle!
                : 'ไม่ได้ระบุชื่อภารกิจ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),

          // คำอธิบายงาน (ถ้ามี)
          if (myMember.description != null &&
              myMember.description!.trim().isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              myMember.description!,
              style: TextStyle(
                fontSize: 13,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                height: 1.4,
              ),
            ),
          ],

          // ผู้รับผิดชอบร่วม (Co-assignees)
          if (coAssignees.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Icon(
                  Icons.people_outline_rounded,
                  size: 16,
                  color: AppColors.stormySkyBlue,
                ),
                const SizedBox(width: 6),
                Text(
                  'ผู้รับผิดชอบร่วม: ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: coAssignees.map((co) {
                        return Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.stormySkyBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircleAvatar(
                                radius: 8,
                                backgroundImage: co.avatarUrl.isNotEmpty
                                    ? NetworkImage(co.avatarUrl)
                                    : null,
                                backgroundColor:
                                    AppColors.stormySkyBlue.withValues(alpha: 0.2),
                                child: co.avatarUrl.isEmpty
                                    ? Text(
                                        co.name.isNotEmpty ? co.name[0] : '?',
                                        style: const TextStyle(fontSize: 8),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                co.name,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: theme.colorScheme.onSurface,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // เมตริกภารกิจ (ความยาก / ปริมาณ / ความเสี่ยง / คะแนน)
          const SizedBox(height: 14),
          Row(
            children: [
              _buildSmallMetricBox(
                label: 'ความยาก',
                value: myMember.difficulty.isNotEmpty
                    ? myMember.difficulty
                    : 'Medium',
                color: _getComplexityColor(myMember.difficulty),
              ),
              const SizedBox(width: 8),
              _buildSmallMetricBox(
                label: 'ปริมาณภารกิจ',
                value: myMember.workload.isNotEmpty
                    ? myMember.workload
                    : 'Medium',
                color: _getWorkloadColor(myMember.workload),
              ),
              const SizedBox(width: 8),
              _buildSmallMetricBox(
                label: 'ความเสี่ยง',
                value: myMember.risk.isNotEmpty ? myMember.risk : 'Low',
                color: _getRiskColor(myMember.risk),
              ),
              if (myMember.score != null &&
                  myMember.score!.trim().isNotEmpty) ...[
                const SizedBox(width: 8),
                _buildSmallMetricBox(
                  label: 'คะแนน',
                  value: '${myMember.score} XP',
                  color: AppColors.stormySkyBlue,
                ),
              ],
            ],
          ),

          // รายการภารกิจย่อยของสมาชิก (Subtasks)
          const SizedBox(height: 14),
          Divider(
            height: 1,
            color: theme.dividerColor.withValues(alpha: 0.15),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                Icons.checklist_rtl_rounded,
                size: 18,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
              const SizedBox(width: 6),
              Text(
                'ภารกิจย่อยของคุณ',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (totalCount > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.stormySkyBlue.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$completedCount/$totalCount',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.stormySkyBlue,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (memberSubtasks.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                'ไม่มีภารกิจย่อย',
                style: TextStyle(
                  fontSize: 13,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                ),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: memberSubtasks.length,
              itemBuilder: (context, index) {
                final subtaskTitle = memberSubtasks[index];
                final isDone = myMember.completedSubTasks.any(
                  (c) => c.trim() == subtaskTitle.trim(),
                );

                return GestureDetector(
                  onTap: () async {
                    if (task.isDeleted) return;
                    final connectivity = context.read<ConnectivityProvider>();
                    if (connectivity.isOffline) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            'ไม่มีการเชื่อมต่ออินเทอร์เน็ต ไม่สามารถดำเนินการได้',
                          ),
                        ),
                      );
                      return;
                    }

                    await taskProvider.toggleMemberSubtask(
                      task.id,
                      myMember.id,
                      subtaskTitle,
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isDone
                          ? (isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : AppColors.stormyOffWhite.withValues(
                                  alpha: 0.5,
                                ))
                          : AppColors.stormySkyBlue.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isDone
                            ? (isDark
                                ? Colors.white.withValues(alpha: 0.1)
                                : AppColors.stormyMutedBlueGrey)
                            : AppColors.stormySkyBlue.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          isDone
                              ? Icons.check_circle_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 20,
                          color: isDone
                              ? AppColors.success
                              : AppColors.stormySkyBlue,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            subtaskTitle,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isDone
                                  ? FontWeight.normal
                                  : FontWeight.w500,
                              color: isDone
                                  ? theme.colorScheme.onSurface.withValues(
                                      alpha: 0.5,
                                    )
                                  : theme.colorScheme.onSurface,
                              decoration: isDone
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSmallMetricBox({
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.25), width: 1),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Color _getComplexityColor(String value) {
    switch (value.toLowerCase()) {
      case 'easy':
        return AppColors.primaryGreen;
      case 'hard':
        return AppColors.accentRed;
      default:
        return AppColors.primaryBlue;
    }
  }

  Color _getWorkloadColor(String value) {
    switch (value.toLowerCase()) {
      case 'small':
        return AppColors.primaryGreen;
      case 'large':
        return AppColors.primaryPurple;
      default:
        return AppColors.primaryBlue;
    }
  }

  Color _getRiskColor(String value) {
    switch (value.toLowerCase()) {
      case 'none':
        return AppColors.primaryGreen;
      case 'high':
        return AppColors.accentRed;
      default:
        return AppColors.warning;
    }
  }

  Widget _buildTaskInfoSection(Task task) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
      ),
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : theme.cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusXLarge),
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.light
                ? AppColors.shadowLight
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ข้อมูลภารกิจ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildInfoRow(
            icon: Icons.calendar_today,
            label: 'วันและเวลา',
            value: _formatDateTime(task.dateTime),
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          if (task.category != null)
            _buildInfoRow(
              icon: Icons.category,
              label: 'หมวดหมู่',
              value: thaiCategoryLabel(task.category!),
            ),
          if (task.category != null)
            const SizedBox(height: AppConstants.paddingMedium),
          if (task.location != null)
            _buildInfoRow(
              icon: Icons.location_on,
              label: 'สถานที่',
              value: task.location!,
            ),
          if (task.location != null)
            const SizedBox(height: AppConstants.paddingMedium),
          _buildInfoRow(
            icon: Icons.access_time,
            label: 'สร้างเมื่อ',
            value: _formatDateTime(task.createdAt),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmissionReviewSection(
    Task task,
    TaskProvider taskProvider,
    String currentUserId,
    bool isLeader,
  ) {
    if (task.isDeleted) {
      return const SizedBox.shrink();
    }

    if (isLeader) {
      return const SizedBox.shrink();
    }

    Member? myMember;
    if (task.isGroup || task.members.isNotEmpty) {
      final found = task.members.firstWhere(
        (m) => m.id == currentUserId,
        orElse: () => const Member(id: '', name: '', avatarUrl: ''),
      );
      if (found.id.isNotEmpty) {
        myMember = found;
      }
    }

    if (myMember != null) {
      final currentMember = myMember;
      if (currentMember.status == 'pending') {
          return Column(
            children: [
              _buildWaitingForApprovalCard(),
              Padding(
                padding: const EdgeInsets.only(
                  left: AppConstants.paddingMedium,
                  right: AppConstants.paddingMedium,
                  bottom: AppConstants.paddingMedium,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(
                              AppConstants.radiusLarge,
                            ),
                          ),
                          title: const Text('ยกเลิกการส่งงาน?'),
                          content: const Text(
                            'คุณต้องการยกเลิกการส่งงานนี้ใช่หรือไม่? รายละเอียดการส่งจะถูกลบออก',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('ย้อนกลับ'),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.accentRed,
                                foregroundColor:
                                    Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppColors.stormyNightBackground
                                        : Colors.white,
                              ),
                              child: const Text('ยกเลิกการส่ง'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await taskProvider.cancelMemberTaskSubmission(
                          task.id,
                          currentMember.id,
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('ยกเลิกการส่งงานเรียบร้อยแล้ว'),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(
                      Icons.cancel_outlined,
                      color: AppColors.accentRed,
                    ),
                    label: const Text(
                      'ยกเลิกการส่งงาน',
                      style: TextStyle(
                        color: AppColors.accentRed,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.accentRed),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        } else if (currentMember.status == 'completed') {
          return _buildCompletedReviewCard(isLeader: false, isSubmitter: true);
        } else {
          return _buildMemberSubmitForm(task, taskProvider, myMember: currentMember);
        }
    }

    switch (task.status) {
      case TaskStatus.pending:
        return Column(
          children: [
            _buildWaitingForApprovalCard(),
            Padding(
              padding: const EdgeInsets.only(
                left: AppConstants.paddingMedium,
                right: AppConstants.paddingMedium,
                bottom: AppConstants.paddingMedium,
              ),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            AppConstants.radiusLarge,
                          ),
                        ),
                        title: const Text('ยกเลิกการส่งงาน?'),
                        content: const Text(
                          'คุณต้องการยกเลิกการส่งงานนี้ใช่หรือไม่? ไฟล์ที่อัปโหลดและรายละเอียดการส่งทั้งหมดจะถูกลบออก',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: const Text('ย้อนกลับ'),
                          ),
                          ElevatedButton(
                            onPressed: () => Navigator.pop(context, true),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentRed,
                              foregroundColor:
                                  Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.stormyNightBackground
                                      : Colors.white,
                            ),
                            child: const Text('ยกเลิกการส่ง'),
                          ),
                        ],
                      ),
                    );

                    if (confirm == true) {
                      await taskProvider.cancelTaskSubmission(task.id);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('ยกเลิกการส่งงานเรียบร้อยแล้ว'),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(
                    Icons.cancel_outlined,
                    color: AppColors.accentRed,
                  ),
                  label: const Text(
                    'ยกเลิกการส่งงาน',
                    style: TextStyle(
                      color: AppColors.accentRed,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.accentRed),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      case TaskStatus.completed:
        return _buildCompletedReviewCard(
          isLeader: false,
          isSubmitter: task.submittedBy == currentUserId,
        );
      case TaskStatus.todo:
      case TaskStatus.inProgress:
        return _buildMemberSubmitForm(task, taskProvider, myMember: myMember);
    }
  }

  Widget _buildMemberSubmitForm(
    Task task,
    TaskProvider taskProvider, {
    Member? myMember,
  }) {
    final theme = Theme.of(context);
    final attachments = myMember != null
        ? (myMember.attachments.isNotEmpty
            ? myMember.attachments
            : (task.submittedBy == myMember.id ? task.attachments : <TaskAttachment>[]))
        : task.attachments;
    final canSubmit =
        _submissionController.text.trim().isNotEmpty || attachments.isNotEmpty;

    return Container(
      margin: const EdgeInsets.all(AppConstants.paddingMedium),
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : theme.cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusXLarge),
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.light
                ? AppColors.shadowLight
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color:
                      (Theme.of(context).brightness == Brightness.light
                              ? AppColors.stormySkyBlue
                              : AppColors.primaryBlue)
                          .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.upload_file_outlined,
                  color: (Theme.of(context).brightness == Brightness.light
                      ? AppColors.stormySkyBlue
                      : AppColors.primaryBlue),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'ส่งงานให้หัวหน้าตรวจสอบ',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          TextField(
            controller: _submissionController,
            minLines: 3,
            maxLines: 5,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'วางลิงก์งานหรือสรุปงานที่นี่...',
              suffixIcon: _isUploading
                  ? Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            (Theme.of(context).brightness == Brightness.light
                                ? AppColors.stormySkyBlue
                                : AppColors.primaryBlue),
                          ),
                        ),
                      ),
                    )
                  : IconButton(
                      icon: Icon(
                        Icons.attach_file,
                        color: (Theme.of(context).brightness == Brightness.light
                            ? AppColors.stormySkyBlue
                            : AppColors.primaryBlue),
                      ),
                      onPressed: () async {
                        final connectivity = context
                            .read<ConnectivityProvider>();
                        if (connectivity.isOffline) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'ไม่มีการเชื่อมต่ออินเทอร์เน็ต ไม่สามารถดำเนินการได้',
                              ),
                            ),
                          );
                          return;
                        }
                        setState(() {
                          _isUploading = true;
                        });
                        try {
                          final attachment = myMember != null
                              ? await taskProvider.uploadMemberAttachment(
                                  task.id,
                                  myMember.id,
                                )
                              : await taskProvider.uploadTaskAttachment(
                                  task.id,
                                );
                          if (attachment != null && mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'อัปโหลดไฟล์ "${attachment['fileName']}" สำเร็จแล้ว!',
                                ),
                                backgroundColor: AppColors.success,
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            final errorMsg =
                                e.toString().contains('FILE_TOO_LARGE')
                                ? 'ไฟล์มีขนาดใหญ่เกินไป! อนุญาตสูงสุด 10MB ต่อไฟล์เท่านั้น'
                                : 'เกิดข้อผิดพลาดในการอัปโหลดไฟล์';
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(errorMsg),
                                backgroundColor: AppColors.error,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() {
                              _isUploading = false;
                            });
                          }
                        }
                      },
                    ),
              filled: true,
              fillColor: theme.brightness == Brightness.light
                  ? const Color(0xFFF8FAFC)
                  : Colors.white.withValues(alpha: 0.05),
              contentPadding: const EdgeInsets.all(16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.4),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: theme.dividerColor.withValues(alpha: 0.35),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(18),
                borderSide: BorderSide(
                  color: (Theme.of(context).brightness == Brightness.light
                      ? AppColors.stormySkyBlue
                      : AppColors.primaryBlue),
                  width: 1.5,
                ),
              ),
            ),
          ),
          if (attachments.isNotEmpty) ...[
            const SizedBox(height: AppConstants.paddingMedium),
            Text(
              'ไฟล์แนบของคุณ (${attachments.length})',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            ...attachments.map(
              (attachment) => _buildAttachmentTile(
                attachment,
                task,
                taskProvider,
                showDelete: true,
                onDelete: () async {
                  if (myMember != null) {
                    await taskProvider.deleteMemberAttachment(
                      task.id,
                      myMember.id,
                      attachment,
                    );
                  } else {
                    await taskProvider.deleteTaskAttachment(
                      task.id,
                      attachment,
                    );
                  }
                },
              ),
            ),
          ],
          const SizedBox(height: AppConstants.paddingMedium),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: canSubmit
                  ? () async {
                      bool hasIncompleteSubtasks = false;

                      if (myMember != null) {
                        if (myMember.subTasks.isNotEmpty) {
                          hasIncompleteSubtasks = myMember.subTasks.any(
                            (st) => !myMember.completedSubTasks.any(
                              (c) => c.trim() == st.trim(),
                            ),
                          );
                        } else if (task.subtasks.isNotEmpty) {
                          hasIncompleteSubtasks = task.subtasks.any(
                            (s) => !s.isDone,
                          );
                        }
                      } else {
                        if (task.subtasks.isNotEmpty) {
                          hasIncompleteSubtasks = task.subtasks.any(
                            (s) => !s.isDone,
                          );
                        }
                      }

                      if (hasIncompleteSubtasks) {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('ไม่สามารถส่งงานได้'),
                            content: const Text(
                              'กรุณาทำภารกิจย่อยทั้งหมดให้เสร็จสิ้นก่อนทำการส่งงานให้หัวหน้า',
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16.0),
                            ),
                            actions: [
                              ElevatedButton(
                                onPressed: () => Navigator.pop(context),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.stormySkyBlue,
                                  foregroundColor:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.stormyNightBackground
                                      : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.0),
                                  ),
                                ),
                                child: const Text('ตกลง'),
                              ),
                            ],
                          ),
                        );
                        return;
                      }

                      if (attachments.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('ไม่สามารถส่งงานได้ กรุณาแนบไฟล์งาน'),
                            backgroundColor: AppColors.error,
                          ),
                        );
                        return;
                      }

                      final shouldProceed =
                          await LatePenaltyDialog.checkAndShow(
                            context,
                            task,
                            isGroupSubmission: true,
                          );
                      if (!shouldProceed) return;
                      if (!context.mounted) return;

                      final submission = _submissionController.text.trim();
                      if (myMember != null) {
                        await taskProvider.submitMemberTaskForReview(
                          task.id,
                          myMember.id,
                          submission,
                        );
                      } else {
                        await taskProvider.submitTaskForReview(
                          task.id,
                          submission,
                        );
                      }
                      if (!mounted) return;
                      _submissionController.clear();
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('ส่งงานให้หัวหน้าตรวจสอบแล้ว'),
                        ),
                      );
                    }
                  : null,
              icon: const Icon(Icons.send_rounded),
              label: const Text('ส่งงานให้หัวหน้าตรวจสอบ'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.stormySkyBlue,
                foregroundColor:
                    theme.brightness == Brightness.dark
                        ? AppColors.stormyNightBackground
                        : Colors.white,
                disabledBackgroundColor: theme.disabledColor.withValues(
                  alpha: 0.12,
                ),
                disabledForegroundColor: theme.disabledColor.withValues(
                  alpha: 0.55,
                ),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingForApprovalCard() {
    return _buildStatusCard(
      icon: Icons.schedule_rounded,
      iconColor: const Color(0xFFE59A00),
      backgroundColor: const Color(0xFFFFF8E1),
      title: 'อยู่ระหว่างรอตรวจสอบ',
      message: 'ส่งงานเรียบร้อยแล้ว อยู่ระหว่างรอหัวหน้ากลุ่มตรวจสอบ...',
    );
  }

  Widget _buildDeletedTaskCard() {
    return _buildStatusCard(
      icon: Icons.delete_rounded,
      iconColor: AppColors.accentRed,
      backgroundColor: const Color(0xFFFFE8E8),
      title: 'ภารกิจนี้ถูกลบแล้ว',
      message:
          'ภารกิจนี้อยู่ในถังขยะ จึงไม่สามารถส่งงาน ตรวจงาน หรือคอมเมนต์ได้',
    );
  }

  // ignore: unused_element
  Widget _buildNoSubmissionCard() {
    return const SizedBox.shrink();
  }

  // ignore: unused_element
  Widget _buildLeaderApprovalPanel(Task task, TaskProvider taskProvider) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final submitter = _submittedMemberForTask(task);
    final submitterName = submitter?.name ?? 'ผู้ส่งงาน';
    final submissionText = task.submissionText?.trim().isNotEmpty == true
        ? task.submissionText!.trim()
        : 'ไม่มีรายละเอียดเพิ่มเติม';

    return Container(
      margin: const EdgeInsets.all(AppConstants.paddingMedium),
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : theme.cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusXLarge),
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.light
                ? AppColors.shadowLight
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor:
                    (Theme.of(context).brightness == Brightness.light
                            ? AppColors.stormyDarkSlate
                            : AppColors.primaryPurple)
                        .withValues(alpha: 0.1),
                backgroundImage:
                    submitter != null && submitter.avatarUrl.isNotEmpty
                    ? NetworkImage(submitter.avatarUrl)
                    : null,
                child: submitter == null || submitter.avatarUrl.isEmpty
                    ? Icon(
                        Icons.person_outline,
                        color: (Theme.of(context).brightness == Brightness.light
                            ? AppColors.stormyDarkSlate
                            : AppColors.primaryPurple),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      submitterName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      task.submittedAt == null
                          ? 'ส่งงานเข้ามาตรวจสอบ'
                          : 'ส่งเมื่อ ${_formatDateTime(task.submittedAt!)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.light
                  ? const Color(0xFFF8FAFC)
                  : Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
            ),
            child: _buildLinkifiedText(
              submissionText,
              TextStyle(
                height: 1.45,
                fontSize: 14,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          _buildScoreRecommendationCard(task),
          const SizedBox(height: AppConstants.paddingMedium),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _showRejectTaskSubmissionDialog(task),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isDark
                        ? const Color(0xFFFF6B6B)
                        : AppColors.accentRed,
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFFFF6B6B)
                          : AppColors.accentRed,
                      width: 1.5,
                    ),
                    backgroundColor:
                        (isDark ? const Color(0xFFFF6B6B) : AppColors.accentRed)
                            .withValues(alpha: isDark ? 0.12 : 0.06),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'ปฏิเสธ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    final connectivity = context.read<ConnectivityProvider>();
                    if (connectivity.isOffline) {
                      _showOfflineDialog(context);
                      return;
                    }
                    await taskProvider.approveTaskSubmission(task.id);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('อนุมัติงานแล้ว'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryGreen,
                    foregroundColor:
                        theme.brightness == Brightness.dark
                            ? AppColors.stormyNightBackground
                            : Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'อนุมัติ',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Widget _buildScoreRecommendationCard(Task task) {
    final theme = Theme.of(context);
    final score = task.calculateXP;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            (Theme.of(context).brightness == Brightness.light
                    ? AppColors.stormyDarkSlate
                    : AppColors.primaryPurple)
                .withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  (Theme.of(context).brightness == Brightness.light
                          ? AppColors.stormyDarkSlate
                          : AppColors.primaryPurple)
                      .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: (Theme.of(context).brightness == Brightness.light
                  ? AppColors.stormyDarkSlate
                  : AppColors.primaryPurple),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'คำแนะนำคะแนนอัตโนมัติ',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'ภารกิจนี้เหมาะกับ $score คะแนน จากความยาก ปริมาณภารกิจ และความเสี่ยง',
                  style: TextStyle(
                    fontSize: 12,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedReviewCard({
    required bool isLeader,
    bool isSubmitter = false,
  }) {
    return _buildStatusCard(
      icon: Icons.verified_rounded,
      iconColor: AppColors.primaryGreen,
      backgroundColor: const Color(0xFFE8FFF6),
      title: isLeader ? 'งานนี้อนุมัติแล้ว' : 'งานผ่านการอนุมัติแล้ว',
      message: isLeader
          ? 'ระบบบันทึกงานนี้เป็นเสร็จสมบูรณ์แล้ว'
          : isSubmitter
          ? 'หัวหน้ากลุ่มตรวจและอนุมัติงานของคุณแล้ว'
          : 'งานนี้ถูกอนุมัติเรียบร้อยแล้ว',
    );
  }

  Widget _buildStatusCard({
    required IconData icon,
    required Color iconColor,
    required Color backgroundColor,
    required String title,
    required String message,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final titleColor = isDark
        ? const Color(0xFF202124)
        : theme.colorScheme.onSurface;
    final messageColor = isDark
        ? const Color(0xFF4B5563)
        : theme.colorScheme.onSurface.withValues(alpha: 0.65);

    return Container(
      margin: const EdgeInsets.all(AppConstants.paddingMedium),
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusXLarge),
        boxShadow: [
          BoxShadow(
            color: iconColor.withValues(alpha: 0.10),
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
              color: Colors.white.withValues(alpha: 0.75),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: titleColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.35,
                    color: messageColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ignore: unused_element
  Member? _submittedMemberForTask(Task task) {
    final submittedBy = task.submittedBy;
    if (submittedBy == null || submittedBy.isEmpty) return null;
    try {
      return task.members.firstWhere((member) => member.id == submittedBy);
    } catch (_) {
      return null;
    }
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : (Theme.of(context).brightness == Brightness.light
                      ? AppColors.stormyOffWhite
                      : AppColors.backgroundLightGrey),
            borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
          ),
          child: Icon(
            icon,
            size: 18,
            color: isDark
                ? AppColors.stormyIceBlue
                : (Theme.of(context).brightness == Brightness.light
                      ? AppColors.stormyMutedBlueGrey
                      : AppColors.textSecondary),
          ),
        ),
        const SizedBox(width: AppConstants.paddingMedium),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? AppColors.stormyIceBlue
                    : (Theme.of(context).brightness == Brightness.light
                          ? AppColors.stormyMutedBlueGrey
                          : AppColors.textLight),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLeaderReviewSection(
    Task task,
    TaskProvider taskProvider,
    AuthProvider authProvider,
  ) {
    final leaderId = taskProvider.leaderIdForTask(task);
    final isLeader = taskProvider.isLeaderForTask(
      task,
      authProvider.currentUser?.id,
    );
    final members = task.members;
    final theme = Theme.of(context);
    final leaderMember = _leaderMemberForTask(task, leaderId);

    if (members.isEmpty) return const SizedBox.shrink();

    // Show detailed Leader Review for group tasks when current user is the leader
    if (task.isGroup && isLeader) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Project Leader Summary Card
          _buildLeaderSummaryCard(
            authProvider.currentUser!,
            task,
            leaderMember,
          ),

          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppConstants.paddingMedium,
              vertical: 8,
            ),
            child: Text(
              'ผู้รับผิดชอบ',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),

          // Detailed Member Review Cards
          ...members
              .where((m) => m.id != leaderId)
              .map(
                (member) => _buildMemberReviewCard(member, task, taskProvider),
              ),
        ],
      );
    }

    // --- Full Team Overview for Member View ---
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Responsible Members Header (Leader Card ย้ายไปแสดงก่อนส่วนส่งงานแล้ว)
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppConstants.paddingMedium,
            vertical: 8,
          ),
          child: Text(
            'ผู้รับผิดชอบ',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),

        // Team Members List
        _buildTeamMembersList(task, taskProvider, leaderId),
      ],
    );
  }

  /// Card แสดงข้อมูลหัวหน้าภารกิจ (สำหรับ Member View — ไม่มีปุ่มอนุมัติ)
  Widget _buildTaskLeaderCard(
    Task task,
    TaskProvider taskProvider,
    String leaderId,
  ) {
    final theme = Theme.of(context);
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    final leaderUser = taskProvider.getUserById(leaderId);
    final leaderName = leaderUser?.name ?? 'หัวหน้าภารกิจ';
    final leaderAvatarUrl = leaderUser?.avatarUrl ?? '';
    final leaderFrame = leaderUser?.equippedFrame ?? '';
    final leaderMember = _leaderMemberForTask(task, leaderId);

    return Container(
      margin: const EdgeInsets.all(AppConstants.paddingMedium),
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : theme.cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.light
                ? Colors.black.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'หัวหน้าภารกิจ:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              UserAvatarWithFrame(
                avatarUrl: leaderAvatarUrl,
                frameId: leaderFrame,
                fallbackName: leaderName,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  leaderName,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ),
              // ปุ่มสามจุด — แสดงเฉพาะเมื่อหัวหน้ามีงานที่ได้รับมอบหมาย และไม่ใช่ตัวเราเอง
              if (leaderMember != null && leaderId != currentUserId)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'view_details') {
                      _openMemberAssignmentDetails(
                        leaderMember,
                        task,
                        isLeader: false,
                      );
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem<String>(
                      value: 'view_details',
                      child: Row(
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 20,
                            color: theme.colorScheme.onSurface,
                          ),
                          const SizedBox(width: 10),
                          const Text('ดูรายละเอียดงานมอบหมาย'),
                        ],
                      ),
                    ),
                  ],
                  icon: Icon(
                    Icons.more_vert,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  /// รายการสมาชิกทีม พร้อม Status Badge (สำหรับ Member View)
  Widget _buildTeamMembersList(
    Task task,
    TaskProvider taskProvider,
    String leaderId,
  ) {
    final nonLeaderMembers = task.members
        .where((m) => m.id != leaderId)
        .toList();

    if (nonLeaderMembers.isEmpty) return const SizedBox.shrink();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
      ),
      itemCount: nonLeaderMembers.length,
      itemBuilder: (context, index) {
        final member = nonLeaderMembers[index];
        return _buildMemberListItem(member, task, taskProvider);
      },
    );
  }

  /// การ์ดสมาชิกแต่ละคน พร้อม ListTile, Status Badge และปุ่มดูรายละเอียด
  Widget _buildMemberListItem(
    Member member,
    Task task,
    TaskProvider taskProvider,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    final isSelf = currentUserId != null && member.id == currentUserId;
    final memberFrame =
        taskProvider.getUserById(member.id)?.equippedFrame ?? '';

    // คำนวณสถานะของสมาชิก
    final statusInfo = _getMemberStatusInfo(member, task);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : theme.cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: UserAvatarWithFrame(
          avatarUrl: member.avatarUrl,
          frameId: memberFrame,
          fallbackName: member.name,
          size: 44,
        ),
        title: Text(
          member.name,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: statusInfo.backgroundColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                statusInfo.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: statusInfo.textColor,
                ),
              ),
            ),
          ),
        ),
        trailing: isSelf
            ? null
            : PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'view_details') {
                    _openMemberAssignmentDetails(member, task, isLeader: false);
                  }
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'view_details',
                    child: Row(
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 20,
                          color: theme.colorScheme.onSurface,
                        ),
                        const SizedBox(width: 10),
                        const Text('ดูรายละเอียดงานมอบหมาย'),
                      ],
                    ),
                  ),
                ],
                icon: Icon(
                  Icons.more_vert,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
      ),
    );
  }

  /// คำนวณสถานะของสมาชิก (กำลังทำ / ส่งแล้ว-รอตรวจ / เสร็จสิ้น)
  _MemberStatusInfo _getMemberStatusInfo(Member member, Task task) {
    // กรณี Member เสร็จสิ้นแล้ว
    if (member.status == 'completed' ||
        (task.status == TaskStatus.completed &&
            task.submittedBy == member.id)) {
      return _MemberStatusInfo(
        label: 'เสร็จสิ้น',
        textColor: AppColors.primaryGreen,
        backgroundColor: AppColors.primaryGreen.withValues(alpha: 0.12),
      );
    }

    // กรณี Member รอตรวจ (pending)
    if (member.status == 'pending' ||
        (task.status == TaskStatus.pending && task.submittedBy == member.id)) {
      return _MemberStatusInfo(
        label: 'ส่งแล้ว/รอตรวจ',
        textColor: const Color(0xFFE59A00),
        backgroundColor: const Color(0xFFFFF8E1),
      );
    }

    // กรณีปกติ — กำลังดำเนินการ
    return _MemberStatusInfo(
      label: 'กำลังทำ',
      textColor: AppColors.accentRed,
      backgroundColor: AppColors.accentRed.withValues(alpha: 0.10),
    );
  }

  Member? _leaderMemberForTask(Task task, String leaderId) {
    try {
      final member = task.members.firstWhere((m) => m.id == leaderId);
      final taskTitle = member.taskTitle;
      if (taskTitle == null || taskTitle.trim().isEmpty) return null;
      return member;
    } catch (_) {
      return null;
    }
  }

  void _openMemberAssignmentDetails(
    Member member,
    Task task, {
    required bool isLeader,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MemberAssignmentDetailScreen(
          member: member,
          allMembers: task.members,
          isLeader: isLeader,
          task: task,
        ),
      ),
    );
  }

  Widget _buildLeaderSummaryCard(User leader, Task task, Member? leaderMember) {
    final theme = Theme.of(context);
    final nonLeaderMembers =
        task.members.where((m) => m.id != leader.id).toList();
    final membersToCheck =
        nonLeaderMembers.isNotEmpty ? nonLeaderMembers : task.members;
    final pendingMembersCount =
        membersToCheck.where((m) => m.status == 'pending').length;
    final completedMembersCount =
        membersToCheck.where((m) => m.status == 'completed').length;
    final totalMembersCount = membersToCheck.length;

    final bool allDone =
        totalMembersCount > 0 && completedMembersCount == totalMembersCount;
    final bool hasPending = pendingMembersCount > 0;

    String bannerText;
    Color bannerColor;
    IconData bannerIcon;

    if (hasPending) {
      bannerText = 'อนุมัติงาน (มีสมาชิกที่รอการอนุมัติ $pendingMembersCount คน)';
      bannerColor = const Color(0xFFE59A00);
      bannerIcon = Icons.pending_actions_rounded;
    } else if (allDone) {
      bannerText = 'อนุมัติงานครบแล้ว (สมาชิกทำงานเสร็จสิ้นทั้งหมด)';
      bannerColor = AppColors.primaryGreen;
      bannerIcon = Icons.check_circle_outline;
    } else {
      bannerText =
          'รอสมาชิกส่งงาน ($completedMembersCount/$totalMembersCount คนเสร็จสิ้น)';
      bannerColor = AppColors.stormySkyBlue;
      bannerIcon = Icons.hourglass_top_rounded;
    }

    return Container(
      margin: const EdgeInsets.all(AppConstants.paddingMedium),
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : theme.cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.light
                ? Colors.black.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'หัวหน้าภารกิจ:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              UserAvatarWithFrame(
                avatarUrl: leader.avatarUrl,
                frameId: leader.equippedFrame,
                fallbackName: leader.name,
                size: 48,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  leader.name,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (leaderMember != null)
                PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'view_details') {
                      _openMemberAssignmentDetails(
                        leaderMember,
                        task,
                        isLeader: true,
                      );
                    }
                  },
                  itemBuilder: (BuildContext context) => [
                    PopupMenuItem<String>(
                      value: 'view_details',
                      child: Row(
                        children: [
                          Icon(
                            Icons.visibility_outlined,
                            size: 20,
                            color: theme.colorScheme.onSurface,
                          ),
                          const SizedBox(width: 10),
                          const Text('ดูรายละเอียดงานมอบหมาย'),
                        ],
                      ),
                    ),
                  ],
                  icon: Icon(
                    Icons.more_vert,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: bannerColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              children: [
                Icon(
                  bannerIcon,
                  color: bannerColor,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    bannerText,
                    style: TextStyle(
                      color: bannerColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMemberReviewCard(
    Member member,
    Task task,
    TaskProvider taskProvider,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final leaderId = taskProvider.leaderIdForTask(task);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;
    final isLeader = currentUserId != null && currentUserId == leaderId;
    final isMemberPending =
        !task.isDeleted &&
        (member.status == 'pending' ||
            (task.status == TaskStatus.pending &&
                task.submittedBy == member.id));
    final isMemberCompleted =
        !task.isDeleted &&
        (member.status == 'completed' ||
            (task.status == TaskStatus.completed &&
                task.submittedBy == member.id));
    final submissionText = member.submissionText?.trim().isNotEmpty == true
        ? member.submissionText!.trim()
        : (task.submittedBy == member.id ? task.submissionText?.trim() : null);
    final attachments = member.attachments.isNotEmpty
        ? member.attachments
        : (task.submittedBy == member.id
              ? task.attachments
              : <TaskAttachment>[]);
    final submittedAt =
        member.submittedAt ??
        (task.submittedBy == member.id ? task.submittedAt : null);

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
        vertical: 8,
      ),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : theme.cardColor,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Member Header
          Row(
            children: [
              UserAvatarWithFrame(
                avatarUrl: member.avatarUrl,
                frameId:
                    taskProvider.getUserById(member.id)?.equippedFrame ?? '',
                fallbackName: member.name,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  member.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'view_details') {
                    _openMemberAssignmentDetails(
                      member,
                      task,
                      isLeader: member.id == leaderId,
                    );
                  }
                },
                itemBuilder: (BuildContext context) => [
                  PopupMenuItem<String>(
                    value: 'view_details',
                    child: Row(
                      children: [
                        Icon(
                          Icons.visibility_outlined,
                          size: 20,
                          color: theme.colorScheme.onSurface,
                        ),
                        const SizedBox(width: 10),
                        const Text('ดูรายละเอียดงานมอบหมาย'),
                      ],
                    ),
                  ),
                ],
                icon: Icon(
                  Icons.more_vert,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Member Task Info
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'ภารกิจที่ได้รับมอบหมาย: ${member.taskTitle ?? "ไม่ได้ระบุ"}',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (member.subTasks.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        'ภารกิจย่อย: ${member.completedSubTasks.length}/${member.subTasks.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryPurple,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    if (isMemberPending && submittedAt != null)
                      Text(
                        'ส่งเมื่อ ${_formatDateTime(submittedAt)}',
                        style: TextStyle(
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.5,
                          ),
                        ),
                      )
                    else if (isMemberCompleted)
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(5),
                            decoration: BoxDecoration(
                              color: AppColors.primaryGreen.withValues(
                                alpha: 0.16,
                              ),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.check_circle,
                              color: AppColors.primaryGreen,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'เสร็จสิ้น!',
                            style: TextStyle(
                              fontSize: 16,
                              color: AppColors.primaryGreen,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      )
                    else
                      const Text(
                        'กำลังทำ',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.accentRed,
                          fontWeight: FontWeight.bold,
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
                  color:
                      (Theme.of(context).brightness == Brightness.light
                              ? AppColors.stormyDarkSlate
                              : AppColors.primaryPurple)
                          .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${member.score ?? "0"} คะแนน',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: (Theme.of(context).brightness == Brightness.light
                        ? AppColors.stormyDarkSlate
                        : AppColors.primaryPurple),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          if ((isMemberPending || isMemberCompleted) &&
              submissionText != null &&
              submissionText.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.05)
                    : (Theme.of(context).brightness == Brightness.light
                          ? AppColors.stormyOffWhite
                          : AppColors.backgroundLightGrey),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.description_outlined,
                    color: (Theme.of(context).brightness == Brightness.light
                        ? AppColors.stormySkyBlue
                        : AppColors.primaryBlue),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildLinkifiedText(
                      submissionText,
                      TextStyle(
                        fontSize: 13,
                        color: (Theme.of(context).brightness == Brightness.light
                            ? AppColors.stormySkyBlue
                            : AppColors.primaryBlue),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],

          if ((isMemberPending || isMemberCompleted) &&
              attachments.isNotEmpty) ...[
            ...attachments.map(
              (attachment) => _buildAttachmentTile(
                attachment,
                task,
                taskProvider,
                showDelete: false,
              ),
            ),
            const SizedBox(height: 12),
          ],

          if (isLeader && isMemberPending)
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () =>
                        _showRejectMemberSubmissionDialog(task, member),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? const Color(0xFFFF6B6B)
                          : AppColors.accentRed,
                      side: BorderSide(
                        color: isDark
                            ? const Color(0xFFFF6B6B)
                            : AppColors.accentRed,
                        width: 1.5,
                      ),
                      backgroundColor: (isDark
                              ? const Color(0xFFFF6B6B)
                              : AppColors.accentRed)
                          .withValues(alpha: isDark ? 0.12 : 0.06),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'ปฏิเสธ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final connectivity = context.read<ConnectivityProvider>();
                      if (connectivity.isOffline) {
                        _showOfflineDialog(context);
                        return;
                      }
                      await taskProvider.approveMemberTaskSubmission(
                        task.id,
                        member.id,
                      );
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('อนุมัติงานแล้ว'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      await _checkAndShowAllMembersApprovedDialog(
                        task,
                        taskProvider,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryGreen,
                      foregroundColor:
                          theme.brightness == Brightness.dark
                              ? AppColors.stormyNightBackground
                              : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text(
                      'อนุมัติ',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            )
          else if (isLeader &&
              isMemberCompleted &&
              !task.isCompleted &&
              member.id != leaderId) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _showRevertApprovalDialog(task, member),
                icon: const Icon(Icons.replay_rounded, size: 18),
                label: const Text(
                  'ส่งกลับไปแก้ไข',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isDark
                      ? const Color(0xFFFFB74D)
                      : const Color(0xFFD97706),
                  side: BorderSide(
                    color: (isDark
                            ? const Color(0xFFFFB74D)
                            : const Color(0xFFD97706))
                        .withValues(alpha: 0.8),
                    width: 1.5,
                  ),
                  backgroundColor: (isDark
                          ? const Color(0xFFFFB74D)
                          : const Color(0xFFD97706))
                      .withValues(alpha: isDark ? 0.12 : 0.06),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15),
                  ),
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _scrollMainCommentsToLatest({bool animated = true}) {
    void doScroll() {
      if (!_mainCommentsScrollController.hasClients) return;
      final maxScroll = _mainCommentsScrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;
      if (animated) {
        _mainCommentsScrollController.animateTo(
          maxScroll,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOutCubic,
        );
      } else {
        _mainCommentsScrollController.jumpTo(maxScroll);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 100), doScroll);
      Future.delayed(const Duration(milliseconds: 250), doScroll);
    });
  }

  Widget _buildCommentsSection(Task task, TaskProvider taskProvider) {
    final theme = Theme.of(context);
    final canAddComments =
        !task.isDeleted && !(task.isGroup && task.isCompleted);

    if (!_didInitialMainScroll || _lastMainCommentsCount != task.comments.length) {
      _didInitialMainScroll = true;
      _lastMainCommentsCount = task.comments.length;
      _scrollMainCommentsToLatest(animated: true);
    }

    return Container(
      margin: const EdgeInsets.all(AppConstants.paddingMedium),
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : theme.cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusXLarge),
        boxShadow: [
          BoxShadow(
            color: theme.brightness == Brightness.light
                ? AppColors.shadowLight
                : Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ความคิดเห็น',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'เปิดแชทเต็ม',
                onPressed: () => _showFullCommentsSheet(task),
                icon: const Icon(Icons.open_in_full_rounded),
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingMedium),

          // Comments List
          if (task.comments.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(AppConstants.paddingLarge),
                child: Column(
                  children: [
                    Icon(
                      Icons.chat_bubble_outline,
                      size: 48,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    const SizedBox(height: AppConstants.paddingSmall),
                    Text(
                      'ยังไม่มีความคิดเห็น',
                      style: TextStyle(
                        fontSize: 14,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 280),
              child: ListView.separated(
                controller: _mainCommentsScrollController,
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: task.comments.length,
                separatorBuilder: (context, index) =>
                    const SizedBox(height: AppConstants.paddingMedium),
                itemBuilder: (context, index) {
                  return _buildCommentItem(
                    task.comments[index],
                    task,
                    taskProvider,
                  );
                },
              ),
            ),

          if (canAddComments) const SizedBox(height: AppConstants.paddingLarge),

          if (canAddComments)
            _buildCommentComposer(
              task,
              taskProvider,
              focusNode: _mainCommentFocusNode,
              onCommentSent: () =>
                  _scrollMainCommentsToLatest(animated: true),
            ),
        ],
      ),
    );
  }

  Future<void> _showFullCommentsSheet(Task task) async {
    final theme = Theme.of(context);

    // Unfocus everything before opening the sheet to prevent focus restoration jumps
    _mainCommentFocusNode.unfocus();
    _sheetCommentFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        bool didInitialScroll = false;
        double lastBottomInset = 0;
        return StatefulBuilder(
          builder: (context, refreshSheet) {
            void refreshCommentComposer() => refreshSheet(() {});

            return NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                if (notification is UserScrollNotification ||
                    (notification is ScrollStartNotification &&
                        notification.dragDetails != null)) {
                  if (_sheetCommentFocusNode.hasFocus) {
                    _sheetCommentFocusNode.unfocus();
                    FocusManager.instance.primaryFocus?.unfocus();
                  }
                }
                return false;
              },
              child: DraggableScrollableSheet(
                initialChildSize: 0.86,
                minChildSize: 0.5,
                maxChildSize: 0.94,
                expand: false,
                builder: (context, scrollController) {
                  final bottomInset = MediaQuery.of(context).viewInsets.bottom;
                  if (bottomInset > 0 &&
                      (bottomInset - lastBottomInset).abs() > 10) {
                    lastBottomInset = bottomInset;
                    _scrollFullCommentsToLatest(
                      scrollController,
                      animated: true,
                    );
                  } else if (bottomInset == 0) {
                    lastBottomInset = 0;
                  }

                  if (!didInitialScroll) {
                    didInitialScroll = true;
                    _scrollFullCommentsToLatest(
                      scrollController,
                      animated: false,
                    );
                  }
                  return Consumer<TaskProvider>(
                    builder: (context, taskProvider, _) {
                      final currentTask =
                          _latestTaskFromProvider(taskProvider, task.id) ??
                          task;
                      final canAddComments =
                          !currentTask.isDeleted &&
                          !(currentTask.isGroup && currentTask.isCompleted);

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom,
                        ),
                        child: GestureDetector(
                          behavior: HitTestBehavior.translucent,
                          onTap: () {
                            _sheetCommentFocusNode.unfocus();
                            FocusManager.instance.primaryFocus?.unfocus();
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: theme.brightness == Brightness.dark
                                  ? AppColors.stormyDarkSlate
                                  : theme.cardColor,
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(
                                  AppConstants.radiusXLarge,
                                ),
                                topRight: Radius.circular(
                                  AppConstants.radiusXLarge,
                                ),
                              ),
                            ),
                            child: SafeArea(
                              top: false,
                              child: Column(
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(
                                      top: 12,
                                      bottom: 8,
                                    ),
                                    width: 40,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.onSurface
                                          .withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppConstants.paddingLarge,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            'ความคิดเห็น',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.bold,
                                              color:
                                                  theme.colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                        IconButton(
                                          tooltip: 'ปิด',
                                          onPressed: () {
                                            _sheetCommentFocusNode.unfocus();
                                            _mainCommentFocusNode.unfocus();
                                            FocusManager.instance.primaryFocus
                                                ?.unfocus();
                                            Navigator.pop(sheetContext);
                                          },
                                          icon: const Icon(Icons.close_rounded),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(
                                    height: AppConstants.paddingSmall,
                                  ),
                                  Expanded(
                                    child: currentTask.comments.isEmpty
                                        ? Center(
                                            child: Text(
                                              'ยังไม่มีความคิดเห็น',
                                              style: TextStyle(
                                                color: theme
                                                    .colorScheme
                                                    .onSurface
                                                    .withValues(alpha: 0.5),
                                              ),
                                            ),
                                          )
                                        : ListView.separated(
                                            controller: scrollController,
                                            padding:
                                                const EdgeInsets.symmetric(
                                                  horizontal:
                                                      AppConstants.paddingLarge,
                                                  vertical:
                                                      AppConstants.paddingSmall,
                                                ),
                                            itemCount:
                                                currentTask.comments.length,
                                            separatorBuilder:
                                                (context, index) =>
                                                    const SizedBox(
                                                      height:
                                                          AppConstants
                                                              .paddingMedium,
                                                    ),
                                            itemBuilder: (context, index) =>
                                                _buildCommentItem(
                                                  currentTask.comments[index],
                                                  currentTask,
                                                  taskProvider,
                                                ),
                                          ),
                                  ),
                                  if (canAddComments)
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        AppConstants.paddingLarge,
                                        AppConstants.paddingSmall,
                                        AppConstants.paddingLarge,
                                        AppConstants.paddingMedium,
                                      ),
                                      child: _buildCommentComposer(
                                        currentTask,
                                        taskProvider,
                                        focusNode: _sheetCommentFocusNode,
                                        onCommentSent: () =>
                                            _scrollFullCommentsToLatest(
                                              scrollController,
                                            ),
                                        onComposerChanged:
                                            refreshCommentComposer,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            );
          },
        );
      },
    );

    // Unfocus again after bottom sheet dismissed to ensure main screen field does not auto-gain focus
    _sheetCommentFocusNode.unfocus();
    _mainCommentFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Widget _buildCommentComposer(
    Task task,
    TaskProvider taskProvider, {
    FocusNode? focusNode,
    VoidCallback? onCommentSent,
    VoidCallback? onComposerChanged,
  }) {
    final theme = Theme.of(context);
    final targetFocusNode = focusNode ?? _mainCommentFocusNode;
    return Column(
      children: [
        if (_commentAttachments.isNotEmpty) ...[
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _commentAttachments.length,
              itemBuilder: (context, index) {
                final attachment = _commentAttachments[index];
                final isImage = _isImageAttachment(attachment);
                return GestureDetector(
                  onTap: () {
                    if (isImage) {
                      _showImagePreviewDialog(
                        context,
                        attachment.fileUrl,
                        attachment.fileName,
                      );
                    } else {
                      _showDocumentDetailsDialog(
                        context,
                        attachment.fileUrl,
                        attachment.fileName,
                        attachment.fileType,
                      );
                    }
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.brightness == Brightness.light
                          ? const Color(0xFFF1F5F9)
                          : Colors.white.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: theme.brightness == Brightness.light
                            ? const Color(0xFFE2E8F0)
                            : Colors.white.withValues(alpha: 0.15),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isImage)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                Image.network(
                                  attachment.fileUrl,
                                  width: 32,
                                  height: 32,
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Icon(
                                        Icons.image,
                                        size: 24,
                                        color: AppColors.stormySkyBlue,
                                      ),
                                ),
                                Container(
                                  width: 32,
                                  height: 32,
                                  color: Colors.black.withValues(alpha: 0.18),
                                  child: const Icon(
                                    Icons.open_in_full_rounded,
                                    color: Colors.white,
                                    size: 14,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          Icon(
                            attachment.fileType.toLowerCase() == 'pdf'
                                ? Icons.picture_as_pdf_outlined
                                : Icons.insert_drive_file_outlined,
                            size: 24,
                            color: attachment.fileType.toLowerCase() == 'pdf'
                                ? AppColors.accentRed
                                : (Theme.of(context).brightness ==
                                          Brightness.light
                                      ? AppColors.stormySkyBlue
                                      : AppColors.primaryBlue),
                          ),
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 100),
                          child: Text(
                            attachment.fileName,
                            style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.onSurface,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            _removeCommentAttachment(
                              attachment,
                              onComposerChanged: onComposerChanged,
                            );
                          },
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.6,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: AppConstants.paddingSmall),
        ],
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                focusNode: targetFocusNode,
                onTap: () {
                  if (!targetFocusNode.hasFocus) {
                    targetFocusNode.requestFocus();
                  }
                },
                onTapOutside: (_) {
                  targetFocusNode.unfocus();
                  FocusManager.instance.primaryFocus?.unfocus();
                },
                style: TextStyle(color: theme.colorScheme.onSurface),
                decoration: InputDecoration(
                  hintText: 'เขียนความคิดเห็น...',
                  hintStyle: TextStyle(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  suffixIcon: _isUploadingCommentAttachment
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.stormySkyBlue,
                            ),
                          ),
                        )
                      : IconButton(
                          icon: const Icon(
                            Icons.attach_file_rounded,
                            color: AppColors.stormySkyBlue,
                          ),
                          onPressed: () => _pickCommentAttachment(
                            task.id,
                            taskProvider,
                            onComposerChanged: onComposerChanged,
                          ),
                        ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusMedium,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusMedium,
                    ),
                    borderSide: BorderSide(
                      color: theme.brightness == Brightness.dark
                          ? AppColors.stormyMutedBlueGrey.withValues(alpha: 0.6)
                          : AppColors.stormyMutedBlueGrey,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(
                      AppConstants.radiusMedium,
                    ),
                    borderSide: const BorderSide(
                      color: AppColors.stormySkyBlue,
                      width: 2,
                    ),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: AppConstants.paddingMedium,
                    vertical: AppConstants.paddingSmall,
                  ),
                ),
                maxLines: null,
              ),
            ),
            const SizedBox(width: AppConstants.paddingSmall),
            GestureDetector(
              onTap: () => _addComment(
                task,
                taskProvider,
                onCommentSent: onCommentSent,
                onComposerChanged: onComposerChanged,
              ),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.stormySkyBlue,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send,
                  color: AppColors.textWhite,
                  size: 20,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  bool _isImageAttachment(TaskAttachment attachment) {
    return [
      'png',
      'jpg',
      'jpeg',
      'webp',
      'gif',
    ].contains(attachment.fileType.toLowerCase());
  }

  void _removeCommentAttachment(
    TaskAttachment attachment, {
    VoidCallback? onComposerChanged,
  }) {
    if (!_commentAttachments.any(
      (item) => _isSameAttachment(item, attachment),
    )) {
      return;
    }

    setState(() {
      _commentAttachments.removeWhere(
        (item) => _isSameAttachment(item, attachment),
      );
    });
    onComposerChanged?.call();
  }

  bool _isSameAttachment(TaskAttachment a, TaskAttachment b) {
    return a.fileUrl == b.fileUrl &&
        a.fileName == b.fileName &&
        a.fileType == b.fileType;
  }

  void _scrollFullCommentsToLatest(
    ScrollController scrollController, {
    bool animated = true,
  }) {
    void doScroll() {
      if (!scrollController.hasClients) return;
      final maxScroll = scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;
      if (animated) {
        scrollController.animateTo(
          maxScroll,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
        );
      } else {
        scrollController.jumpTo(maxScroll);
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      doScroll();
      Future.delayed(const Duration(milliseconds: 150), doScroll);
      Future.delayed(const Duration(milliseconds: 300), doScroll);
    });
  }

  void _showCopyToast(
    String message, {
    bool isError = false,
    IconData? icon,
    Color? iconColor,
  }) {
    _toastEntry?.remove();
    _toastEntry = null;

    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final effectiveIcon = icon ??
        (isError ? Icons.error_outline_rounded : Icons.check_circle_rounded);
    final effectiveColor = iconColor ??
        (isError ? const Color(0xFFF87171) : const Color(0xFF4ADE80));

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        bottom: 80 + MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              builder: (context, val, child) {
                return Opacity(
                  opacity: val,
                  child: Transform.scale(
                    scale: 0.85 + (0.15 * val),
                    child: child,
                  ),
                );
              },
              child: Container(
                constraints: const BoxConstraints(maxWidth: 420),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      effectiveIcon,
                      color: effectiveColor,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        message,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          height: 1.3,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    _toastEntry = entry;
    overlay.insert(entry);

    Future.delayed(const Duration(seconds: 2), () {
      if (_toastEntry == entry) {
        entry.remove();
        _toastEntry = null;
      }
    });
  }

  void _copyCommentText(String text) {
    if (text.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: text.trim()));
    _showCopyToast('คัดลอกข้อความแล้ว');
  }

  Future<void> _confirmDeleteComment(
    BuildContext context,
    Task task,
    Comment comment,
    TaskProvider taskProvider,
  ) async {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.stormyDarkSlate : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.accentRed.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: AppColors.accentRed,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              'ลบความคิดเห็น?',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        content: Text(
          'คุณต้องการลบความคิดเห็นนี้ใช่หรือไม่ ข้อความหรือไฟล์แนบนี้จะถูกลบออกจากทุกคนในกลุ่มทันที',
          style: TextStyle(
            color: isDark
                ? AppColors.stormyIceBlue
                : theme.colorScheme.onSurface.withValues(alpha: 0.82),
            fontSize: 14,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: isDark
                  ? AppColors.stormySkyBlue
                  : AppColors.textSecondary,
            ),
            child: const Text('ยกเลิก'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor: isDark
                  ? AppColors.stormyNightBackground
                  : Colors.white,
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

    if (confirmed == true) {
      await taskProvider.deleteComment(task.id, comment.id);
      _showCopyToast('ลบความคิดเห็นแล้ว');
    }
  }

  Widget _buildCommentItem(
    Comment comment,
    Task task,
    TaskProvider taskProvider,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final leaderId = taskProvider.leaderIdForTask(task);
    final isCommenterLeader = comment.userId == leaderId;

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;
    final canDelete =
        (currentUserId != null && currentUserId == comment.userId) ||
        (currentUserId != null && currentUserId == leaderId);

    final commenter = taskProvider.getUserById(comment.userId);
    final frameId = commenter?.equippedFrame ?? '';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        UserAvatarWithFrame(
          avatarUrl: comment.userAvatarUrl,
          frameId: frameId,
          fallbackName: comment.userName,
          size: AppConstants.avatarSmall,
        ),
        const SizedBox(width: AppConstants.paddingSmall),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(AppConstants.paddingMedium),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : (Theme.of(context).brightness == Brightness.light
                        ? AppColors.stormyOffWhite
                        : AppColors.backgroundLightGrey),
              borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
            ),
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
                            comment.userName,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (isCommenterLeader) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    (Theme.of(context).brightness ==
                                                Brightness.light
                                            ? AppColors.stormySkyBlue
                                            : AppColors.primaryPink)
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: AppColors.stormySkyBlue,
                                  width: 0.5,
                                ),
                              ),
                              child: Text(
                                'หัวหน้า',
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.stormySkyBlue,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          _formatCommentTime(comment.createdAt),
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? Colors.white54
                                : (Theme.of(context).brightness == Brightness.light
                                      ? AppColors.stormyMutedBlueGrey
                                      : AppColors.textLight),
                          ),
                        ),
                        if (comment.content.isNotEmpty) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _copyCommentText(comment.content),
                            child: Tooltip(
                              message: 'คัดลอกข้อความ',
                              child: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Icon(
                                  Icons.copy_rounded,
                                  size: 13,
                                  color: isDark
                                      ? Colors.white38
                                      : (Theme.of(context).brightness == Brightness.light
                                            ? AppColors.stormyMutedBlueGrey.withValues(alpha: 0.8)
                                            : AppColors.textLight),
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (canDelete) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () => _confirmDeleteComment(
                              context,
                              task,
                              comment,
                              taskProvider,
                            ),
                            child: Tooltip(
                              message: 'ลบความคิดเห็น',
                              child: Padding(
                                padding: const EdgeInsets.all(2.0),
                                child: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 14,
                                  color: isDark
                                      ? Colors.redAccent.withValues(alpha: 0.7)
                                      : AppColors.accentRed.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                if (comment.content.isNotEmpty)
                  _buildLinkifiedText(
                    comment.content,
                    TextStyle(
                      fontSize: 13,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                if (comment.attachments.isNotEmpty) ...[
                  if (comment.content.isNotEmpty) const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: comment.attachments.map((attachment) {
                      final isImage = _isImageAttachment(attachment);
                      return GestureDetector(
                        onTap: () {
                          if (isImage) {
                            _showImagePreviewDialog(
                              context,
                              attachment.fileUrl,
                              attachment.fileName,
                            );
                          } else {
                            _showDocumentDetailsDialog(
                              context,
                              attachment.fileUrl,
                              attachment.fileName,
                              attachment.fileType,
                            );
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : (Theme.of(context).brightness ==
                                            Brightness.light
                                        ? AppColors.stormyOffWhite
                                        : AppColors.backgroundLightGrey),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (isImage)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.network(
                                    attachment.fileUrl,
                                    width: 24,
                                    height: 24,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) => Icon(
                                          Icons.image,
                                          size: 20,
                                          color: AppColors.stormySkyBlue,
                                        ),
                                  ),
                                )
                              else
                                Icon(
                                  attachment.fileType.toLowerCase() == 'pdf'
                                      ? Icons.picture_as_pdf_outlined
                                      : Icons.insert_drive_file_outlined,
                                  size: 20,
                                  color:
                                      attachment.fileType.toLowerCase() == 'pdf'
                                      ? AppColors.accentRed
                                      : (Theme.of(context).brightness ==
                                                Brightness.light
                                            ? AppColors.stormySkyBlue
                                            : AppColors.primaryBlue),
                                ),
                              const SizedBox(width: 6),
                              ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 150,
                                ),
                                child: Text(
                                  attachment.fileName,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: theme.colorScheme.onSurface,
                                    decoration: TextDecoration.underline,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _addComment(
    Task task,
    TaskProvider taskProvider, {
    VoidCallback? onCommentSent,
    VoidCallback? onComposerChanged,
  }) {
    if (task.isDeleted || (task.isGroup && task.isCompleted)) {
      return;
    }

    final trimmedText = _commentController.text.trim();
    if (trimmedText.isEmpty && _commentAttachments.isEmpty) {
      return;
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final user = authProvider.currentUser;
    if (user == null) return;

    final now = DateTime.now();
    final List<Comment> commentsToSend = [];

    if (trimmedText.isNotEmpty && _commentAttachments.isNotEmpty) {
      // 💥 แยกส่งข้อความและไฟล์แนบออกจากกัน เพื่อให้เลือกลบเฉพาะจุดได้
      // คอมเมนต์ที่ 1: เฉพาะข้อความ
      commentsToSend.add(
        Comment(
          id: 'comment_${now.millisecondsSinceEpoch}_text',
          userId: user.id,
          userName: user.name,
          userAvatarUrl: user.avatarUrl,
          content: trimmedText,
          createdAt: now,
          attachments: const [],
        ),
      );
      // คอมเมนต์ที่ 2+: สำหรับไฟล์แนบแต่ละไฟล์
      for (int i = 0; i < _commentAttachments.length; i++) {
        commentsToSend.add(
          Comment(
            id: 'comment_${now.millisecondsSinceEpoch + i + 1}_attachment',
            userId: user.id,
            userName: user.name,
            userAvatarUrl: user.avatarUrl,
            content: '',
            createdAt: now.add(Duration(milliseconds: i + 10)),
            attachments: [_commentAttachments[i]],
          ),
        );
      }
    } else if (trimmedText.isNotEmpty) {
      // เฉพาะข้อความ
      commentsToSend.add(
        Comment(
          id: 'comment_${now.millisecondsSinceEpoch}',
          userId: user.id,
          userName: user.name,
          userAvatarUrl: user.avatarUrl,
          content: trimmedText,
          createdAt: now,
          attachments: const [],
        ),
      );
    } else {
      // เฉพาะไฟล์แนบ (แยกการ์ดละไฟล์ เพื่อให้เลือกลบเฉพาะไฟล์ที่ต้องการได้)
      for (int i = 0; i < _commentAttachments.length; i++) {
        commentsToSend.add(
          Comment(
            id: 'comment_${now.millisecondsSinceEpoch + i}_attachment',
            userId: user.id,
            userName: user.name,
            userAvatarUrl: user.avatarUrl,
            content: '',
            createdAt: now.add(Duration(milliseconds: i)),
            attachments: [_commentAttachments[i]],
          ),
        );
      }
    }

    taskProvider.addMultipleComments(task.id, commentsToSend);
    _commentController.clear();
    setState(() {
      _commentAttachments.clear();
    });
    onComposerChanged?.call();
    onCommentSent?.call();
  }

  Future<void> _pickCommentAttachment(
    String taskId,
    TaskProvider taskProvider, {
    VoidCallback? onComposerChanged,
  }) async {
    final connectivity = context.read<ConnectivityProvider>();
    if (connectivity.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่มีการเชื่อมต่ออินเทอร์เน็ต ไม่สามารถดำเนินการได้'),
        ),
      );
      return;
    }
    setState(() {
      _isUploadingCommentAttachment = true;
    });
    onComposerChanged?.call();

    try {
      final attachmentMap = await taskProvider.uploadCommentAttachment(taskId);
      if (attachmentMap != null && mounted) {
        setState(() {
          _commentAttachments.add(TaskAttachment.fromMap(attachmentMap));
        });
        onComposerChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        final errorMsg = e.toString().contains('FILE_TOO_LARGE')
            ? 'ไฟล์มีขนาดใหญ่เกินไป! อนุญาตสูงสุด 10MB ต่อไฟล์เท่านั้น'
            : 'เกิดข้อผิดพลาดในการอัปโหลดไฟล์';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMsg), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingCommentAttachment = false;
        });
        onComposerChanged?.call();
      }
    }
  }

  Widget _buildLinkifiedText(
    String text,
    TextStyle baseStyle, {
    TextAlign textAlign = TextAlign.start,
  }) {
    final urlRegex = RegExp(r'(https?:\/\/[^\s]+)', caseSensitive: false);

    final matches = urlRegex.allMatches(text);
    if (matches.isEmpty) {
      return SelectableText(
        text,
        style: baseStyle,
        textAlign: textAlign,
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      );
    }

    final List<InlineSpan> spans = [];
    int lastIndex = 0;

    for (final match in matches) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: text.substring(lastIndex, match.start),
            style: baseStyle,
          ),
        );
      }

      final url = match.group(0)!;
      spans.add(
        TextSpan(
          text: url,
          style: baseStyle.copyWith(
            color: (Theme.of(context).brightness == Brightness.light
                ? AppColors.stormySkyBlue
                : AppColors.primaryBlue),
            decoration: TextDecoration.underline,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () async {
              final uri = Uri.tryParse(url);
              if (uri != null) {
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (e) {
                  debugPrint('Error launching linkified URL: $e');
                }
              }
            },
        ),
      );

      lastIndex = match.end;
    }

    if (lastIndex < text.length) {
      spans.add(TextSpan(text: text.substring(lastIndex), style: baseStyle));
    }

    return SelectableText.rich(
      TextSpan(children: spans),
      textAlign: textAlign,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
    );
  }

  Task? _latestTaskFromProvider(TaskProvider taskProvider, String taskId) {
    try {
      return taskProvider.tasks.firstWhere((task) => task.id == taskId);
    } catch (_) {
      return taskProvider.selectedTask?.id == taskId
          ? taskProvider.selectedTask
          : null;
    }
  }

  Future<void> _completeTaskAsLeader(
    Task task,
    TaskProvider taskProvider, {
    bool closeDetailScreen = true,
  }) async {
    final connectivity = context.read<ConnectivityProvider>();
    if (connectivity.isOffline) {
      _showOfflineDialog(context);
      return;
    }

    final latestTask = taskProvider.tasks.firstWhere(
      (t) => t.id == task.id,
      orElse: () => task,
    );
    if (latestTask.subtasks.isNotEmpty &&
        latestTask.subtasks.any((s) => !s.isDone)) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('ไม่สามารถเสร็จสิ้นภารกิจได้'),
          content: const Text(
            'กรุณาทำภารกิจย่อยทั้งหมดให้เสร็จสิ้นก่อนทำการปิดภารกิจหลัก',
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16.0),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.stormySkyBlue,
                foregroundColor: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.stormyNightBackground
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.0),
                ),
              ),
              child: const Text('ตกลง'),
            ),
          ],
        ),
      );
      return;
    }

    final isSoundEnabled =
        context.read<AuthProvider>().currentUser?.isSoundEnabled ?? true;
    final shouldProceed = await LatePenaltyDialog.checkAndShow(
      context,
      latestTask,
    );
    if (!shouldProceed) return;
    if (!mounted) return;

    unawaited(
      SoundService.instance.playTaskCompleteSound(
        isSoundEnabled: isSoundEnabled,
      ),
    );
    final result = await taskProvider.completeTaskWithSubtasks(
      latestTask.id,
      true,
    );
    if (!mounted) return;
    await FastCompletionWarningDialog.showCompletionFeedback(
      context,
      result,
    );

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
    if (closeDetailScreen && mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _checkAndShowAllMembersApprovedDialog(
    Task task,
    TaskProvider taskProvider,
  ) async {
    if (!mounted) return;

    final currentUserId = context.read<AuthProvider>().currentUser?.id;
    final latestTask =
        _latestTaskFromProvider(taskProvider, task.id) ?? task;

    if (!latestTask.isGroup && latestTask.members.isEmpty) return;
    if (latestTask.isCompleted || latestTask.isDeleted) return;

    final isLeader = taskProvider.isLeaderForTask(latestTask, currentUserId);
    if (!isLeader) return;

    final leaderId = taskProvider.leaderIdForTask(latestTask);
    if (!_areAllMembersCompleted(latestTask, leaderId)) return;

    final prefs = await SharedPreferences.getInstance();
    final hasSeen =
        prefs.getBool('has_seen_all_members_approved_dialog') ?? false;
    if (hasSeen) return;

    if (!mounted) return;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final theme = Theme.of(dialogContext);
        final isDark = theme.brightness == Brightness.dark;

        return AlertDialog(
          backgroundColor: isDark
              ? AppColors.stormyDarkSlate
              : theme.colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(
                Icons.task_alt_rounded,
                color: AppColors.primaryGreen,
                size: 26,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'อนุมัติงานครบทุกคนแล้ว',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
              ),
            ],
          ),
          content: Text(
            'เนื่องจากคุณอนุมัติงานสมาชิกทุกคนแล้ว ต้องการกดเสร็จสิ้นเพื่อปิดงานนี้เลยหรือไม่? ซึ่งคุณสามารถกดปุ่มเสร็จสิ้นได้ในปุ่มสามจุดมุมขวาบนในหน้านี้ทีหลังได้',
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: isDark
                  ? AppColors.stormyIceBlue
                  : theme.colorScheme.onSurface.withValues(alpha: 0.85),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              style: TextButton.styleFrom(
                foregroundColor: isDark
                    ? AppColors.stormySkyBlue
                    : AppColors.textSecondary,
              ),
              child: const Text('ยังก่อน'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(
                backgroundColor: AppColors.primaryGreen,
                foregroundColor: isDark
                    ? AppColors.stormyNightBackground
                    : Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'เสร็จสิ้น',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );

    if (result == true) {
      if (!mounted) return;
      await _completeTaskAsLeader(
        latestTask,
        taskProvider,
        closeDetailScreen: true,
      );
    }
  }

  Future<void> _openEditTaskModal(BuildContext context, Task task) async {
    await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateTaskModal(task: task),
    );
  }

  void _showOptionsMenu(BuildContext context, Task task, {bool isLeader = true}) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? AppColors.stormyDarkSlate
              : theme.cardColor,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppConstants.radiusXLarge),
            topRight: Radius.circular(AppConstants.radiusXLarge),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: theme.brightness == Brightness.light
                    ? (Theme.of(context).brightness == Brightness.light
                          ? AppColors.stormyMutedBlueGrey
                          : AppColors.backgroundDarkGrey)
                    : Colors.grey[800],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (isLeader && !task.isDeleted)
              ListTile(
                leading: Icon(
                  Icons.edit_outlined,
                  color: (Theme.of(context).brightness == Brightness.light
                      ? AppColors.stormySkyBlue
                      : AppColors.primaryBlue),
                ),
                title: Text('แก้ไขภารกิจ', style: TextStyle(color: onSurface)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openEditTaskModal(context, task);
                },
              ),
            if (isLeader)
              ListTile(
              leading: Icon(
                task.isDeleted
                    ? Icons.restore
                    : (task.isCompleted
                          ? Icons.undo
                          : Icons.check_circle_outline),
                color: task.isDeleted
                    ? onSurface
                    : (task.isCompleted
                          ? AppColors.warning
                          : AppColors.success),
              ),
              title: Text(
                task.isDeleted
                    ? (task.isCompleted ? 'เลิกทำเสร็จสิ้น' : 'คืนค่า')
                    : (task.isCompleted ? 'เลิกทำเสร็จสิ้น' : 'ทำว่าเสร็จสิ้น'),
                style: TextStyle(color: onSurface),
              ),
              onTap: () async {
                final connectivity = context.read<ConnectivityProvider>();
                if (connectivity.isOffline) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'ไม่มีการเชื่อมต่ออินเทอร์เน็ต ไม่สามารถดำเนินการได้',
                      ),
                    ),
                  );
                  Navigator.pop(sheetContext);
                  return;
                }
                final taskProvider = Provider.of<TaskProvider>(
                  context,
                  listen: false,
                );
                if (task.isDeleted) {
                  taskProvider.restoreTask(task.id);
                  Navigator.pop(sheetContext);
                  Navigator.pop(context);
                } else {
                  if (!task.isCompleted) {
                    final isLeader = taskProvider.isLeaderForTask(
                      task,
                      context.read<AuthProvider>().currentUser?.id,
                    );
                    if (isLeader &&
                        (task.type == TaskType.group ||
                            task.members.isNotEmpty)) {
                      final leaderId = taskProvider.leaderIdForTask(task);
                      if (!_areAllMembersCompleted(task, leaderId)) {
                        Navigator.pop(sheetContext);
                        _showIncompleteMembersAlert(context, task, leaderId);
                        return;
                      }
                    }

                    Navigator.pop(sheetContext);
                    await _completeTaskAsLeader(
                      task,
                      taskProvider,
                      closeDetailScreen: false,
                    );
                  } else {
                    await taskProvider.toggleTaskCompletion(
                      task.id,
                      updateSubtasks: true,
                    );
                    if (!mounted || !sheetContext.mounted) return;
                    Navigator.pop(sheetContext);
                    Navigator.pop(context);
                  }
                }
              },
            ),
            ListTile(
              leading: Icon(
                task.isDeleted ? Icons.delete_forever : Icons.delete_outline,
                color: AppColors.error,
              ),
              title: Text(
                task.isDeleted ? 'ลบถาวร' : 'ส่งไปที่ถังขยะ',
                style: const TextStyle(color: AppColors.error),
              ),
              onTap: () {
                Navigator.pop(sheetContext);
                if (task.isDeleted) {
                  _showPermanentDeleteConfirmation(task);
                } else {
                  _showDeleteConfirmation(task, isLeader: isLeader);
                }
              },
            ),
            const SizedBox(height: AppConstants.paddingLarge),
          ],
        ),
      ),
    );
  }

  void _showPermanentDeleteConfirmation(Task task) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'ลบถาวร',
          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
        ),
        content: Text(
          'คุณแน่ใจหรือไม่ว่าต้องการลบภารกิจ "${task.title}" ถาวร? การดำเนินการนี้ไม่สามารถย้อนกลับได้',
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
                Navigator.pop(dialogContext);
                return;
              }
              final taskProvider = Provider.of<TaskProvider>(
                context,
                listen: false,
              );
              taskProvider.permanentlyDeleteTask(task.id);
              Navigator.pop(dialogContext); // Close dialog
              Navigator.pop(context); // Pop TaskDetailScreen
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
              'ลบ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(Task task, {bool isLeader = true}) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : Theme.of(context).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'ยืนยันการลบภารกิจ',
          style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold),
        ),
        content: Text(
          task.isGroup && !isLeader
              ? 'คุณแน่ใจหรือไม่ว่าต้องการลบภารกิจกลุ่มนี้ออกจากรายการของคุณ?\n\n(การลบนี้จะมีผลเฉพาะกับคุณเท่านั้น โดยไม่ส่งผลกระทบต่อกลุ่มหรือสมาชิกคนอื่น)'
              : 'คุณแน่ใจหรือไม่ว่าต้องการลบภารกิจ "${task.title}"? การดำเนินการนี้จะส่งงานไปที่ถังขยะและสามารถกู้คืนได้ภายหลัง',
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
              final taskProvider = Provider.of<TaskProvider>(
                context,
                listen: false,
              );

              // 1. เก็บ NavigatorState ไว้ก่อนที่ context จะถูกทำลาย
              final rootNavigator = Navigator.of(this.context);

              // 2. แสดง SnackBar ก่อนที่จะ Pop หน้าจอ
              SnackBarUtils.showNavigationSnackBar(
                this.context,
                message: 'ย้ายไปยังถังขยะแล้ว',
                actionLabel: 'ดูถังขยะ',
                onNavigate: () {
                  // ใช้ rootNavigator ที่เก็บไว้เพื่อ push ไปหน้าถังขยะ
                  rootNavigator.push(
                    MaterialPageRoute(builder: (ctx) => const BinScreen()),
                  );
                },
              );

              // 3. ลบภารกิจและ Pop หน้าต่างต่างๆ
              taskProvider.deleteTask(task.id);
              Navigator.pop(context); // ปิด Dialog
              rootNavigator.pop(); // ปิดหน้า TaskDetailScreen
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
              'ยืนยันการลบ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return thaiDateTime(dateTime);
  }

  String _formatCommentTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'เมื่อสักครู่';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} นาทีที่แล้ว';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ชม.ที่แล้ว';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} วันที่แล้ว';
    } else {
      return thaiShortDate(dateTime);
    }
  }

  Widget _buildAttachmentsSection(
    Task task,
    TaskProvider taskProvider, {
    Member? myMember,
  }) {
    // สำหรับภารกิจกลุ่ม: หน้าสมาชิกเมื่อยังไม่ได้ส่งงาน (กำลังทำ/โดนปฏิเสธ/ส่งกลับไปแก้ไข)
    // ไฟล์แนบจะแสดงเฉพาะในช่องส่งงานด้านบนเท่านั้น
    // ไฟล์แนบข้างล่างจะแสดงก็ต่อเมื่อกดส่งงานไปแล้ว (status == 'pending' หรือ 'completed')
    if (task.isGroup) {
      final isSubmitted = myMember != null &&
          (myMember.status == 'pending' || myMember.status == 'completed');
      if (!isSubmitted) {
        return const SizedBox.shrink();
      }
    }

    final List<TaskAttachment> displayAttachments;
    if (task.isGroup) {
      if (myMember != null && myMember.attachments.isNotEmpty) {
        displayAttachments = myMember.attachments;
      } else if (task.submittedBy == myMember?.id && task.attachments.isNotEmpty) {
        displayAttachments = task.attachments;
      } else {
        displayAttachments = myMember?.attachments ?? task.attachments;
      }
    } else {
      displayAttachments = task.attachments;
    }

    if (displayAttachments.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppConstants.paddingMedium,
        vertical: AppConstants.paddingSmall,
      ),
      padding: const EdgeInsets.all(AppConstants.paddingLarge),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : theme.cardColor,
        borderRadius: BorderRadius.circular(AppConstants.radiusXLarge),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withValues(alpha: 0.3)
                : AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      (Theme.of(context).brightness == Brightness.light
                              ? AppColors.stormySkyBlue
                              : AppColors.primaryBlue)
                          .withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.attach_file_rounded,
                  color: (Theme.of(context).brightness == Brightness.light
                      ? AppColors.stormySkyBlue
                      : AppColors.primaryBlue),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'ไฟล์แนบ (${displayAttachments.length})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppConstants.paddingMedium),
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: displayAttachments.length,
            itemBuilder: (context, index) {
              final attachment = displayAttachments[index];
              return _buildAttachmentTile(
                attachment,
                task,
                taskProvider,
                showDelete: myMember != null && myMember.status == 'inProgress',
                onDelete: () async {
                  if (myMember != null) {
                    await taskProvider.deleteMemberAttachment(
                      task.id,
                      myMember.id,
                      attachment,
                    );
                  } else {
                    await taskProvider.deleteTaskAttachment(
                      task.id,
                      attachment,
                    );
                  }
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAttachmentTile(
    TaskAttachment attachment,
    Task task,
    TaskProvider taskProvider, {
    VoidCallback? onDelete,
    bool? showDelete,
  }) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final type = attachment.fileType.toLowerCase();
    final isImage = ['png', 'jpg', 'jpeg', 'webp', 'gif'].contains(type);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;
    final isLeader = taskProvider.isLeaderForTask(task, currentUserId);
    final showDeleteButton =
        showDelete ??
        (!task.isDeleted &&
            !isLeader &&
            (task.status == TaskStatus.todo ||
                task.status == TaskStatus.inProgress));

    if (isImage) {
      return GestureDetector(
        onTap: () => _showImagePreviewDialog(
          context,
          attachment.fileUrl,
          attachment.fileName,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 60,
                  height: 60,
                  color: isDark ? Colors.grey[900] : Colors.grey[200],
                  child: Image.network(
                    attachment.fileUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(
                        Icons.image_not_supported_outlined,
                        color: Colors.grey,
                      );
                    },
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(
                        child: SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.stormySkyBlue,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.fileName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'รูปภาพ • แตะเพื่อดูไฟล์',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: (Theme.of(context).brightness == Brightness.light
                    ? AppColors.stormySkyBlue
                    : AppColors.primaryBlue),
              ),
              if (showDeleteButton) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    if (onDelete != null) {
                      _confirmAndDeleteCustom(attachment, onDelete);
                    } else {
                      _deleteAttachment(task, attachment, taskProvider);
                    }
                  },
                  child: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.accentRed,
                  ),
                ),
              ],
              const SizedBox(width: 4),
            ],
          ),
        ),
      );
    } else {
      IconData docIcon;
      Color iconBgColor;
      Color iconColor;

      if (['pdf'].contains(type)) {
        docIcon = Icons.picture_as_pdf_rounded;
        iconColor = const Color(0xFFEF4444);
        iconBgColor = const Color(0xFFFEE2E2);
      } else if (['xlsx', 'xls'].contains(type)) {
        docIcon = Icons.table_chart_rounded;
        iconColor = const Color(0xFF10B981);
        iconBgColor = const Color(0xFFD1FAE5);
      } else if (['docx', 'doc'].contains(type)) {
        docIcon = Icons.description_rounded;
        iconColor = const Color(0xFF3B82F6);
        iconBgColor = const Color(0xFFDBEAFE);
      } else {
        docIcon = Icons.insert_drive_file_rounded;
        iconColor = const Color(0xFF6B7280);
        iconBgColor = const Color(0xFFF3F4F6);
      }

      return GestureDetector(
        onTap: () => _showDocumentDetailsDialog(
          context,
          attachment.fileUrl,
          attachment.fileName,
          type,
        ),
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.04)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: theme.dividerColor.withValues(alpha: 0.15),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(docIcon, color: iconColor, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      attachment.fileName,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${type.toUpperCase()} เอกสาร • แตะเพื่อดูไฟล์',
                      style: TextStyle(
                        fontSize: 12,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.55,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.open_in_new_rounded,
                size: 18,
                color: (Theme.of(context).brightness == Brightness.light
                    ? AppColors.stormySkyBlue
                    : AppColors.primaryBlue),
              ),
              if (showDeleteButton) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    if (onDelete != null) {
                      _confirmAndDeleteCustom(attachment, onDelete);
                    } else {
                      _deleteAttachment(task, attachment, taskProvider);
                    }
                  },
                  child: const Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: AppColors.accentRed,
                  ),
                ),
              ],
              const SizedBox(width: 4),
            ],
          ),
        ),
      );
    }
  }

  Future<void> _confirmAndDeleteCustom(
    TaskAttachment attachment,
    VoidCallback onDelete,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        ),
        title: const Text('ลบไฟล์แนบ?'),
        content: Text(
          'คุณต้องการลบไฟล์ "${attachment.fileName}" ใช่หรือไม่? ไฟล์นี้จะถูกลบออกจากภารกิจนี้ถาวร',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ย้อนกลับ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor:
                  Theme.of(context).brightness == Brightness.dark
                      ? AppColors.stormyNightBackground
                      : Colors.white,
            ),
            child: const Text('ลบไฟล์'),
          ),
        ],
      ),
    );

    if (confirm != true) return;
    if (!mounted) return;

    // ignore: use_build_context_synchronously
    final connectivity = context.read<ConnectivityProvider>();
    if (connectivity.isOffline) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่มีการเชื่อมต่ออินเทอร์เน็ต ไม่สามารถดำเนินการได้'),
        ),
      );
      return;
    }

    onDelete();
  }

  Future<void> _deleteAttachment(
    Task task,
    TaskAttachment attachment,
    TaskProvider taskProvider,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radiusLarge),
        ),
        title: const Text('ลบไฟล์แนบ?'),
        content: Text(
          'คุณต้องการลบไฟล์ "${attachment.fileName}" ใช่หรือไม่? ไฟล์นี้จะถูกลบออกจากภารกิจนี้ถาวร',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ย้อนกลับ'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor:
                  Theme.of(context).brightness == Brightness.dark
                      ? AppColors.stormyNightBackground
                      : Colors.white,
            ),
            child: const Text('ลบไฟล์'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // ignore: use_build_context_synchronously
    final connectivity = context.read<ConnectivityProvider>();
    if (connectivity.isOffline) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่มีการเชื่อมต่ออินเทอร์เน็ต ไม่สามารถดำเนินการได้'),
        ),
      );
      return;
    }

    await taskProvider.deleteTaskAttachment(task.id, attachment);
  }

  Future<void> _saveImageToGallery(String imageUrl, String fileName) async {
    try {
      final uri = Uri.tryParse(imageUrl);
      if (uri == null) {
        _showCopyToast('ลิงก์รูปภาพไม่ถูกต้อง', isError: true);
        return;
      }

      final response = await http.get(uri).timeout(
        const Duration(seconds: 15),
        onTimeout: () => throw TimeoutException('ดาวน์โหลดรูปภาพนานเกินไป'),
      );

      if (response.statusCode != 200) {
        _showCopyToast(
          'เซิร์ฟเวอร์ตอบกลับรหัส (${response.statusCode})',
          isError: true,
        );
        return;
      }

      final bytes = response.bodyBytes;
      if (bytes.isEmpty) {
        _showCopyToast('ไม่พบข้อมูลไฟล์รูปภาพ', isError: true);
        return;
      }

      String cleanName = fileName.isNotEmpty
          ? fileName.replaceAll(RegExp(r'[^\w\.-]'), '_')
          : 'image_${DateTime.now().millisecondsSinceEpoch}';
      if (!cleanName.toLowerCase().endsWith('.jpg') &&
          !cleanName.toLowerCase().endsWith('.jpeg') &&
          !cleanName.toLowerCase().endsWith('.png') &&
          !cleanName.toLowerCase().endsWith('.webp') &&
          !cleanName.toLowerCase().endsWith('.gif')) {
        cleanName = '$cleanName.jpg';
      }

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (launched) {
          _showCopyToast('เปิดดาวน์โหลดรูปภาพผ่านเบราว์เซอร์แล้ว');
        } else {
          _showCopyToast('ไม่สามารถเปิดเบราว์เซอร์เพื่อดาวน์โหลดได้', isError: true);
        }
        return;
      }

      final hasAccess = await Gal.hasAccess();
      if (!hasAccess) {
        final granted = await Gal.requestAccess();
        if (!granted) {
          _showCopyToast('ไม่ได้รับอนุญาตให้เข้าถึงคลังรูปภาพ กรุณาเปิดสิทธิ์ในตั้งค่า', isError: true);
          return;
        }
      }

      await Gal.putImageBytes(
        bytes,
        name: cleanName,
      );
      _showCopyToast('บันทึกรูปภาพลงคลังภาพเรียบร้อยแล้ว');
    } on GalException catch (e) {
      debugPrint('GalException: ${e.type.message}');
      switch (e.type) {
        case GalExceptionType.accessDenied:
          _showCopyToast('ไม่ได้รับอนุญาตให้เข้าถึงคลังรูปภาพ', isError: true);
          break;
        case GalExceptionType.notEnoughSpace:
          _showCopyToast('พื้นที่จัดเก็บข้อมูลในเครื่องไม่เพียงพอ', isError: true);
          break;
        case GalExceptionType.notSupportedFormat:
          _showCopyToast('รูปแบบไฟล์ภาพไม่รองรับ', isError: true);
          break;
        default:
          _showCopyToast('ไม่สามารถบันทึกลงคลังภาพได้: ${e.type.message}', isError: true);
      }
    } on SocketException catch (_) {
      _showCopyToast('ไม่มีการเชื่อมต่ออินเทอร์เน็ต กรุณาตรวจสอบสัญญาณเน็ต', isError: true);
    } on TimeoutException catch (_) {
      _showCopyToast('หมดเวลาดาวน์โหลด กรุณาลองใหม่อีกครั้ง', isError: true);
    } on MissingPluginException catch (_) {
      final uri = Uri.tryParse(imageUrl);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        _showCopyToast('เปิดดาวน์โหลดรูปภาพผ่านเบราว์เซอร์แล้ว');
      } else {
        _showCopyToast('แพลตฟอร์มนี้ยังไม่รองรับการบันทึกลงคลังภาพ', isError: true);
      }
    } catch (e) {
      debugPrint('Error saving image: $e');
      final errorMsg = e.toString().replaceAll('Exception:', '').trim();
      _showCopyToast(
        'เกิดข้อผิดพลาด: ${errorMsg.length > 50 ? "${errorMsg.substring(0, 47)}..." : errorMsg}',
        isError: true,
      );
    }
  }

  void _showImagePreviewDialog(
    BuildContext context,
    String imageUrl,
    String fileName,
  ) {
    bool isSaving = false;
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        final media = MediaQuery.of(dialogContext);
        return StatefulBuilder(
          builder: (dialogContext, setDialogState) {
            return Dialog.fullscreen(
              backgroundColor: Colors.black,
              child: Stack(
                children: [
                  Positioned.fill(
                    child: InteractiveViewer(
                      panEnabled: true,
                      minScale: 0.8,
                      maxScale: 5.0,
                      child: Center(
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          width: media.size.width,
                          height: media.size.height,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              margin: const EdgeInsets.all(24),
                              padding: const EdgeInsets.all(24),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: AppColors.accentRed,
                                    size: 48,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'ไม่สามารถโหลดรูปภาพได้',
                                    style: TextStyle(
                                      color: Colors.black,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    top: media.padding.top + 12,
                    left: 16,
                    right: 16,
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            fileName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: Colors.white.withValues(alpha: 0.16),
                          child: isSaving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : IconButton(
                                  tooltip: 'บันทึกรูปภาพลงเครื่อง',
                                  icon: const Icon(
                                    Icons.download_rounded,
                                    color: Colors.white,
                                  ),
                                  onPressed: () async {
                                    setDialogState(() {
                                      isSaving = true;
                                    });
                                    await _saveImageToGallery(imageUrl, fileName);
                                    if (dialogContext.mounted) {
                                      setDialogState(() {
                                        isSaving = false;
                                      });
                                    }
                                  },
                                ),
                        ),
                        const SizedBox(width: 8),
                        CircleAvatar(
                          backgroundColor: Colors.white.withValues(alpha: 0.16),
                          child: IconButton(
                            tooltip: 'ปิด',
                            icon: const Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                            ),
                            onPressed: () => Navigator.pop(dialogContext),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: media.padding.bottom + 16,
                    child: IgnorePointer(
                      child: Text(
                        'บีบเพื่อซูม • ลากเพื่อเลื่อนภาพ',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDocumentDetailsDialog(
    BuildContext context,
    String fileUrl,
    String fileName,
    String fileType,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Row(
            children: [
              Icon(
                Icons.insert_drive_file,
                color: (Theme.of(context).brightness == Brightness.light
                    ? AppColors.stormySkyBlue
                    : AppColors.primaryBlue),
              ),
              const SizedBox(width: 10),
              const Text('รายละเอียดไฟล์เอกสาร'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ชื่อไฟล์: $fileName',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('ประเภทไฟล์'),
              const SizedBox(height: 16),
              const Text(
                'เนื่องจากเป็นไฟล์เอกสาร ระบบจะเปิดไฟล์นี้ผ่านเว็บเบราว์เซอร์ของระบบเพื่อให้ท่านดาวน์โหลดหรือเปิดดูโดยละเอียด',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('ปิด'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                _launchURL(fileUrl);
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('เปิดในบราวเซอร์'),
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    (Theme.of(context).brightness == Brightness.light
                    ? AppColors.stormySkyBlue
                    : AppColors.primaryBlue),
                foregroundColor:
                    Theme.of(context).brightness == Brightness.dark
                        ? AppColors.stormyNightBackground
                        : Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  void _showRejectTaskSubmissionDialog(Task task) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.stormyDarkSlate : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFFFF6B6B) : AppColors.accentRed)
                    .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cancel_outlined,
                color: isDark ? const Color(0xFFFF6B6B) : AppColors.accentRed,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'ปฏิเสธงานที่ส่งมา',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'คุณต้องการปฏิเสธงานที่ส่งมาและส่งกลับไปให้แก้ไขใช่หรือไม่?',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'ยกเลิก',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final connectivity = context.read<ConnectivityProvider>();
              if (connectivity.isOffline) {
                _showOfflineDialog(context);
                return;
              }
              final taskProvider =
                  Provider.of<TaskProvider>(context, listen: false);
              await taskProvider.rejectTaskSubmission(task.id);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('ปฏิเสธงานแล้ว'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDark ? const Color(0xFFFF6B6B) : AppColors.accentRed,
              foregroundColor:
                  isDark ? AppColors.stormyNightBackground : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'ยืนยันปฏิเสธ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showRejectMemberSubmissionDialog(Task task, Member member) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.stormyDarkSlate : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: (isDark ? const Color(0xFFFF6B6B) : AppColors.accentRed)
                    .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.cancel_outlined,
                color: isDark ? const Color(0xFFFF6B6B) : AppColors.accentRed,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'ปฏิเสธงานที่ส่งมา',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'ต้องการปฏิเสธงานของ "${member.name}" และส่งกลับไปให้แก้ไขใช่หรือไม่?',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'ยกเลิก',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final connectivity = context.read<ConnectivityProvider>();
              if (connectivity.isOffline) {
                _showOfflineDialog(context);
                return;
              }
              final taskProvider =
                  Provider.of<TaskProvider>(context, listen: false);
              await taskProvider.rejectMemberTaskSubmission(
                task.id,
                member.id,
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('ปฏิเสธงานของ "${member.name}" แล้ว'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDark ? const Color(0xFFFF6B6B) : AppColors.accentRed,
              foregroundColor:
                  isDark ? AppColors.stormyNightBackground : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'ยืนยันปฏิเสธ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showRevertApprovalDialog(Task task, Member member) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark ? AppColors.stormyDarkSlate : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color:
                    (isDark ? const Color(0xFFFFB74D) : const Color(0xFFD97706))
                        .withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.replay_rounded,
                color:
                    isDark ? const Color(0xFFFFB74D) : const Color(0xFFD97706),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'ส่งงานกลับไปแก้ไข',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        content: Text(
          'คุณต้องการยกเลิกการอนุมัติและส่งงานของ "${member.name}" กลับไปแก้ไขใช่หรือไม่?\n\n(ระบบจะเปลี่ยนสถานะเป็นกำลังทำภารกิจ และเรียกคืนคะแนนที่สมาชิกได้รับ)',
          style: TextStyle(
            fontSize: 14,
            height: 1.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              'ยกเลิก',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              final connectivity = context.read<ConnectivityProvider>();
              if (connectivity.isOffline) {
                _showOfflineDialog(context);
                return;
              }
              final taskProvider =
                  Provider.of<TaskProvider>(context, listen: false);
              await taskProvider.rejectMemberTaskSubmission(
                task.id,
                member.id,
              );
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('ส่งงานของ "${member.name}" กลับไปแก้ไขแล้ว'),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  isDark ? const Color(0xFFFFB74D) : const Color(0xFFD97706),
              foregroundColor: isDark ? Colors.black : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text(
              'ยืนยันส่งกลับ',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showOfflineDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ไม่มีการเชื่อมต่ออินเทอร์เน็ต'),
        content: const Text('กรุณาเชื่อมต่ออินเทอร์เน็ตเพื่อดำเนินการนี้'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.stormySkyBlue,
              foregroundColor:
                  Theme.of(context).brightness == Brightness.dark
                      ? AppColors.stormyNightBackground
                      : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
            child: const Text('ตกลง'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('ไม่สามารถเปิดลิงก์ได้')));
      }
    }
  }
}

/// Data class สำหรับเก็บข้อมูลสถานะสมาชิก (label, สี)
class _MemberStatusInfo {
  final String label;
  final Color textColor;
  final Color backgroundColor;

  const _MemberStatusInfo({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
  });
}
