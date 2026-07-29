import 'package:flutter/material.dart';
import '../config/colors.dart';
import '../config/constants.dart';

class AboutAppSheet extends StatelessWidget {
  const AboutAppSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? AppColors.stormyNightBackground
            : theme.colorScheme.surface,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.paddingLarge),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle Bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.grey[800]
                        : AppColors.stormyMutedBlueGrey,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // App Title & Tagline
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/logo.png',
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QuestLife',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : AppColors.stormyDarkSlate,
                          ),
                        ),
                        Text(
                          'เปลี่ยนชีวิตธรรมดาให้เป็นการผจญภัย',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: isDark
                                ? AppColors.stormyIceBlue
                                : AppColors.textSecondary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Description
              Text(
                'QuestLife เป็นแอปพลิเคชันจัดการงานที่ออกแบบมาเพื่อช่วยให้การใช้ชีวิตและการทำงานมีประสิทธิภาพมากขึ้นด้วยระบบ Gamification.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Features
              Text(
                'คุณสมบัติหลัก',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? AppColors.stormySkyBlue
                      : AppColors.primaryBlue,
                ),
              ),
              const SizedBox(height: 12),
              _buildFeatureItem(
                context,
                Icons.star_rounded,
                'จัดการงาน พร้อมรับ XP',
              ),
              _buildFeatureItem(
                context,
                Icons.group_off_rounded,
                'ระบบรองรับการทำงานเป็นทีม และ การทำงานแบบคนเดียว',
              ),
              _buildFeatureItem(
                context,
                Icons.sync_rounded,
                'อัปเดตข้อมูลแบบเรียลไทม์ผ่าน Firebase',
              ),

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),

              // Developers
              Text(
                'ผู้พัฒนา',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : AppColors.stormyDarkSlate,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'จัดทำโดย \nนายธีรเมธ ทวีกิจกุศล 166405241011 CSS16641N \n นางสาวศริณพร โนนทิง 166405241021 CSS16641N',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isDark ? Colors.white70 : AppColors.textSecondary,
                ),
              ),

              const SizedBox(height: 32),

              // Version History Placeholder
              Center(
                child: Text(
                  'Version 1.0.0 (ล่าสุด)',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isDark
                        ? AppColors.stormyMutedBlueGrey
                        : AppColors.textLight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, IconData icon, String text) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color: isDark ? AppColors.stormySkyBlue : AppColors.primaryBlue,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? Colors.white70 : AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
