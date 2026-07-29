import 'package:flutter/material.dart';

// Palette Reference
const Color stormyBackground = Color(0xFF1A2530);
const Color stormySurface = Color(0xFF384959);
const Color stormyPrimary = Color(0xFF88BDF2);
const Color stormyTextPrimary = Color(0xFFFFFFFF);
const Color stormyTextSecondary = Color(0xFFBDDDFC);
const Color stormyTextMuted = Color(0xFF6A89A7);

void main() {
  runApp(const HomePreviewApp());
}

class HomePreviewApp extends StatelessWidget {
  const HomePreviewApp({super.key});

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
      home: const HomePreviewScreen(),
    );
  }
}

class HomePreviewScreen extends StatefulWidget {
  const HomePreviewScreen({super.key});

  @override
  State<HomePreviewScreen> createState() => _HomePreviewScreenState();
}

class _HomePreviewScreenState extends State<HomePreviewScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: stormyBackground,
      appBar: AppBar(
        backgroundColor: stormyBackground,
        elevation: 0,
        title: const Text(
          'ตัวช่วยจัดการภารกิจในรูปแบบเกม',
          style: TextStyle(color: stormyTextPrimary),
        ),
        centerTitle: true,
        leading: const Icon(Icons.menu, color: stormyTextPrimary),
        actions: const [
          Icon(Icons.notifications_none_outlined, color: stormyTextPrimary),
          SizedBox(width: 16),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildTabBar(),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'สิ่งที่ต้องทำวันนี้',
                    style: TextStyle(
                      color: stormyTextPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTaskCard('frfr', 'การตลาด', '19:24 น.'),
                  const SizedBox(height: 24),
                  const Text(
                    'ภารกิจที่ยังไม่เสร็จ',
                    style: TextStyle(
                      color: Color(0xFFE57373), // Red highlight for overdue
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _buildTaskCard(
                    'tygg',
                    'ภารกิจส่วนตัว',
                    '19:10 น.',
                    isOverdue: true,
                  ),
                  const SizedBox(height: 12),
                  _buildTaskCard(
                    'thhh',
                    'ภารกิจส่วนตัว',
                    '19:03 น.',
                    isOverdue: true,
                  ),
                ],
              ),
            ),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'สวัสดีตอนเย็น, Pookub2',
                style: TextStyle(color: stormyTextPrimary, fontSize: 14),
              ),
              Text(
                'วันนี้',
                style: TextStyle(
                  color: stormyTextPrimary,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '24/06/2026',
                style: TextStyle(color: stormyTextPrimary, fontSize: 14),
              ),
            ],
          ),
          Row(
            children: const [
              Text('🔥', style: TextStyle(fontSize: 24)),
              SizedBox(width: 4),
              Text(
                '4',
                style: TextStyle(
                  color: stormyTextPrimary,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(width: 16),
              Icon(Icons.search, color: stormyPrimary, size: 32),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: stormyBackground, // Heavily muted background
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: stormySurface,
          width: 2,
        ), // Optional border for visibility
      ),
      child: TabBar(
        controller: _tabController,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: stormySurface,
          borderRadius: BorderRadius.circular(12),
        ),
        labelColor: stormyTextPrimary,
        unselectedLabelColor: stormyTextMuted,
        tabs: const [
          Tab(text: 'ภารกิจส่วนตัว'),
          Tab(text: 'ภารกิจกลุ่ม'),
        ],
      ),
    );
  }

  Widget _buildTaskCard(
    String title,
    String tag,
    String time, {
    bool isOverdue = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: stormySurface,
        borderRadius: BorderRadius.circular(16),
        border: isOverdue
            ? Border.all(color: const Color(0xFFE57373), width: 1.5)
            : null,
        boxShadow: const [
          BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              border: Border.all(color: stormyTextMuted, width: 2),
              borderRadius: BorderRadius.circular(6),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: stormyTextPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: stormyBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      color: stormyTextSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: stormyBackground,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time, size: 14, color: stormyTextMuted),
                const SizedBox(width: 4),
                Text(
                  time,
                  style: const TextStyle(color: stormyTextMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          const Icon(Icons.more_vert, color: stormyTextMuted),
        ],
      ),
    );
  }
}
