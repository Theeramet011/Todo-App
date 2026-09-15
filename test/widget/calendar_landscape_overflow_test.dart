import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:todo_app/widgets/calendar_widget.dart';
import 'package:todo_app/widgets/daily_timeline.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH', null);
  });

  group('Calendar Layout Tests', () {
    testWidgets(
      'renders calendar layout in tablet landscape (1280x800) without overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(1280, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final focusedDay = DateTime(2026, 9, 14);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SafeArea(
                child: Builder(
                  builder: (context) {
                    final isLandscape =
                        MediaQuery.of(context).orientation ==
                        Orientation.landscape;
                    final isTablet = MediaQuery.of(context).size.width >= 600;

                    return Column(
                      children: [
                        // Header
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 24.0 : 16.0,
                            vertical:
                                isLandscape ? 8.0 : (isTablet ? 24.0 : 16.0),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(
                                  isLandscape ? 10 : (isTablet ? 16 : 12),
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(
                                    isLandscape ? 14 : (isTablet ? 18 : 12),
                                  ),
                                ),
                                child: Icon(
                                  Icons.calendar_month,
                                  size: isLandscape ? 22 : (isTablet ? 30 : 24),
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(
                                width: isLandscape
                                    ? 12
                                    : (isTablet ? 24 : 16),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ปฏิทิน',
                                    style: TextStyle(
                                      fontSize:
                                          isLandscape
                                              ? 22
                                              : (isTablet ? 28 : 22),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'จัดการตารางเวลาของคุณ',
                                    style: TextStyle(
                                      fontSize:
                                          isLandscape
                                              ? 13
                                              : (isTablet ? 16 : 14),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        // Calendar
                        CalendarWidget(
                          focusedDay: focusedDay,
                          selectedDay: focusedDay,
                          calendarFormat: CalendarFormat.month,
                          onFormatChanged: (_) {},
                          onDaySelected: (_) {},
                          events: const {},
                        ),

                        // Toggle
                        GestureDetector(
                          child: Container(
                            width: double.infinity,
                            alignment: Alignment.center,
                            padding: EdgeInsets.only(
                              bottom:
                                  isLandscape ? 4.0 : (isTablet ? 12.0 : 8.0),
                              top: isLandscape ? 2.0 : (isTablet ? 6.0 : 4.0),
                            ),
                            child: Icon(
                              Icons.keyboard_arrow_up,
                              size: isLandscape ? 24 : (isTablet ? 34 : 28),
                            ),
                          ),
                        ),

                        // Date info
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical:
                                isLandscape ? 4.0 : (isTablet ? 12.0 : 8.0),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal:
                                      isLandscape ? 14 : (isTablet ? 18 : 16),
                                  vertical:
                                      isLandscape ? 4 : (isTablet ? 8 : 4),
                                ),
                                child: const Text('จ. 14 กันยายน'),
                              ),
                            ],
                          ),
                        ),

                        // Daily timeline
                        Expanded(
                          child: DailyTimeline(
                            tasks: const [],
                            date: focusedDay,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check for overflow
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'renders calendar layout in tablet portrait (800x1280) without overflow',
      (WidgetTester tester) async {
        tester.view.physicalSize = const Size(800, 1280);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() {
          tester.view.resetPhysicalSize();
          tester.view.resetDevicePixelRatio();
        });

        final focusedDay = DateTime(2026, 9, 14);

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SafeArea(
                child: Builder(
                  builder: (context) {
                    final isLandscape =
                        MediaQuery.of(context).orientation ==
                        Orientation.landscape;
                    final isTablet = MediaQuery.of(context).size.width >= 600;

                    return Column(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 24.0 : 16.0,
                            vertical:
                                isLandscape ? 8.0 : (isTablet ? 24.0 : 16.0),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.all(
                                  isLandscape ? 10 : (isTablet ? 16 : 12),
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.blue,
                                  borderRadius: BorderRadius.circular(
                                    isLandscape ? 14 : (isTablet ? 18 : 12),
                                  ),
                                ),
                                child: Icon(
                                  Icons.calendar_month,
                                  size: isLandscape ? 22 : (isTablet ? 30 : 24),
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(
                                width: isLandscape
                                    ? 12
                                    : (isTablet ? 24 : 16),
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'ปฏิทิน',
                                    style: TextStyle(
                                      fontSize:
                                          isLandscape
                                              ? 22
                                              : (isTablet ? 28 : 22),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    'จัดการตารางเวลาของคุณ',
                                    style: TextStyle(
                                      fontSize:
                                          isLandscape
                                              ? 13
                                              : (isTablet ? 16 : 14),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        CalendarWidget(
                          focusedDay: focusedDay,
                          selectedDay: focusedDay,
                          calendarFormat: CalendarFormat.month,
                          onFormatChanged: (_) {},
                          onDaySelected: (_) {},
                          events: const {},
                        ),
                        GestureDetector(
                          child: Container(
                            width: double.infinity,
                            alignment: Alignment.center,
                            padding: EdgeInsets.only(
                              bottom:
                                  isLandscape ? 4.0 : (isTablet ? 12.0 : 8.0),
                              top: isLandscape ? 2.0 : (isTablet ? 6.0 : 4.0),
                            ),
                            child: Icon(
                              Icons.keyboard_arrow_up,
                              size: isLandscape ? 24 : (isTablet ? 34 : 28),
                            ),
                          ),
                        ),
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical:
                                isLandscape ? 4.0 : (isTablet ? 12.0 : 8.0),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal:
                                      isLandscape ? 14 : (isTablet ? 18 : 16),
                                  vertical:
                                      isLandscape ? 4 : (isTablet ? 8 : 4),
                                ),
                                child: const Text('จ. 14 กันยายน'),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: DailyTimeline(
                            tasks: const [],
                            date: focusedDay,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });
}
