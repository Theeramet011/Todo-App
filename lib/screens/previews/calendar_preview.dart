import 'package:flutter/material.dart';

// Palette Reference
const Color stormyBackground = Color(0xFF1A2530);
const Color stormySurface = Color(0xFF384959);
const Color stormyPrimary = Color(0xFF88BDF2);
const Color stormyTextPrimary = Color(0xFFFFFFFF);
const Color stormyTextSecondary = Color(0xFFBDDDFC);
const Color stormyTextMuted = Color(0xFF6A89A7);

void main() {
  runApp(const CalendarPreviewApp());
}

class CalendarPreviewApp extends StatelessWidget {
  const CalendarPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: stormyBackground,
        colorScheme: const ColorScheme.dark(
          surface: stormySurface,
          primary: stormyPrimary,
        ),
      ),
      home: const CalendarPreviewScreen(),
    );
  }
}

class CalendarPreviewScreen extends StatelessWidget {
  const CalendarPreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: stormyBackground,
      appBar: AppBar(
        backgroundColor: stormyBackground,
        elevation: 0,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: stormyPrimary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.calendar_month, color: stormyBackground),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'ปฏิทิน',
                  style: TextStyle(
                    color: stormyTextPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'จัดการตารางเวลาของคุณ',
                  style: TextStyle(color: stormyTextMuted, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildCalendarWidget(),
            const SizedBox(height: 24),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: stormyPrimary,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: const [
                      Icon(
                        Icons.calendar_today,
                        size: 16,
                        color: stormyBackground,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'พ. 24 มิถุนายน',
                        style: TextStyle(
                          color: stormyBackground,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                const Text(
                  'ตารางเวลา',
                  style: TextStyle(
                    color: stormyTextPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: stormySurface,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    '1 tasks',
                    style: TextStyle(color: stormyPrimary, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildScheduleCard('7:24 PM', 'frfr', 'การตลาด'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: stormyPrimary,
        child: const Icon(Icons.add, color: stormyBackground),
      ),
    );
  }

  Widget _buildCalendarWidget() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: stormySurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Icon(Icons.chevron_left, color: stormyTextPrimary),
              Text(
                'มิถุนายน 2026',
                style: TextStyle(
                  color: stormyTextPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Icon(Icons.chevron_right, color: stormyTextPrimary),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['อา.', 'จ.', 'อ.', 'พ.', 'พฤ.', 'ศ.', 'ส.']
                .map(
                  (day) => Text(
                    day,
                    style: TextStyle(
                      color: day == 'อา.' || day == 'ส.'
                          ? const Color(0xFFE57373)
                          : stormyTextPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 16),
          // Mock calendar grid
          ...List.generate(5, (row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: List.generate(7, (col) {
                  int dayNum = row * 7 + col - 0; // offset
                  if (dayNum < 1) {
                    return const Text(
                      '31',
                      style: TextStyle(color: stormyTextMuted),
                    );
                  }
                  if (dayNum > 30) {
                    return Text(
                      '${dayNum - 30}',
                      style: const TextStyle(color: stormyTextMuted),
                    );
                  }

                  bool isActive = dayNum == 24;
                  return Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: isActive ? stormyPrimary : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '$dayNum',
                      style: TextStyle(
                        color: isActive ? stormyBackground : stormyTextPrimary,
                        fontWeight: isActive
                            ? FontWeight.bold
                            : FontWeight.normal,
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildScheduleCard(String time, String title, String tag) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: stormySurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: stormyBackground, width: 2),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.only(top: 4),
            decoration: const BoxDecoration(
              color: stormyPrimary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: const TextStyle(
                    color: stormyPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: const TextStyle(
                    color: stormyTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  tag,
                  style: const TextStyle(
                    color: stormyTextSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.circle, color: stormyPrimary, size: 8),
        ],
      ),
    );
  }
}
