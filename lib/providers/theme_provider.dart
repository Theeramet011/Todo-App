// ThemeProvider - ตัวจัดการสถานะธีมของแอปพลิเคชัน (Theme State Management)
//
// ควบคุมและสลับโหมดการแสดงผลระหว่าง Light Mode และ Dark Mode
// พร้อมบันทึกความตั้งค่าผู้ใช้ลงใน SharedPreferences เพื่อใช้อย่างต่อเนื่องในการเปิดแอปครั้งถัดไป
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _themeKey = 'is_dark_mode';
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  ThemeMode get themeMode => _isDarkMode ? ThemeMode.dark : ThemeMode.light;

  ThemeProvider() {
    _loadThemeFromPrefs();
  }

  Future<void> _loadThemeFromPrefs() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isDarkMode = prefs.getBool(_themeKey) ?? false;
      notifyListeners();
    } catch (e) {
      debugPrint('Error loading theme preference: $e');
    }
  }

  Future<void> toggleTheme(bool isOn) async {
    _isDarkMode = isOn;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_themeKey, isOn);
    } catch (e) {
      debugPrint('Error saving theme preference: $e');
    }
  }
}
