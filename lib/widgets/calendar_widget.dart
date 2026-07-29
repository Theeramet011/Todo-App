import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../config/colors.dart';
import '../config/constants.dart';

class CalendarWidget extends StatelessWidget {
  final DateTime focusedDay;
  final DateTime selectedDay;
  final Function(DateTime) onDaySelected;
  final Map<DateTime, List> events;
  final CalendarFormat calendarFormat;
  final Function(CalendarFormat)? onFormatChanged;

  const CalendarWidget({
    super.key,
    required this.focusedDay,
    required this.selectedDay,
    required this.onDaySelected,
    required this.events,
    this.calendarFormat = CalendarFormat.month,
    this.onFormatChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.all(AppConstants.paddingMedium),
      padding: const EdgeInsets.all(AppConstants.paddingMedium),
      decoration: BoxDecoration(
        color: isDarkMode
            ? AppColors.stormyDarkSlate
            : AppColors.backgroundWhite,
        borderRadius: BorderRadius.circular(AppConstants.radiusXLarge),
        boxShadow: [
          BoxShadow(
            color: isDarkMode
                ? Colors.black.withValues(alpha: 0.3)
                : AppColors.shadowLight,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: TableCalendar(
        locale: 'th_TH',
        firstDay: DateTime.utc(2024, 1, 1),
        lastDay: DateTime.utc(2026, 12, 31),
        focusedDay: focusedDay,
        calendarFormat: calendarFormat,
        onFormatChanged: onFormatChanged,
        selectedDayPredicate: (day) => isSameDay(selectedDay, day),
        eventLoader: (day) => events[day] ?? [],
        onDaySelected: (selectedDay, focusedDay) {
          onDaySelected(selectedDay);
        },
        calendarStyle: CalendarStyle(
          // Today
          todayDecoration: BoxDecoration(
            color: AppColors.stormySkyBlue.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          todayTextStyle: const TextStyle(
            color: AppColors.stormySkyBlue,
            fontWeight: FontWeight.bold,
          ),
          // Selected
          selectedDecoration: const BoxDecoration(
            color: AppColors.stormySkyBlue,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: TextStyle(
            color: isDarkMode
                ? AppColors.stormyNightBackground
                : AppColors.textWhite,
            fontWeight: FontWeight.bold,
          ),
          // Weekend
          weekendTextStyle: TextStyle(
            color: isDarkMode ? const Color(0xFFE57373) : AppColors.accentRed,
          ),
          // Outside days
          outsideDaysVisible: true,
          outsideTextStyle: TextStyle(
            color: isDarkMode ? Colors.grey[600] : AppColors.textLight,
          ),
          // Default days
          defaultTextStyle: TextStyle(
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
          ),
          // Marker
          markerDecoration: const BoxDecoration(
            color: AppColors.stormySkyBlue,
            shape: BoxShape.circle,
          ),
          markersMaxCount: 3,
        ),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDarkMode ? Colors.white : AppColors.textPrimary,
          ),
          leftChevronIcon: Icon(
            Icons.chevron_left,
            color: isDarkMode ? Colors.white70 : AppColors.textSecondary,
          ),
          rightChevronIcon: Icon(
            Icons.chevron_right,
            color: isDarkMode ? Colors.white70 : AppColors.textSecondary,
          ),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? Colors.grey[400] : AppColors.textSecondary,
          ),
          weekendStyle: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDarkMode ? AppColors.primaryPink : AppColors.accentRed,
          ),
        ),
        calendarBuilders: CalendarBuilders(
          todayBuilder: (context, day, focusedDay) {
            return Container(
              margin: const EdgeInsets.all(6.4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.transparent,
                border: Border.all(
                  color: isDarkMode
                      ? const Color(0xFF88BDF2)
                      : AppColors.stormySkyBlue,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: isDarkMode
                      ? const Color(0xFF88BDF2)
                      : AppColors.stormySkyBlue,
                ),
              ),
            );
          },
          selectedBuilder: (context, day, focusedDay) {
            final isToday = isSameDay(day, DateTime.now());
            return Container(
              margin: const EdgeInsets.all(6.4),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? const Color(0xFF88BDF2)
                    : AppColors.stormySkyBlue,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '${day.day}',
                style: TextStyle(
                  color: isDarkMode
                      ? const Color(0xFF1A2530)
                      : AppColors.textWhite,
                  fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            );
          },
          markerBuilder: (context, date, events) {
            if (events.isEmpty) return const SizedBox.shrink();

            return Positioned(
              bottom: 1,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: events.map((event) {
                  return Container(
                    width: 4,
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: isDarkMode
                          ? AppColors.primaryPurple
                          : AppColors.stormySkyBlue,
                      shape: BoxShape.circle,
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
      ),
    );
  }
}
