// SplashToLoginScreen - หน้าจอเริ่มต้นต้อนรับ (Splash / Onboarding Screen)
//
// แสดงแอนิเมชันเปิดแอป ข้อความต้อนรับ และปุ่มสำหรับนำทางไปยังหน้าเข้าสู่ระบบ (Login)
import 'dart:ui';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../config/colors.dart';
import '../providers/auth_provider.dart';
import '../utils/responsive.dart';
import 'login_screen.dart'; // To reuse AnimatedMeshBackground

class SplashToLoginScreen extends StatefulWidget {
  const SplashToLoginScreen({super.key});

  @override
  State<SplashToLoginScreen> createState() => _SplashToLoginScreenState();
}

class _SplashToLoginScreenState extends State<SplashToLoginScreen>
    with SingleTickerProviderStateMixin {
  bool _showLogin = false;

  @override
  void initState() {
    super.initState();
    // 1. Initial delay: Show the logo in the center for 1.5 seconds
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      setState(() {
        // 2. Reveal the login card content (which naturally pushes the logo up)
        _showLogin = true;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // A ColorFilter matrix to slightly boost brightness in dark mode
    const darkBrightnessMatrix = <double>[
      1.15,
      0,
      0,
      0,
      15,
      0,
      1.15,
      0,
      0,
      15,
      0,
      0,
      1.15,
      0,
      15,
      0,
      0,
      0,
      1.0,
      0,
    ];

    // Normal identity matrix for light mode
    const identityMatrix = <double>[
      1,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
      0,
      0,
      0,
      0,
      1,
      0,
    ];

    Widget logoWidget = SizedBox(
      width: 100,
      height: 100,
      child: OverflowBox(
        maxWidth: 150,
        maxHeight: 150,
        child: Image.asset('assets/images/logo.png', width: 150, height: 150),
      ),
    );

    // Apply color filter adaptation for dark mode
    logoWidget = ColorFiltered(
      colorFilter: ColorFilter.matrix(
        isDark ? darkBrightnessMatrix : identityMatrix,
      ),
      child: logoWidget,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: isDark
            ? AppColors.stormyNightBackground
            : Colors.white,
        systemNavigationBarIconBrightness: isDark
            ? Brightness.light
            : Brightness.dark,
      ),
      child: Scaffold(
        body: Stack(
          children: [
            // Background (Animated Mesh Gradient reused from login_screen.dart)
            RepaintBoundary(child: AnimatedMeshBackground(isDark: isDark)),

            // Main Content
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: Responsive.maxContentWidth(context),
                  ),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: MediaQuery.of(context).size.width * 0.08,
                      vertical: MediaQuery.of(context).size.height * 0.05,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Center Glass Card (Glassmorphism)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 800),
                          curve: Curves.easeInOutCubic,
                          decoration: BoxDecoration(
                            // When login is hidden, we hide the glass background to keep it a pure splash screen
                            color: _showLogin
                                ? (isDark
                                      ? const Color(
                                          0xFF1A2530,
                                        ).withValues(alpha: 0.3)
                                      : Colors.white.withValues(alpha: 0.15))
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                              color: _showLogin
                                  ? Colors.white.withValues(alpha: 0.4)
                                  : Colors.transparent,
                              width: 1.5,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: BackdropFilter(
                              filter: ImageFilter.blur(
                                sigmaX: _showLogin ? 15 : 0.001,
                                sigmaY: _showLogin ? 15 : 0.001,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 32,
                                  vertical: 48,
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Logo (Always visible)
                                    logoWidget,

                                    // Content that pushes the logo up (AnimatedSize)
                                    AnimatedSize(
                                      duration: const Duration(
                                        milliseconds: 800,
                                      ),
                                      curve: Curves.easeInOutCubic,
                                      child: !_showLogin
                                          ? const SizedBox(
                                              width: double.infinity,
                                              height: 0,
                                            )
                                          : Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const SizedBox(height: 32),

                                                // App Name
                                                Text(
                                                  'QuestLife',
                                                  style: TextStyle(
                                                    fontSize: 32,
                                                    fontWeight: FontWeight.bold,
                                                    color: isDark
                                                        ? Colors.white
                                                        : AppColors
                                                              .stormyDarkSlate,
                                                    letterSpacing: 1.2,
                                                  ),
                                                  textAlign: TextAlign.center,
                                                ),

                                                const SizedBox(height: 8),

                                                // Slogan
                                                SizedBox(
                                                  height: 48,
                                                  child: AnimatedTextKit(
                                                    repeatForever: true,
                                                    displayFullTextOnTap: true,
                                                    pause: const Duration(
                                                      seconds: 2,
                                                    ),
                                                    animatedTexts: [
                                                      TypewriterAnimatedText(
                                                        'อัปเลเวลให้ชีวิต พิชิตทีละเป้าหมาย',
                                                        textStyle: TextStyle(
                                                          fontSize: 14,
                                                          color: isDark
                                                              ? AppColors
                                                                    .stormyIceBlue
                                                              : AppColors
                                                                    .stormyMutedBlueGrey,
                                                          letterSpacing: 0.5,
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                        speed: const Duration(
                                                          milliseconds: 100,
                                                        ),
                                                      ),
                                                      TypewriterAnimatedText(
                                                        'เปลี่ยนทุกความรับผิดชอบ ให้เป็นความท้าทาย',
                                                        textStyle: TextStyle(
                                                          fontSize: 14,
                                                          color: isDark
                                                              ? AppColors
                                                                    .stormyIceBlue
                                                              : AppColors
                                                                    .stormyMutedBlueGrey,
                                                          letterSpacing: 0.5,
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                        speed: const Duration(
                                                          milliseconds: 100,
                                                        ),
                                                      ),
                                                      TypewriterAnimatedText(
                                                        'เคลียร์เควสต์วันนี้ เพื่อผลลัพธ์ที่ดีกว่าเดิม',
                                                        textStyle: TextStyle(
                                                          fontSize: 14,
                                                          color: isDark
                                                              ? AppColors
                                                                    .stormyIceBlue
                                                              : AppColors
                                                                    .stormyMutedBlueGrey,
                                                          letterSpacing: 0.5,
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                        speed: const Duration(
                                                          milliseconds: 100,
                                                        ),
                                                      ),
                                                      TypewriterAnimatedText(
                                                        'พร้อมจะเริ่มภารกิจใหม่แล้วหรือยัง?',
                                                        textStyle: TextStyle(
                                                          fontSize: 14,
                                                          color: isDark
                                                              ? AppColors
                                                                    .stormyIceBlue
                                                              : AppColors
                                                                    .stormyMutedBlueGrey,
                                                          letterSpacing: 0.5,
                                                        ),
                                                        textAlign:
                                                            TextAlign.center,
                                                        speed: const Duration(
                                                          milliseconds: 100,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),

                                                const SizedBox(height: 48),

                                                // Google Sign In Button
                                                Consumer<AuthProvider>(
                                                  builder: (context, authProvider, _) {
                                                    if (authProvider
                                                        .isLoading) {
                                                      return const CircularProgressIndicator(
                                                        valueColor:
                                                            AlwaysStoppedAnimation<
                                                              Color
                                                            >(
                                                              AppColors
                                                                  .stormySkyBlue,
                                                            ),
                                                      );
                                                    } else {
                                                      return _buildSignInButton(
                                                        context,
                                                      );
                                                    }
                                                  },
                                                ),
                                              ],
                                            ).animate().fadeIn(
                                              duration: 600.ms,
                                              delay: 200.ms,
                                            ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignInButton(BuildContext context) {
    return GestureDetector(
      onTap: () async {
        final authProvider = Provider.of<AuthProvider>(context, listen: false);
        final success = await authProvider.signInWithGoogle();

        if (!context.mounted) return;

        if (success && authProvider.isLoggedIn) {
          await Future.delayed(const Duration(milliseconds: 300));
          if (!context.mounted) return;
          // AuthGate will automatically navigate us to HomeScreen when authProvider.isLoggedIn becomes true.
          // Removed Navigator.pushReplacement to prevent race condition with achievement dialogs.
        } else if (authProvider.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.error_outline, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'การลงชื่อเข้าใช้ถูกยกเลิก',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              margin: const EdgeInsets.all(20),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowMedium,
              blurRadius: 10,
              offset: Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              'https://www.gstatic.com/images/branding/product/2x/googleg_48dp.png',
              width: 24,
              height: 24,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.g_mobiledata,
                size: 32,
                color: AppColors.stormyDarkSlate,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'ลงชื่อเข้าใช้ด้วย Google',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
