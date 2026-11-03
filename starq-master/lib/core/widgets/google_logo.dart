import 'package:flutter/material.dart';

/// Renders the official multi-color Google 'G' icon using zero-dependency vector paths.
class GoogleLogo extends StatelessWidget {
  final double size;

  const GoogleLogo({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _GoogleLogoPainter(),
      ),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 24.0;
    canvas.save();
    canvas.scale(scale, scale);

    final bluePaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final greenPaint = Paint()
      ..color = const Color(0xFF34A853)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final yellowPaint = Paint()
      ..color = const Color(0xFFFBBC05)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final redPaint = Paint()
      ..color = const Color(0xFFEA4335)
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    // Blue segment
    final bluePath = Path()
      ..moveTo(23.745, 12.27)
      ..relativeCubicTo(0, -0.7, -0.06, -1.4, -0.19, -2.07)
      ..lineTo(12, 10.2)
      ..lineTo(12, 14.71)
      ..lineTo(18.6, 14.71)
      ..relativeCubicTo(-0.29, 1.52, -1.14, 2.8, -2.4, 3.66)
      ..relativeLineTo(3.88, 3.04)
      ..relativeCubicTo(2.28, -2.09, 3.66, -5.17, 3.66, -9.14)
      ..close();
    canvas.drawPath(bluePath, bluePaint);

    // Green segment
    final greenPath = Path()
      ..moveTo(12, 24)
      ..relativeCubicTo(3.24, 0, 5.95, -1.08, 7.93, -2.91)
      ..relativeLineTo(-3.88, -3.04)
      ..relativeCubicTo(-1.08, 0.72, -2.45, 1.16, -4.05, 1.16)
      ..relativeCubicTo(-3.12, 0, -5.77, -2.1, -6.72, -4.93)
      ..lineTo(1.24, 14.28)
      ..relativeLineTo(0, 3.13)
      ..cubicTo(3.26, 21.36, 7.33, 24, 12, 24)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // Yellow segment
    final yellowPath = Path()
      ..moveTo(5.28, 14.28)
      ..relativeCubicTo(-0.25, -0.72, -0.38, -1.49, -0.38, -2.28)
      ..relativeCubicTo(0, -0.79, 0.14, -1.56, 0.38, -2.28)
      ..lineTo(5.28, 6.59)
      ..lineTo(1.24, 6.59)
      ..cubicTo(0.45, 8.16, 0, 9.93, 0, 12)
      ..cubicTo(0, 14.07, 0.45, 15.84, 1.24, 17.41)
      ..lineTo(5.28, 14.28)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // Red segment
    final redPath = Path()
      ..moveTo(12, 4.75)
      ..relativeCubicTo(1.77, 0, 3.35, 0.61, 4.6, 1.8)
      ..relativeLineTo(3.42, -3.42)
      ..cubicTo(17.95, 1.19, 15.24, 0, 12, 0)
      ..cubicTo(7.33, 0, 3.26, 2.64, 1.24, 6.59)
      ..relativeLineTo(4.04, 3.13)
      ..cubicTo(6.23, 6.89, 8.88, 4.75, 12, 4.75)
      ..close();
    canvas.drawPath(redPath, redPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
