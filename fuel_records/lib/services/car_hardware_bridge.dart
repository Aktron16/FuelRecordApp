import 'dart:math';
import '../models/vehicle.dart';
import 'station_and_price_resolver.dart';

enum CarHeadUnitType {
  androidAuto,
  appleCarPlay,
  none,
}

class HeadUnitPromptData {
  final String title;
  final String message;
  final double litersAdded;
  final double estimatedCost;
  final String stationName;
  final String currency;

  HeadUnitPromptData({
    required this.title,
    required this.message,
    required this.litersAdded,
    required this.estimatedCost,
    required this.stationName,
    required this.currency,
  });
}

class CarHardwareBridge {
  bool _isCarSessionActive = false;
  CarHeadUnitType _headUnitType = CarHeadUnitType.none;

  bool get isCarSessionActive => _isCarSessionActive;
  CarHeadUnitType get headUnitType => _headUnitType;

  /// Starts or simulates an Android Auto / Apple CarPlay head-unit session
  void connectCarSession(CarHeadUnitType type) {
    _isCarSessionActive = true;
    _headUnitType = type;
  }

  void disconnectCarSession() {
    _isCarSessionActive = false;
    _headUnitType = CarHeadUnitType.none;
  }

  /// Cross-verifies telemetry between Android Auto CarInfo / CarPlay and OBD-II BLE dongle:
  /// If both return data, averages or selects the higher precision source.
  /// If no OBD dongle is paired, returns the CarInfo telemetry directly.
  static Map<String, double> fuseTelemetry({
    double? headUnitFuelPercent,
    double? headUnitMileageOdometer,
    double? obdFuelPercent,
    double? obdOdometer,
  }) {
    double finalFuelPercent;
    double finalOdometer;

    if (headUnitFuelPercent != null && obdFuelPercent != null) {
      // Both available: cross-verify (detect discrepancy within 3%, average)
      if ((headUnitFuelPercent - obdFuelPercent).abs() <= 5.0) {
        finalFuelPercent = (headUnitFuelPercent + obdFuelPercent) / 2.0;
      } else {
        // Prefer OBD direct sensor if discrepancy is high
        finalFuelPercent = obdFuelPercent;
      }
    } else {
      finalFuelPercent = headUnitFuelPercent ?? (obdFuelPercent ?? 50.0);
    }

    if (headUnitMileageOdometer != null && obdOdometer != null) {
      // Odometer should be strictly monotonically increasing, pick max
      finalOdometer = max(headUnitMileageOdometer, obdOdometer);
    } else {
      finalOdometer = headUnitMileageOdometer ?? (obdOdometer ?? 0.0);
    }

    return {
      'fuelPercent': double.parse(finalFuelPercent.toStringAsFixed(2)),
      'odometer': double.parse(finalOdometer.toStringAsFixed(1)),
    };
  }

  /// Checks if tank jump on ignition constitutes a refuel event (>= 10% tank increase)
  static bool isIgnitionRefuelDetected({
    required double currentFuelPercent,
    required double? lastKnownFuelPercent,
  }) {
    if (lastKnownFuelPercent == null) return false;
    final diff = currentFuelPercent - lastKnownFuelPercent;
    return diff >= 10.0;
  }

  /// Generates the driver-safe head unit confirmation prompt:
  /// "Refuel Detected at [Station Name]: +[XX.XX] L (~[Currency][Total Cost])"
  static HeadUnitPromptData buildHeadUnitPrompt({
    required Vehicle vehicle,
    required String stationName,
    required double currentFuelPercent,
    required double lastKnownFuelPercent,
    required double pricePerLitre,
  }) {
    final liters = StationAndPriceResolver.calculateLitersAdded(
      currentFuelPct: currentFuelPercent,
      lastFuelPct: lastKnownFuelPercent,
      tankCapacityLiters: vehicle.tankCapacityLiters,
      calibrationFactor: vehicle.calibrationFactor,
    );
    final totalCost = StationAndPriceResolver.calculateTotalCost(
      litersAdded: liters,
      pricePerLitre: pricePerLitre,
    );

    final title = 'Refuel Detected at $stationName';
    final message = '+$liters L (~${vehicle.currency}$totalCost)';

    return HeadUnitPromptData(
      title: title,
      message: message,
      litersAdded: liters,
      estimatedCost: totalCost,
      stationName: stationName,
      currency: vehicle.currency,
    );
  }
}

