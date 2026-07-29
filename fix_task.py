# ============================================================================
# ไฟล์สคริปต์นี้เปรียบเสมือน "ช่างซ่อมบำรุงอัตโนมัติ" สำหรับหน้าจอรายละเอียดภารกิจ
# ทำหน้าที่เข้าไปค้นหาท่อนโค้ดที่มีปัญหา (บั๊ก) ในไฟล์ `lib/screens/task_detail_screen.dart`
# แล้วทำการสับเปลี่ยน (Replace) ด้วยโค้ดที่ถูกต้อง เพื่อให้ระบบกลับมาทำงานได้ปกติ
# ============================================================================
with open("lib/screens/task_detail_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

target1 = """                              const SizedBox(width: 6),
    Task task,
    TaskProvider taskProvider, {"""

replacement1 = """                              const SizedBox(width: 6),
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
    TaskProvider taskProvider, {"""

content = content.replace(target1, replacement1)

target2 = """                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (e) {
                          updateSubtasks: true,
                        );
                      },
                    );"""

replacement2 = """                try {
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

    return RichText(
      textAlign: textAlign,
      text: TextSpan(children: spans),
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

  Future<void> _openEditTaskModal(BuildContext context, Task task) async {
    await showModalBottomSheet<Task>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateTaskModal(task: task),
    );
  }

  void _showOptionsMenu(BuildContext context, Task task) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => Container(
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark ? AppColors.stormyDarkSlate : theme.cardColor,
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
                    ? (Theme.of(context).brightness == Brightness.light ? AppColors.stormyMutedBlueGrey : AppColors.backgroundDarkGrey)
                    : Colors.grey[800],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            if (!task.isDeleted)
              ListTile(
                leading: Icon(
                  Icons.edit_outlined,
                  color: (Theme.of(context).brightness == Brightness.light ? AppColors.stormySkyBlue : AppColors.primaryBlue),
                ),
                title: Text('แก้ไขภารกิจ', style: TextStyle(color: onSurface)),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _openEditTaskModal(context, task);
                },
              ),
            ListTile(
              leading: Icon(
                task.isDeleted
                    ? Icons.restore
                    : (task.isCompleted
                          ? Icons.undo
                          : Icons.check_circle_outline),
                color: task.isDeleted
                    ? (Theme.of(context).brightness == Brightness.light ? AppColors.stormySkyBlue : AppColors.primaryPink)
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
                    final result = await taskProvider.completeTaskWithSubtasks(
                      task.id,
                      true,
                    );
                    if (!mounted || !sheetContext.mounted) return;
                    Navigator.pop(sheetContext);
                    await FastCompletionWarningDialog.showCompletionFeedback(
                      context,
                      result,
                    );
                    
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
                    );"""

content = content.replace(target2, replacement2)

with open("lib/screens/task_detail_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
