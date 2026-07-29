import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../providers/auth_provider.dart';
import 'package:flutter/services.dart';

class CustomRecurringConfig {
  final String mode; // 'byDueDate' | 'byFixedDate'
  final int frequencyNum; // 1 to 365
  final String frequencyUnit; // 'วัน' | 'สัปดาห์' | 'เดือน' | 'ปี'
  final List<String> selectedDays; // e.g. ['จ.', 'ศ.']
  final List<DateTime>
  fixedDates; // list of selected DateTimes (date + time for each date)

  const CustomRecurringConfig({
    this.mode = 'byDueDate',
    this.frequencyNum = 1,
    this.frequencyUnit = 'สัปดาห์',
    this.selectedDays = const ['จ.', 'ศ.'],
    this.fixedDates = const [],
  });

  static String formatWeekdays(List<String> days) {
    if (days.length == 7) return 'ทุกวัน';
    const weekdaysOnly = ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.'];
    if (days.length == 5 && weekdaysOnly.every((d) => days.contains(d))) {
      return 'จ.-ศ.';
    }
    const allDays = ['อา.', 'จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.'];
    return allDays.where((d) => days.contains(d)).join(', ');
  }

  String getDisplayText() {
    if (mode == 'byFixedDate') {
      if (fixedDates.isEmpty) {
        return 'ตามวันที่กำหนด';
      }
      return 'กำหนดเอง (${fixedDates.length} วัน)';
    }
    if (frequencyUnit == 'สัปดาห์' && selectedDays.isNotEmpty) {
      final daysText = formatWeekdays(selectedDays);
      if (frequencyNum == 1) {
        return 'ทุกสัปดาห์ ($daysText)';
      }
      return 'ทุก $frequencyNum สัปดาห์ ($daysText)';
    }
    if (frequencyNum == 1) {
      return 'ทุก$frequencyUnit';
    }
    return 'ทุก $frequencyNum $frequencyUnit';
  }

  Map<String, dynamic> toMap() => {
    'mode': mode,
    'frequencyNum': frequencyNum,
    'frequencyUnit': frequencyUnit,
    'selectedDays': selectedDays,
    'fixedDates': fixedDates.map((d) => d.toIso8601String()).toList(),
  };

  factory CustomRecurringConfig.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const CustomRecurringConfig();
    return CustomRecurringConfig(
      mode: map['mode'] ?? 'byDueDate',
      frequencyNum: map['frequencyNum'] ?? 1,
      frequencyUnit: map['frequencyUnit'] ?? 'สัปดาห์',
      selectedDays: List<String>.from(map['selectedDays'] ?? ['จ.', 'ศ.']),
      fixedDates:
          (map['fixedDates'] as List<dynamic>?)
              ?.map((e) => DateTime.parse(e as String))
              .toList() ??
          const [],
    );
  }

  CustomRecurringConfig copyWith({
    String? mode,
    int? frequencyNum,
    String? frequencyUnit,
    List<String>? selectedDays,
    List<DateTime>? fixedDates,
  }) {
    return CustomRecurringConfig(
      mode: mode ?? this.mode,
      frequencyNum: frequencyNum ?? this.frequencyNum,
      frequencyUnit: frequencyUnit ?? this.frequencyUnit,
      selectedDays: selectedDays ?? this.selectedDays,
      fixedDates: fixedDates ?? this.fixedDates,
    );
  }
}

class CustomRecurringModal extends StatefulWidget {
  final CustomRecurringConfig initialConfig;

  const CustomRecurringModal({
    super.key,
    this.initialConfig = const CustomRecurringConfig(),
  });

  @override
  State<CustomRecurringModal> createState() => _CustomRecurringModalState();
}

class _CustomRecurringModalState extends State<CustomRecurringModal> {
  late String _selectedMode;
  late int _frequencyNum;
  late String _frequencyUnit;
  late List<String> _selectedDays;
  late List<DateTime> _fixedDates;
  late DateTime _calendarMonth;

  late FixedExtentScrollController _numController;
  late FixedExtentScrollController _unitController;

  static const List<String> _units = ['วัน', 'สัปดาห์', 'เดือน', 'ปี'];
  static const List<String> _allWeekdays = [
    'อา.',
    'จ.',
    'อ.',
    'พ.',
    'พฤ.',
    'ศ.',
    'ส.',
  ];

  @override
  void initState() {
    super.initState();
    _selectedMode = widget.initialConfig.mode;
    _frequencyNum = widget.initialConfig.frequencyNum.clamp(1, 365);
    _frequencyUnit = _units.contains(widget.initialConfig.frequencyUnit)
        ? widget.initialConfig.frequencyUnit
        : 'สัปดาห์';
    _selectedDays = List<String>.from(widget.initialConfig.selectedDays);
    _fixedDates = List<DateTime>.from(widget.initialConfig.fixedDates);
    _deduplicateFixedDates();

    final now = DateTime.now();
    _calendarMonth = DateTime(now.year, now.month, 1);

    _numController = FixedExtentScrollController(
      initialItem: _frequencyNum - 1,
    );
    _unitController = FixedExtentScrollController(
      initialItem: _units.indexOf(_frequencyUnit),
    );
  }

  @override
  void dispose() {
    _numController.dispose();
    _unitController.dispose();
    super.dispose();
  }

  void _playScrollSound() {
    final isSoundEnabled =
        context.read<AuthProvider>().currentUser?.isSoundEnabled ?? true;
    if (isSoundEnabled) {
      SystemSound.play(SystemSoundType.click);
    }
  }

  void _deduplicateFixedDates() {
    final Map<String, DateTime> uniqueMap = {};
    for (final date in _fixedDates) {
      final key = '${date.year}-${date.month}-${date.day}';
      if (!uniqueMap.containsKey(key)) {
        uniqueMap[key] = date;
      }
    }
    _fixedDates = uniqueMap.values.toList();
    _fixedDates.sort((a, b) => a.compareTo(b));
  }

  String _getSummaryText() {
    final config = CustomRecurringConfig(
      mode: _selectedMode,
      frequencyNum: _frequencyNum,
      frequencyUnit: _frequencyUnit,
      selectedDays: _selectedDays,
      fixedDates: _fixedDates,
    );
    return config.getDisplayText();
  }

  void _toggleDay(String day) {
    setState(() {
      if (_selectedDays.contains(day)) {
        _selectedDays.remove(day);
      } else {
        _selectedDays.add(day);
      }
    });
  }

  void _onSave() {
    _deduplicateFixedDates();
    final config = CustomRecurringConfig(
      mode: _selectedMode,
      frequencyNum: _frequencyNum,
      frequencyUnit: _frequencyUnit,
      selectedDays: _selectedDays,
      fixedDates: _fixedDates,
    );
    Navigator.pop(context, config);
  }

  void _showRecurringInfoDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final dialogBgColor = isDark
        ? AppColors.stormyNightBackground
        : Colors.white;
    final textColor = isDark ? Colors.white : theme.colorScheme.onSurface;

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: dialogBgColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'เกี่ยวกับประเภทการทำซ้ำ',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 16),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: textColor.withValues(alpha: 0.8),
                    ),
                    children: [
                      const TextSpan(
                        text: 'ตามวันถึงกำหนด: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(
                        text:
                            'ทำซ้ำเฉพาะตามกฎการซ้ำที่คุณตั้งค่าล่วงหน้าตามรูปแบบที่เรียบร้อย',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: textColor.withValues(alpha: 0.8),
                    ),
                    children: [
                      const TextSpan(
                        text: 'ตามวันที่กำหนด: ',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const TextSpan(
                        text: 'เลือกวันที่และเวลาเท่าที่คุณต้องการทำงาน',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.stormySkyBlue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: const Text(
                      'เข้าใจแล้ว',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final cardBgColor = isDark ? AppColors.stormyDarkSlate : Colors.white;
    final dialogBgColor = isDark
        ? AppColors.stormyNightBackground
        : Colors.white;
    final textColor = isDark ? Colors.white : theme.colorScheme.onSurface;
    final activeBlue = AppColors.stormySkyBlue;
    final boxBorderColor = isDark
        ? AppColors.stormyMutedBlueGrey.withValues(alpha: 0.6)
        : AppColors.stormyMutedBlueGrey;
    final unselectedPillBg = isDark
        ? AppColors.stormyNightBackground
        : AppColors.backgroundGrey;

    return Scaffold(
      backgroundColor: dialogBgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Header Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.close, color: textColor, size: 24),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'กำหนดเอง',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.check, color: activeBlue, size: 24),
                    onPressed: _onSave,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Dropdown Mode Selector
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: boxBorderColor),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                'รูปแบบการซ้ำ',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => _showRecurringInfoDialog(context),
                                child: Icon(
                                  Icons.help_outline,
                                  size: 18,
                                  color: textColor.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                          PopupMenuButton<String>(
                            position: PopupMenuPosition.under,
                            color: cardBgColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            onSelected: (val) {
                              setState(() => _selectedMode = val);
                            },
                            itemBuilder: (context) => [
                              PopupMenuItem<String>(
                                value: 'byDueDate',
                                child: Text(
                                  'ตามวันถึงกำหนด',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: textColor,
                                    fontWeight: _selectedMode == 'byDueDate'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'byFixedDate',
                                child: Text(
                                  'ตามวันที่กำหนด',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: textColor,
                                    fontWeight: _selectedMode == 'byFixedDate'
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                            ],
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _selectedMode == 'byFixedDate'
                                      ? 'ตามวันที่กำหนด'
                                      : 'ตามวันถึงกำหนด',
                                  style: TextStyle(
                                    fontSize: 15,
                                    color: textColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  color: textColor,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    if (_selectedMode == 'byDueDate') ...[
                      // Section 2: Frequency Wheel Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: boxBorderColor),
                          boxShadow: isDark
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ความถี่',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              height: 140,
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: Text(
                                        'ทุกๆ',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w500,
                                          color: textColor.withValues(
                                            alpha: 0.8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: CupertinoPicker(
                                      scrollController: _numController,
                                      itemExtent: 40,
                                      selectionOverlay: const SizedBox.shrink(),
                                      onSelectedItemChanged: (index) {
                                        setState(() {
                                          _frequencyNum = index + 1;
                                        });
                                        _playScrollSound();
                                      },
                                      children: List.generate(365, (i) {
                                        final num = i + 1;
                                        final isSelected = num == _frequencyNum;
                                        return Center(
                                          child: Text(
                                            '$num',
                                            style: TextStyle(
                                              fontSize: isSelected ? 20 : 16,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: isSelected
                                                  ? textColor
                                                  : textColor.withValues(
                                                      alpha: 0.35,
                                                    ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 3,
                                    child: CupertinoPicker(
                                      scrollController: _unitController,
                                      itemExtent: 40,
                                      selectionOverlay: const SizedBox.shrink(),
                                      onSelectedItemChanged: (index) {
                                        setState(() {
                                          _frequencyUnit = _units[index];
                                        });
                                        _playScrollSound();
                                      },
                                      children: List.generate(_units.length, (
                                        i,
                                      ) {
                                        final unit = _units[i];
                                        final isSelected =
                                            unit == _frequencyUnit;
                                        return Center(
                                          child: Text(
                                            unit,
                                            style: TextStyle(
                                              fontSize: isSelected ? 20 : 16,
                                              fontWeight: isSelected
                                                  ? FontWeight.bold
                                                  : FontWeight.normal,
                                              color: isSelected
                                                  ? textColor
                                                  : textColor.withValues(
                                                      alpha: 0.35,
                                                    ),
                                            ),
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          _getSummaryText(),
                          style: TextStyle(
                            fontSize: 14,
                            color: textColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Section 3: Weekdays Multi-select Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: boxBorderColor),
                          boxShadow: isDark
                              ? null
                              : [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.04),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'สัปดาห์',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: _allWeekdays.sublist(0, 4).map((day) {
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: _buildDayPill(
                                      day: day,
                                      isSelected: _selectedDays.contains(day),
                                      activeBlue: activeBlue,
                                      unselectedBg: unselectedPillBg,
                                      textColor: textColor,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                ..._allWeekdays.sublist(4, 7).map((day) {
                                  return Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      child: _buildDayPill(
                                        day: day,
                                        isSelected: _selectedDays.contains(day),
                                        activeBlue: activeBlue,
                                        unselectedBg: unselectedPillBg,
                                        textColor: textColor,
                                      ),
                                    ),
                                  );
                                }),
                                const Expanded(child: SizedBox.shrink()),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      // Section for "byFixedDate": Multi-select Calendar & Date/Time pickers
                      _buildMultiSelectCalendar(
                        cardBgColor: cardBgColor,
                        textColor: textColor,
                        activeBlue: activeBlue,
                        isDark: isDark,
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'เลือกไว้แล้ว ${_fixedDates.length} วัน',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: textColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildFixedDatesList(
                        cardBgColor: cardBgColor,
                        textColor: textColor,
                        boxBorderColor: boxBorderColor,
                        isDark: isDark,
                      ),
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

  Widget _buildMultiSelectCalendar({
    required Color cardBgColor,
    required Color textColor,
    required Color activeBlue,
    required bool isDark,
  }) {
    final year = _calendarMonth.year;
    final month = _calendarMonth.month;
    final firstDayOfMonth = DateTime(year, month, 1);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final startingWeekday = firstDayOfMonth.weekday % 7;

    final thaiMonths = [
      'มกราคม',
      'กุมภาพันธ์',
      'มีนาคม',
      'เมษายน',
      'พฤษภาคม',
      'มิถุนายน',
      'กรกฎาคม',
      'สิงหาคม',
      'กันยายน',
      'ตลุาคม',
      'พฤศจิกายน',
      'ธันวาคม',
    ];
    final monthName = thaiMonths[month - 1];
    final weekDays = ['อา.', 'จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.'];
    final now = DateTime.now();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(20),
        border: null,
        boxShadow: isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                monthName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(Icons.chevron_left, color: textColor),
                    onPressed: () {
                      setState(() {
                        _calendarMonth = DateTime(year, month - 1, 1);
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.chevron_right, color: textColor),
                    onPressed: () {
                      setState(() {
                        _calendarMonth = DateTime(year, month + 1, 1);
                      });
                    },
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(weekDays.length, (i) {
              final w = weekDays[i];
              final isWeekendHeader = (i == 0 || i == 6);
              return Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isWeekendHeader
                          ? const Color(0xFFE57373)
                          : textColor.withValues(alpha: 0.5),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: startingWeekday + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 6,
              crossAxisSpacing: 6,
            ),
            itemBuilder: (context, index) {
              if (index < startingWeekday) {
                return const SizedBox.shrink();
              }
              final dayNum = index - startingWeekday + 1;
              final dayOfWeek = index % 7;
              final isWeekend = (dayOfWeek == 0 || dayOfWeek == 6);
              final isToday =
                  (year == now.year && month == now.month && dayNum == now.day);

              final isSelected = _fixedDates.any(
                (d) => d.year == year && d.month == month && d.day == dayNum,
              );

              BoxDecoration? cellDecoration;
              Color dayTextColor;

              if (isSelected) {
                cellDecoration = BoxDecoration(
                  color: activeBlue,
                  shape: BoxShape.circle,
                );
                dayTextColor = Colors.white;
              } else if (isToday) {
                cellDecoration = BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: activeBlue, width: 2),
                );
                dayTextColor = isWeekend ? const Color(0xFFE57373) : activeBlue;
              } else {
                cellDecoration = null;
                dayTextColor = isWeekend
                    ? const Color(0xFFE57373)
                    : textColor.withValues(alpha: 0.85);
              }

              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (isSelected) {
                      _fixedDates.removeWhere(
                        (d) =>
                            d.year == year &&
                            d.month == month &&
                            d.day == dayNum,
                      );
                    } else {
                      _fixedDates.add(
                        DateTime(year, month, dayNum, now.hour, now.minute),
                      );
                      _deduplicateFixedDates();
                    }
                  });
                },
                child: Container(
                  decoration: cellDecoration,
                  alignment: Alignment.center,
                  child: Text(
                    '$dayNum',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: (isSelected || isToday)
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: dayTextColor,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFixedDatesList({
    required Color cardBgColor,
    required Color textColor,
    required Color boxBorderColor,
    required bool isDark,
  }) {
    return Column(
      children: List.generate(_fixedDates.length, (index) {
        final itemDate = _fixedDates[index];
        final dateStr = '${itemDate.day}/${itemDate.month}/${itemDate.year}';
        final timeStr =
            '${itemDate.hour.toString().padLeft(2, '0')}:${itemDate.minute.toString().padLeft(2, '0')}';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: InkWell(
                  enableFeedback: false,
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: itemDate,
                      firstDate: DateTime(2024, 1, 1),
                      lastDate: DateTime(2030, 12, 31),
                    );
                    if (picked != null) {
                      setState(() {
                        _fixedDates[index] = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          itemDate.hour,
                          itemDate.minute,
                        );
                        _deduplicateFixedDates();
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: boxBorderColor),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'วันที่ทำซ้ำ',
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: 18,
                              color: textColor.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: InkWell(
                  enableFeedback: false,
                  onTap: () async {
                    final picked = await showTimePicker(
                      context: context,
                      initialTime: TimeOfDay(
                        hour: itemDate.hour,
                        minute: itemDate.minute,
                      ),
                    );
                    if (picked != null) {
                      setState(() {
                        _fixedDates[index] = DateTime(
                          itemDate.year,
                          itemDate.month,
                          itemDate.day,
                          picked.hour,
                          picked.minute,
                        );
                      });
                    }
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: boxBorderColor),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.03),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'เวลาทำซ้ำ',
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_outlined,
                              size: 18,
                              color: textColor.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildDayPill({
    required String day,
    required bool isSelected,
    required Color activeBlue,
    required Color unselectedBg,
    required Color textColor,
  }) {
    return GestureDetector(
      onTap: () => _toggleDay(day),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? activeBlue : unselectedBg,
          borderRadius: BorderRadius.circular(16),
        ),
        alignment: Alignment.center,
        child: Text(
          day,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : textColor.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
