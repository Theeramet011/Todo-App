import 'dart:ui';
import 'dart:math' as math;
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/colors.dart';
import '../providers/auth_provider.dart';
import '../utils/responsive.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
          CurvedAnimation(parent: _animationController, curve: Curves.easeOut),
        );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
            // Background (Animated Mesh Gradient)
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
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Center Glass Card (Glassmorphism)
                            ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 15,
                                  sigmaY: 15,
                                ),
                                child: Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 32,
                                    vertical: 48,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(
                                            0xFF1A2530,
                                          ).withValues(alpha: 0.3)
                                        : Colors.white.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(24),
                                    border: Border.all(
                                      color: Colors.white.withValues(
                                        alpha: 0.4,
                                      ),
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Logo
                                      SizedBox(
                                        width: 100,
                                        height: 100,
                                        child: OverflowBox(
                                          maxWidth: 150,
                                          maxHeight: 150,
                                          child: Image.asset(
                                            'assets/images/logo.png',
                                            width: 150,
                                            height: 150,
                                          ),
                                        ),
                                      ),

                                      const SizedBox(height: 32),

                                      // App Name
                                      Text(
                                        'QuestLife',
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.bold,
                                          color: isDark
                                              ? Colors.white
                                              : AppColors.stormyDarkSlate,
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
                                          pause: const Duration(seconds: 2),
                                          animatedTexts: [
                                            TypewriterAnimatedText(
                                              'อัปเลเวลให้ชีวิต พิชิตทีละเป้าหมาย',
                                              textStyle: TextStyle(
                                                fontSize: 14,
                                                color: isDark
                                                    ? AppColors.stormyIceBlue
                                                    : AppColors
                                                          .stormyMutedBlueGrey,
                                                letterSpacing: 0.5,
                                              ),
                                              textAlign: TextAlign.center,
                                              speed: const Duration(
                                                milliseconds: 100,
                                              ),
                                            ),
                                            TypewriterAnimatedText(
                                              'เปลี่ยนทุกความรับผิดชอบ ให้เป็นความท้าทาย',
                                              textStyle: TextStyle(
                                                fontSize: 14,
                                                color: isDark
                                                    ? AppColors.stormyIceBlue
                                                    : AppColors
                                                          .stormyMutedBlueGrey,
                                                letterSpacing: 0.5,
                                              ),
                                              textAlign: TextAlign.center,
                                              speed: const Duration(
                                                milliseconds: 100,
                                              ),
                                            ),
                                            TypewriterAnimatedText(
                                              'เคลียร์เควสต์วันนี้ เพื่อผลลัพธ์ที่ดีกว่าเดิม',
                                              textStyle: TextStyle(
                                                fontSize: 14,
                                                color: isDark
                                                    ? AppColors.stormyIceBlue
                                                    : AppColors
                                                          .stormyMutedBlueGrey,
                                                letterSpacing: 0.5,
                                              ),
                                              textAlign: TextAlign.center,
                                              speed: const Duration(
                                                milliseconds: 100,
                                              ),
                                            ),
                                            TypewriterAnimatedText(
                                              'พร้อมจะเริ่มภารกิจใหม่แล้วหรือยัง?',
                                              textStyle: TextStyle(
                                                fontSize: 14,
                                                color: isDark
                                                    ? AppColors.stormyIceBlue
                                                    : AppColors
                                                          .stormyMutedBlueGrey,
                                                letterSpacing: 0.5,
                                              ),
                                              textAlign: TextAlign.center,
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
                                          if (authProvider.isLoading) {
                                            return const CircularProgressIndicator(
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    AppColors.stormySkyBlue,
                                                  ),
                                            );
                                          } else {
                                            return _buildSignInButton(context);
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
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

        // ล็อกอินด้วย Google
        final success = await authProvider.signInWithGoogle();

        // ตรวจสอบว่าหน้าจอนี้ยังเปิดอยู่ไหม (ป้องกัน Error ก่อนใช้งาน context)
        if (!context.mounted) return;

        if (success && authProvider.isLoggedIn) {
          // เพิ่มดีเลย์เล็กน้อยเพื่อให้ Emulator ประมวลผลหน้าต่าง Google Sign-in เสร็จก่อน (ลดอาการค้าง)
          await Future.delayed(const Duration(milliseconds: 300));

          if (!context.mounted) return;

          // AuthGate will automatically navigate us to HomeScreen when authProvider.isLoggedIn becomes true.
          // Removed Navigator.pushReplacement to prevent race condition with achievement dialogs.
        } else if (authProvider.errorMessage != null) {
          // แสดง Error Message ที่เป็นมิตรมากขึ้น
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.error_outline, color: Colors.white, size: 20),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'การเข้าสู่ระบบถูกยกเลิก',
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
            // Google Icon
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
              'เข้าสู่ระบบด้วย Google',
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

// ==========================================
// Animated Mesh Background
// ==========================================

class AnimatedMeshBackground extends StatefulWidget {
  final bool isDark;
  const AnimatedMeshBackground({super.key, required this.isDark});

  @override
  State<AnimatedMeshBackground> createState() => _AnimatedMeshBackgroundState();
}

class _AnimatedMeshBackgroundState extends State<AnimatedMeshBackground>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 15),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          painter: MeshGradientPainter(
            isDark: widget.isDark,
            animationValue: _controller.value,
          ),
          child: Container(), // Fills the available space
        );
      },
    );
  }
}

class MeshGradientPainter extends CustomPainter {
  final bool isDark;
  final double animationValue;

  MeshGradientPainter({required this.isDark, required this.animationValue});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw Base Gradient
    final rect = Offset.zero & size;
    final baseGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: isDark
          ? [
              AppColors.stormyNightBackground,
              AppColors.stormyDarkSlate,
              AppColors.stormySkyBlue.withValues(alpha: 0.3),
            ]
          : [
              Colors.white,
              AppColors.stormyIceBlue,
              AppColors.stormySkyBlue.withValues(alpha: 0.5),
            ],
      stops: const [0.0, 0.6, 1.0],
    );
    canvas.drawRect(rect, Paint()..shader = baseGradient.createShader(rect));

    final t = animationValue * 2 * math.pi;

    // Helper function to get oscillating opacity
    double getOpacity(double offset) {
      return 0.3 +
          (math.sin(t + offset) + 1) /
              2 *
              0.5; // Oscillates between 0.3 and 0.8
    }

    // Common MaskFilter for blur effect
    const maskFilter = MaskFilter.blur(BlurStyle.normal, 80);

    // 2. Draw Blob 1
    final color1 = isDark
        ? AppColors.stormySkyBlue.withValues(alpha: 0.5)
        : AppColors.stormyIceBlue;
    final paint1 = Paint()
      ..color = color1.withValues(alpha: getOpacity(0))
      ..maskFilter = maskFilter;
    canvas.drawCircle(
      Offset(
        size.width / 2 + math.sin(t) * size.width * 0.3,
        size.height / 2 + math.cos(t) * size.height * 0.3,
      ),
      size.width * 0.5,
      paint1,
    );

    // 3. Draw Blob 2
    final color2 = isDark
        ? AppColors.stormyDarkSlate
        : AppColors.stormySkyBlue.withValues(alpha: 0.6);
    final paint2 = Paint()
      ..color = color2.withValues(alpha: getOpacity(math.pi / 2))
      ..maskFilter = maskFilter;
    canvas.drawCircle(
      Offset(
        size.width / 2 + math.sin(t + math.pi) * size.width * 0.4,
        size.height / 2 + math.cos(t + math.pi) * size.height * 0.3,
      ),
      size.width * 0.4,
      paint2,
    );

    // 4. Draw Blob 3
    final color3 = isDark
        ? const Color(0xFF1A2530)
        : Colors.white.withValues(alpha: 0.4);
    final paint3 = Paint()
      ..color = color3.withValues(alpha: getOpacity(math.pi))
      ..maskFilter = maskFilter;
    canvas.drawCircle(
      Offset(
        size.width / 2 + math.sin(t + math.pi / 2) * size.width * 0.4,
        size.height / 2 + math.cos(t + math.pi / 2) * size.height * 0.4,
      ),
      size.width * 0.45,
      paint3,
    );
  }

  @override
  bool shouldRepaint(covariant MeshGradientPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isDark != isDark;
  }
}
