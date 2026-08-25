// MemberAssignmentDetailScreen - หน้าจอรายละเอียดการมอบหมายงานให้สมาชิกในทีม (Member Assignment Detail)
//
// แสดงรายละเอียดการมอบหมายงาน รายชื่อสมาชิกที่รับผิดชอบ สถานะการทำงาน
// และการจัดการสิทธิ์ของหัวหน้าทีม (Leader) หรือสมาชิกกลุ่ม
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../models/task.dart';
import '../providers/auth_provider.dart';
import '../providers/task_provider.dart';
import '../providers/connectivity_provider.dart';

class MemberAssignmentDetailScreen extends StatefulWidget {
  final Member member;
  final List<Member> allMembers;
  final bool isLeader;
  final Task? task;

  const MemberAssignmentDetailScreen({
    super.key,
    required this.member,
    this.allMembers = const [],
    this.isLeader = false,
    this.task,
  });

  @override
  State<MemberAssignmentDetailScreen> createState() =>
      _MemberAssignmentDetailScreenState();
}

class _MemberAssignmentDetailScreenState
    extends State<MemberAssignmentDetailScreen> {
  // ดึงข้อมูลสมาชิก (Assignee) ล่าสุดจาก TaskProvider เสมอ เพื่อให้การแก้ไขคะแนนหรือภารกิจแสดงผลแบบเรียลไทม์
  Member get member {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final taskId = widget.task?.id;
    // ค้นหางานล่าสุดจากรายการใน Provider
    final currentTask = taskId != null
        ? taskProvider.tasks.firstWhere(
            (t) => t.id == taskId,
            orElse: () => widget.task!,
          )
        : widget.task;
    // ค้นหาและดึงข้อมูลของสมาชิกคนนี้จากงานล่าสุด
    return currentTask != null
        ? currentTask.members.firstWhere(
            (m) => m.id == widget.member.id,
            orElse: () => widget.member,
          )
        : widget.member;
  }

  // ดึงข้อมูลภารกิจ (Task) ล่าสุดจาก TaskProvider เพื่อความสอดคล้องของข้อมูล
  Task? get task {
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final taskId = widget.task?.id;
    return taskId != null
        ? taskProvider.tasks.firstWhere(
            (t) => t.id == taskId,
            orElse: () => widget.task!,
          )
        : widget.task;
  }

  // รายชื่อผู้ร่วมรับผิดชอบทั้งหมด ดึงจากข้อมูลล่าสุด
  List<Member> get allMembers => task?.members ?? widget.allMembers;
  bool get isLeader => widget.isLeader;

  @override
  Widget build(BuildContext context) {
    Provider.of<TaskProvider>(context);
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.brightness == Brightness.dark
          ? AppColors.stormyNightBackground
          : theme.scaffoldBackgroundColor,
      appBar: AppBar(
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: theme.colorScheme.onSurface),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'รายละเอียดงานมอบหมาย',
          style: TextStyle(
            color: theme.colorScheme.onSurface,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.paddingLarge),
        child: Column(
          children: [
            // Member Profile Header
            _buildProfileHeader(context),
            const SizedBox(height: 24),

            // Task Overview Section
            _buildTaskOverview(context),
            const SizedBox(height: 20),

            // Co-assignees Section
            _buildCoAssigneesSection(context),
            const SizedBox(height: 20),

            // Assignment Metrics
            _buildMetricsGrid(context),
            const SizedBox(height: 20),

            // Sub-tasks Progress
            _buildSubTasksSection(context),
            const SizedBox(height: 20),

            // Performance Info
            _buildPerformanceInfo(context),
            const SizedBox(height: 20),

            _buildAttachmentsSection(context),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCoAssigneesSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // Filter members who share the same task title (excluding current member)
    final coAssignees = allMembers
        .where(
          (m) =>
              m.id != member.id &&
              m.taskTitle == member.taskTitle &&
              member.taskTitle != null &&
              member.taskTitle!.isNotEmpty,
        )
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.stormyDarkSlate : theme.cardColor,
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
          Row(
            children: [
              const Icon(Icons.people_outline, color: AppColors.stormySkyBlue),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'ผู้รับผิดชอบร่วมกัน (Co-assignees)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.onSurface,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (coAssignees.isEmpty)
            Text(
              'ไม่มีผู้รับผิดชอบร่วม',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            )
          else
            SizedBox(
              height: 75,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: coAssignees.length,
                itemBuilder: (context, index) {
                  final co = coAssignees[index];
                  return Padding(
                    padding: const EdgeInsets.only(right: 16),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundImage: co.avatarUrl.isNotEmpty
                              ? NetworkImage(co.avatarUrl)
                              : null,
                          backgroundColor: AppColors.stormySkyBlue.withValues(
                            alpha: 0.1,
                          ),
                          child: co.avatarUrl.isEmpty
                              ? Text(
                                  co.name[0],
                                  style: const TextStyle(fontSize: 12),
                                )
                              : null,
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: 50,
                          child: Text(
                            co.name,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 10,
                              color: theme.colorScheme.onSurface,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.stormySkyBlue, width: 3),
          ),
          child: CircleAvatar(
            radius: 50,
            backgroundImage: member.avatarUrl.isNotEmpty
                ? NetworkImage(member.avatarUrl)
                : null,
            backgroundColor: AppColors.stormySkyBlue.withValues(alpha: 0.1),
            child: member.avatarUrl.isEmpty
                ? Text(member.name[0], style: const TextStyle(fontSize: 32))
                : null,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          member.name,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildTaskOverview(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.stormyDarkSlate : theme.cardColor,
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
          Row(
            children: [
              const Icon(
                Icons.assignment_outlined,
                color: AppColors.primaryBlue,
              ),
              const SizedBox(width: 8),
              Text(
                'รายละเอียดภารกิจ',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            member.taskTitle ?? 'ไม่ได้ระบุชื่อภารกิจ',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            member.description ?? 'ไม่มีรายละเอียดเพิ่มเติม',
            style: TextStyle(
              fontSize: 14,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    return Row(
      children: [
        _buildMetricBox(
          context,
          'ความยาก',
          member.difficulty,
          _getComplexityColor(member.difficulty),
        ),
        const SizedBox(width: 12),
        _buildMetricBox(
          context,
          'ปริมาณภารกิจ',
          member.workload,
          _getWorkloadColor(member.workload),
        ),
        const SizedBox(width: 12),
        _buildMetricBox(
          context,
          'ความเสี่ยง',
          member.risk,
          _getRiskColor(member.risk),
        ),
      ],
    );
  }

  Widget _buildMetricBox(
    BuildContext context,
    String label,
    String value,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 15,
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSubTasksSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final currentTask = task;
    final completedCount = member.subTasks
        .where(
          (st) => member.completedSubTasks.any((c) => c.trim() == st.trim()),
        )
        .length;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.stormyDarkSlate : theme.cardColor,
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
          Row(
            children: [
              const Icon(
                Icons.checklist_rtl_rounded,
                color: AppColors.primaryPurple,
              ),
              const SizedBox(width: 8),
              Text(
                'ภารกิจย่อยของสมาชิก',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              if (member.subTasks.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryPurple.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$completedCount/${member.subTasks.length}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryPurple,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          if (member.subTasks.isEmpty)
            Text(
              'ไม่มีภารกิจย่อย',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
              ),
            )
          else
            ...member.subTasks.map((subTaskTitle) {
              final isDone = member.completedSubTasks.any(
                (c) => c.trim() == subTaskTitle.trim(),
              );
              final authProvider = context.read<AuthProvider>();
              final currentUserId = authProvider.currentUser?.id;
              final isOwner =
                  currentUserId != null && currentUserId == member.id;

              return InkWell(
                onTap: () async {
                  if (currentTask == null) return;
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

                  if (!isOwner) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'เฉพาะสมาชิกเจ้าของงานเท่านั้นที่สามารถอัปเดตภารกิจย่อยนี้ได้',
                        ),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    return;
                  }

                  await taskProvider.toggleMemberSubtask(
                    currentTask.id,
                    member.id,
                    subTaskTitle,
                  );
                },
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 8,
                    horizontal: 4,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDone
                            ? Icons.check_box_rounded
                            : Icons.check_box_outline_blank_rounded,
                        size: 22,
                        color: isDone
                            ? AppColors.primaryGreen
                            : theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          subTaskTitle,
                          style: TextStyle(
                            fontSize: 14,
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
                      if (!isOwner)
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
            }),
        ],
      ),
    );
  }

  Widget _buildPerformanceInfo(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [AppColors.stormyNightBackground, AppColors.stormyDarkSlate]
              : [AppColors.stormyMutedBlueGrey, AppColors.stormySkyBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color:
                (isDark ? AppColors.stormyDarkSlate : AppColors.stormySkyBlue)
                    .withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'คะแนนที่ได้รับ',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'อ้างอิงตามคุณภาพภารกิจ',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Text(
              member.score ?? "0",
              style: TextStyle(
                color: isDark
                    ? AppColors.stormyNightBackground
                    : AppColors.stormyDarkSlate,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkifiedText(
    String text,
    TextStyle baseStyle, {
    TextAlign textAlign = TextAlign.start,
  }) {
    final urlRegex = RegExp(r'(https?:\/\/[^\s]+)', caseSensitive: false);

    final matches = urlRegex.allMatches(text);
    if (matches.isEmpty) {
      return Text(text, style: baseStyle, textAlign: textAlign);
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
            color: AppColors.primaryBlue,
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

    return RichText(
      textAlign: textAlign,
      text: TextSpan(children: spans),
    );
  }

  Widget _buildAttachmentsSection(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final currentTask = task;
    final isSubmissionOwner = currentTask?.submittedBy == member.id;
    final submittedText = member.submissionText?.trim().isNotEmpty == true
        ? member.submissionText!.trim()
        : (isSubmissionOwner ? currentTask?.submissionText?.trim() : null);
    final attachments = member.attachments.isNotEmpty
        ? member.attachments
        : (isSubmissionOwner
              ? currentTask?.attachments ?? []
              : <TaskAttachment>[]);

    final hasContent =
        (submittedText != null && submittedText.isNotEmpty) ||
        attachments.isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? AppColors.stormyDarkSlate : theme.cardColor,
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
          Row(
            children: [
              const Icon(Icons.attach_file, color: AppColors.primaryGreen),
              const SizedBox(width: 8),
              Text(
                'รายละเอียดงานที่ส่ง',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasContent)
            Text(
              'ยังไม่มีการส่งงานขณะนี้',
              style: TextStyle(
                fontSize: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              ),
            )
          else ...[
            if (submittedText != null && submittedText.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.05)
                      : AppColors.backgroundLightGrey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: _buildLinkifiedText(
                  submittedText,
                  TextStyle(fontSize: 14, color: theme.colorScheme.onSurface),
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (attachments.isNotEmpty) ...[
              Text(
                'ไฟล์แนบ:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 8),
              ...attachments.map(
                (file) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    enableFeedback: false,
                    onTap: () {
                      final type = file.fileType.toLowerCase();
                      final isImage = [
                        'png',
                        'jpg',
                        'jpeg',
                        'webp',
                        'gif',
                      ].contains(type);
                      if (isImage) {
                        _showImagePreviewDialog(
                          context,
                          file.fileUrl,
                          file.fileName,
                        );
                      } else {
                        _showDocumentDetailsDialog(
                          context,
                          file.fileUrl,
                          file.fileName,
                          type,
                        );
                      }
                    },
                    child: Row(
                      children: [
                        const Icon(
                          Icons.insert_drive_file_outlined,
                          size: 20,
                          color: AppColors.primaryBlue,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            file.fileName,
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.primaryBlue,
                              decoration: TextDecoration.underline,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
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

  void _showImagePreviewDialog(
    BuildContext context,
    String imageUrl,
    String fileName,
  ) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 24,
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: InteractiveViewer(
                  panEnabled: true,
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.7,
                        maxWidth: MediaQuery.of(context).size.width * 0.9,
                      ),
                      color: Colors.black,
                      child: Image.network(
                        imageUrl,
                        fit: BoxFit.contain,
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
                            padding: const EdgeInsets.all(24),
                            color: Colors.white,
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
              ),
              Positioned(
                top: 0,
                right: 0,
                child: CircleAvatar(
                  backgroundColor: Colors.black.withValues(alpha: 0.6),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
              ),
            ],
          ),
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
              const Icon(Icons.insert_drive_file, color: AppColors.primaryBlue),
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
              onPressed: () async {
                Navigator.pop(context);
                final Uri url = Uri.parse(fileUrl);
                try {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('เกิดข้อผิดพลาด')),
                  );
                }
              },
              icon: const Icon(Icons.open_in_new),
              label: const Text('เปิดในบราวเซอร์'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }
}
