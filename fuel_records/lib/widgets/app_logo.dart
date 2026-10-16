import 'package:flutter/material.dart';

/// Crisp vector/SVG-style artwork depicting a man filling up a car with fuel
/// viewed from behind (perspective from behind the car and driver).
class FuelManLogo extends StatelessWidget {
  final double size;
  final Color primaryColor;
  final bool showBackground;

  const FuelManLogo({
    super.key,
    this.size = 40,
    this.primaryColor = const Color(0xFF1E88E5),
    this.showBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    Widget canvas = CustomPaint(
      size: Size(size, size),
      painter: _FuelManPainter(
        carColor: primaryColor,
        isDark: isDark,
      ),
    );

    if (!showBackground) return canvas;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.35),
          width: 1.2,
        ),
      ),
      child: Center(child: canvas),
    );
  }
}

class _FuelManPainter extends CustomPainter {
  final Color carColor;
  final bool isDark;

  _FuelManPainter({
    required this.carColor,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Ground shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.22)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.52, h * 0.88),
        width: w * 0.78,
        height: h * 0.12,
      ),
      shadowPaint,
    );

    // 1. Gas Pump Dispenser on Right
    final pumpPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [const Color(0xFF455A64), const Color(0xFF263238)],
      ).createShader(Rect.fromLTWH(w * 0.82, h * 0.38, w * 0.15, h * 0.46));
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.82, h * 0.38, w * 0.15, h * 0.46), const Radius.circular(3)),
      pumpPaint,
    );
    // Pump screen
    canvas.drawRect(
      Rect.fromLTWH(w * 0.84, h * 0.44, w * 0.11, h * 0.08),
      Paint()..color = const Color(0xFF81D4FA),
    );

    // 2. Rear View of Car (Slightly to the left/center, perspective from behind)
    // Left & Right Rear Tires
    final tirePaint = Paint()..color = const Color(0xFF1A1A1A);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.12, h * 0.72, w * 0.11, h * 0.15), const Radius.circular(3)),
      tirePaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.48, h * 0.72, w * 0.11, h * 0.15), const Radius.circular(3)),
      tirePaint,
    );

    // Car Rear Body Silhouette
    final carPath = Path();
    carPath.moveTo(w * 0.10, h * 0.74); // Lower left bumper
    carPath.lineTo(w * 0.09, h * 0.56); // Left waistline
    carPath.lineTo(w * 0.16, h * 0.38); // Left C-pillar slope up
    carPath.lineTo(w * 0.48, h * 0.38); // Roof
    carPath.lineTo(w * 0.58, h * 0.56); // Right C-pillar slope down
    carPath.lineTo(w * 0.61, h * 0.74); // Lower right bumper
    carPath.close();

    final bodyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        carColor.withValues(alpha: 0.95),
        carColor,
        Color.lerp(carColor, Colors.black, 0.4)!,
      ],
    );
    canvas.drawPath(carPath, Paint()..shader = bodyGradient.createShader(Rect.fromLTWH(0, 0, w, h)));

    // Rear Windshield (Glass)
    final glassPath = Path();
    glassPath.moveTo(w * 0.18, h * 0.41);
    glassPath.lineTo(w * 0.46, h * 0.41);
    glassPath.lineTo(w * 0.52, h * 0.54);
    glassPath.lineTo(w * 0.14, h * 0.54);
    glassPath.close();

    final glassPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [const Color(0xFF80D8FF).withValues(alpha: 0.85), const Color(0xFF0277BD)],
      ).createShader(Rect.fromLTWH(w * 0.14, h * 0.41, w * 0.38, h * 0.14));
    canvas.drawPath(glassPath, glassPaint);

    // Taillights (Left & Right) with bright connecting LED strip
    final tailLightPaint = Paint()..color = const Color(0xFFFF2A4B);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.10, h * 0.58, w * 0.09, h * 0.05), const Radius.circular(2.5)),
      tailLightPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.51, h * 0.58, w * 0.09, h * 0.05), const Radius.circular(2.5)),
      tailLightPaint,
    );
    // Center LED bar
    canvas.drawLine(
      Offset(w * 0.19, h * 0.60),
      Offset(w * 0.51, h * 0.60),
      Paint()..color = const Color(0xFFFF3B5C)..strokeWidth = 1.6,
    );

    // License Plate
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.27, h * 0.63, w * 0.16, h * 0.06), const Radius.circular(1.5)),
      Paint()..color = Colors.white,
    );

    // Fuel Door (Open on right rear quarter panel)
    final fuelDoorPaint = Paint()..color = const Color(0xFF0C4A6E);
    canvas.drawCircle(Offset(w * 0.59, h * 0.59), w * 0.032, fuelDoorPaint);
    canvas.drawCircle(Offset(w * 0.59, h * 0.59), w * 0.032, Paint()..color = const Color(0xFF38BDF8)..style = PaintingStyle.stroke..strokeWidth = 1.0);

    // 3. Man Seen from Behind (Standing between pump and car quarter panel)
    // Man's Pants / Legs
    final pantsPaint = Paint()..color = const Color(0xFF0F172A);
    // Left leg
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.63, h * 0.68, w * 0.055, h * 0.18), const Radius.circular(2)),
      pantsPaint,
    );
    // Right leg
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.70, h * 0.68, w * 0.055, h * 0.18), const Radius.circular(2)),
      pantsPaint,
    );

    // Man's Torso / Jacket (Seen from back)
    final jacketPaint = Paint()..color = const Color(0xFF2563EB); // Vibrant royal blue jacket
    final torsoPath = Path();
    torsoPath.moveTo(w * 0.62, h * 0.52); // Left shoulder
    torsoPath.lineTo(w * 0.76, h * 0.52); // Right shoulder
    torsoPath.lineTo(w * 0.75, h * 0.69); // Right waist
    torsoPath.lineTo(w * 0.63, h * 0.69); // Left waist
    torsoPath.close();
    canvas.drawPath(torsoPath, jacketPaint);

    // Man's Head / Hair (Back of head)
    final headPaint = Paint()..color = const Color(0xFF1E293B);
    canvas.drawCircle(Offset(w * 0.69, h * 0.46), w * 0.05, headPaint);

    // Left Arm holding the Fuel Nozzle towards the car's fuel door
    final armPaint = Paint()
      ..color = const Color(0xFF3B82F6)
      ..strokeWidth = w * 0.04
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.64, h * 0.55), Offset(w * 0.60, h * 0.59), armPaint);

    // Fuel Nozzle (Black gun inserted into fuel port)
    final nozzlePaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.62, h * 0.60), Offset(w * 0.59, h * 0.59), nozzlePaint);

    // Flexible Fuel Hose from Pump to Nozzle with electric cyan highlight
    final hosePath = Path();
    hosePath.moveTo(w * 0.83, h * 0.56); // Pump outlet
    hosePath.quadraticBezierTo(w * 0.78, h * 0.72, w * 0.63, h * 0.62); // Hanging loop into nozzle
    final hosePaint = Paint()
      ..color = const Color(0xFF0F172A)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(hosePath, hosePaint);
    final hoseGlowPaint = Paint()
      ..color = const Color(0xFF38BDF8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(hosePath, hoseGlowPaint);
  }

  @override
  bool shouldRepaint(covariant _FuelManPainter oldDelegate) {
    return oldDelegate.carColor != carColor || oldDelegate.isDark != isDark;
  }
}

