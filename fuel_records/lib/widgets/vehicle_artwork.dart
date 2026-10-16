import 'package:flutter/material.dart';
import '../models/vehicle.dart';

/// A rich, vector-rendered automotive artwork widget for all vehicle types.
/// Supports dynamic body color, shadow, wheels, glass highlights, and responsive sizing.
class VehicleArtwork extends StatelessWidget {
  final VehicleType type;
  final Color bodyColor;
  final double width;
  final double height;
  final bool showBadge;

  const VehicleArtwork({
    super.key,
    required this.type,
    this.bodyColor = const Color(0xFF1E88E5),
    this.width = 120,
    this.height = 70,
    this.showBadge = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(width, height),
            painter: VehiclePainter(
              type: type,
              bodyColor: bodyColor,
            ),
          ),
          if (showBadge)
            Positioned(
              bottom: 2,
              right: 2,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.65),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white24, width: 0.8),
                ),
                child: Text(
                  type.shortName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class VehiclePainter extends CustomPainter {
  final VehicleType type;
  final Color bodyColor;

  VehiclePainter({
    required this.type,
    required this.bodyColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Ground shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withOpacity(0.18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(w * 0.5, h * 0.88),
        width: w * 0.86,
        height: h * 0.12,
      ),
      shadowPaint,
    );

    switch (type) {
      case VehicleType.suv:
        _drawSUV(canvas, size);
        break;
      case VehicleType.sedan:
        _drawSedan(canvas, size);
        break;
      case VehicleType.compact:
        _drawCompact(canvas, size);
        break;
      case VehicleType.truck:
        _drawTruck(canvas, size);
        break;
      case VehicleType.coupe:
        _drawCoupe(canvas, size);
        break;
      case VehicleType.van:
        _drawVan(canvas, size);
        break;
      case VehicleType.motorcycle:
        _drawMotorcycle(canvas, size);
        break;
      case VehicleType.ev:
        _drawEV(canvas, size);
        break;
    }
  }

  void _drawWheels(Canvas canvas, Size size, double frontX, double rearX, double wheelY, double radius) {
    final tirePaint = Paint()..color = const Color(0xFF212121);
    final rimPaint = Paint()..color = const Color(0xFFD6D6D6);
    final hubPaint = Paint()..color = const Color(0xFF424242);
    final treadPaint = Paint()
      ..color = const Color(0xFF111111)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (final x in [frontX, rearX]) {
      final center = Offset(x, wheelY);
      // Outer tire
      canvas.drawCircle(center, radius, tirePaint);
      canvas.drawCircle(center, radius, treadPaint);
      // Silver rim
      canvas.drawCircle(center, radius * 0.62, rimPaint);
      // Inner hub
      canvas.drawCircle(center, radius * 0.32, hubPaint);
      // Spoke accents
      final spokePaint = Paint()
        ..color = const Color(0xFF757575)
        ..strokeWidth = 1.0;
      canvas.drawLine(Offset(x - radius * 0.5, wheelY), Offset(x + radius * 0.5, wheelY), spokePaint);
      canvas.drawLine(Offset(x, wheelY - radius * 0.5), Offset(x, wheelY + radius * 0.5), spokePaint);
    }
  }

  void _drawSUV(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Roof rack
    final rackPaint = Paint()
      ..color = const Color(0xFF424242)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.28, h * 0.23), Offset(w * 0.76, h * 0.23), rackPaint);
    canvas.drawLine(Offset(w * 0.34, h * 0.23), Offset(w * 0.34, h * 0.27), rackPaint);
    canvas.drawLine(Offset(w * 0.70, h * 0.23), Offset(w * 0.70, h * 0.27), rackPaint);

    // Body path
    final bodyPath = Path();
    bodyPath.moveTo(w * 0.08, h * 0.65); // Rear bumper
    bodyPath.lineTo(w * 0.10, h * 0.34); // Rear pillar
    bodyPath.lineTo(w * 0.25, h * 0.26); // Roof start
    bodyPath.lineTo(w * 0.74, h * 0.26); // Roof end
    bodyPath.lineTo(w * 0.88, h * 0.44); // Windshield down
    bodyPath.lineTo(w * 0.94, h * 0.47); // Hood
    bodyPath.lineTo(w * 0.96, h * 0.64); // Front bumper
    bodyPath.lineTo(w * 0.08, h * 0.65); // Underbody base
    bodyPath.close();

    final bodyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        bodyColor.withOpacity(0.95),
        bodyColor,
        Color.lerp(bodyColor, Colors.black, 0.35)!,
      ],
    );
    final bodyPaint = Paint()..shader = bodyGradient.createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(bodyPath, bodyPaint);

    // Windows
    final glassPath = Path();
    glassPath.moveTo(w * 0.27, h * 0.30);
    glassPath.lineTo(w * 0.48, h * 0.30);
    glassPath.lineTo(w * 0.48, h * 0.44);
    glassPath.lineTo(w * 0.22, h * 0.44);
    glassPath.close();

    glassPath.moveTo(w * 0.52, h * 0.30);
    glassPath.lineTo(w * 0.72, h * 0.30);
    glassPath.lineTo(w * 0.83, h * 0.44);
    glassPath.lineTo(w * 0.52, h * 0.44);
    glassPath.close();

    final glassPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [const Color(0xFF90CAF9).withOpacity(0.9), const Color(0xFF1565C0).withOpacity(0.75)],
      ).createShader(Rect.fromLTWH(w * 0.2, h * 0.25, w * 0.7, h * 0.25));
    canvas.drawPath(glassPath, glassPaint);

    // Headlight & Taillight
    final headlightPaint = Paint()..color = const Color(0xFFFFF176);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.92, h * 0.50, w * 0.04, h * 0.08), const Radius.circular(2)),
      headlightPaint,
    );
    final taillightPaint = Paint()..color = const Color(0xFFE53935);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.08, h * 0.46, w * 0.03, h * 0.10), const Radius.circular(2)),
      taillightPaint,
    );

    // Wheels
    _drawWheels(canvas, size, w * 0.77, w * 0.24, h * 0.68, h * 0.16);
  }

  void _drawSedan(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bodyPath = Path();
    bodyPath.moveTo(w * 0.06, h * 0.65); // Rear
    bodyPath.lineTo(w * 0.16, h * 0.50); // Trunk
    bodyPath.lineTo(w * 0.30, h * 0.33); // Rear window
    bodyPath.lineTo(w * 0.66, h * 0.33); // Roof
    bodyPath.lineTo(w * 0.82, h * 0.48); // Windshield
    bodyPath.lineTo(w * 0.94, h * 0.52); // Hood
    bodyPath.lineTo(w * 0.96, h * 0.65); // Front bumper
    bodyPath.lineTo(w * 0.06, h * 0.65);
    bodyPath.close();

    final bodyGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        bodyColor.withOpacity(0.95),
        bodyColor,
        Color.lerp(bodyColor, Colors.black, 0.3)!,
      ],
    );
    canvas.drawPath(bodyPath, Paint()..shader = bodyGradient.createShader(Rect.fromLTWH(0, 0, w, h)));

    // Windows
    final glassPath = Path();
    glassPath.moveTo(w * 0.33, h * 0.36);
    glassPath.lineTo(w * 0.48, h * 0.36);
    glassPath.lineTo(w * 0.48, h * 0.48);
    glassPath.lineTo(w * 0.26, h * 0.48);
    glassPath.close();

    glassPath.moveTo(w * 0.51, h * 0.36);
    glassPath.lineTo(w * 0.65, h * 0.36);
    glassPath.lineTo(w * 0.78, h * 0.48);
    glassPath.lineTo(w * 0.51, h * 0.48);
    glassPath.close();

    final glassPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [const Color(0xFFB3E5FC), const Color(0xFF0288D1)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(glassPath, glassPaint);

    // Lights
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.91, h * 0.53, w * 0.045, h * 0.06), const Radius.circular(2)),
      Paint()..color = const Color(0xFFFFF9C4),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.06, h * 0.52, w * 0.03, h * 0.08), const Radius.circular(2)),
      Paint()..color = const Color(0xFFE53935),
    );

    // Wheels
    _drawWheels(canvas, size, w * 0.77, w * 0.24, h * 0.66, h * 0.15);
  }

  void _drawCompact(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bodyPath = Path();
    bodyPath.moveTo(w * 0.10, h * 0.65);
    bodyPath.lineTo(w * 0.12, h * 0.42); // Steep hatch rear
    bodyPath.lineTo(w * 0.28, h * 0.30); // Roof start
    bodyPath.lineTo(w * 0.64, h * 0.30); // Roof
    bodyPath.lineTo(w * 0.82, h * 0.48); // Windshield
    bodyPath.lineTo(w * 0.92, h * 0.52); // Short hood
    bodyPath.lineTo(w * 0.94, h * 0.65); // Front bumper
    bodyPath.lineTo(w * 0.10, h * 0.65);
    bodyPath.close();

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [bodyColor.withOpacity(0.95), bodyColor, Color.lerp(bodyColor, Colors.black, 0.3)!],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(bodyPath, bodyPaint);

    // Windows
    final glassPath = Path();
    glassPath.moveTo(w * 0.26, h * 0.33);
    glassPath.lineTo(w * 0.46, h * 0.33);
    glassPath.lineTo(w * 0.46, h * 0.46);
    glassPath.lineTo(w * 0.20, h * 0.46);
    glassPath.close();

    glassPath.moveTo(w * 0.49, h * 0.33);
    glassPath.lineTo(w * 0.63, h * 0.33);
    glassPath.lineTo(w * 0.77, h * 0.46);
    glassPath.lineTo(w * 0.49, h * 0.46);
    glassPath.close();

    canvas.drawPath(
      glassPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFFB3E5FC), const Color(0xFF0288D1)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Lights
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.89, h * 0.53, w * 0.045, h * 0.07), const Radius.circular(2)),
      Paint()..color = const Color(0xFFFFF9C4),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.10, h * 0.45, w * 0.03, h * 0.10), const Radius.circular(2)),
      Paint()..color = const Color(0xFFE53935),
    );

    _drawWheels(canvas, size, w * 0.74, w * 0.26, h * 0.67, h * 0.15);
  }

  void _drawTruck(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bodyPath = Path();
    bodyPath.moveTo(w * 0.06, h * 0.63);
    bodyPath.lineTo(w * 0.06, h * 0.46); // Bed tailgate
    bodyPath.lineTo(w * 0.42, h * 0.46); // Bed rail
    bodyPath.lineTo(w * 0.43, h * 0.25); // Cabin rear
    bodyPath.lineTo(w * 0.72, h * 0.25); // Cabin roof
    bodyPath.lineTo(w * 0.85, h * 0.45); // Windshield
    bodyPath.lineTo(w * 0.96, h * 0.47); // Tall hood
    bodyPath.lineTo(w * 0.97, h * 0.63); // Rugged front bumper
    bodyPath.lineTo(w * 0.06, h * 0.63);
    bodyPath.close();

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [bodyColor.withOpacity(0.95), bodyColor, Color.lerp(bodyColor, Colors.black, 0.35)!],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(bodyPath, bodyPaint);

    // Bed liner
    final bedPaint = Paint()..color = const Color(0xFF2E2E2E);
    canvas.drawRect(Rect.fromLTWH(w * 0.08, h * 0.48, w * 0.34, h * 0.14), bedPaint);

    // Cabin window
    final glassPath = Path();
    glassPath.moveTo(w * 0.46, h * 0.29);
    glassPath.lineTo(w * 0.70, h * 0.29);
    glassPath.lineTo(w * 0.81, h * 0.44);
    glassPath.lineTo(w * 0.46, h * 0.44);
    glassPath.close();
    canvas.drawPath(
      glassPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFFB3E5FC), const Color(0xFF0288D1)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Lights
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.93, h * 0.49, w * 0.04, h * 0.09), const Radius.circular(2)),
      Paint()..color = const Color(0xFFFFF59D),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.06, h * 0.47, w * 0.025, h * 0.10), const Radius.circular(2)),
      Paint()..color = const Color(0xFFE53935),
    );

    // High clearance rugged wheels
    _drawWheels(canvas, size, w * 0.78, w * 0.23, h * 0.67, h * 0.17);
  }

  void _drawCoupe(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Rear spoiler
    final spoilerPaint = Paint()
      ..color = Color.lerp(bodyColor, Colors.black, 0.4)!
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.05, h * 0.47), Offset(w * 0.13, h * 0.47), spoilerPaint);

    final bodyPath = Path();
    bodyPath.moveTo(w * 0.06, h * 0.67);
    bodyPath.lineTo(w * 0.12, h * 0.52); // Sleek rear
    bodyPath.lineTo(w * 0.32, h * 0.36); // Fastback slope
    bodyPath.lineTo(w * 0.58, h * 0.36); // Short roof
    bodyPath.lineTo(w * 0.78, h * 0.51); // Aggressive windshield
    bodyPath.lineTo(w * 0.94, h * 0.55); // Long low hood
    bodyPath.lineTo(w * 0.97, h * 0.67); // Front splitter
    bodyPath.lineTo(w * 0.06, h * 0.67);
    bodyPath.close();

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [bodyColor.withOpacity(0.95), bodyColor, Color.lerp(bodyColor, Colors.black, 0.3)!],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(bodyPath, bodyPaint);

    // Window
    final glassPath = Path();
    glassPath.moveTo(w * 0.36, h * 0.39);
    glassPath.lineTo(w * 0.57, h * 0.39);
    glassPath.lineTo(w * 0.74, h * 0.50);
    glassPath.lineTo(w * 0.28, h * 0.50);
    glassPath.close();
    canvas.drawPath(
      glassPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [const Color(0xFF80D8FF), const Color(0xFF0091EA)],
        ).createShader(Rect.fromLTWH(0, 0, w, h)),
    );

    // Sharp Headlights
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.90, h * 0.56, w * 0.055, h * 0.05), const Radius.circular(2)),
      Paint()..color = const Color(0xFFFFF9C4),
    );

    // Sport wheels
    _drawWheels(canvas, size, w * 0.78, w * 0.23, h * 0.67, h * 0.14);
  }

  void _drawVan(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final bodyPath = Path();
    bodyPath.moveTo(w * 0.08, h * 0.66);
    bodyPath.lineTo(w * 0.08, h * 0.30); // Tall upright rear
    bodyPath.lineTo(w * 0.18, h * 0.24);
    bodyPath.lineTo(w * 0.74, h * 0.24); // Long flat roof
    bodyPath.lineTo(w * 0.88, h * 0.42); // Steep windshield
    bodyPath.lineTo(w * 0.95, h * 0.46); // Short nose
    bodyPath.lineTo(w * 0.96, h * 0.66);
    bodyPath.lineTo(w * 0.08, h * 0.66);
    bodyPath.close();

    final bodyPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [bodyColor.withOpacity(0.95), bodyColor, Color.lerp(bodyColor, Colors.black, 0.3)!],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(bodyPath, bodyPaint);

    // Windows row
    final glassPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [const Color(0xFFB3E5FC), const Color(0xFF0288D1)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.16, h * 0.29, w * 0.18, h * 0.15), const Radius.circular(2)),
      glassPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.38, h * 0.29, w * 0.20, h * 0.15), const Radius.circular(2)),
      glassPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.62, h * 0.29, w * 0.20, h * 0.15), const Radius.circular(2)),
      glassPaint,
    );

    _drawWheels(canvas, size, w * 0.77, w * 0.24, h * 0.68, h * 0.15);
  }

  void _drawEV(Canvas canvas, Size size) {
    // Futuristic aerodynamic EV
    _drawSedan(canvas, size);

    final w = size.width;
    final h = size.height;

    // Glowing cyan accent line representing EV/clean energy
    final evGlowPaint = Paint()
      ..color = const Color(0xFF00E5FF)
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.32, h * 0.62), Offset(w * 0.68, h * 0.62), evGlowPaint);

    // Subtle lightning badge icon
    final boltPath = Path();
    boltPath.moveTo(w * 0.50, h * 0.40);
    boltPath.lineTo(w * 0.47, h * 0.46);
    boltPath.lineTo(w * 0.51, h * 0.46);
    boltPath.lineTo(w * 0.48, h * 0.53);
    boltPath.lineTo(w * 0.53, h * 0.45);
    boltPath.lineTo(w * 0.49, h * 0.45);
    boltPath.close();

    canvas.drawPath(boltPath, Paint()..color = const Color(0xFF00E5FF));
  }

  void _drawMotorcycle(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // Bike Frame
    final framePaint = Paint()
      ..color = bodyColor
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.28, h * 0.68), Offset(w * 0.48, h * 0.52), framePaint);
    canvas.drawLine(Offset(w * 0.48, h * 0.52), Offset(w * 0.68, h * 0.42), framePaint);
    canvas.drawLine(Offset(w * 0.68, h * 0.42), Offset(w * 0.75, h * 0.68), framePaint);

    // Fuel Tank
    final tankPaint = Paint()..color = bodyColor;
    canvas.drawOval(Rect.fromLTWH(w * 0.44, h * 0.38, w * 0.22, h * 0.14), tankPaint);

    // Handlebars & Seat
    final partPaint = Paint()
      ..color = const Color(0xFF212121)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.66, h * 0.40), Offset(w * 0.62, h * 0.28), partPaint); // Fork
    canvas.drawLine(Offset(w * 0.34, h * 0.46), Offset(w * 0.46, h * 0.47), partPaint); // Seat

    // Exhaust
    final exhaustPaint = Paint()
      ..color = const Color(0xFFB0BEC5)
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(w * 0.44, h * 0.64), Offset(w * 0.22, h * 0.64), exhaustPaint);

    // Big moto wheels
    _drawWheels(canvas, size, w * 0.75, w * 0.24, h * 0.68, h * 0.18);
  }

  @override
  bool shouldRepaint(covariant VehiclePainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.bodyColor != bodyColor;
  }
}

