import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../providers/auth_provider.dart';
import '../services/sound_service.dart';

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
  final DateTime? initialDate;

  const CustomRecurringModal({
    super.key,
    this.initialConfig = const CustomRecurringConfig(),
    this.initialDate,
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
    final effectiveDate = widget.initialDate ?? now;
    _calendarMonth = DateTime(effectiveDate.year, effectiveDate.month, 1);

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
    SoundService.instance.playClickSound(isSoundEnabled: isSoundEnabled);
  }

  void _playClickSound() {
    _playScrollSound();
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
    if (_selectedMode == 'byDueDate') {
      // Mode 1: ตามวันถึงกำหนด (FREQUENCY)
      if (_frequencyUnit == 'สัปดาห์' && _selectedDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('กรุณาเลือกวันในสัปดาห์อย่างน้อย 1 วัน'),
            backgroundColor: AppColors.accentRed,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final config = CustomRecurringConfig(
        mode: 'byDueDate',
        frequencyNum: _frequencyNum,
        frequencyUnit: _frequencyUnit,
        selectedDays: _frequencyUnit == 'สัปดาห์'
            ? List<String>.from(_selectedDays)
            : const [],
        fixedDates: const [], // Ignore calendar date selections
      );
      Navigator.pop(context, config);
    } else if (_selectedMode == 'byFixedDate') {
      // Mode 2: ตามวันที่กำหนด (SPECIFIC_DATES)
      _deduplicateFixedDates();
      if (_fixedDates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('กรุณาเลือกวันที่ทำซ้ำอย่างน้อย 1 วัน'),
            backgroundColor: AppColors.accentRed,
            duration: Duration(seconds: 2),
          ),
        );
        return;
      }

      final config = CustomRecurringConfig(
        mode: 'byFixedDate',
        frequencyNum: 1,
        frequencyUnit: 'วัน',
        selectedDays: const [], // Ignore frequency & weekday rules
        fixedDates: List<DateTime>.from(_fixedDates),
      );
      Navigator.pop(context, config);
    }
  }

  void _showRecurringInfoDialog(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isTablet = MediaQuery.of(context).size.width >= 600;

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
            borderRadius: BorderRadius.circular(isTablet ? 28 : 24),
          ),
          child: Padding(
            padding: EdgeInsets.all(isTablet ? 30 : 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'เกี่ยวกับประเภทการทำซ้ำ',
                  style: TextStyle(
                    fontSize: isTablet ? 22 : 18,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                SizedBox(height: isTablet ? 20 : 16),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14.5,
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
                SizedBox(height: isTablet ? 18 : 14),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 14.5,
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
                SizedBox(height: isTablet ? 28 : 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.stormySkyBlue,
                      foregroundColor:
                          Theme.of(context).brightness == Brightness.dark
                              ? AppColors.stormyNightBackground
                              : Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: isTablet ? 16 : 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isTablet ? 18 : 16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'เข้าใจแล้ว',
                      style: TextStyle(
                        fontSize: isTablet ? 18 : 16,
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
    final isTablet = MediaQuery.of(context).size.width >= 600;

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
              padding: EdgeInsets.symmetric(
                horizontal: isTablet ? 16 : 12,
                vertical: isTablet ? 12 : 8,
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.close,
                      color: textColor,
                      size: isTablet ? 28 : 24,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  Expanded(
                    child: Center(
                      child: Text(
                        'กำหนดเอง',
                        style: TextStyle(
                          fontSize: isTablet ? 24 : 18,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.check,
                      color: activeBlue,
                      size: isTablet ? 28 : 24,
                    ),
                    onPressed: _onSave,
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isTablet ? 24 : 16,
                  vertical: isTablet ? 16 : 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section 1: Dropdown Mode Selector
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.symmetric(
                        horizontal: isTablet ? 20 : 16,
                        vertical: isTablet ? 16 : 12,
                      ),
                      decoration: BoxDecoration(
                        color: cardBgColor,
                        borderRadius: BorderRadius.circular(
                          isTablet ? 24 : 20,
                        ),
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
                                  fontSize: isTablet ? 18 : 16,
                                  fontWeight: FontWeight.w500,
                                  color: textColor,
                                ),
                              ),
                              const SizedBox(width: 6),
                              GestureDetector(
                                onTap: () => _showRecurringInfoDialog(context),
                                child: Icon(
                                  Icons.help_outline,
                                  size: isTablet ? 22 : 18,
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
                                    fontSize: isTablet ? 17 : 15,
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
                                    fontSize: isTablet ? 17 : 15,
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
                                    fontSize: isTablet ? 17 : 15,
                                    color: textColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  Icons.keyboard_arrow_down,
                                  size: isTablet ? 26 : 24,
                                  color: textColor,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isTablet ? 20 : 16),

                    if (_selectedMode == 'byDueDate') ...[
                      // Section 2: Frequency Wheel Card
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(isTablet ? 20 : 16),
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(
                            isTablet ? 24 : 20,
                          ),
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
                                fontSize: isTablet ? 20 : 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            SizedBox(height: isTablet ? 16 : 12),
                            SizedBox(
                              height: isTablet ? 160 : 140,
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Align(
                                      alignment: Alignment.center,
                                      child: Text(
                                        'ทุกๆ',
                                        style: TextStyle(
                                          fontSize: isTablet ? 22 : 18,
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
                                      itemExtent: isTablet ? 48 : 40,
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
                                              fontSize: isSelected
                                                  ? (isTablet ? 26 : 20)
                                                  : (isTablet ? 20 : 16),
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
                                      itemExtent: isTablet ? 48 : 40,
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
                                              fontSize: isSelected
                                                  ? (isTablet ? 26 : 20)
                                                  : (isTablet ? 20 : 16),
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
                      SizedBox(height: isTablet ? 16 : 12),

                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          _getSummaryText(),
                          style: TextStyle(
                            fontSize: isTablet ? 16 : 14,
                            color: textColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ),
                      SizedBox(height: isTablet ? 16 : 12),

                      // Section 3: Weekdays Multi-select Card
                      Builder(
                        builder: (context) {
                          final isWeekUnit = _frequencyUnit == 'สัปดาห์';
                          final badgeBgColor = isDark
                              ? AppColors.stormySkyBlue.withValues(alpha: 0.16)
                              : const Color(0xFFE1F5FE);
                          final badgeTextColor = isDark
                              ? const Color(0xFF64B5F6)
                              : const Color(0xFF0277BD);
                          final badgeBorderColor = isDark
                              ? AppColors.stormySkyBlue.withValues(alpha: 0.3)
                              : const Color(0xFF81D4FA);

                          return Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(isTablet ? 20 : 16),
                            decoration: BoxDecoration(
                              color: cardBgColor,
                              borderRadius: BorderRadius.circular(
                                isTablet ? 24 : 20,
                              ),
                              border: Border.all(color: boxBorderColor),
                              boxShadow: isDark
                                  ? null
                                  : [
                                      BoxShadow(
                                        color: Colors.black.withValues(
                                          alpha: 0.04,
                                        ),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'สัปดาห์',
                                      style: TextStyle(
                                        fontSize: isTablet ? 20 : 16,
                                        fontWeight: FontWeight.bold,
                                        color: textColor,
                                      ),
                                    ),
                                    if (!isWeekUnit)
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: isTablet ? 14 : 10,
                                          vertical: isTablet ? 7 : 5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: badgeBgColor,
                                          borderRadius:
                                              BorderRadius.circular(20),
                                          border: Border.all(
                                            color: badgeBorderColor,
                                            width: 1,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.info_outline_rounded,
                                              size: isTablet ? 16 : 14,
                                              color: badgeTextColor,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              'เฉพาะความถี่สัปดาห์',
                                              style: TextStyle(
                                                fontSize: isTablet ? 14 : 12,
                                                fontWeight: FontWeight.w600,
                                                color: badgeTextColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                  ],
                                ),
                                SizedBox(height: isTablet ? 20 : 16),
                                IgnorePointer(
                                  ignoring: !isWeekUnit,
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 200),
                                    opacity: isWeekUnit ? 1.0 : 0.35,
                                    child: Column(
                                      children: [
                                        Row(
                                          children: _allWeekdays
                                              .sublist(0, 4)
                                              .map((day) {
                                                return Expanded(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 4,
                                                        ),
                                                    child: _buildDayPill(
                                                      day: day,
                                                      isSelected: _selectedDays
                                                          .contains(day),
                                                      activeBlue: activeBlue,
                                                      unselectedBg:
                                                          unselectedPillBg,
                                                      textColor: textColor,
                                                      isTablet: isTablet,
                                                    ),
                                                  ),
                                                );
                                              })
                                              .toList(),
                                        ),
                                        SizedBox(height: isTablet ? 16 : 12),
                                        Row(
                                          children: [
                                            ..._allWeekdays.sublist(4, 7).map((
                                              day,
                                            ) {
                                              return Expanded(
                                                child: Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 4,
                                                      ),
                                                  child: _buildDayPill(
                                                    day: day,
                                                    isSelected: _selectedDays
                                                        .contains(day),
                                                    activeBlue: activeBlue,
                                                    unselectedBg:
                                                        unselectedPillBg,
                                                    textColor: textColor,
                                                    isTablet: isTablet,
                                                  ),
                                                ),
                                              );
                                            }),
                                            const Expanded(
                                              child: SizedBox.shrink(),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ] else ...[
                      // Section for "byFixedDate": Multi-select Calendar & Date/Time pickers
                      _buildMultiSelectCalendar(
                        cardBgColor: cardBgColor,
                        textColor: textColor,
                        activeBlue: activeBlue,
                        isDark: isDark,
                        isTablet: isTablet,
                      ),
                      SizedBox(height: isTablet ? 16 : 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          'เลือกไว้แล้ว ${_fixedDates.length} วัน',
                          style: TextStyle(
                            fontSize: isTablet ? 17 : 14,
                            fontWeight: FontWeight.w500,
                            color: textColor.withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                      SizedBox(height: isTablet ? 20 : 16),
                      _buildFixedDatesList(
                        cardBgColor: cardBgColor,
                        textColor: textColor,
                        boxBorderColor: boxBorderColor,
                        isDark: isDark,
                        isTablet: isTablet,
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
    bool isTablet = false,
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
      'ตุลาคม',
      'พฤศจิกายน',
      'ธันวาคม',
    ];
    final monthName = thaiMonths[month - 1];
    final weekDays = ['อา.', 'จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.'];
    final now = DateTime.now();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isTablet ? 20 : 16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(isTablet ? 24 : 20),
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
                  fontSize: isTablet ? 22 : 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              Row(
                children: [
                  IconButton(
                    icon: Icon(
                      Icons.chevron_left,
                      color: textColor,
                      size: isTablet ? 28 : 24,
                    ),
                    onPressed: () {
                      setState(() {
                        _calendarMonth = DateTime(year, month - 1, 1);
                      });
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.chevron_right,
                      color: textColor,
                      size: isTablet ? 28 : 24,
                    ),
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
          SizedBox(height: isTablet ? 16 : 12),
          Row(
            children: List.generate(weekDays.length, (i) {
              final w = weekDays[i];
              final isWeekendHeader = (i == 0 || i == 6);
              return Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: TextStyle(
                      fontSize: isTablet ? 16 : 13,
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
          SizedBox(height: isTablet ? 12 : 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: startingWeekday + daysInMonth,
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: isTablet ? 10 : 6,
              crossAxisSpacing: isTablet ? 10 : 6,
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

              return Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(isTablet ? 28 : 24),
                  onTap: () {
                    _playClickSound();
                    setState(() {
                      if (isSelected) {
                        _fixedDates.removeWhere(
                          (d) =>
                              d.year == year &&
                              d.month == month &&
                              d.day == dayNum,
                        );
                      } else {
                        final defaultHour = _fixedDates.isNotEmpty
                            ? _fixedDates.first.hour
                            : (widget.initialDate?.hour ?? now.hour);
                        final defaultMinute = _fixedDates.isNotEmpty
                            ? _fixedDates.first.minute
                            : (widget.initialDate?.minute ?? now.minute);
                        _fixedDates.add(
                          DateTime(
                            year,
                            month,
                            dayNum,
                            defaultHour,
                            defaultMinute,
                          ),
                        );
                        _deduplicateFixedDates();
                      }
                    });
                  },
                  child: Center(
                    child: Container(
                      width: isTablet ? 48 : 40,
                      height: isTablet ? 48 : 40,
                      decoration: cellDecoration,
                      alignment: Alignment.center,
                      child: Text(
                        '$dayNum',
                        style: TextStyle(
                          fontSize: isTablet ? 17 : 14,
                          fontWeight: (isSelected || isToday)
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: dayTextColor,
                        ),
                      ),
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
    bool isTablet = false,
  }) {
    return Column(
      children: List.generate(_fixedDates.length, (index) {
        final itemDate = _fixedDates[index];
        final dateStr = '${itemDate.day}/${itemDate.month}/${itemDate.year}';
        final timeStr =
            '${itemDate.hour.toString().padLeft(2, '0')}:${itemDate.minute.toString().padLeft(2, '0')}';

        return Container(
          margin: EdgeInsets.only(bottom: isTablet ? 16 : 12),
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
                  borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 18 : 14,
                      vertical: isTablet ? 16 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
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
                            fontSize: isTablet ? 14 : 12,
                            color: textColor.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today_outlined,
                              size: isTablet ? 22 : 18,
                              color: textColor.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: isTablet ? 17 : 14,
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
              SizedBox(width: isTablet ? 16 : 12),
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
                      builder: (context, child) {
                        return MediaQuery(
                          data: MediaQuery.of(context).copyWith(
                            alwaysUse24HourFormat: true,
                          ),
                          child: child!,
                        );
                      },
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
                  borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isTablet ? 18 : 14,
                      vertical: isTablet ? 16 : 12,
                    ),
                    decoration: BoxDecoration(
                      color: cardBgColor,
                      borderRadius: BorderRadius.circular(isTablet ? 20 : 16),
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
                            fontSize: isTablet ? 14 : 12,
                            color: textColor.withValues(alpha: 0.6),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_outlined,
                              size: isTablet ? 22 : 18,
                              color: textColor.withValues(alpha: 0.7),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              timeStr,
                              style: TextStyle(
                                fontSize: isTablet ? 17 : 14,
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
    bool isTablet = false,
  }) {
    return GestureDetector(
      onTap: () => _toggleDay(day),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: isTablet ? 56 : 48,
        decoration: BoxDecoration(
          color: isSelected ? activeBlue : unselectedBg,
          borderRadius: BorderRadius.circular(isTablet ? 18 : 16),
        ),
        alignment: Alignment.center,
        child: Text(
          day,
          style: TextStyle(
            fontSize: isTablet ? 18 : 15,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? Colors.white : textColor.withValues(alpha: 0.7),
          ),
        ),
      ),
    );
  }
}
