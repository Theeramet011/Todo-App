// CalendarScreen - หน้าจอปฏิทิน (Calendar View)
//
// แสดงปฏิทินรายเดือน/รายสัปดาห์ พร้อมรายการงานและไทม์ไลน์ตามวันที่เลือก
// รองรับการเปลี่ยนมุมมองวันที่ การดูรายละเอียดงาน และการสร้างงานใหม่ตามวันที่กำหนด
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../config/constants.dart';
import '../providers/task_provider.dart';
import '../widgets/calendar_widget.dart';
import '../widgets/daily_timeline.dart';
import '../widgets/custom_drawer.dart';
import '../providers/connectivity_provider.dart';
import 'package:table_calendar/table_calendar.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  late DateTime _focusedDay;
  late DateTime _selectedDay;
  CalendarFormat _calendarFormat = CalendarFormat.month;

  @override
  void initState() {
    super.initState();
    _focusedDay = DateTime.now();
    _selectedDay = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = Provider.of<TaskProvider>(context);
    final tasksByDate = _getTasksByDate(taskProvider.tasks);
    final selectedTasks = taskProvider.getTasksForDate(_selectedDay);
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: Theme.of(context).brightness == Brightness.dark
          ? AppColors.stormyNightBackground
          : null,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(context, isTablet),

            // Calendar
            CalendarWidget(
              focusedDay: _focusedDay,
              selectedDay: _selectedDay,
              calendarFormat: _calendarFormat,
              onFormatChanged: (format) {
                setState(() {
                  _calendarFormat = format;
                });
              },
              onDaySelected: (selectedDay) {
                setState(() {
                  _selectedDay = selectedDay;
                  _focusedDay = selectedDay;
                });
                taskProvider.setSelectedDate(selectedDay);
              },
              events: tasksByDate,
            ),

            // Collapse/Expand Toggle Button
            GestureDetector(
              onTap: () {
                setState(() {
                  _calendarFormat = _calendarFormat == CalendarFormat.month
                      ? CalendarFormat.week
                      : CalendarFormat.month;
                });
              },
              child: Container(
                width: double.infinity,
                alignment: Alignment.center,
                padding: EdgeInsets.only(
                  bottom: isTablet ? 12.0 : 8.0,
                  top: isTablet ? 6.0 : 4.0,
                ),
                child: Icon(
                  _calendarFormat == CalendarFormat.month
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: Colors.grey,
                  size: isTablet ? 34 : 28,
                ),
              ),
            ),

            // Selected Date Info
            _buildSelectedDateInfo(isTablet),

            // Daily Timeline
            Expanded(
              child: RefreshIndicator(
                color: AppColors.stormySkyBlue,
                backgroundColor: Theme.of(context).brightness == Brightness.dark
                    ? AppColors.stormyNightBackground
                    : AppColors.backgroundWhite,
                onRefresh: () async {
                  final connectivity = context.read<ConnectivityProvider>();
                  if (connectivity.isOffline) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('ไม่ได้เชื่อมต่ออินเทอร์เน็ต'),
                      ),
                    );
                    return;
                  }
                  await Future.delayed(const Duration(seconds: 1));
                },
                child: DailyTimeline(tasks: selectedTasks, date: _selectedDay),
              ),
            ),
          ],
        ),
      ),
      drawer: const CustomDrawer(),
    );
  }

  Widget _buildHeader(BuildContext context, bool isTablet) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.all(
        isTablet ? AppConstants.paddingLarge : AppConstants.paddingMedium,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isTablet ? 16 : 12),
            decoration: BoxDecoration(
              color: theme.brightness == Brightness.light
                  ? AppColors.stormySkyBlue
                  : AppColors.stormySkyBlue,
              borderRadius: BorderRadius.circular(
                isTablet ? 18 : AppConstants.radiusMedium,
              ),
            ),
            child: Icon(
              Icons.calendar_month,
              color: AppColors.textWhite,
              size: isTablet ? 30 : 24,
            ),
          ),
          SizedBox(
            width: isTablet
                ? AppConstants.paddingLarge
                : AppConstants.paddingMedium,
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'ปฏิทิน',
                style: TextStyle(
                  fontSize: isTablet ? 28 : 22,
                  fontWeight: FontWeight.bold,
                  color: theme.brightness == Brightness.dark
                      ? Colors.white
                      : theme.colorScheme.onSurface,
                ),
              ),
              Text(
                'จัดการตารางเวลาของคุณ',
                style: TextStyle(
                  fontSize: isTablet ? 16 : 14,
                  color: theme.brightness == Brightness.dark
                      ? AppColors.stormyMutedBlueGrey
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectedDateInfo(bool isTablet) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppConstants.paddingLarge,
        vertical: isTablet ? 12 : AppConstants.paddingSmall,
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isTablet ? 18 : AppConstants.paddingMedium,
              vertical: isTablet ? 8 : AppConstants.paddingSmall / 2,
            ),
            decoration: BoxDecoration(
              // ignore: deprecated_member_use
              color: Theme.of(context).brightness == Brightness.light
                  ? AppColors.stormyIceBlue
                  : AppColors.stormySkyBlue,
              borderRadius: BorderRadius.circular(
                isTablet ? AppConstants.radiusMedium : AppConstants.radiusSmall,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.event,
                  size: isTablet ? 20 : 16,
                  color: Theme.of(context).brightness == Brightness.light
                      ? AppColors.stormyDarkSlate
                      : AppColors.stormyNightBackground,
                ),
                SizedBox(width: isTablet ? 10 : 8),
                Text(
                  _formatSelectedDate(_selectedDay),
                  style: TextStyle(
                    fontSize: isTablet ? 16 : 14,
                    fontWeight: FontWeight.w600,
                    color: Theme.of(context).brightness == Brightness.light
                        ? AppColors.stormyDarkSlate
                        : AppColors.stormyNightBackground,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Map<DateTime, List> _getTasksByDate(List tasks) {
    Map<DateTime, List> events = {};
    for (var task in tasks) {
      DateTime date = DateTime(
        task.dateTime.year,
        task.dateTime.month,
        task.dateTime.day,
      );
      if (!events.containsKey(date)) {
        events[date] = [];
      }
      events[date]!.add(task);
    }
    return events;
  }

  String _formatSelectedDate(DateTime date) {
    final months = [
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
    final days = ['จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.', 'อา.'];

    return '${days[date.weekday - 1]} ${date.day} ${months[date.month - 1]}';
  }
}
