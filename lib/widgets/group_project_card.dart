import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../services/sound_service.dart';
import '../config/colors.dart';
import '../screens/task_detail_screen.dart';
import 'create_task_modal.dart';
import 'fast_completion_warning_dialog.dart';
import '../utils/snack_bar_utils.dart';
import '../screens/bin_screen.dart';
import '../providers/connectivity_provider.dart';
import '../config/constants.dart';
import '../utils/responsive.dart';

class GroupProjectCard extends StatelessWidget {
  final Task project;
  final Function(String) onDelete;
  final Function(Task)? onToggleComplete;
  final bool? isCompletedOverride;
  final bool isOverdue;

  const GroupProjectCard({
    super.key,
    required this.project,
    required this.onDelete,
    this.onToggleComplete,
    this.isCompletedOverride,
    this.isOverdue = false,
  });

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final theme = Theme.of(context);
    final isLeader = taskProvider.isLeaderForTask(
      project,
      authProvider.currentUser?.id,
    );
    final isCompleted = isCompletedOverride ?? project.isCompleted;
    final areAllCompleted = taskProvider.areAllGroupMembersCompleted(project);
    final canMemberDelete = !isLeader && (isCompleted || areAllCompleted);
    final canShowCompleteToggle = isLeader && (isCompleted || areAllCompleted);
    final isTablet = Responsive.isTablet(context);

    return GestureDetector(
      onTap: () async {
        taskProvider.selectTask(project);
        await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => TaskDetailScreen()),
        );
      },
      child: Container(
        margin: EdgeInsets.zero,
        padding: EdgeInsets.all(isTablet ? 24 : 20),
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? AppColors.stormyDarkSlate
              : theme.cardColor,
          borderRadius: BorderRadius.circular(25),
          boxShadow: [
            BoxShadow(
              color: theme.brightness == Brightness.dark
                  ? Colors.black.withValues(alpha: 0.3)
                  : theme.shadowColor.withValues(alpha: 0.08),
              blurRadius: 15,
              offset: const Offset(0, 5),
            ),
          ],
          border: theme.brightness == Brightness.dark
              ? null
              : Border.all(
                  color: isOverdue
                      ? Colors.redAccent
                      : theme.colorScheme.onSurface.withValues(alpha: 0.08),
                  width: isOverdue ? 1.5 : 1,
                ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isCompleted) ...[
              _buildCompletedBadge(context),
              const SizedBox(height: 12),
            ],

            // Title and Menu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          project.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isTablet ? 22 : 18,
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      if (isLeader) ...[
                        const SizedBox(width: 8),
                        _buildLeaderBadge(context),
                      ],
                    ],
                  ),
                ),
                if (isLeader || canMemberDelete)
                  PopupMenuButton<String>(
                    onSelected: (value) async {
                      switch (value) {
                        case 'edit':
                          await _openEditTaskModal(context);
                          break;
                        case 'toggle_complete':
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
                          if (!project.isCompleted) {
                            final leaderId =
                                taskProvider.leaderIdForTask(project);
                            final nonLeaderMembers = project.members
                                .where((m) => m.id != leaderId)
                                .toList();
                            final membersToCheck = nonLeaderMembers.isNotEmpty
                                ? nonLeaderMembers
                                : project.members;
                            final areAllCompleted = project.members.isEmpty
                                ? (project.status == TaskStatus.completed ||
                                    (project.submissionText != null &&
                                        project.submissionText!
                                            .trim()
                                            .isNotEmpty) ||
                                    project.attachments.isNotEmpty ||
                                    (project.submittedBy != null &&
                                        project.submittedBy!.isNotEmpty) ||
                                    project.status == TaskStatus.pending)
                                : membersToCheck
                                    .every((m) => m.status == 'completed');

                            if (!areAllCompleted) {
                              final isDark =
                                  Theme.of(context).brightness ==
                                  Brightness.dark;
                              final incompleteCount = membersToCheck
                                  .where((m) => m.status != 'completed')
                                  .length;
                              final pendingReviewCount = membersToCheck
                                  .where((m) => m.status == 'pending')
                                  .length;

                              String message;
                              if (project.members.isEmpty) {
                                message =
                                    'ยังไม่มีการส่งงานของสมาชิกเข้ามาในภารกิจนี้';
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
                                  backgroundColor: isDark
                                      ? AppColors.stormyDarkSlate
                                      : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20.0),
                                  ),
                                  title: Text(
                                    'ไม่สามารถเสร็จสิ้นภารกิจได้',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurface,
                                    ),
                                  ),
                                  content: Text(
                                    message,
                                    style: TextStyle(
                                      fontSize: 14,
                                      height: 1.5,
                                      color: isDark
                                          ? Colors.white.withValues(alpha: 0.85)
                                          : AppColors.stormyDarkSlate.withValues(
                                              alpha: 0.85,
                                            ),
                                    ),
                                  ),
                                  actions: [
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            AppColors.stormySkyBlue,
                                        foregroundColor: isDark
                                            ? AppColors.stormyNightBackground
                                            : Colors.white,
                                        elevation: 0,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                          vertical: 10,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(12.0),
                                        ),
                                      ),
                                      child: const Text(
                                        'ตกลง',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                              return;
                            }
                          }

                          if (onToggleComplete != null) {
                            onToggleComplete!(project);
                          } else {
                            if (!project.isCompleted) {
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

                              final taskProviderRef = context
                                  .read<TaskProvider>();
                              final result = await taskProviderRef
                                  .completeTaskWithSubtasks(project.id, true);
                              if (!context.mounted) return;
                              await FastCompletionWarningDialog.showCompletionFeedback(
                                context,
                                result,
                              );

                              if (!context.mounted) return;
                              SnackBarUtils.showUndoSnackBar(
                                context,
                                message: 'ทำเครื่องหมายเสร็จสิ้นแล้ว',
                                onUndo: () async {
                                  await taskProviderRef.toggleTaskCompletion(
                                    project.id,
                                    updateSubtasks: true,
                                  );
                                },
                              );
                            } else {
                              await context
                                  .read<TaskProvider>()
                                  .toggleTaskCompletion(
                                    project.id,
                                    updateSubtasks: true,
                                  );
                            }
                          }
                          break;
                        case 'delete':
                          _showDeleteConfirmation(context, isLeader: isLeader);
                          break;
                      }
                    },
                    icon: Icon(
                      Icons.more_vert,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                    itemBuilder: (context) => [
                      if (isLeader) ...[
                        const PopupMenuItem(
                          value: 'edit',
                          child: Row(
                            children: [
                              Icon(
                                Icons.edit_outlined,
                                color: AppColors.primaryBlue,
                                size: 20,
                              ),
                              SizedBox(width: 10),
                              Text('แก้ไขภารกิจ'),
                            ],
                          ),
                        ),
                        if (canShowCompleteToggle)
                          PopupMenuItem(
                            value: 'toggle_complete',
                            child: Row(
                              children: [
                                Icon(
                                  isCompleted
                                      ? Icons.undo
                                      : Icons.check_circle_outline,
                                  color: isCompleted
                                      ? AppColors.warning
                                      : AppColors.success,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  isCompleted ? 'ทำยังไม่เสร็จ' : 'ทำว่าเสร็จสิ้น',
                                ),
                              ],
                            ),
                          ),
                      ],
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline,
                              color: AppColors.accentRed,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'ลบภารกิจ',
                              style: TextStyle(color: AppColors.accentRed),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            // Description
            if (project.description.trim().isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                project.description,
                style: TextStyle(
                  fontSize: isTablet ? 15 : 14,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            if (project.subtasks.isNotEmpty) ...[
              const SizedBox(height: AppConstants.paddingSmall),
              Padding(
                padding: const EdgeInsets.only(
                  left: AppConstants.paddingSmall,
                ),
                child: _GroupInlineSubtasks(
                  project: project,
                  isLeader: isLeader,
                ),
              ),
            ],

            const SizedBox(height: 12),

            // Members and Progress Info
            () {
              final leaderId = taskProvider.leaderIdForTask(project);
              final nonLeaderMembers = project.members
                  .where((m) =>
                      m.id.isNotEmpty &&
                      m.id != leaderId &&
                      m.id != project.creatorId)
                  .toList();
              final completedNonLeaderCount = nonLeaderMembers
                  .where((m) => m.status == 'completed')
                  .length;
              final totalNonLeaderCount = nonLeaderMembers.length;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildMemberAvatars(context, taskProvider),
                      const Spacer(),
                      if (totalNonLeaderCount > 0)
                        Text(
                          'สมาชิกเสร็จสิ้น $completedNonLeaderCount/$totalNonLeaderCount คน',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        )
                      else
                        Text(
                          'ยังไม่มีสมาชิก',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          ),
                        ),
                    ],
                  ),
                  if (totalNonLeaderCount > 0) ...[
                    const SizedBox(height: 10),
                    // Member Progress Bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: completedNonLeaderCount / totalNonLeaderCount,
                        backgroundColor: theme.colorScheme.onSurface.withValues(
                          alpha: 0.08,
                        ),
                        valueColor: AlwaysStoppedAnimation<Color>(
                          nonLeaderMembers.every((m) => m.status == 'completed')
                              ? AppColors.success
                              : AppColors.stormySkyBlue,
                        ),
                        minHeight: 8,
                      ),
                    ),
                  ],
                ],
              );
            }(),
          ],
        ),
      ),
    );
  }



  Future<void> _openEditTaskModal(BuildContext context) async {
    await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateTaskModal(task: project),
    );
  }

  Widget _buildCompletedBadge(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.check_circle,
            size: 16,
            color: AppColors.primaryGreen,
          ),
          const SizedBox(width: 6),
          Text(
            'เสร็จสิ้น',
            style: theme.textTheme.labelMedium?.copyWith(
              color: AppColors.primaryGreen,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLeaderBadge(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.light
            ? theme.colorScheme.primary.withValues(alpha: 0.14)
            : AppColors.stormySkyBlue.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'หัวหน้า',
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.brightness == Brightness.light
              ? theme.colorScheme.primary
              : AppColors.stormySkyBlue,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildMemberAvatars(BuildContext context, TaskProvider taskProvider) {
    final memberIds = project.assigneeIds;
    final memberCount = memberIds.length;
    final displayCount = memberCount > 5 ? 5 : memberCount;
    final theme = Theme.of(context);
    // Calculate width to avoid unbounded layout in Row
    final stackWidth =
        (displayCount * 20.0) + 14.0 + (memberCount > 5 ? 20.0 : 0);

    if (memberCount == 0) return const SizedBox.shrink();

    return SizedBox(
      height: 32,
      width: stackWidth,
      child: Stack(
        children: [
          for (int i = 0; i < displayCount; i++)
            Positioned(
              left: i * 20.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 2,
                  ),
                ),
                child: Builder(
                  builder: (context) {
                    final user = taskProvider.getUserById(memberIds[i]);
                    return CircleAvatar(
                      radius: 14,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      backgroundImage:
                          user?.avatarUrl != null && user!.avatarUrl.isNotEmpty
                          ? NetworkImage(user.avatarUrl)
                          : null,
                      child:
                          (user?.avatarUrl == null || user!.avatarUrl.isEmpty)
                          ? Text(
                              user?.name[0] ?? '?',
                              style: TextStyle(
                                fontSize: 10,
                                color: theme.colorScheme.onSurface,
                              ),
                            )
                          : null,
                    );
                  },
                ),
              ),
            ),
          if (memberCount > 5)
            Positioned(
              left: 5 * 20.0,
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 2,
                  ),
                ),
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  child: Text(
                    '+${memberCount - 5}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext parentContext, {required bool isLeader}) {
    showDialog(
      context: parentContext,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Theme.of(parentContext).brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : Theme.of(parentContext).colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'ยืนยันการลบภารกิจ',
          style: TextStyle(
            color: AppColors.accentRed,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          isLeader
              ? 'คุณแน่ใจหรือไม่ว่าต้องการลบโครงการกลุ่มนี้โดยส่งไปที่ถังขยะ?'
              : 'คุณแน่ใจหรือไม่ว่าต้องการลบภารกิจกลุ่มนี้ออกจากรายการของคุณ?\n\n(การลบนี้จะมีผลเฉพาะกับคุณเท่านั้น โดยไม่ส่งผลกระทบต่อกลุ่มหรือสมาชิกคนอื่น)',
          style: TextStyle(
            color: Theme.of(parentContext).brightness == Brightness.dark
                ? AppColors.stormyIceBlue
                : Theme.of(
                    parentContext,
                  ).colorScheme.onSurface.withValues(alpha: 0.82),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            style: TextButton.styleFrom(
              foregroundColor:
                  Theme.of(parentContext).brightness == Brightness.dark
                  ? AppColors.stormySkyBlue
                  : AppColors.textSecondary,
            ),
            child: const Text('ยกเลิก'),
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
              onDelete(project.id);
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
}

class _GroupInlineSubtasks extends StatefulWidget {
  final Task project;
  final bool isLeader;

  const _GroupInlineSubtasks({
    required this.project,
    required this.isLeader,
  });

  @override
  State<_GroupInlineSubtasks> createState() => _GroupInlineSubtasksState();
}

class _GroupInlineSubtasksState extends State<_GroupInlineSubtasks> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final taskProvider = context.read<TaskProvider>();
    const maxInitial = 3;
    final subtasks = widget.project.subtasks;
    final hasMore = subtasks.length > maxInitial;
    final displayedEntries = _isExpanded
        ? subtasks.asMap().entries.toList()
        : subtasks.take(maxInitial).toList().asMap().entries.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final entry in displayedEntries)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: InkWell(
              enableFeedback: false,
              borderRadius: BorderRadius.circular(8),
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
                  return;
                }

                if (!widget.isLeader) {
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

                await taskProvider.toggleSubtask(widget.project.id, entry.key);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: entry.value.isDone
                          ? (theme.brightness == Brightness.dark
                              ? AppColors.stormySkyBlue
                              : theme.colorScheme.primary)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(
                        color: entry.value.isDone
                            ? (theme.brightness == Brightness.dark
                                ? AppColors.stormySkyBlue
                                : theme.colorScheme.primary)
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.22,
                              ),
                        width: 2,
                      ),
                    ),
                    child: entry.value.isDone
                        ? Icon(
                            Icons.check,
                            size: 12,
                            color: theme.brightness == Brightness.dark
                                ? AppColors.stormyNightBackground
                                : theme.colorScheme.onPrimary,
                          )
                        : null,
                  ),
                  const SizedBox(width: AppConstants.paddingSmall),
                  Flexible(
                    child: Text(
                      entry.value.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: entry.value.isDone
                            ? theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              )
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.75,
                              ),
                        decoration: entry.value.isDone
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                  if (!widget.isLeader)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Icon(
                        Icons.lock_outline_rounded,
                        size: 13,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.3,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (hasMore)
          InkWell(
            onTap: () {
              setState(() {
                _isExpanded = !_isExpanded;
              });
            },
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 2),
              child: Text(
                _isExpanded
                    ? 'ย่อภารกิจย่อย'
                    : '+ อีก ${subtasks.length - maxInitial} ภารกิจย่อย',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: (theme.brightness == Brightness.dark
                      ? AppColors.stormySkyBlue
                      : theme.colorScheme.primary),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

