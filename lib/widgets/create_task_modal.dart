import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../models/task.dart';
import '../models/user.dart';
import '../providers/task_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/mock_data.dart';
import '../utils/snack_bar_utils.dart';
import 'member_config_sheet.dart';
import 'custom_recurring_modal.dart';
import '../providers/connectivity_provider.dart';

const List<String> _thaiShortWeekdaysList = [
  'จ.',
  'อ.',
  'พ.',
  'พฤ.',
  'ศ.',
  'ส.',
  'อา.',
];
const List<String> _thaiShortMonthsList = [
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

class CreateTaskModal extends StatefulWidget {
  final Task? task;
  final TaskType? initialType;
  final DateTime? initialDate;
  const CreateTaskModal({
    super.key,
    this.task,
    this.initialType,
    this.initialDate,
  });

  @override
  State<CreateTaskModal> createState() => _CreateTaskModalState();
}

class _CreateTaskModalState extends State<CreateTaskModal> {
  final _formKey = GlobalKey<FormState>();
  final GlobalKey _titleFieldKey = GlobalKey();
  final GlobalKey _memberSectionKey = GlobalKey();
  final GlobalKey _subtaskKey = GlobalKey();
  final FocusNode _subtaskFocusNode = FocusNode();
  int? _editingSubtaskIndex;
  final TextEditingController _inlineSubtaskController =
      TextEditingController();
  final FocusNode _inlineSubtaskFocusNode = FocusNode();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  final _subtaskController = TextEditingController();

  late String _selectedCategory;
  late String _selectedLocation;
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  bool _isRecurring = false;
  String _selectedRecurringType = 'daily';
  DateTime _recurringDate = DateTime.now();
  TimeOfDay _recurringTime = TimeOfDay.now();
  CustomRecurringConfig _customRecurringConfig = const CustomRecurringConfig();
  late Priority _selectedPriority;
  late TaskType _selectedType;
  final List<Member> _selectedMembers = [];

  // New Fields
  late String _selectedNotification;
  final Map<String, bool> customReminders = {};
  late String _selectedComplexity;
  late String _selectedWorkload;
  late String _selectedRisk;
  final List<SubTask> _subtasks = [];
  bool _isSubtasksExpanded = false;
  // สถานะแสดงความผิดพลาดกรณีที่สมาชิกกลุ่มมีจำนวนน้อยกว่าที่กำหนด (ขั้นต่ำ 2 คน)
  bool _showGroupValidationError = false;
  // สถานะแสดงความผิดพลาดกรณีแอดสมาชิกกลุ่มแล้ว แต่เว้นรายละเอียดงานเป็นค่าว่าง
  bool _showMemberValidationError = false;

  @override
  void initState() {
    super.initState();

    final task = widget.task;
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    _titleController = TextEditingController(text: task?.title ?? '');
    _descriptionController = TextEditingController(
      text: task?.description ?? '',
    );

    String mapCategoryToThai(String cat) {
      switch (cat.toLowerCase()) {
        case 'general':
          return 'ทั่วไป';
        case 'personal':
          return 'ออกแบบ';
        case 'design':
          return 'ออกแบบ';
        case 'development':
          return 'พัฒนา';
        case 'marketing':
          return 'การตลาด';
        case 'meeting':
          return 'ประชุม';
        case 'documentation':
          return 'เอกสาร';
        case 'presentation':
          return 'นำเสนอ';
        default:
          return cat.isNotEmpty ? cat : 'ทั่วไป';
      }
    }

    _selectedCategory = mapCategoryToThai(task?.category ?? 'ทั่วไป');
    _selectedLocation = task?.location ?? '';
    final initialDateTime = task?.dateTime ?? widget.initialDate;
    _selectedDate = initialDateTime ?? DateTime.now();
    _selectedTime = TimeOfDay.fromDateTime(task?.dateTime ?? DateTime.now());
    _isRecurring = task?.isRecurring ?? false;
    _selectedRecurringType = task?.recurringType ?? 'daily';
    _recurringDate = task?.recurringDate ?? _selectedDate;
    _recurringTime = _timeFromString(task?.recurringTime) ?? _selectedTime;
    if (task != null && task.isRecurring && task.recurringType == 'custom') {
      _customRecurringConfig = CustomRecurringConfig(
        mode: task.customRecurringMode ?? 'byDueDate',
        frequencyNum: task.customRecurringNum ?? 1,
        frequencyUnit: task.customRecurringUnit ?? 'สัปดาห์',
        selectedDays: task.customRecurringDays ?? const ['จ.', 'ศ.'],
        fixedDates: task.customRecurringFixedDates ?? const [],
      );
    }
    _selectedPriority = task?.priority ?? Priority.low;
    _selectedType = task?.type ?? widget.initialType ?? TaskType.personal;
    _selectedNotification = task?.notificationFormat ?? 'No Notification';
    customReminders.addAll(task?.customReminders ?? const {});

    // Map int to String for UI
    _selectedComplexity = _difficultyToString(task?.difficulty ?? 1);
    _selectedWorkload = _workloadToString(task?.workload ?? 1);
    _selectedRisk = _riskToString(task?.risk ?? 1);

    if (task != null) {
      _subtasks.addAll(task.subtasks);
      _isSubtasksExpanded = task.subtasks.isNotEmpty;
      // For group tasks, we need to populate members
      if (task.isGroup) {
        _selectedMembers.addAll(task.members);

        // Requirement: Automatically insert the Leader as the first item
        _ensureLeaderFirst(authProvider);
      }
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (authProvider.currentUser != null) {
          setState(() {
            _selectedMembers.add(Member.fromUser(authProvider.currentUser!));
          });
        }
      });
    }

    _subtaskFocusNode.addListener(() {
      if (_subtaskFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted && _subtaskKey.currentContext != null) {
            Scrollable.ensureVisible(
              _subtaskKey.currentContext!,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: 0.5,
            );
          }
        });
      }
    });

    _inlineSubtaskFocusNode.addListener(() {
      if (_inlineSubtaskFocusNode.hasFocus) {
        Future.delayed(const Duration(milliseconds: 250), () {
          if (mounted && _subtaskKey.currentContext != null) {
            Scrollable.ensureVisible(
              _subtaskKey.currentContext!,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              alignment: 0.5,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _subtaskController.dispose();
    _subtaskFocusNode.dispose();
    _inlineSubtaskController.dispose();
    _inlineSubtaskFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final onSurface = theme.colorScheme.onSurface;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
        decoration: BoxDecoration(
          color: theme.brightness == Brightness.dark
              ? AppColors.stormyNightBackground
              : theme.colorScheme.surface,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: theme.brightness == Brightness.light
                  ? AppColors.shadowLight
                  : Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle Bar
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

                // Header
                Padding(
                  padding: const EdgeInsets.all(AppConstants.paddingLarge),
                  child: Row(
                    children: [
                      Text(
                        widget.task != null ? 'แก้ไขภารกิจ' : 'สร้างภารกิจใหม่',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: onSurface,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.close,
                          color: onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),

                const Divider(height: 1),

                // Form
                Flexible(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      AppConstants.paddingLarge,
                      12,
                      AppConstants.paddingLarge,
                      95 + bottomInset, // Extra padding to keep clear distance from fixed button & keyboard
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Task Type Toggle
                          _buildTaskTypeToggle(),

                          const SizedBox(height: 13),

                          // Title Field
                          _buildTitleField(),

                          const SizedBox(height: 13),

                          // Description Field
                          _buildDescriptionField(),

                          const SizedBox(height: 13),

                          // Notification Format
                          _buildCustomReminderSection(),

                          const SizedBox(height: 13),

                          // Date & Time Row (ONLY 1 ROW!)
                          Row(
                            children: [
                              Expanded(child: _buildDateField()),
                              const SizedBox(width: 10),
                              Expanded(child: _buildTimeField()),
                            ],
                          ),

                          const SizedBox(height: 13),

                          if (_selectedType == TaskType.personal) ...[
                            _buildCombinedRatingsRow(),
                            const SizedBox(height: 13),
                          ],

                          _buildRecurringSection(),

                          const SizedBox(height: 13),

                          // Priority Selection
                          _buildPrioritySelection(),

                          const SizedBox(height: 13),

                          // Sub-tasks section
                          _buildSubtasksSection(),

                          // Group Tab Specific: Project Selection
                          if (_selectedType == TaskType.group) ...[
                            const SizedBox(height: 13),
                            _buildMemberSectionRedesigned(),
                          ],

                          const SizedBox(height: 12),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),

            // Fixed Submit Button at Bottom
            Positioned(
              left: AppConstants.paddingLarge,
              right: AppConstants.paddingLarge,
              bottom: AppConstants.paddingLarge + bottomInset,
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _createTask,
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.zero,
                    backgroundColor: AppColors.stormySkyBlue,
                    foregroundColor:
                        Theme.of(context).brightness == Brightness.dark
                        ? AppColors.stormyNightBackground
                        : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                        AppConstants.radiusLarge,
                      ),
                    ),
                    elevation: 4,
                    shadowColor:
                        (Theme.of(context).brightness == Brightness.light
                                ? AppColors.stormySkyBlue
                                : AppColors.stormySkyBlue)
                            .withValues(alpha: 0.4),
                  ),
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        widget.task != null ? 'อัปเดตภารกิจ' : 'สร้างภารกิจ',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_showGroupValidationError)
              Positioned(
                top: 85,
                left: AppConstants.paddingLarge,
                right: AppConstants.paddingLarge,
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.accentRed,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.15),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'ไม่สามารถสร้างภารกิจกลุ่มได้เนื่องจากยังไม่มีสมาชิกคนอื่นในโปรเจกต์',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 16,
                        ),
                        onPressed: () {
                          setState(() {
                            _showGroupValidationError = false;
                          });
                        },
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
              ),
          ],
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
              selectedValue: _selectedComplexity,
              options: ['ง่าย', 'ปานกลาง', 'ยาก'],
              onSelected: (val) => setState(() => _selectedComplexity = val),
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
              selectedValue: _selectedWorkload,
              options: ['น้อย', 'ปานกลาง', 'มาก'],
              onSelected: (val) => setState(() => _selectedWorkload = val),
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
              selectedValue: _selectedRisk,
              options: ['ไม่มี', 'ต่ำ', 'สูง'],
              onSelected: (val) => setState(() => _selectedRisk = val),
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
    int selectedIndex = options.indexOf(selectedValue);
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

  void _showEditLocationDialog() {
    final controller = TextEditingController(text: _selectedLocation);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark
            ? AppColors.stormyDarkSlate
            : theme.colorScheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'ระบุสถานที่',
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.stormyDarkSlate,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: TextStyle(
            color: isDark ? Colors.white : AppColors.stormyDarkSlate,
          ),
          decoration: InputDecoration(
            hintText: 'กรอกชื่อสถานที่...',
            hintStyle: TextStyle(
              color: isDark ? Colors.white38 : AppColors.stormyMutedBlueGrey,
            ),
            prefixIcon: Icon(
              Icons.location_on_outlined,
              color: isDark
                  ? AppColors.stormySkyBlue
                  : AppColors.stormyMutedBlueGrey,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark
                    ? AppColors.stormySkyBlue.withValues(alpha: 0.5)
                    : AppColors.stormyMutedBlueGrey,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.stormySkyBlue,
                width: 1.5,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              setState(() => _selectedLocation = '');
              Navigator.pop(context);
            },
            child: const Text(
              'ลบสถานที่',
              style: TextStyle(
                color: AppColors.accentRed,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.stormySkyBlue,
              foregroundColor: isDark
                  ? AppColors.stormyNightBackground
                  : Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            ),
            onPressed: () {
              setState(() => _selectedLocation = controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text(
              'บันทึก',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomReminderSection() {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final categories = [
      'ทั่วไป',
      'ออกแบบ',
      'พัฒนา',
      'การตลาด',
      'ประชุม',
      'เอกสาร',
      'นำเสนอ',
    ];
    final sortedReminderKeys = customReminders.keys.toList()
      ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'หมวดหมู่ / สถานที่ / การแจ้งเตือน',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isLight
                ? AppColors.stormyDarkSlate
                : theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              // 1. Category Dropdown Chip
              PopupMenuButton<String>(
                position: PopupMenuPosition.under,
                onSelected: (val) => setState(() => _selectedCategory = val),
                itemBuilder: (context) => categories.map((cat) {
                  return PopupMenuItem(
                    value: cat,
                    child: Text(
                      cat,
                      style: TextStyle(
                        fontWeight: cat == _selectedCategory
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  );
                }).toList(),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isLight
                        ? AppColors.stormyIceBlue
                        : AppColors.stormyDarkSlate,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.category_outlined,
                        size: 16,
                        color: isLight
                            ? AppColors.stormyDarkSlate
                            : Colors.white,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'หมวด: $_selectedCategory',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: isLight
                              ? AppColors.stormyDarkSlate
                              : Colors.white,
                        ),
                      ),
                      Icon(
                        Icons.arrow_drop_down,
                        size: 16,
                        color: isLight
                            ? AppColors.stormyDarkSlate
                            : Colors.white,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // 2. Location Chip
              InkWell(
                enableFeedback: false,
                onTap: _showEditLocationDialog,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: _selectedLocation.isNotEmpty
                        ? AppColors.primaryPurple
                        : (isLight
                              ? AppColors.stormyIceBlue
                              : AppColors.stormyDarkSlate),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_outlined,
                        size: 16,
                        color: _selectedLocation.isNotEmpty
                            ? Colors.white
                            : (isLight
                                  ? AppColors.stormyDarkSlate
                                  : Colors.white),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _selectedLocation.isNotEmpty
                            ? _selectedLocation
                            : '+ สถานที่',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: _selectedLocation.isNotEmpty
                              ? Colors.white
                              : (isLight
                                    ? AppColors.stormyDarkSlate
                                    : Colors.white),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // 3. Reminder Shortcuts
              _buildReminderShortcutButton(
                label: 'ก่อน 30 นาที',
                isSelected: customReminders.containsKey('30'),
                onTap: () => _addQuickReminder('30'),
              ),
              const SizedBox(width: 6),
              _buildReminderShortcutButton(
                label: 'ก่อน 1 ชม.',
                isSelected: customReminders.containsKey('60'),
                onTap: () => _addQuickReminder('60'),
              ),
              const SizedBox(width: 6),
              _buildReminderShortcutButton(
                label: 'ก่อน 24 ชม.',
                isSelected: customReminders.containsKey('1440'),
                onTap: () => _addQuickReminder('1440'),
              ),
              const SizedBox(width: 6),
              InkWell(
                enableFeedback: false,
                onTap: _showAddCustomReminderSheet,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isLight
                          ? AppColors.stormyMutedBlueGrey
                          : AppColors.stormySkyBlue,
                      width: 1.2,
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.add_rounded,
                        size: 16,
                        color: isLight
                            ? AppColors.stormyDarkSlate
                            : AppColors.stormySkyBlue,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'เพิ่ม',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isLight
                              ? AppColors.stormyDarkSlate
                              : AppColors.stormySkyBlue,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (sortedReminderKeys.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: sortedReminderKeys.map((minutesKey) {
              return InputChip(
                label: Text(_customReminderLabel(minutesKey)),
                onDeleted: () {
                  setState(() {
                    customReminders.remove(minutesKey);
                    _syncNotificationFormatFromCustomReminders();
                  });
                },
                deleteIcon: const Icon(Icons.close_rounded, size: 14),
                labelStyle: TextStyle(
                  color: isLight
                      ? AppColors.stormyDarkSlate
                      : AppColors.primaryBlue,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
                backgroundColor: isLight
                    ? AppColors.stormyIceBlue
                    : AppColors.primaryBlue.withValues(alpha: 0.1),
                deleteIconColor: isLight
                    ? AppColors.stormyDarkSlate
                    : AppColors.primaryBlue,
                side: BorderSide(
                  color: isLight
                      ? AppColors.stormyIceBlue
                      : AppColors.primaryBlue,
                  width: 1.0,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              );
            }).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildReminderShortcutButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final legacyActiveColor = AppColors.primaryBlue;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isLight
              ? (isSelected
                    ? AppColors.stormyDarkSlate
                    : AppColors.stormyIceBlue)
              : (isSelected
                    ? legacyActiveColor.withValues(alpha: 0.12)
                    : AppColors.stormyDarkSlate),
          borderRadius: BorderRadius.circular(20.0),
          border: isLight
              ? null
              : Border.all(
                  color: isSelected ? legacyActiveColor : Colors.transparent,
                  width: 1.5,
                ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: isLight
                ? (isSelected ? Colors.white : AppColors.stormyDarkSlate)
                : (isSelected ? legacyActiveColor : AppColors.stormyIceBlue),
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  void _addQuickReminder(String minutesKey) {
    setState(() {
      if (customReminders.containsKey(minutesKey)) {
        customReminders.remove(minutesKey);
      } else {
        customReminders[minutesKey] = false;
      }
      _syncNotificationFormatFromCustomReminders();
    });
  }

  Future<void> _showAddCustomReminderSheet() async {
    final taskDateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final result = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _CustomReminderSheetContent(taskDateTime: taskDateTime),
    );

    if (result != null) {
      if (mounted) {
        setState(() {
          customReminders[result.toString()] = false;
          _syncNotificationFormatFromCustomReminders();
        });
      }
    }
  }

  String _customReminderLabel(String minutesKey) {
    final minutes = int.tryParse(minutesKey) ?? 0;
    if (minutes >= 10080 && minutes % 10080 == 0) {
      return 'ล่วงหน้า ${minutes ~/ 10080} สัปดาห์';
    }
    if (minutes >= 1440 && minutes % 1440 == 0) {
      return 'ล่วงหน้า ${minutes ~/ 1440} วัน';
    }
    if (minutes >= 60 && minutes % 60 == 0) {
      return 'ล่วงหน้า ${minutes ~/ 60} ชั่วโมง';
    }
    return 'ล่วงหน้า $minutes นาที';
  }

  void _syncNotificationFormatFromCustomReminders() {
    _selectedNotification = customReminders.isEmpty
        ? 'No Notification'
        : 'Custom';
  }

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
                setState(() => _isSubtasksExpanded = !_isSubtasksExpanded),
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
                  if (_subtasks.isNotEmpty) ...[
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
                        '${_subtasks.length}',
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
                    _isSubtasksExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
          if (_isSubtasksExpanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Column(
                children: [
                  if (_subtasks.isNotEmpty)
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _subtasks.length,
                      itemBuilder: (context, index) {
                        final isEditingThis = _editingSubtaskIndex == index;

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
                                    controller: _inlineSubtaskController,
                                    focusNode: _inlineSubtaskFocusNode,
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
                                        _saveInlineSubtask(index),
                                  ),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  style: IconButton.styleFrom(
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    minimumSize: Size.zero,
                                    padding: EdgeInsets.zero,
                                  ),
                                  icon: const Icon(
                                    Icons.check,
                                    size: 18,
                                    color: AppColors.success,
                                  ),
                                  onPressed: () => _saveInlineSubtask(index),
                                  constraints: const BoxConstraints(
                                    minWidth: 26,
                                    minHeight: 26,
                                  ),
                                  padding: EdgeInsets.zero,
                                  tooltip: 'บันทึก',
                                ),
                                const SizedBox(width: 2),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  style: IconButton.styleFrom(
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    minimumSize: Size.zero,
                                    padding: EdgeInsets.zero,
                                  ),
                                  icon: const Icon(
                                    Icons.close,
                                    size: 18,
                                    color: AppColors.accentRed,
                                  ),
                                  onPressed: _cancelInlineSubtask,
                                  constraints: const BoxConstraints(
                                    minWidth: 26,
                                    minHeight: 26,
                                  ),
                                  padding: EdgeInsets.zero,
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
                                  _subtasks[index].title,
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.8),
                                  ),
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                style: IconButton.styleFrom(
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  minimumSize: Size.zero,
                                  padding: EdgeInsets.zero,
                                ),
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
                                    _editingSubtaskIndex = index;
                                    _inlineSubtaskController.text =
                                        _subtasks[index].title;
                                  });
                                  Future.microtask(() =>
                                      _inlineSubtaskFocusNode.requestFocus());
                                },
                                constraints: const BoxConstraints(
                                  minHeight: 28,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                              const SizedBox(width: 2),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                style: IconButton.styleFrom(
                                  tapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                  minimumSize: Size.zero,
                                  padding: EdgeInsets.zero,
                                ),
                                icon: const Icon(
                                  Icons.delete_outline,
                                  size: 18,
                                  color: AppColors.accentRed,
                                ),
                                onPressed: () =>
                                    setState(() => _subtasks.removeAt(index)),
                                constraints: const BoxConstraints(
                                  minWidth: 26,
                                  minHeight: 26,
                                ),
                                padding: EdgeInsets.zero,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  if (_subtasks.isNotEmpty) const SizedBox(height: 4),
                  Row(
                    key: _subtaskKey,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _subtaskController,
                          focusNode: _subtaskFocusNode,
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
                                : Colors.white,
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
                          onSubmitted: (val) => _addSubtask(),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton.filled(
                        onPressed: _addSubtask,
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

  void _addSubtask() {
    if (_subtaskController.text.isNotEmpty) {
      setState(() {
        _subtasks.add(SubTask(title: _subtaskController.text));
        _subtaskController.clear();
        _isSubtasksExpanded = true;
      });
    }
  }

  void _saveInlineSubtask(int index) {
    final newTitle = _inlineSubtaskController.text.trim();
    if (newTitle.isNotEmpty && index >= 0 && index < _subtasks.length) {
      setState(() {
        _subtasks[index] = _subtasks[index].copyWith(title: newTitle);
        _editingSubtaskIndex = null;
      });
    }
  }

  void _cancelInlineSubtask() {
    setState(() {
      _editingSubtaskIndex = null;
    });
  }

  Member? _leaderMember(AuthProvider authProvider) {
    final task = widget.task;
    final leaderId = task?.creatorId ?? authProvider.currentUser?.id;
    if (leaderId == null) return null;

    if (task != null) {
      for (final member in task.members) {
        if (member.id == leaderId) {
          return member;
        }
      }
    }

    final user = MockData.getUserById(leaderId) ?? authProvider.currentUser;
    if (user == null) return null;

    final leader = Member.fromUser(user);
    if (task == null) return leader;

    return leader.copyWith(
      taskTitle: task.title,
      description: task.description,
      difficulty: _difficultyToString(task.difficulty),
      workload: _workloadToString(task.workload),
      risk: _riskToString(task.risk),
      subTasks: task.subtasks.map((s) => s.title).toList().cast<String>(),
    );
  }

  void _ensureLeaderFirst(AuthProvider authProvider) {
    final leaderId = widget.task?.creatorId ?? authProvider.currentUser?.id;
    if (leaderId == null) return;

    final leaderIndex = _selectedMembers.indexWhere(
      (member) => member.id == leaderId,
    );
    if (leaderIndex > 0) {
      final leader = _selectedMembers.removeAt(leaderIndex);
      _selectedMembers.insert(0, leader);
      return;
    }

    if (leaderIndex == -1) {
      final leader = _leaderMember(authProvider);
      if (leader != null) {
        _selectedMembers.insert(0, leader);
      }
    }
  }

  void _updateMemberConfig(
    MemberConfigResult result,
    AuthProvider authProvider,
  ) {
    setState(() {
      // Step A (Clear Old): Locate the Previous Assignee and RESET all their task-related fields
      if (result.previousAssigneeId != null) {
        final int prevIndex = _selectedMembers.indexWhere(
          (m) => m.id == result.previousAssigneeId,
        );
        if (prevIndex != -1) {
          _selectedMembers[prevIndex] = _selectedMembers[prevIndex].copyWith(
            taskTitle: '',
            description: '',
            difficulty: 'Easy',
            workload: 'Small',
            risk: 'None',
            subTasks: [],
            score: '',
            coAssigneeIds: [],
          );
        }
      }

      // Step B (Update New): Locate the New Assignee and update them with copied data
      final int index = _selectedMembers.indexWhere(
        (Member m) => m.id == result.mainAssignee.id,
      );
      if (index != -1) {
        // Step B.1 (Clear Removed Co-assignees): Check who was removed
        final oldMainAssignee = _selectedMembers[index];
        final oldCoAssigneeIds = oldMainAssignee.coAssigneeIds;
        final newCoAssigneeIds = result.coAssigneeIds;

        final removedIds = oldCoAssigneeIds
            .where((id) => !newCoAssigneeIds.contains(id))
            .toList();
        for (String removedId in removedIds) {
          final removedIndex = _selectedMembers.indexWhere(
            (m) => m.id == removedId,
          );
          if (removedIndex != -1) {
            _selectedMembers[removedIndex] = _selectedMembers[removedIndex]
                .copyWith(
                  taskTitle: '',
                  description: '',
                  difficulty: 'Easy',
                  workload: 'Small',
                  risk: 'None',
                  subTasks: [],
                  score: '',
                  coAssigneeIds: [],
                );
          }
        }

        _selectedMembers[index] = result.mainAssignee;
      } else {
        // Step C: If the new assignee wasn't already in the list, add them
        _selectedMembers.add(result.mainAssignee);
      }

      // Syncing Co-assignees Logic
      for (Member coMember in result.coAssigneeMembers) {
        final List<String> syncedCoAssigneeIds = List.from(
          result.coAssigneeIds,
        );
        syncedCoAssigneeIds.remove(coMember.id);
        if (!syncedCoAssigneeIds.contains(result.mainAssignee.id)) {
          syncedCoAssigneeIds.add(result.mainAssignee.id);
        }

        final updatedCoFriend = coMember.copyWith(
          taskTitle: result.mainAssignee.taskTitle,
          description: result.mainAssignee.description,
          difficulty: result.mainAssignee.difficulty,
          workload: result.mainAssignee.workload,
          risk: result.mainAssignee.risk,
          subTasks: List.from(result.mainAssignee.subTasks),
          score: result.mainAssignee.score,
          coAssigneeIds: syncedCoAssigneeIds,
        );

        final int existingIndex = _selectedMembers.indexWhere(
          (m) => m.id == coMember.id,
        );
        if (existingIndex != -1) {
          _selectedMembers[existingIndex] = updatedCoFriend;
        } else {
          _selectedMembers.add(updatedCoFriend);
        }
      }
      _ensureLeaderFirst(authProvider);
      _showMemberValidationError = false;
    });
  }

  Widget _buildMemberSectionRedesigned() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;
    final leaderId = widget.task?.creatorId ?? currentUserId;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Column(
      key: _memberSectionKey,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'ผู้เข้าร่วม',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                if (_showMemberValidationError) ...[
                  const SizedBox(width: 6),
                  const Text(
                    '(กรุณากรอกข้อมูลมอบหมายงาน)',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ],
            ),
            InkWell(
              enableFeedback: false,
              onTap: _showMemberSelectionDialog,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.add_rounded,
                      size: 16,
                      color: isDark
                          ? AppColors.stormySkyBlue
                          : AppColors.stormySkyBlue,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      'เพิ่ม',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? AppColors.stormySkyBlue
                            : AppColors.stormySkyBlue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : (Theme.of(context).brightness == Brightness.light
                      ? AppColors.stormyOffWhite
                      : AppColors.backgroundLightGrey),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _showMemberValidationError
                  ? AppColors.error
                  : (isDark
                        ? Colors.grey[800]!
                        : (Theme.of(context).brightness == Brightness.light
                                  ? AppColors.stormyMutedBlueGrey
                                  : AppColors.backgroundDarkGrey)
                              .withValues(alpha: 0.5)),
              width: _showMemberValidationError ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: _selectedMembers.map((Member user) {
              final bool isLeader = user.id == leaderId;
              final bool isMe = user.id == currentUserId;

              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundImage: user.avatarUrl.isNotEmpty
                          ? NetworkImage(user.avatarUrl)
                          : null,
                      backgroundColor:
                          (Theme.of(context).brightness == Brightness.light
                                  ? AppColors.stormySkyBlue
                                  : AppColors.stormySkyBlue)
                              .withValues(alpha: 0.2),
                      child: user.avatarUrl.isEmpty
                          ? Text(
                              user.name[0],
                              style: TextStyle(
                                color:
                                    (Theme.of(context).brightness ==
                                        Brightness.light
                                    ? AppColors.stormySkyBlue
                                    : AppColors.stormySkyBlue),
                                fontWeight: FontWeight.bold,
                              ),
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  user.name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (isLeader)
                                Container(
                                  margin: const EdgeInsets.only(left: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        (Theme.of(context).brightness ==
                                                    Brightness.light
                                                ? AppColors.stormySkyBlue
                                                : AppColors.stormySkyBlue)
                                            .withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color:
                                          (Theme.of(context).brightness ==
                                              Brightness.light
                                          ? AppColors.stormySkyBlue
                                          : AppColors.stormySkyBlue),
                                      width: 0.5,
                                    ),
                                  ),
                                  child: Text(
                                    'หัวหน้าภารกิจ',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          (Theme.of(context).brightness ==
                                              Brightness.light
                                          ? AppColors.stormySkyBlue
                                          : AppColors.stormySkyBlue),
                                    ),
                                  ),
                                )
                              else if (isMe)
                                Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Text(
                                    '(Me)',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          (Theme.of(context).brightness ==
                                              Brightness.light
                                          ? AppColors.stormySkyBlue
                                          : AppColors.stormySkyBlue),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (user.taskTitle != null &&
                              user.taskTitle!.isNotEmpty)
                            Text(
                              '${user.taskTitle} (${user.difficulty})',
                              style: TextStyle(
                                fontSize: 12,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.6,
                                ),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            )
                          else if (!isLeader && _showMemberValidationError)
                            const Text(
                              '(ยังไม่ได้กรอกรายละเอียดงาน)',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.error,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () async {
                        final MemberConfigResult?
                        result = await showModalBottomSheet<MemberConfigResult>(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (context) => MemberConfigSheet(
                            memberTask: user,
                            allSelectedMembers: _selectedMembers,
                            isMe: isLeader || isMe,
                            isLeader: isLeader,
                            task: widget.task,
                            onSave: (MemberConfigResult result) {
                              _updateMemberConfig(result, authProvider);
                            },
                            onDelete: () {
                              // Requirement: Prevent Leader from being deleted
                              if (isLeader) return;

                              setState(() {
                                _selectedMembers.removeWhere(
                                  (Member m) => m.id == user.id,
                                );
                              });
                              Navigator.pop(context);
                            },
                          ),
                        );

                        if (result != null) {
                          _updateMemberConfig(result, authProvider);
                        }
                      },
                      icon: Icon(
                        Icons.edit_outlined,
                        size: 20,
                        color: (Theme.of(context).brightness == Brightness.light
                            ? AppColors.stormyMutedBlueGrey
                            : AppColors.textSecondary),
                      ),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  void _showMemberSelectionDialog() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final leaderId = widget.task?.creatorId ?? authProvider.currentUser?.id;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: theme.colorScheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                'เลือกผู้เข้าร่วม',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.9)
                      : theme.colorScheme.onSurface,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: FutureBuilder<List<User>>(
                  future: taskProvider.getRealFriendsList(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return SizedBox(
                        height: 120,
                        child: Center(
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              (Theme.of(context).brightness == Brightness.light
                                  ? AppColors.stormySkyBlue
                                  : AppColors.stormySkyBlue),
                            ),
                          ),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'เกิดข้อผิดพลาดในการโหลดข้อมูลเพื่อน',
                          style: TextStyle(
                            color: Colors.red[400],
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    final friendsList = snapshot.data ?? [];
                    if (friendsList.isEmpty) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 32),
                        child: Text(
                          'ไม่มีรายชื่อเพื่อนในระบบ',
                          style: TextStyle(
                            color:
                                (Theme.of(context).brightness ==
                                    Brightness.light
                                ? AppColors.stormyMutedBlueGrey
                                : AppColors.textSecondary),
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }

                    return ListView.builder(
                      shrinkWrap: true,
                      itemCount: friendsList.length,
                      itemBuilder: (context, index) {
                        final friend = friendsList[index];
                        final isSelected = _selectedMembers.any(
                          (m) => m.id == friend.id,
                        );
                        final isLeader = friend.id == leaderId;

                        return CheckboxListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 4,
                          ),
                          activeColor:
                              (Theme.of(context).brightness == Brightness.light
                              ? AppColors.stormySkyBlue
                              : AppColors.stormySkyBlue),
                          checkboxShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          secondary: CircleAvatar(
                            radius: 20,
                            backgroundColor:
                                (Theme.of(context).brightness ==
                                            Brightness.light
                                        ? AppColors.stormySkyBlue
                                        : AppColors.stormySkyBlue)
                                    .withValues(alpha: 0.15),
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
                                                style: TextStyle(
                                                  color:
                                                      (Theme.of(
                                                            context,
                                                          ).brightness ==
                                                          Brightness.light
                                                      ? AppColors.stormySkyBlue
                                                      : AppColors
                                                            .stormySkyBlue),
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
                                        style: TextStyle(
                                          color:
                                              (Theme.of(context).brightness ==
                                                  Brightness.light
                                              ? AppColors.stormySkyBlue
                                              : AppColors.stormySkyBlue),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                          title: Text(
                            friend.name,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          subtitle: isLeader
                              ? Text(
                                  'หัวหน้าภารกิจ',
                                  style: TextStyle(
                                    color:
                                        (Theme.of(context).brightness ==
                                            Brightness.light
                                        ? AppColors.stormySkyBlue
                                        : AppColors.stormySkyBlue),
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              : null,
                          value: isSelected,
                          enabled: !isLeader,
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                _selectedMembers.add(Member.fromUser(friend));
                              } else {
                                _selectedMembers.removeWhere(
                                  (m) => m.id == friend.id,
                                );
                              }
                              _ensureLeaderFirst(authProvider);
                            });
                            setState(() {
                              if (_selectedMembers.length > 1) {
                                _showGroupValidationError = false;
                              }
                            }); // Update main widget
                          },
                        );
                      },
                    );
                  },
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'เสร็จ',
                    style: TextStyle(
                      color: (Theme.of(context).brightness == Brightness.light
                          ? AppColors.stormySkyBlue
                          : AppColors.stormySkyBlue),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildTaskTypeToggle() {
    // Requirement: If editing, show only the current type and disable toggle
    if (widget.task != null) {
      final bool isPersonal = _selectedType == TaskType.personal;
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light
              ? AppColors.stormyIceBlue.withValues(alpha: 0.5)
              : AppColors.stormyDarkSlate,
          borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isPersonal ? Icons.person_outline : Icons.people_outline,
              size: 20,
              color: isPersonal
                  ? (Theme.of(context).brightness == Brightness.light
                        ? AppColors.stormySkyBlue
                        : AppColors.stormySkyBlue)
                  : (Theme.of(context).brightness == Brightness.light
                        ? AppColors.stormySkyBlue
                        : AppColors.stormySkyBlue),
            ),
            const SizedBox(width: 8),
            Text(
              isPersonal ? 'ภารกิจส่วนตัว' : 'ภารกิจกลุ่ม',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isPersonal
                    ? (Theme.of(context).brightness == Brightness.light
                          ? AppColors.stormySkyBlue
                          : AppColors.stormySkyBlue)
                    : (Theme.of(context).brightness == Brightness.light
                          ? AppColors.stormySkyBlue
                          : AppColors.stormySkyBlue),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.light
            ? AppColors.stormyIceBlue
            : AppColors.stormyDarkSlate,
        borderRadius: BorderRadius.circular(AppConstants.radiusMedium),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedType = TaskType.personal;
                _selectedMembers
                    .clear(); // Clear members when switching to Personal
                _showGroupValidationError = false;
                _showMemberValidationError = false;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedType == TaskType.personal
                      ? (Theme.of(context).brightness == Brightness.light
                            ? AppColors.backgroundWhite
                            : Theme.of(context).colorScheme.surface)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                  boxShadow: _selectedType == TaskType.personal
                      ? [
                          BoxShadow(
                            color:
                                (Theme.of(context).brightness ==
                                            Brightness.light
                                        ? AppColors.stormySkyBlue
                                        : AppColors.stormySkyBlue)
                                    .withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.person_outline,
                      size: 18,
                      color: _selectedType == TaskType.personal
                          ? (Theme.of(context).brightness == Brightness.light
                                ? AppColors.stormySkyBlue
                                : AppColors.stormySkyBlue)
                          : (Theme.of(context).brightness == Brightness.light
                                ? AppColors.stormyMutedBlueGrey
                                : AppColors.textLight),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ส่วนตัว',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _selectedType == TaskType.personal
                            ? (Theme.of(context).brightness == Brightness.light
                                  ? AppColors.stormySkyBlue
                                  : AppColors.stormySkyBlue)
                            : (Theme.of(context).brightness == Brightness.light
                                  ? AppColors.stormyMutedBlueGrey
                                  : AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() {
                _selectedType = TaskType.group;
                _showGroupValidationError = false;
                _showMemberValidationError = false;
                // Re-add current user if they were cleared when switching to Personal
                final authProvider = Provider.of<AuthProvider>(
                  context,
                  listen: false,
                );
                if (authProvider.currentUser != null &&
                    !_selectedMembers.any(
                      (m) => m.id == authProvider.currentUser!.id,
                    )) {
                  _selectedMembers.insert(
                    0,
                    Member.fromUser(authProvider.currentUser!),
                  );
                }
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: _selectedType == TaskType.group
                      ? (Theme.of(context).brightness == Brightness.light
                            ? AppColors.backgroundWhite
                            : Theme.of(context).colorScheme.surface)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppConstants.radiusSmall),
                  boxShadow: _selectedType == TaskType.group
                      ? [
                          BoxShadow(
                            color:
                                (Theme.of(context).brightness ==
                                            Brightness.light
                                        ? AppColors.stormySkyBlue
                                        : AppColors.stormySkyBlue)
                                    .withValues(alpha: 0.1),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.people_outline,
                      size: 18,
                      color: _selectedType == TaskType.group
                          ? (Theme.of(context).brightness == Brightness.light
                                ? AppColors.stormySkyBlue
                                : AppColors.stormySkyBlue)
                          : (Theme.of(context).brightness == Brightness.light
                                ? AppColors.stormyMutedBlueGrey
                                : AppColors.textLight),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'กลุ่ม',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _selectedType == TaskType.group
                            ? (Theme.of(context).brightness == Brightness.light
                                  ? AppColors.stormySkyBlue
                                  : AppColors.stormySkyBlue)
                            : (Theme.of(context).brightness == Brightness.light
                                  ? AppColors.stormyMutedBlueGrey
                                  : AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    final theme = Theme.of(context);
    return TextFormField(
      key: _titleFieldKey,
      controller: _titleController,
      style: TextStyle(
        color: theme.brightness == Brightness.dark
            ? Colors.white
            : theme.colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: theme.brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : AppColors.backgroundWhite,
        labelText: 'ชื่อภารกิจ',
        labelStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        hintText: 'ใส่ชื่อภารกิจ',
        hintStyle: TextStyle(
          color: theme.brightness == Brightness.dark
              ? AppColors.stormyMutedBlueGrey
              : theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        prefixIcon: Icon(
          Icons.title,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(
            color: theme.brightness == Brightness.light
                ? AppColors.stormyMutedBlueGrey
                : AppColors.stormyMutedBlueGrey.withValues(alpha: 0.6),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(
            color: theme.brightness == Brightness.light
                ? AppColors.stormyDarkSlate
                : AppColors.stormySkyBlue,
            width: 1.5,
          ),
        ),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'กรุณาใส่ชื่อภารกิจ';
        }
        return null;
      },
    );
  }

  Widget _buildDescriptionField() {
    final theme = Theme.of(context);
    return TextFormField(
      controller: _descriptionController,
      minLines: 1,
      maxLines: 3,
      style: TextStyle(
        fontSize: 14,
        color: theme.brightness == Brightness.dark
            ? Colors.white
            : theme.colorScheme.onSurface,
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: theme.brightness == Brightness.dark
            ? AppColors.stormyDarkSlate
            : AppColors.backgroundWhite,
        labelText: 'รายละเอียด',
        labelStyle: TextStyle(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
        ),
        hintText: 'ใส่รายละเอียดภารกิจ (ไม่บังคับ)',
        hintStyle: TextStyle(
          color: theme.brightness == Brightness.dark
              ? AppColors.stormyMutedBlueGrey
              : theme.colorScheme.onSurface.withValues(alpha: 0.4),
        ),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        alignLabelWithHint: true,
        prefixIcon: Icon(
          Icons.description,
          size: 20,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(
            color: theme.brightness == Brightness.light
                ? AppColors.stormyMutedBlueGrey
                : AppColors.stormyMutedBlueGrey.withValues(alpha: 0.6),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide(
            color: theme.brightness == Brightness.light
                ? AppColors.stormyDarkSlate
                : AppColors.stormySkyBlue,
            width: 1.5,
          ),
        ),
      ),
    );
  }

  Widget _buildDateField() {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    final today = DateTime.now();
    final firstDate = DateTime(2024, 1, 1);
    final defaultLastDate = DateTime(today.year + 1, today.month, today.day);
    final lastDate = _selectedDate.isAfter(defaultLastDate)
        ? DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)
        : defaultLastDate;

    return Container(
      decoration: isLight
          ? BoxDecoration(
              color: AppColors.stormyOffWhite,
              borderRadius: BorderRadius.circular(12.0),
            )
          : null,
      child: InkWell(
        enableFeedback: false,
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: firstDate,
            lastDate: lastDate,
          );
          if (picked != null) {
            setState(() => _selectedDate = picked);
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            isDense: true,
            labelText: 'วันที่',
            floatingLabelBehavior: FloatingLabelBehavior.always,
            labelStyle: TextStyle(
              color: isLight
                  ? AppColors.stormyMutedBlueGrey
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            prefixIcon: Icon(
              Icons.calendar_today_outlined,
              size: 20,
              color: isLight
                  ? AppColors.stormyMutedBlueGrey
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(
                color: isLight
                    ? AppColors.stormyMutedBlueGrey
                    : AppColors.stormyMutedBlueGrey.withValues(alpha: 0.6),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(
                color: isLight
                    ? AppColors.stormyDarkSlate
                    : AppColors.stormySkyBlue,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12.0,
              horizontal: 8.0,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
              maxLines: 1,
              style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeField() {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    return Container(
      decoration: isLight
          ? BoxDecoration(
              color: AppColors.stormyOffWhite,
              borderRadius: BorderRadius.circular(12.0),
            )
          : null,
      child: InkWell(
        enableFeedback: false,
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: _selectedTime,
          );
          if (picked != null) {
            setState(() => _selectedTime = picked);
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            isDense: true,
            labelText: 'เวลา',
            floatingLabelBehavior: FloatingLabelBehavior.always,
            labelStyle: TextStyle(
              color: isLight
                  ? AppColors.stormyMutedBlueGrey
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            prefixIcon: Icon(
              Icons.access_time_outlined,
              size: 20,
              color: isLight
                  ? AppColors.stormyMutedBlueGrey
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(
                color: isLight
                    ? AppColors.stormyMutedBlueGrey
                    : AppColors.stormyMutedBlueGrey.withValues(alpha: 0.6),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(
                color: isLight
                    ? AppColors.stormyDarkSlate
                    : AppColors.stormySkyBlue,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12.0,
              horizontal: 8.0,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _selectedTime.format(context),
              maxLines: 1,
              style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }

  String _getRecurringDisplayLabel() {
    if (!_isRecurring) return 'ไม่มี';

    final weekdayStr = _thaiShortWeekdaysList[_selectedDate.weekday - 1];
    final dayNum = _selectedDate.day;
    final monthStr = _thaiShortMonthsList[_selectedDate.month - 1];

    switch (_selectedRecurringType) {
      case 'daily':
        return 'ทุกวัน';
      case 'weekly':
        return 'รายสัปดาห์ ($weekdayStr)';
      case 'monthly':
        return 'รายเดือน (วันที่ $dayNum)';
      case 'yearly':
        return 'รายปี (เมื่อวันที่ $dayNum $monthStr)';
      case 'weekdays':
        return 'ทุกวันทำงานในสัปดาห์ (จันทร์ - ศุกร์)';
      case 'custom':
        return 'กำหนดเอง (${_customRecurringConfig.getDisplayText()})';
      default:
        return 'ไม่มี';
    }
  }

  void _showRecurringBottomSheet() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final weekdayStr = _thaiShortWeekdaysList[_selectedDate.weekday - 1];
    final dayNum = _selectedDate.day;
    final monthStr = _thaiShortMonthsList[_selectedDate.month - 1];

    final options = [
      {'key': 'none', 'label': 'ไม่มี'},
      {'key': 'daily', 'label': 'ทุกวัน'},
      {'key': 'weekly', 'label': 'รายสัปดาห์ ($weekdayStr)'},
      {'key': 'monthly', 'label': 'รายเดือน (วันที่ $dayNum)'},
      {'key': 'yearly', 'label': 'รายปี (เมื่อวันที่ $dayNum $monthStr)'},
      {'key': 'weekdays', 'label': 'ทุกวันทำงานในสัปดาห์ (จันทร์ - ศุกร์)'},
      {'key': 'custom', 'label': 'กำหนดเอง'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.stormyNightBackground
                    : theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ซ้ำ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...options.map((opt) {
                      final key = opt['key']!;
                      final label = opt['label']!;

                      final isSelected = key == 'none'
                          ? !_isRecurring
                          : (_isRecurring && _selectedRecurringType == key);

                      final isDividerBefore = key == 'weekdays';

                      return Column(
                        children: [
                          if (isDividerBefore)
                            Divider(
                              height: 16,
                              thickness: 0.8,
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.12,
                              ),
                            ),
                          InkWell(
                            enableFeedback: false,
                            onTap: () async {
                              if (key == 'none') {
                                setSheetState(() {
                                  _isRecurring = false;
                                });
                                setState(() {
                                  _isRecurring = false;
                                });
                              } else if (key == 'custom') {
                                final result =
                                    await Navigator.push<CustomRecurringConfig>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            CustomRecurringModal(
                                              initialConfig:
                                                  _customRecurringConfig,
                                            ),
                                      ),
                                    );
                                if (result != null) {
                                  setSheetState(() {
                                    _isRecurring = true;
                                    _selectedRecurringType = 'custom';
                                    _customRecurringConfig = result;
                                  });
                                  setState(() {
                                    _isRecurring = true;
                                    _selectedRecurringType = 'custom';
                                    _customRecurringConfig = result;
                                  });
                                }
                              } else {
                                setSheetState(() {
                                  _isRecurring = true;
                                  _selectedRecurringType = key;
                                });
                                setState(() {
                                  _isRecurring = true;
                                  _selectedRecurringType = key;
                                });
                              }
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 8,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      label,
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: isSelected
                                            ? FontWeight.w600
                                            : FontWeight.normal,
                                        color: isSelected
                                            ? (isDark
                                                  ? AppColors.stormySkyBlue
                                                  : AppColors.stormySkyBlue)
                                            : theme.colorScheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_rounded,
                                      color: isDark
                                          ? AppColors.stormySkyBlue
                                          : AppColors.stormySkyBlue,
                                      size: 20,
                                    ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'เสร็จ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: isDark
                                ? AppColors.stormySkyBlue
                                : AppColors.stormySkyBlue,
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
      },
    );
  }

  Widget _buildRecurringSection() {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return Container(
      decoration: isLight
          ? BoxDecoration(
              color: AppColors.stormyOffWhite,
              borderRadius: BorderRadius.circular(12.0),
            )
          : null,
      child: InkWell(
        enableFeedback: false,
        onTap: _showRecurringBottomSheet,
        borderRadius: BorderRadius.circular(12.0),
        child: InputDecorator(
          decoration: InputDecoration(
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(
                color: isLight
                    ? AppColors.stormyMutedBlueGrey
                    : AppColors.stormyMutedBlueGrey.withValues(alpha: 0.6),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(
                color: isLight
                    ? AppColors.stormyDarkSlate
                    : AppColors.stormySkyBlue,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16.0,
              horizontal: 12.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.sync_rounded,
                color: isLight
                    ? AppColors.stormyMutedBlueGrey
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 12),
              Text(
                'ซ้ำ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getRecurringDisplayLabel(),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 15,
                    color: isLight
                        ? AppColors.stormyMutedBlueGrey
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isLight
                    ? AppColors.stormyMutedBlueGrey
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getPriorityDisplayLabel(Priority priority) {
    switch (priority) {
      case Priority.low:
        return 'ต่ำ';
      case Priority.medium:
        return 'ปานกลาง';
      case Priority.high:
        return 'สูง';
      case Priority.urgent:
        return 'ด่วน';
    }
  }

  void _showPriorityBottomSheet() {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final options = [
      {'priority': Priority.low, 'label': 'ต่ำ'},
      {'priority': Priority.medium, 'label': 'ปานกลาง'},
      {'priority': Priority.high, 'label': 'สูง'},
      {'priority': Priority.urgent, 'label': 'ด่วน'},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.stormyNightBackground
                    : theme.colorScheme.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.2,
                          ),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'ความสำคัญ',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ...options.map((opt) {
                      final priority = opt['priority'] as Priority;
                      final label = opt['label'] as String;
                      final isSelected = _selectedPriority == priority;

                      return InkWell(
                        enableFeedback: false,
                        onTap: () {
                          setSheetState(() {
                            _selectedPriority = priority;
                          });
                          setState(() {
                            _selectedPriority = priority;
                          });
                        },
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 8,
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isSelected
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: isSelected
                                        ? AppColors.stormySkyBlue
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                const Icon(
                                  Icons.check_rounded,
                                  color: AppColors.stormySkyBlue,
                                  size: 20,
                                ),
                            ],
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text(
                          'เสร็จ',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.stormySkyBlue,
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
      },
    );
  }

  Widget _buildPrioritySelection() {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

    return Container(
      decoration: isLight
          ? BoxDecoration(
              color: AppColors.stormyOffWhite,
              borderRadius: BorderRadius.circular(12.0),
            )
          : null,
      child: InkWell(
        enableFeedback: false,
        onTap: _showPriorityBottomSheet,
        borderRadius: BorderRadius.circular(12.0),
        child: InputDecorator(
          decoration: InputDecoration(
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(
                color: isLight
                    ? AppColors.stormyMutedBlueGrey
                    : AppColors.stormyMutedBlueGrey.withValues(alpha: 0.6),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(
                color: isLight
                    ? AppColors.stormyDarkSlate
                    : AppColors.stormySkyBlue,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16.0,
              horizontal: 12.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.flag_outlined,
                color: isLight
                    ? AppColors.stormyMutedBlueGrey
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 12),
              Text(
                'ความสำคัญ',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _getPriorityDisplayLabel(_selectedPriority),
                  textAlign: TextAlign.right,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 15,
                    color: isLight
                        ? AppColors.stormyMutedBlueGrey
                        : theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: isLight
                    ? AppColors.stormyMutedBlueGrey
                    : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _difficultyToString(int value) {
    switch (value) {
      case 1:
        return 'ง่าย';
      case 2:
        return 'ปานกลาง';
      case 3:
        return 'ยาก';
      default:
        return 'ปานกลาง';
    }
  }

  int _difficultyToInt(String value) {
    switch (value) {
      case 'ง่าย':
        return 1;
      case 'ปานกลาง':
        return 2;
      case 'ยาก':
        return 3;
      default:
        return 2;
    }
  }

  String _workloadToString(int value) {
    switch (value) {
      case 1:
        return 'น้อย';
      case 2:
        return 'ปานกลาง';
      case 3:
        return 'มาก';
      default:
        return 'ปานกลาง';
    }
  }

  int _workloadToInt(String value) {
    switch (value) {
      case 'น้อย':
        return 1;
      case 'ปานกลาง':
        return 2;
      case 'มาก':
        return 3;
      default:
        return 2;
    }
  }

  String _riskToString(int value) {
    switch (value) {
      case 1:
        return 'ไม่มี';
      case 2:
        return 'ต่ำ';
      case 3:
        return 'สูง';
      default:
        return 'ไม่มี';
    }
  }

  int _riskToInt(String value) {
    switch (value) {
      case 'ไม่มี':
        return 1;
      case 'ต่ำ':
        return 2;
      case 'สูง':
        return 3;
      default:
        return 1;
    }
  }

  TimeOfDay? _timeFromString(String? value) {
    if (value == null || value.isEmpty) return null;
    final parts = value.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return TimeOfDay(hour: hour, minute: minute);
  }

  String _formatTimeForStorage(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  bool _isSaving = false;

  void _triggerGroupValidationError() {
    setState(() {
      _showGroupValidationError = true;
      _isSaving = false;
    });

    // ให้แบนเนอร์ข้อผิดพลาดจางหายไปเองอัตโนมัติเมื่อครบ 20 วินาที
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted && _showGroupValidationError) {
        setState(() {
          _showGroupValidationError = false;
        });
      }
    });
  }

  void _scrollToKey(GlobalKey key) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = key.currentContext;
      if (context != null) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          alignment: 0.1,
        );
      }
    });
  }

  void _createTask() {
    final connectivity = context.read<ConnectivityProvider>();
    if (connectivity.isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่มีการเชื่อมต่ออินเทอร์เน็ต ไม่สามารถดำเนินการได้'),
        ),
      );
      return;
    }

    if (_isSaving) return;

    final bool isFormValid = _formKey.currentState!.validate();
    if (!isFormValid) {
      _scrollToKey(_titleFieldKey);
      return;
    }

    final taskProvider = Provider.of<TaskProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    if (_selectedType == TaskType.group) {
      if (_selectedMembers.length <= 1) {
        _triggerGroupValidationError();
        _scrollToKey(_memberSectionKey);
        return;
      }

      final selectedProjId =
          widget.task?.projectId ?? taskProvider.selectedProject?.id;
      if (selectedProjId != null) {
        final project = taskProvider.getProjectById(selectedProjId);
        if (project != null && project.memberIds.length <= 1) {
          _triggerGroupValidationError();
          _scrollToKey(_memberSectionKey);
          return;
        }
      }

      // ตรวจสอบว่ามีสมาชิกที่ถูกเพิ่มเข้ามา (ยกเว้นหัวหน้างาน) คนใดที่รายละเอียดงานเป็นค่าว่างหรือไม่
      final leaderId = widget.task?.creatorId ?? authProvider.currentUser?.id;
      final hasEmptyMember = _selectedMembers.any(
        (m) =>
            m.id != leaderId &&
            (m.taskTitle == null || m.taskTitle!.trim().isEmpty),
      );

      // หากตรวจพบว่ามีสมาชิกที่รายละเอียดงานเป็นค่าว่าง
      if (hasEmptyMember) {
        setState(() {
          _showMemberValidationError =
              true; // เปิดใช้งานสถานะการแสดงเตือนสีแดงใน UI
          _isSaving = false; // ปิดสถานะการกำลังบันทึกเพื่อให้กดเซฟใหม่ได้
        });
        // แสดง Snackbar แจ้งเตือนสีแดงทันทีบริเวณด้านล่างสุดของหน้าจอ
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'ไม่สามารถสร้างภารกิจได้: กรุณากรอกรายละเอียดงานของสมาชิกให้ครบถ้วน!',
            ),
            backgroundColor: AppColors.error,
          ),
        );
        _scrollToKey(_memberSectionKey);
        return; // ปฏิเสธการทำงานไม่ให้บันทึกข้อมูลสำเร็จ
      }
    }

    setState(() {
      _isSaving = true;
    });

    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final isDateTimeChanged = widget.task == null ||
        !widget.task!.dateTime.isAtSameMomentAs(dateTime);

    final bool resetNotified = isDateTimeChanged;

    final Map<String, bool> finalCustomReminders = isDateTimeChanged
        ? customReminders.map((k, v) => MapEntry(k, false))
        : Map<String, bool>.from(customReminders);

    final updatedTask = Task(
      id: widget.task?.id ?? 'task_${DateTime.now().millisecondsSinceEpoch}',
      title: _titleController.text,
      description: _descriptionController.text,
      category: _selectedCategory,
      location: _selectedLocation.isEmpty ? null : _selectedLocation,
      dateTime: dateTime,
      priority: _selectedPriority,
      status: widget.task?.status ?? TaskStatus.inProgress,
      type: _selectedType,
      projectId: widget.task?.projectId,
      creatorId: widget.task?.creatorId ?? authProvider.currentUser!.id,
      assigneeIds: _selectedType == TaskType.personal
          ? [authProvider.currentUser!.id]
          : _selectedMembers
                .where((m) {
                  final lId =
                      widget.task?.creatorId ?? authProvider.currentUser!.id;
                  return m.id != lId ||
                      (m.taskTitle != null && m.taskTitle!.trim().isNotEmpty);
                })
                .map((m) => m.id)
                .toList(),
      members: _selectedType == TaskType.personal
          ? []
          : List<Member>.from(_selectedMembers),
      createdAt: widget.task?.createdAt ?? DateTime.now(),
      completedAt: widget.task?.completedAt,
      isDeleted: widget.task?.isDeleted ?? false,
      notificationFormat: _selectedNotification,
      customReminders: finalCustomReminders,
      isRecurring: _isRecurring,
      recurringType: _isRecurring ? _selectedRecurringType : 'daily',
      recurringDate: _isRecurring && _selectedRecurringType == 'custom'
          ? DateTime(
              _recurringDate.year,
              _recurringDate.month,
              _recurringDate.day,
            )
          : null,
      recurringTime: _isRecurring && _selectedRecurringType == 'custom'
          ? _formatTimeForStorage(_recurringTime)
          : null,
      customRecurringMode: _isRecurring && _selectedRecurringType == 'custom'
          ? _customRecurringConfig.mode
          : null,
      customRecurringNum: _isRecurring && _selectedRecurringType == 'custom'
          ? _customRecurringConfig.frequencyNum
          : null,
      customRecurringUnit: _isRecurring && _selectedRecurringType == 'custom'
          ? _customRecurringConfig.frequencyUnit
          : null,
      customRecurringDays: _isRecurring && _selectedRecurringType == 'custom'
          ? _customRecurringConfig.selectedDays
          : null,
      customRecurringFixedDates:
          _isRecurring && _selectedRecurringType == 'custom'
              ? _customRecurringConfig.fixedDates
              : null,
      notified1Week: resetNotified ? false : (widget.task?.notified1Week ?? false),
      notified1Day: resetNotified ? false : (widget.task?.notified1Day ?? false),
      notified1Hour: resetNotified ? false : (widget.task?.notified1Hour ?? false),
      notifiedExact: resetNotified ? false : (widget.task?.notifiedExact ?? false),
      notifiedFollowUp: resetNotified ? false : (widget.task?.notifiedFollowUp ?? false),
      difficulty: _difficultyToInt(_selectedComplexity),
      workload: _workloadToInt(_selectedWorkload),
      risk: _riskToInt(_selectedRisk),
      subtasks: List.from(_subtasks),
      comments: widget.task?.comments ?? [],
      attachments: widget.task?.attachments ?? [],
      deletedForUserIds: widget.task?.deletedForUserIds ?? const [],
      hiddenForUserIds: widget.task?.hiddenForUserIds ?? const [],
      submissionText: widget.task?.submissionText,
      submittedBy: widget.task?.submittedBy,
      submittedAt: widget.task?.submittedAt,
      awardedXP: widget.task?.awardedXP ?? 0,
      rewardBlocked: widget.task?.rewardBlocked ?? false,
      rewardBlockedReason: widget.task?.rewardBlockedReason,
      rewardBlockedAt: widget.task?.rewardBlockedAt,
      rewardBlockedBy: widget.task?.rewardBlockedBy,
      completionAgeSeconds: widget.task?.completionAgeSeconds,
    );

    if (widget.task != null) {
      taskProvider.updateTask(updatedTask);
    } else {
      taskProvider.addTask(updatedTask);
    }

    final rootContext = Navigator.of(context).context;
    final rootNavigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final isNewTask = widget.task == null;

    Navigator.pop(context, updatedTask);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final taskDate = DateTime(
      updatedTask.dateTime.year,
      updatedTask.dateTime.month,
      updatedTask.dateTime.day,
    );
    final isUpcoming = taskDate.isAfter(today);

    if (isNewTask && isUpcoming) {
      if (rootContext.mounted) {
        SnackBarUtils.showNavigationSnackBar(
          rootContext,
          message: 'สร้างภารกิจล่วงหน้าสำเร็จ!',
          actionLabel: 'ดูเร็วๆนี้',
          onNavigate: () {
            rootNavigator.pushNamed('/upcoming');
          },
        );
      }
    } else {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            isNewTask ? 'สร้างภารกิจสำเร็จ!' : 'อัปเดตภารกิจสำเร็จ!',
          ),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }
}

class EditMembersBottomSheet extends StatefulWidget {
  final List<String> initialMembers;

  const EditMembersBottomSheet({super.key, required this.initialMembers});

  @override
  State<EditMembersBottomSheet> createState() => _EditMembersBottomSheetState();
}

class _EditMembersBottomSheetState extends State<EditMembersBottomSheet> {
  late List<String> _currentMembers;

  @override
  void initState() {
    super.initState();
    _currentMembers = List.from(widget.initialMembers);
  }

  void _removeMember(String id) {
    // Requirement 3: Safety Check
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (id == authProvider.currentUser?.id) return;

    if (mounted) {
      setState(() {
        _currentMembers.remove(id);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final currentUserId = authProvider.currentUser?.id;

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: (Theme.of(context).brightness == Brightness.light
            ? AppColors.stormyOffWhite
            : AppColors.backgroundLightGrey),
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          // Handle Bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: (Theme.of(context).brightness == Brightness.light
                  ? AppColors.stormyMutedBlueGrey
                  : AppColors.backgroundDarkGrey),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.all(AppConstants.paddingLarge),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'แก้ไขรายชื่อผู้เข้าร่วม',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: (Theme.of(context).brightness == Brightness.light
                        ? AppColors.stormyDarkSlate
                        : AppColors.textPrimary),
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, _currentMembers),
                  child: Text(
                    'เสร็จสิ้น',
                    style: TextStyle(
                      color: (Theme.of(context).brightness == Brightness.light
                          ? AppColors.stormySkyBlue
                          : AppColors.stormySkyBlue),
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Member List
          Expanded(
            child: _currentMembers.isEmpty
                ? Center(
                    child: Text(
                      'ไม่มีรายชื่อผู้เข้าร่วม',
                      style: TextStyle(
                        color: (Theme.of(context).brightness == Brightness.light
                            ? AppColors.stormyMutedBlueGrey
                            : AppColors.textLight),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _currentMembers.length,
                    itemBuilder: (context, index) {
                      final userId = _currentMembers[index];
                      final user = MockData.getUserById(userId);
                      if (user == null) return const SizedBox.shrink();

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.check_circle,
                              color:
                                  (Theme.of(context).brightness ==
                                      Brightness.light
                                  ? AppColors.stormySkyBlue
                                  : AppColors.stormySkyBlue),
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            CircleAvatar(
                              radius: 20,
                              backgroundImage: user.avatarUrl.isNotEmpty
                                  ? NetworkImage(user.avatarUrl)
                                  : null,
                              backgroundColor:
                                  (Theme.of(context).brightness ==
                                              Brightness.light
                                          ? AppColors.stormySkyBlue
                                          : AppColors.stormySkyBlue)
                                      .withValues(alpha: 0.1),
                              child: user.avatarUrl.isEmpty
                                  ? Text(user.name[0])
                                  : null,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                user.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color:
                                      (Theme.of(context).brightness ==
                                          Brightness.light
                                      ? AppColors.stormyDarkSlate
                                      : AppColors.textPrimary),
                                ),
                              ),
                            ),
                            if (userId != currentUserId)
                              TextButton.icon(
                                onPressed: () => _removeMember(userId),
                                icon: const Icon(
                                  Icons.remove_circle_outline,
                                  color: AppColors.accentRed,
                                  size: 18,
                                ),
                                label: const Text(
                                  'นำออก',
                                  style: TextStyle(
                                    color: AppColors.accentRed,
                                    fontSize: 12,
                                  ),
                                ),
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                ),
                              )
                            else
                              Padding(
                                padding: EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  'หัวหน้า',
                                  style: TextStyle(
                                    color:
                                        (Theme.of(context).brightness ==
                                            Brightness.light
                                        ? AppColors.stormySkyBlue
                                        : AppColors.stormySkyBlue),
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Footer Button
          Padding(
            padding: const EdgeInsets.all(AppConstants.paddingLarge),
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context, _currentMembers);
              },
              icon: const Icon(Icons.add),
              label: const Text('เพิ่มผู้เข้าร่วม'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 56),
                foregroundColor:
                    (Theme.of(context).brightness == Brightness.light
                    ? AppColors.stormySkyBlue
                    : AppColors.primaryBlue),
                side: BorderSide(
                  color: (Theme.of(context).brightness == Brightness.light
                      ? AppColors.stormySkyBlue
                      : AppColors.primaryBlue),
                  width: 1.5,
                ),
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
}

class _CustomReminderSheetContent extends StatefulWidget {
  final DateTime taskDateTime;
  const _CustomReminderSheetContent({required this.taskDateTime});

  @override
  State<_CustomReminderSheetContent> createState() =>
      _CustomReminderSheetContentState();
}

class _CustomReminderSheetContentState
    extends State<_CustomReminderSheetContent> {
  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  String? errorText;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _selectedTime = TimeOfDay(hour: now.hour, minute: now.minute);
  }

  Widget _buildDateField() {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    return Container(
      decoration: isLight
          ? BoxDecoration(
              color: AppColors.stormyOffWhite,
              borderRadius: BorderRadius.circular(12.0),
            )
          : null,
      child: InkWell(
        enableFeedback: false,
        onTap: () async {
          final picked = await showDatePicker(
            context: context,
            initialDate: _selectedDate,
            firstDate: DateTime.now().subtract(const Duration(days: 365)),
            lastDate: DateTime(2101),
          );
          if (picked != null) {
            setState(() {
              _selectedDate = picked;
              errorText = null;
            });
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            isDense: true,
            labelText: 'วันที่',
            floatingLabelBehavior: FloatingLabelBehavior.always,
            labelStyle: TextStyle(
              color: isLight
                  ? AppColors.stormyMutedBlueGrey
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            prefixIcon: Icon(
              Icons.calendar_today_outlined,
              size: 20,
              color: isLight
                  ? AppColors.stormyMutedBlueGrey
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 36,
              minHeight: 36,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(
                color: isLight
                    ? AppColors.stormyMutedBlueGrey
                    : AppColors.stormyMutedBlueGrey.withValues(alpha: 0.6),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(
                color: isLight
                    ? AppColors.stormyDarkSlate
                    : AppColors.stormySkyBlue,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 12.0,
              horizontal: 8.0,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}',
              maxLines: 1,
              style: TextStyle(fontSize: 15, color: theme.colorScheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTimeField() {
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;
    return Container(
      decoration: isLight
          ? BoxDecoration(
              color: AppColors.stormyOffWhite,
              borderRadius: BorderRadius.circular(12.0),
            )
          : null,
      child: InkWell(
        enableFeedback: false,
        onTap: () async {
          final picked = await showTimePicker(
            context: context,
            initialTime: _selectedTime,
          );
          if (picked != null) {
            setState(() {
              _selectedTime = picked;
              errorText = null;
            });
          }
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: 'เวลา',
            floatingLabelBehavior: FloatingLabelBehavior.always,
            labelStyle: TextStyle(
              color: isLight
                  ? AppColors.stormyMutedBlueGrey
                  : theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
            prefixIcon: Icon(
              Icons.access_time_outlined,
              color: isLight
                  ? AppColors.stormyMutedBlueGrey
                  : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(
                color: isLight
                    ? AppColors.stormyMutedBlueGrey
                    : AppColors.stormyMutedBlueGrey.withValues(alpha: 0.6),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12.0),
              borderSide: BorderSide(
                color: isLight
                    ? AppColors.stormyDarkSlate
                    : AppColors.stormySkyBlue,
                width: 1.5,
              ),
            ),
            contentPadding: const EdgeInsets.symmetric(
              vertical: 16.0,
              horizontal: 12.0,
            ),
          ),
          child: Text(
            _selectedTime.format(context),
            style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurface),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'เพิ่มการแจ้งเตือนล่วงหน้า',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _buildDateField()),
                  const SizedBox(width: 12),
                  Expanded(child: _buildTimeField()),
                ],
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorText!,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    fontSize: 14,
                  ),
                ),
              ],
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    final reminderDateTime = DateTime(
                      _selectedDate.year,
                      _selectedDate.month,
                      _selectedDate.day,
                      _selectedTime.hour,
                      _selectedTime.minute,
                    );

                    final minutes = widget.taskDateTime
                        .difference(reminderDateTime)
                        .inMinutes;

                    if (minutes <= 0) {
                      setState(() {
                        errorText = 'ต้องตั้งเตือนก่อนเวลาของภารกิจ';
                      });
                      return;
                    }

                    if (mounted) {
                      Navigator.of(context).pop(minutes);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor:
                        (Theme.of(context).brightness == Brightness.light
                        ? AppColors.stormySkyBlue
                        : AppColors.stormySkyBlue),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'บันทึก',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
