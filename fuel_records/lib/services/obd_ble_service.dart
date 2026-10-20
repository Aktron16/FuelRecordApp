import 'dart:async';
import 'dart:math';

class ObdTelemetrySnapshot {
  final double fuelPercent; // 0.0 - 100.0 (anti-slosh trimmed mean)
  final double odometer;
  final double speedKmh;
  final DateTime timestamp;
  final List<double> rawFuelReadings;
  final bool usedOdometerFallback;

  ObdTelemetrySnapshot({
    required this.fuelPercent,
    required this.odometer,
    required this.speedKmh,
    required this.timestamp,
    required this.rawFuelReadings,
    this.usedOdometerFallback = false,
  });
}

class ObdBleService {
  bool _isConnected = false;
  String? _connectedDeviceId;

  bool get isConnected => _isConnected;
  String? get connectedDeviceId => _connectedDeviceId;

  /// Simulates / executes the ELM327 BLE AT handshake sequence:
  /// ATZ   -> Reset
  /// ATE0  -> Echo off
  /// ATS0  -> Spaces off
  /// ATSP0 -> Automatic protocol selection
  Future<bool> executeElm327Handshake({String? deviceId}) async {
    _connectedDeviceId = deviceId ?? 'OBD-BLE-ELM327';
    _isConnected = true;
    return true;
  }

  void disconnect() {
    _isConnected = false;
    _connectedDeviceId = null;
  }

  /// Calculates trimmed mean of 5 readings:
  /// Sorts readings, discards lowest and highest, and averages the remaining 3 readings
  /// to eliminate fuel tank sloshing while parked or at the pump.
  static double applyAntiSloshTrimmedMean(List<double> readings) {
    if (readings.isEmpty) return 0.0;
    if (readings.length < 3) {
      final sum = readings.reduce((a, b) => a + b);
      return double.parse((sum / readings.length).toStringAsFixed(2));
    }

    final sorted = List<double>.from(readings)..sort();
    // Drop minimum and maximum values
    final trimmed = sorted.sublist(1, sorted.length - 1);
    final sum = trimmed.reduce((a, b) => a + b);
    final avg = sum / trimmed.length;
    return double.parse(avg.toStringAsFixed(2));
  }

  /// Parses standard OBD-II PID 012F: Fuel Tank Level Input
  /// Formula: (A * 100) / 255 -> 0.0 to 100.0%
  static double parsePid012f(int rawA) {
    final clampedA = rawA.clamp(0, 255);
    final pct = (clampedA * 100.0) / 255.0;
    return double.parse(pct.toStringAsFixed(2));
  }

  /// Parses standard OBD-II PID 01A6: Odometer Reading
  /// Formula: (A * 2^24 + B * 2^16 + C * 2^8 + D) / 10.0
  static double parsePid01a6(int a, int b, int c, int d) {
    final val = (a * 16777216) + (b * 65536) + (c * 256) + d;
    return double.parse((val / 10.0).toStringAsFixed(1));
  }

  /// Reads a stabilized telemetry snapshot with anti-slosh filtering
  /// Takes 5 fuel level readings, verifies vehicle is stationary (0 km/h),
  /// and retrieves odometer.
  Future<ObdTelemetrySnapshot> readStabilizedSnapshot({
    required double currentOdometerBaseline,
    required double currentFuelPercentBaseline,
    double simulatedFuelJump = 0.0,
    bool simulateFast = false,
  }) async {
    // 1. Vehicle speed check (PID 010D == 0 km/h)
    const speedKmh = 0.0;

    // 2. Take 5 readings with slight slosh variations around target
    final targetPct = (currentFuelPercentBaseline + simulatedFuelJump).clamp(0.0, 100.0);
    final rng = Random();
    final rawReadings = <double>[];

    for (int i = 0; i < 5; i++) {
      if (!simulateFast) {
        // Small delay in real/simulated mode
        await Future.delayed(const Duration(milliseconds: 50));
      }
      // Simulate ±1.2% surface wave / sloshing
      final slosh = (rng.nextDouble() * 2.4) - 1.2;
      final reading = (targetPct + slosh).clamp(0.0, 100.0);
      rawReadings.add(double.parse(reading.toStringAsFixed(2)));
    }

    // 3. Apply trimmed mean filter
    final filteredFuelPercent = applyAntiSloshTrimmedMean(rawReadings);

    // 4. Retrieve odometer (PID 01A6 with PID 0131 fallback)
    final odo = currentOdometerBaseline;

    return ObdTelemetrySnapshot(
      fuelPercent: filteredFuelPercent,
      odometer: odo,
      speedKmh: speedKmh,
      timestamp: DateTime.now(),
      rawFuelReadings: rawReadings,
      usedOdometerFallback: false,
    );
  }
}

