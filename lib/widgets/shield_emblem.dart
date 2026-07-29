import 'package:flutter/material.dart';

/// A custom widget that draws a "Shield Emblem" logo representing progress
/// and achievement for the QuestLife app.
class ShieldEmblem extends StatelessWidget {
  final double size;

  const ShieldEmblem({super.key, this.size = 100.0});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(size: Size(size, size), painter: ShieldEmblemPainter());
  }
}

class ShieldEmblemPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;

    // Gradient Paint for the emblem
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF88BDF2), // Sky Blue (Primary)
          Color(0xFF384959), // Dark Slate (Shadow/Depth)
        ],
      ).createShader(Rect.fromLTWH(0, 0, w, h))
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.08
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 1. Draw the Shield Path
    final shieldPath = Path();
    shieldPath.moveTo(w * 0.1, h * 0.2); // Top left
    shieldPath.lineTo(w * 0.5, h * 0.05); // Top center peak
    shieldPath.lineTo(w * 0.9, h * 0.2); // Top right

    // Curves for the bottom of the shield
    shieldPath.quadraticBezierTo(w * 0.9, h * 0.7, w * 0.5, h * 0.95);
    shieldPath.quadraticBezierTo(w * 0.1, h * 0.7, w * 0.1, h * 0.2);
    shieldPath.close();

    // Add a subtle drop shadow to the shield to make it look like a physical badge
    canvas.drawShadow(
      shieldPath,
      Colors.black.withValues(alpha: 0.3),
      4.0,
      false,
    );

    // Render the shield outline
    canvas.drawPath(shieldPath, paint);

    // 2. Draw the Stylized 'Q' (Blade/Sword)
    final qPath = Path();

    // Angular, sharp inner diamond for the 'Q' body
    qPath.moveTo(w * 0.5, h * 0.35); // Top point
    qPath.lineTo(w * 0.65, h * 0.5); // Right point
    qPath.lineTo(w * 0.5, h * 0.65); // Bottom point
    qPath.lineTo(w * 0.35, h * 0.5); // Left point
    qPath.close();

    // Sword slash representing the tail of the 'Q'
    qPath.moveTo(w * 0.58, h * 0.58);
    qPath.lineTo(w * 0.75, h * 0.75);

    final innerPaint = Paint()
      ..shader = paint.shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.06
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(qPath, innerPaint);

    // 3. Draw Achievements (3 small diagonal bars)
    final barPaint = Paint()
      ..shader = paint.shader
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04
      ..strokeCap = StrokeCap.round;

    // Small, evenly spaced diagonal bars at the top-right corner
    canvas.drawLine(
      Offset(w * 0.70, h * 0.22),
      Offset(w * 0.78, h * 0.14),
      barPaint,
    );
    canvas.drawLine(
      Offset(w * 0.76, h * 0.28),
      Offset(w * 0.84, h * 0.20),
      barPaint,
    );
    canvas.drawLine(
      Offset(w * 0.82, h * 0.34),
      Offset(w * 0.90, h * 0.26),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    // Static drawing, no need to repaint unless size changes
    return false;
  }
}
