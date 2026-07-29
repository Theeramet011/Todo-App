import 'package:flutter/material.dart';

// Palette Reference
const Color stormyBackground = Color(0xFF1A2530);
const Color stormySurface = Color(0xFF384959);
const Color stormyPrimary = Color(0xFF88BDF2);
const Color stormyTextPrimary = Color(0xFFFFFFFF);
const Color stormyTextSecondary = Color(0xFFBDDDFC);
const Color stormyTextMuted = Color(0xFF6A89A7);
const Color stormyError = Color(0xFFE57373); // Pastel Red

void main() {
  runApp(const SettingsPreviewApp());
}

class SettingsPreviewApp extends StatelessWidget {
  const SettingsPreviewApp({super.key});

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
      home: const SettingsPreviewScreen(),
    );
  }
}

class SettingsPreviewScreen extends StatelessWidget {
  const SettingsPreviewScreen({super.key});

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
              child: const Icon(Icons.settings, color: stormyBackground),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'ตั้งค่า',
                  style: TextStyle(
                    color: stormyTextPrimary,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'จัดการการตั้งค่าของคุณ',
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
            _buildStatsCard(),
            const SizedBox(height: 16),
            _buildAchievementsCard(),
            const SizedBox(height: 24),
            const Text(
              'การตั้งค่า',
              style: TextStyle(
                color: stormyTextPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _buildSettingsList(),
            const SizedBox(height: 32),
            _buildLogoutButton(),
            const SizedBox(height: 16),
            const Center(
              child: Text(
                'เวอร์ชัน 1.0.0',
                style: TextStyle(color: stormyTextMuted, fontSize: 12),
              ),
            ),
            const SizedBox(height: 32),
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

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: stormySurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('74', 'ภารกิจที่เสร็จ'),
          _buildStatItem('4', 'วันที่ต่อเนื่อง'),
          _buildStatItem('12500', 'XP ทั้งหมด'),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: stormyTextPrimary,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(color: stormyTextMuted, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildAchievementsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: stormySurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: const [
                  Text('🏅', style: TextStyle(fontSize: 16)),
                  SizedBox(width: 8),
                  Text(
                    'ตราความสำเร็จ',
                    style: TextStyle(
                      color: stormyTextPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Row(
                children: const [
                  Text(
                    '6/9',
                    style: TextStyle(
                      color: stormyError,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(width: 4),
                  Icon(Icons.chevron_right, color: stormyTextMuted),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: const [
              Icon(Icons.shield, color: stormyPrimary, size: 32),
              SizedBox(width: 16),
              Icon(Icons.star, color: Color(0xFFE57373), size: 32),
              SizedBox(width: 16),
              Icon(Icons.emoji_events, color: Colors.amber, size: 32),
              SizedBox(width: 16),
              Icon(Icons.diamond, color: Colors.purpleAccent, size: 32),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsList() {
    return Container(
      decoration: BoxDecoration(
        color: stormySurface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          _buildSettingsToggle(
            Icons.notifications_none_outlined,
            'การแจ้งเตือน',
            'รับการแจ้งเตือนภารกิจ',
            true,
          ),
          const Divider(color: stormyBackground, height: 1),
          _buildSettingsToggle(
            Icons.nightlight_round,
            'โหมดมืด',
            'เปลี่ยนเป็นธีมมืด',
            true,
          ),
          const Divider(color: stormyBackground, height: 1),
          _buildSettingsToggle(
            Icons.volume_up_outlined,
            'เสียง',
            'เปิดเสียงเอฟเฟกต์',
            false,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsToggle(
    IconData icon,
    String title,
    String subtitle,
    bool value,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: stormyBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: stormyTextMuted),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: stormyTextPrimary,
          fontWeight: FontWeight.bold,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: stormyTextMuted, fontSize: 12),
      ),
      trailing: Switch(
        value: value,
        onChanged: (val) {},
        activeThumbColor: stormyBackground,
        activeTrackColor: stormyPrimary,
        inactiveThumbColor: stormyTextMuted,
        inactiveTrackColor: stormyBackground,
      ),
    );
  }

  Widget _buildLogoutButton() {
    return OutlinedButton.icon(
      onPressed: () {},
      icon: const Icon(Icons.logout, color: stormyError),
      label: const Text(
        'ออกจากระบบ',
        style: TextStyle(color: stormyError, fontWeight: FontWeight.bold),
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        side: const BorderSide(color: stormyError, width: 1.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: Colors.transparent, // Transparent background
      ),
    );
  }
}
