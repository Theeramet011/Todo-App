import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../providers/task_provider.dart';
import '../providers/auth_provider.dart';

class MemberConfigResult {
  final Member mainAssignee;
  final List<String> coAssigneeIds;
  final List<Member> coAssigneeMembers;
  final String? previousAssigneeId;

  MemberConfigResult({
    required this.mainAssignee,
    required this.coAssigneeIds,
    this.coAssigneeMembers = const [],
    this.previousAssigneeId,
  });
}

class MemberConfigSheet extends StatefulWidget {
  final Member memberTask;
  final List<Member> allSelectedMembers;
  final Function(MemberConfigResult result) onSave;
  final VoidCallback onDelete;
  final bool isMe;
  final bool isLeader;
  final Task? task;

  const MemberConfigSheet({
    super.key,
    required this.memberTask,
    required this.allSelectedMembers,
    required this.onSave,
    required this.onDelete,
    this.isMe = false,
    this.isLeader = false,
    this.task,
  });

  @override
  State<MemberConfigSheet> createState() => _MemberConfigSheetState();
}

class _MemberConfigSheetState extends State<MemberConfigSheet> {
  late Member _currentAssignee;
  late List<String> _currentCoAssignees;
  List<Member> _currentCoAssigneeMembers = [];

  late TextEditingController titleController;
  late TextEditingController descController;
  final _subTaskController = TextEditingController();
  late TextEditingController _scoreController;

  late List<String> _subTasks;
  int? _editingSubTaskIndex;
  final TextEditingController _inlineSubTaskController =
      TextEditingController();
  final FocusNode _inlineSubTaskFocusNode = FocusNode();

  late String _complexity;
  late String _workload;
  late String _risk;

  late bool _hasTask;
  bool _hasTitleError = false;
  final ScrollController _scrollController = ScrollController();

  void _scrollToTopError() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _currentAssignee = widget.memberTask;

    // Initialize controllers with existing data from the memberTask object
    titleController = TextEditingController(text: widget.memberTask.taskTitle);
    descController = TextEditingController(text: widget.memberTask.description);
    _scoreController = TextEditingController(text: widget.memberTask.score);

    // Initialize other state variables
    _subTasks = List.from(widget.memberTask.subTasks);
    _complexity = widget.memberTask.difficulty;
    _workload = widget.memberTask.workload;
    _risk = widget.memberTask.risk;

    // Initialize _hasTask state for Leader
    _hasTask =
        !widget.isLeader ||
        (widget.memberTask.taskTitle != null &&
            widget.memberTask.taskTitle!.trim().isNotEmpty);

    // Requirement 3: Pre-check members who share the same task title and description
    final sharedMembers = widget.allSelectedMembers
        .where(
          (m) =>
              m.id != _currentAssignee.id &&
              m.taskTitle == _currentAssignee.taskTitle &&
              m.description == _currentAssignee.description &&
              _currentAssignee.taskTitle != null &&
              _currentAssignee.taskTitle!.isNotEmpty,
        )
        .map((m) => m.id)
        .toList();

    _currentCoAssignees = List.from(widget.memberTask.coAssigneeIds);
    for (var id in sharedMembers) {
      if (!_currentCoAssignees.contains(id)) {
        _currentCoAssignees.add(id);
      }
    }
    _currentCoAssignees.remove(_currentAssignee.id);
    _currentCoAssigneeMembers = widget.allSelectedMembers
        .where((m) => _currentCoAssignees.contains(m.id))
        .toList();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    titleController.dispose();
    descController.dispose();
    _subTaskController.dispose();
    _scoreController.dispose();
    _inlineSubTaskController.dispose();
    _inlineSubTaskFocusNode.dispose();
    super.dispose();
  }

  void _showChangeAssigneeDialog() {
    final theme = Theme.of(context);
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'เปลี่ยนผู้รับผิดชอบ',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).brightness == Brightness.dark
                ? Colors.white.withValues(alpha: 0.9)
                : theme.colorScheme.onSurface,
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SizedBox(
          width: double.maxFinite,
          child: FutureBuilder<List<User>>(
            future: taskProvider.getRealFriendsList(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SizedBox(
                  height: 100,
                  child: Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppColors.stormySkyBlue,
                      ),
                    ),
                  ),
                );
              }
              if (snapshot.hasError || !snapshot.hasData) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'เกิดข้อผิดพลาดในการโหลดข้อมูลเพื่อน',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              final friendsList = snapshot.data!;
              if (friendsList.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Text(
                    'ไม่มีรายชื่อเพื่อนในระบบ',
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                itemCount: friendsList.length,
                itemBuilder: (context, index) {
                  final friend = friendsList[index];
                  return ListTile(
                    leading: CircleAvatar(
                      radius: 20,
                      backgroundColor: AppColors.stormySkyBlue.withValues(
                        alpha: 0.15,
                      ),
                      child: ClipOval(
                        child: friend.avatarUrl.isNotEmpty
                            ? Image.network(
                                friend.avatarUrl,
                                width: 40,
                                height: 40,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Center(
                                    child: Text(
                                      friend.name.isNotEmpty
                                          ? friend.name[0].toUpperCase()
                                          : '?',
                                      style: const TextStyle(
                                        color: AppColors.stormySkyBlue,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  );
                                },
                              )
                            : Center(
                                child: Text(
                                  friend.name.isNotEmpty
                                      ? friend.name[0].toUpperCase()
                                      : '?',
                                  style: const TextStyle(
                                    color: AppColors.stormySkyBlue,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                      ),
                    ),
                    title: Text(friend.name),
                    onTap: () {
                      setState(
                        () =>
                            _currentAssignee = Member.fromUser(friend).copyWith(
                              taskTitle: _currentAssignee.taskTitle,
                              description: _currentAssignee.description,
                              difficulty: _complexity,
                              workload: _workload,
                              risk: _risk,
                              subTasks: _subTasks,
                              score: _taskScoreForSave,
                              coAssigneeIds: _currentCoAssignees,
                            ),
                      );
                      Navigator.pop(context);
                    },
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }

  void _showCoAssigneeDialog() {
    final theme = Theme.of(context);
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(
                'เพิ่มผู้รับผิดชอบร่วมกัน',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).brightness == Brightness.dark
                      ? Colors.white.withValues(alpha: 0.9)
                      : theme.colorScheme.onSurface,
                ),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: FutureBuilder<List<User>>(
                  future: taskProvider.getRealFriendsList(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox(
                        height: 100,
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.stormySkyBlue,
                            ),
                          ),
                        ),
                      );
                    }
                    if (snapshot.hasError || !snapshot.hasData) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Text(
                          'เกิดข้อผิดพลาดในการโหลดข้อมูลเพื่อน',
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    final List<User> rawAvailableUsers = [];
                    for (var member in widget.allSelectedMembers) {
                      rawAvailableUsers.add(
                        User(
                          id: member.id,
                          name: member.name,
                          email: '',
                          avatarUrl: member.avatarUrl,
                          joinedAt: DateTime.now(),
                        ),
                      );
                    }

                    for (var friend in snapshot.data!) {
                      if (!rawAvailableUsers.any((u) => u.id == friend.id)) {
                        rawAvailableUsers.add(friend);
                      }
                    }

                    final availableUsers = rawAvailableUsers
                        .where((u) => u.id != _currentAssignee.id)
                        .toList();

                    if (availableUsers.isEmpty) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: SizedBox(
                          width: double.infinity,
                          child: Text(
                            'ไม่มีรายชื่อเพื่อนในระบบ',
                            style: TextStyle(
                              color:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              fontSize: 14,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: availableUsers.length,
                      itemBuilder: (context, index) {
                        final friend = availableUsers[index];
                        final isSelected = _currentCoAssignees.contains(
                          friend.id,
                        );
                        return CheckboxListTile(
                          title: Text(friend.name),
                          secondary: CircleAvatar(
                            radius: 20,
                            backgroundColor: AppColors.stormySkyBlue.withValues(
                              alpha: 0.15,
                            ),
                            child: ClipOval(
                              child: friend.avatarUrl.isNotEmpty
                                  ? Image.network(
                                      friend.avatarUrl,
                                      width: 40,
                                      height: 40,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) {
                                            return Center(
                                              child: Text(
                                                friend.name.isNotEmpty
                                                    ? friend.name[0]
                                                          .toUpperCase()
                                                    : '?',
                                                style: const TextStyle(
                                                  color:
                                                      AppColors.stormySkyBlue,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                ),
                                              ),
                                            );
                                          },
                                    )
                                  : Center(
                                      child: Text(
                                        friend.name.isNotEmpty
                                            ? friend.name[0].toUpperCase()
                                            : '?',
                                        style: const TextStyle(
                                          color: AppColors.stormySkyBlue,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          value: isSelected,
                          onChanged: (value) {
                            setDialogState(() {
                              if (value!) {
                                if (!_currentCoAssignees.contains(friend.id)) {
                                  _currentCoAssignees.add(friend.id);
                                  _currentCoAssigneeMembers.add(
                                    Member.fromUser(friend),
                                  );
                                }
                              } else {
                                _currentCoAssignees.remove(friend.id);
                                _currentCoAssigneeMembers.removeWhere(
                                  (m) => m.id == friend.id,
                                );
                              }
                            });
                            // Trigger rebuild of the main sheet to update the count display
                            setState(() {});
                          },
                        );
                      },
                    );
                  },
                ),
              ),
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
                      borderRadius: BorderRadius.circular(8.0),
                    ),
                  ),
                  child: const Text('ตกลง'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _addSubTask() {
    if (_subTaskController.text.trim().isNotEmpty) {
      setState(() {
        _subTasks.add(_subTaskController.text.trim());
        _subTaskController.clear();
      });
    }
  }

  int get _suggestedTaskScore {
    return (_metricScore(_complexity) * 15) +
        (_metricScore(_workload) * 10) +
        (_metricScore(_risk) * 5);
  }

  int _metricScore(String value) {
    switch (value.toLowerCase()) {
      case 'hard':
      case 'large':
      case 'high':
        return 3;
      case 'normal':
      case 'medium':
      case 'low':
        return 2;
      case 'easy':
      case 'small':
      case 'none':
      default:
        return 1;
    }
  }

  // ฟังก์ชันดักจับการเปลี่ยนแปลงความยาก ปริมาณงาน และความเสี่ยง แบบเรียลไทม์
  void _onMetricChanged(String type, String newValue) {
    // บันทึกคะแนนที่ระบบแนะนำ ณ ค่าสเกลปัจจุบันเอาไว้ก่อนเปลี่ยนค่าใหม่
    final oldSuggested = _suggestedTaskScore;
    setState(() {
      if (type == 'complexity') _complexity = newValue;
      if (type == 'workload') _workload = newValue;
      if (type == 'risk') _risk = newValue;

      // จัดการกับตัวเลขในช่องกรอกคะแนน
      final currentScoreText = _scoreController.text.trim();
      // หากช่องกรอกว่างเปล่า หรือตัวเลขที่กรอกค้างอยู่ดันตรงกับคะแนนแนะนำตัวเก่าพอดี (ไม่ได้กรอกแบบเจาะจงเอง)
      // ให้ทำการล้างค่าในช่อง เพื่อโชว์คำแนะนำแนะนำคะแนนตัวใหม่จางๆ (Placeholder/Hint) แบบเรียลไทม์
      if (currentScoreText.isEmpty ||
          currentScoreText == oldSuggested.toString()) {
        _scoreController.clear();
      }
    });
  }

  // ดึงค่าคะแนนที่ผู้ใช้กรอก หรือระบบคำนวณให้ เพื่อเตรียมบันทึกลงฐานข้อมูล
  String get _taskScoreForSave {
    // หากเป็นตัวของหัวหน้างานเอง ให้คำนวณคะแนนอัตโนมัติตามสเกลความยากง่ายเสมอ (เนื่องจากไม่มีช่องป้อนคะแนนแสดงใน UI)
    if (widget.isMe) {
      return _suggestedTaskScore.toString();
    }
    final score = _scoreController.text.trim();
    // หากช่องป้อนคะแนนว่างเปล่า ให้ดึงค่าแนะนำของระบบ ณ สเกลปัจจุบันไปใช้งานโดยอัตโนมัติ
    return score.isEmpty ? _suggestedTaskScore.toString() : score;
  }

  void _showDeleteMemberConfirmation() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'ยืนยันการลบสมาชิก',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.accentRed,
          ),
        ),
        content: Text(
          'ต้องการลบสมาชิก ${_currentAssignee.name} ออกหรือไม่?',
          style: TextStyle(
            fontSize: 15,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'ยกเลิก',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              widget.onDelete(); // Proceed with deletion
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text(
              'ยืนยัน',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showDeleteTaskConfirmation() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'ยืนยันการลบภารกิจ',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.accentRed,
          ),
        ),
        content: Text(
          'คุณแน่ใจหรือไม่ว่าต้องการลบภารกิจนี้และกลับไปเป็นผู้ตรวจงานอย่างเดียว?',
          style: TextStyle(
            fontSize: 15,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
          ),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'ยกเลิก',
              style: TextStyle(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context); // Close dialog

              // 1. Clear leader-assigned data locally in the state
              setState(() {
                titleController.clear();
                descController.clear();
                _complexity = 'Easy';
                _workload = 'Small';
                _risk = 'None';
                _subTasks.clear();
                _scoreController.clear();
                _currentCoAssignees.clear();
                _hasTask = false;
              });

              // 2. Prepare the cleared leader Member object (using nulls for leader-specific metrics)
              final clearedLeader = Member(
                id: _currentAssignee.id,
                name: _currentAssignee.name,
                avatarUrl: _currentAssignee.avatarUrl,
                taskTitle: null,
                description: null,
                difficulty: 'Easy',
                workload: 'Small',
                risk: 'None',
                subTasks: const [],
                score: null,
                coAssigneeIds: const [],
              );

              final result = MemberConfigResult(
                mainAssignee: clearedLeader,
                coAssigneeIds: const [],
                coAssigneeMembers: const [],
              );

              // 3. Notify the parent immediately so the local state in CreateTaskModal stays in sync
              widget.onSave(result);

              // 4. Perform Firestore update if task already exists
              if (widget.task != null) {
                final leaderId = _currentAssignee.id;
                final updatedMembers = widget.allSelectedMembers.map((m) {
                  if (m.id == leaderId) {
                    return clearedLeader;
                  }
                  return m;
                }).toList();

                await FirebaseFirestore.instance
                    .collection('tasks')
                    .doc(widget.task!.id)
                    .update({
                      'assigneeIds': FieldValue.arrayRemove([leaderId]),
                      'members': updatedMembers.map((m) => m.toMap()).toList(),
                    });
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentRed,
              foregroundColor: Colors.white,
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

  void _saveLeaderTask() {
    if (_hasTask && titleController.text.trim().isEmpty) {
      setState(() {
        _hasTitleError = true;
      });
      _scrollToTopError();
      return;
    }
    setState(() {
      _hasTitleError = false;
    });

    final updatedMember = _currentAssignee.copyWith(
      taskTitle: titleController.text,
      description: descController.text,
      difficulty: _complexity,
      workload: _workload,
      risk: _risk,
      subTasks: _subTasks,
      score: _taskScoreForSave,
      coAssigneeIds: _currentCoAssignees,
    );

    final result = MemberConfigResult(
      mainAssignee: updatedMember,
      coAssigneeIds: _currentCoAssignees,
      coAssigneeMembers: _currentCoAssigneeMembers,
      previousAssigneeId: _currentAssignee.id != widget.memberTask.id
          ? widget.memberTask.id
          : null,
    );

    widget.onSave(result);
    Navigator.pop(context, result);
  }

  Widget _buildReviewerOnlyState(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.03)
                : AppColors.stormySkyBlue.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.stormySkyBlue.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.stormySkyBlue.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.rate_review_outlined,
                  color: AppColors.stormySkyBlue,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "คุณเป็น 'ผู้ตรวจงานอย่างเดียว'\nเมื่อจบภารกิจนี้ คุณจะได้รับแค่ 'คะแนนบริหาร' โดยไม่มีการคิดคะแนนจากความยากของเนื้อภารกิจ คุณสามารถสร้างภารกิจของตัวเองได้ที่ปุ่มบวกด้านล่าง",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  height: 1.6,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        // Large Circular Floating Action Button (+) Style Icon
        GestureDetector(
          onTap: () {
            setState(() {
              _hasTask = true;
            });
          },
          child: Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppColors.stormySkyBlue,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.stormySkyBlue.withValues(alpha: 0.4),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(Icons.add, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;

    // 1. ดึงค่าความสูงของแถบด้านบน (Status Bar / รอยบากกล้อง)
    final topPadding = MediaQuery.of(context).padding.top;
    return Container(
      decoration: BoxDecoration(
        color: theme.brightness == Brightness.dark
            ? AppColors.stormyNightBackground
            : theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),

      child: Padding(
        padding: EdgeInsets.only(
          // ดันลงมาเท่ากับความสูงขอบจอ + ระยะห่างอีกนิดหน่อยเพื่อให้กดง่าย
          top: topPadding > 0 ? topPadding + 16 : 32,
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  // ขยายขนาดพื้นที่กด (Tap Target) ให้ปุ่มย้อนกลับกดง่ายขึ้น
                  IconButton(
                    iconSize: 28,
                    padding: const EdgeInsets.all(12),
                    onPressed: () {
                      if (widget.isLeader && !_hasTask) {
                        final clearedLeader = Member(
                          id: _currentAssignee.id,
                          name: _currentAssignee.name,
                          avatarUrl: _currentAssignee.avatarUrl,
                          taskTitle: null,
                          description: null,
                          difficulty: 'Easy',
                          workload: 'Small',
                          risk: 'None',
                          subTasks: const [],
                          score: null,
                          coAssigneeIds: const [],
                        );
                        final result = MemberConfigResult(
                          mainAssignee: clearedLeader,
                          coAssigneeIds: const [],
                          coAssigneeMembers: const [],
                        );
                        Navigator.pop(context, result);
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    icon: Icon(Icons.arrow_back, color: onSurface),
                  ),
                  Text(
                    'แก้ไขผู้รับผิดชอบ',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: onSurface,
                    ),
                  ),
                ],
              ),
            ),

            Flexible(
              child: SingleChildScrollView(
                controller: _scrollController,
                padding: const EdgeInsets.all(AppConstants.paddingLarge),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile Section
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 40,
                            backgroundImage:
                                _currentAssignee.avatarUrl.isNotEmpty
                                ? NetworkImage(_currentAssignee.avatarUrl)
                                : null,
                            backgroundColor: AppColors.stormySkyBlue.withValues(
                              alpha: 0.1,
                            ),
                            child: _currentAssignee.avatarUrl.isEmpty
                                ? Text(
                                    _currentAssignee.name[0],
                                    style: const TextStyle(fontSize: 28),
                                  )
                                : null,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _currentAssignee.name,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Show empty state if leader has no task
                    if (widget.isLeader && !_hasTask)
                      _buildReviewerOnlyState(context)
                    else ...[
                      // Field 1: ชื่อภารกิจ
                      _buildTextField(
                        controller: titleController,
                        label: 'ชื่อภารกิจ',
                        hint: 'เช่น ออกแบบ UI หน้า Login',
                        errorText: _hasTitleError ? 'กรุณาใส่ชื่อภารกิจ' : null,
                      ),

                      const SizedBox(height: 16),

                      // Field 2: รายละเอียด
                      _buildTextField(
                        controller: descController,
                        label: 'รายละเอียด',
                        hint: 'อธิบายงานโดยย่อ',
                        minLines: 1,
                        maxLines: 4,
                      ),

                      const SizedBox(height: 16),

                      // Combined Ratings Row (ความยาก / ปริมาณภารกิจ / ความเสี่ยง)
                      _buildCombinedRatingsRow(),

                      const SizedBox(height: 16),

                      // Expandable Subtasks Section
                      _buildSubtasksSection(),

                      const SizedBox(height: 16),

                      // Hide "Change Assignee" for Leader to make configuration cleaner
                      if (!widget.isLeader) ...[
                        // Field 5: เปลี่ยนผู้รับผิดชอบ
                        _buildTappableBox(
                          label: 'เปลี่ยนผู้รับผิดชอบ',
                          value: _currentAssignee.name,
                          icon: Icons.person_outline,
                          onTap: _showChangeAssigneeDialog,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Field 6: เพิ่มผู้รับผิดชอบร่วมกัน
                      _buildTappableBox(
                        label: '',
                        value: _currentCoAssignees.isEmpty
                            ? 'เพิ่มผู้รับผิดชอบร่วมกัน'
                            : '${_currentCoAssignees.length} คน',
                        icon: Icons.add,
                        onTap: _showCoAssigneeDialog,
                        isCoAssignee: true,
                      ),

                      const SizedBox(height: 16),

                      // Field 7: คะแนนภารกิจ
                      if (!widget.isMe)
                        _buildTextField(
                          controller: _scoreController,
                          label: 'คะแนนภารกิจ',
                          hint: 'แนะนำ $_suggestedTaskScore คะแนน',
                          keyboardType: TextInputType.number,
                          bottomHint:
                              'กรณีไม่ใส่คะแนนระบบจะแนะนำคะแนนตามภารกิจอัตโนมัติ',
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8),
                          child: Text(
                            'คะแนนของหัวหน้าโครงการจะได้รับเมื่อจบภารกิจทั้งหมด',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.stormySkyBlue,
                              fontWeight: FontWeight.bold,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),

                      const SizedBox(height: 32),

                      // Action Buttons
                      if (widget.isLeader) ...[
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: _showDeleteTaskConfirmation,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: AppColors.error,
                                  side: const BorderSide(
                                    color: AppColors.error,
                                    width: 1.5,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: const Text(
                                  'ลบภารกิจ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () {
                                  if (titleController.text.trim().isEmpty) {
                                    setState(() {
                                      _hasTitleError = true;
                                    });
                                    _scrollToTopError();
                                    return;
                                  }
                                  _saveLeaderTask();
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.stormySkyBlue,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  shadowColor: AppColors.stormySkyBlue
                                      .withValues(alpha: 0.3),
                                  elevation: 4,
                                ),
                                child: const Text(
                                  'บันทึก',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ] else ...[
                        Builder(
                          builder: (context) {
                            final authProvider = Provider.of<AuthProvider>(
                              context,
                              listen: false,
                            );
                            final currentUserId = authProvider.currentUser?.id;
                            final leaderId =
                                widget.task?.creatorId ?? currentUserId;
                            final isCurrentUserLeader =
                                currentUserId != null &&
                                currentUserId == leaderId;

                            return Row(
                              children: [
                                if (isCurrentUserLeader && !widget.isMe) ...[
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _showDeleteMemberConfirmation,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: AppColors.error,
                                        side: const BorderSide(
                                          color: AppColors.error,
                                          width: 1.5,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                        ),
                                      ),
                                      child: const Text(
                                        'ลบ',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                ],
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () {
                                      if (titleController.text.trim().isEmpty) {
                                        setState(() {
                                          _hasTitleError = true;
                                        });
                                        return;
                                      }
                                      setState(() {
                                        _hasTitleError = false;
                                      });

                                      final updatedMember = _currentAssignee
                                          .copyWith(
                                            taskTitle: titleController.text,
                                            description: descController.text,
                                            difficulty: _complexity,
                                            workload: _workload,
                                            risk: _risk,
                                            subTasks: _subTasks,
                                            score: _taskScoreForSave,
                                            coAssigneeIds: _currentCoAssignees,
                                          );

                                      final result = MemberConfigResult(
                                        mainAssignee: updatedMember,
                                        coAssigneeIds: _currentCoAssignees,
                                        coAssigneeMembers:
                                            _currentCoAssigneeMembers,
                                        previousAssigneeId:
                                            _currentAssignee.id !=
                                                widget.memberTask.id
                                            ? widget.memberTask.id
                                            : null,
                                      );

                                      widget.onSave(result);
                                      Navigator.pop(context, result);
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.stormySkyBlue,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: const Text(
                                      'เสร็จสิ้น',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCombinedRatingsRow() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isDark ? AppColors.stormyDarkSlate : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? AppColors.stormyMutedBlueGrey.withValues(alpha: 0.6)
              : AppColors.stormyMutedBlueGrey,
        ),
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildCompactRatingItem(
              label: 'ความยาก',
              selectedValue: _complexity,
              options: const ['Easy', 'Normal', 'Hard'],
              onSelected: (val) => _onMetricChanged('complexity', val),
              activeIcon: Icons.star_rounded,
              activeColor: const Color(0xFFFFB800),
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: theme.dividerColor.withValues(alpha: 0.2),
          ),
          Expanded(
            child: _buildCompactRatingItem(
              label: 'ปริมาณภารกิจ',
              selectedValue: _workload,
              options: const ['Small', 'Medium', 'Large'],
              onSelected: (val) => _onMetricChanged('workload', val),
              activeIcon: Icons.description,
              activeColor: AppColors.primaryGreen,
            ),
          ),
          Container(
            width: 1,
            height: 40,
            color: theme.dividerColor.withValues(alpha: 0.2),
          ),
          Expanded(
            child: _buildCompactRatingItem(
              label: 'ความเสี่ยง',
              selectedValue: _risk,
              options: const ['None', 'Low', 'High'],
              onSelected: (val) => _onMetricChanged('risk', val),
              activeIcon: Icons.shield_rounded,
              activeColor: AppColors.accentRed,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactRatingItem({
    required String label,
    required String selectedValue,
    required List<String> options,
    required Function(String) onSelected,
    required IconData activeIcon,
    required Color activeColor,
  }) {
    final isLight = Theme.of(context).brightness == Brightness.light;
    int selectedIndex = options.indexWhere(
      (opt) => opt.toLowerCase() == selectedValue.toLowerCase(),
    );
    if (selectedIndex == -1) selectedIndex = 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isLight
                ? AppColors.stormyDarkSlate
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(options.length, (index) {
            bool isActive = index <= selectedIndex;
            final color = isActive
                ? activeColor
                : (isLight ? Colors.grey[400]! : Colors.grey[700]!);

            return GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                if (selectedIndex == index && index > 0) {
                  onSelected(options[index - 1]);
                } else {
                  onSelected(options[index]);
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 4.0,
                  vertical: 2.0,
                ),
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 180),
                  opacity: isActive ? 1.0 : 0.35,
                  child: Icon(activeIcon, color: color, size: 26),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  bool _isSubTasksExpanded = true;

  Widget _buildSubtasksSection() {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isLight ? AppColors.stormyOffWhite : AppColors.stormyDarkSlate,
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(
          color: isLight
              ? AppColors.stormyMutedBlueGrey
              : AppColors.stormyMutedBlueGrey.withValues(alpha: 0.6),
          width: isLight ? 1.0 : 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            enableFeedback: false,
            onTap: () =>
                setState(() => _isSubTasksExpanded = !_isSubTasksExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.playlist_add_check_rounded,
                    size: 20,
                    color: isLight
                        ? AppColors.stormyMutedBlueGrey
                        : theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ภารกิจย่อย',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  if (_subTasks.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.stormySkyBlue.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${_subTasks.length}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: AppColors.stormySkyBlue,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    _isSubTasksExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
          if (_isSubTasksExpanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                children: [
                  if (_subTasks.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _subTasks.length,
                      itemBuilder: (context, index) {
                        final isEditingThis = _editingSubTaskIndex == index;

                        if (isEditingThis) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 7),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : AppColors.stormySkyBlue
                                      .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: AppColors.stormySkyBlue,
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.only(
                                    left: 4,
                                    right: 8,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: AppColors.stormySkyBlue,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: _inlineSubTaskController,
                                    focusNode: _inlineSubTaskFocusNode,
                                    autofocus: true,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 6,
                                      ),
                                      border: InputBorder.none,
                                    ),
                                    onSubmitted: (val) =>
                                        _saveInlineSubTask(index),
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  style: IconButton.styleFrom(
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    minimumSize: Size.zero,
                                    padding: EdgeInsets.zero,
                                  ),
                                  icon: const Icon(
                                    Icons.check,
                                    size: 18,
                                    color: AppColors.success,
                                  ),
                                  onPressed: () => _saveInlineSubTask(index),
                                  constraints: const BoxConstraints(
                                    minWidth: 26,
                                    minHeight: 26,
                                  ),
                                  tooltip: 'บันทึก',
                                ),
                                const SizedBox(width: 2),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  style: IconButton.styleFrom(
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    minimumSize: Size.zero,
                                    padding: EdgeInsets.zero,
                                  ),
                                  icon: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: AppColors.accentRed,
                                  ),
                                  onPressed: _cancelInlineSubTask,
                                  constraints: const BoxConstraints(
                                    minWidth: 26,
                                    minHeight: 26,
                                  ),
                                  tooltip: 'ยกเลิก',
                                ),
                              ],
                            ),
                          );
                        }

                        return Container(
                          margin: const EdgeInsets.only(bottom: 7),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.06)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.05)
                                  : AppColors.stormyMutedBlueGrey.withValues(
                                      alpha: 0.35,
                                    ),
                              width: 0.8,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                margin: const EdgeInsets.only(
                                  left: 4,
                                  right: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.onSurface.withValues(
                                    alpha: 0.5,
                                  ),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  _subTasks[index],
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: 18,
                                  color: (Theme.of(context).brightness ==
                                          Brightness.light
                                      ? AppColors.stormySkyBlue
                                      : AppColors.primaryBlue),
                                ),
                                 onPressed: () {
                                   setState(() {
                                     _editingSubTaskIndex = index;
                                     _inlineSubTaskController.text =
                                         _subTasks[index];
                                   });
                                   Future.microtask(() =>
                                       _inlineSubTaskFocusNode.requestFocus());
                                 },
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: AppColors.accentRed,
                                ),
                                onPressed: () =>
                                    setState(() => _subTasks.removeAt(index)),
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _subTaskController,
                          style: TextStyle(
                            fontSize: 13,
                            color: theme.colorScheme.onSurface,
                          ),
                          decoration: InputDecoration(
                            hintText: 'เพิ่มภารกิจย่อย...',
                            hintStyle: TextStyle(
                              fontSize: 13,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.4,
                              ),
                            ),
                            filled: true,
                            fillColor: isDark
                                ? Colors.white.withValues(alpha: 0.05)
                                : Colors.transparent,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 8,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(
                                color: isDark
                                    ? Colors.grey[800]!
                                    : Colors.grey[300]!,
                              ),
                            ),
                          ),
                          onSubmitted: (val) => _addSubTask(),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filled(
                        onPressed: _addSubTask,
                        icon: const Icon(Icons.add, size: 18),
                        constraints: const BoxConstraints(
                          minWidth: 36,
                          minHeight: 36,
                        ),
                        padding: EdgeInsets.zero,
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.stormySkyBlue,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _saveInlineSubTask(int index) {
    final newTitle = _inlineSubTaskController.text.trim();
    if (newTitle.isNotEmpty && index >= 0 && index < _subTasks.length) {
      setState(() {
        _subTasks[index] = newTitle;
        _editingSubTaskIndex = null;
      });
    }
  }

  void _cancelInlineSubTask() {
    setState(() {
      _editingSubTaskIndex = null;
    });
  }

  Widget _buildTappableBox({
    required String label,
    required String value,
    required IconData icon,
    required VoidCallback onTap,
    bool isCoAssignee = false,
  }) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label.isNotEmpty) ...[
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: onSurface,
            ),
          ),
          const SizedBox(height: 8),
        ],
        InkWell(
          enableFeedback: false,
          onTap: onTap,
          borderRadius: BorderRadius.circular(15),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.05)
                  : AppColors.backgroundLightGrey,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(
                color: isDark
                    ? Colors.grey[800]!
                    : AppColors.backgroundDarkGrey,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: TextStyle(fontSize: 15, color: onSurface),
                  ),
                ),
                Icon(icon, size: 20, color: onSurface.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    int? minLines,
    int? maxLines = 1,
    TextInputType? keyboardType,
    String? bottomHint,
    String? errorText,
  }) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: onSurface,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          minLines: minLines,
          maxLines: maxLines,
          keyboardType: keyboardType,
          style: TextStyle(color: onSurface),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: onSurface.withValues(alpha: 0.4)),
            filled: true,
            fillColor: isDark ? AppColors.stormyDarkSlate : Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.grey[800]!
                    : AppColors.backgroundDarkGrey,
              ),
            ),
            errorText: errorText,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 12,
            ),
          ),
        ),
        if (bottomHint != null) ...[
          const SizedBox(height: 4),
          Text(
            bottomHint,
            style: TextStyle(
              fontSize: 12,
              color: onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ],
    );
  }
}
