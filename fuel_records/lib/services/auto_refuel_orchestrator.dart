import '../models/vehicle.dart';
import '../models/fuel_record.dart';
import '../models/pending_auto_refuel.dart';
import '../models/pit_stop_log.dart';
import 'station_and_price_resolver.dart';
import 'obd_ble_service.dart';
import 'car_hardware_bridge.dart';
import 'motion_pit_stop_service.dart';
import 'delayed_ecu_math_engine.dart';

class PreFlightSensorStatus {
  final bool isBluetoothOn;
  final bool isLocationOn;
  final bool hasBluetoothConsent;
  final bool hasLocationConsent;

  PreFlightSensorStatus({
    required this.isBluetoothOn,
    required this.isLocationOn,
    required this.hasBluetoothConsent,
    required this.hasLocationConsent,
  });

  bool get shouldAlertUser {
    final btNeedsAlert = hasBluetoothConsent && !isBluetoothOn;
    final locNeedsAlert = hasLocationConsent && !isLocationOn;
    return btNeedsAlert || locNeedsAlert;
  }

  String get alertMessage {
    if (!isBluetoothOn && !isLocationOn) {
      return 'Turn on Bluetooth & Location so FuelRecordApp can automatically detect your gas station, local price, and fuel volume at the pump.';
    } else if (!isBluetoothOn) {
      return 'Turn on Bluetooth so FuelRecordApp can read your car\'s fuel level and odometer automatically.';
    } else {
      return 'Turn on Location so FuelRecordApp can identify your gas station and local fuel prices at the pump.';
    }
  }
}

class AutoRefuelOrchestrator {
  final ObdBleService obdService = ObdBleService();
  final CarHardwareBridge carBridge = CarHardwareBridge();
  final MotionPitStopService motionService = MotionPitStopService();

  // Hardware switches (simulated/monitored)
  bool _isBluetoothHardwareOn = true;
  bool _isLocationHardwareOn = true;

  bool get isBluetoothHardwareOn => _isBluetoothHardwareOn;
  bool get isLocationHardwareOn => _isLocationHardwareOn;

  void setBluetoothHardwareState(bool isOn) {
    _isBluetoothHardwareOn = isOn;
  }

  void setLocationHardwareState(bool isOn) {
    _isLocationHardwareOn = isOn;
  }

  /// Checks pre-flight sensor readiness for Bluetooth & Location
  PreFlightSensorStatus checkPreFlightReadiness({
    required bool hasBluetoothConsent,
    required bool hasLocationConsent,
  }) {
    return PreFlightSensorStatus(
      isBluetoothOn: _isBluetoothHardwareOn,
      isLocationOn: _isLocationHardwareOn,
      hasBluetoothConsent: hasBluetoothConsent,
      hasLocationConsent: hasLocationConsent,
    );
  }

  /// Updates vehicle calibration factor using self-learning algorithm:
  /// actualLiters = Number((actualAmountPaid / pricePerLitre).toFixed(2))
  /// car.calibrationFactor = clamp(0.8 * oldFactor + 0.2 * (actualLiters / rawObdLiters), 0.85, 1.15)
  static double updateCalibrationFactor({
    required double oldFactor,
    required double actualAmountPaid,
    required double pricePerLitre,
    required double rawObdLiters,
  }) {
    if (pricePerLitre <= 0 || rawObdLiters <= 0) return oldFactor;
    final actualLiters = double.parse((actualAmountPaid / pricePerLitre).toStringAsFixed(2));
    final ratio = actualLiters / rawObdLiters;
    final newFactor = (0.8 * oldFactor) + (0.2 * ratio);
    // Clamp between 0.85 and 1.15 for safety
    return double.parse(newFactor.clamp(0.85, 1.15).toStringAsFixed(4));
  }

  /// Tier 1: Process Android Auto / Apple CarPlay Refuel Detection
  PendingAutoRefuel? processTier1CarPlayAndroidAuto({
    required Vehicle vehicle,
    required String countryName,
    required List<FuelRecord> historyRecords,
    required double currentFuelPercent,
    required double currentOdometer,
    double? latitude,
    double? longitude,
  }) {
    final lastFuel = vehicle.lastKnownFuelPercent ?? (currentFuelPercent - 25.0);
    final isRefuel = CarHardwareBridge.isIgnitionRefuelDetected(
      currentFuelPercent: currentFuelPercent,
      lastKnownFuelPercent: lastFuel,
    );

    if (!isRefuel) return null;

    final station = StationAndPriceResolver.resolveStationName(
      latitude: latitude,
      longitude: longitude,
      countryName: countryName,
      historyRecords: historyRecords,
    );

    final priceInfo = StationAndPriceResolver.resolvePricePerLitre(
      stationName: station,
      vehicle: vehicle,
      countryName: countryName,
      historyRecords: historyRecords,
      latitude: latitude,
      longitude: longitude,
    );

    final deltaPercent = currentFuelPercent - lastFuel;
    final volumeMilliliters = ((deltaPercent / 100.0) * vehicle.tankCapacityMilliliters).round();
    final rawLiters = volumeMilliliters / 1000.0;
    final liters = double.parse((rawLiters * vehicle.calibrationFactor).toStringAsFixed(2));

    final totalCost = StationAndPriceResolver.calculateTotalCost(
      litersAdded: liters,
      pricePerLitre: priceInfo.pricePerLitre,
    );

    return PendingAutoRefuel(
      id: 'auto-t1-${DateTime.now().millisecondsSinceEpoch}',
      vehicleId: vehicle.id,
      timestamp: DateTime.now(),
      latitude: latitude,
      longitude: longitude,
      detectedStationName: station,
      resolvedPricePerLitre: priceInfo.pricePerLitre,
      estimatedOdometer: currentOdometer,
      estimatedLiters: liters,
      estimatedTotalCost: totalCost,
      detectionTier: 1,
      status: 'AWAITING_USER_VERIFY',
      rawObdLiters: double.parse(rawLiters.toStringAsFixed(2)),
    );
  }

  /// Tier 2: Live OBD-II BLE + Stabilized Sensor Fusion + Hyper-Local GPS Price Resolver
  Future<PendingAutoRefuel?> processTier2LiveObdAndGps({
    required Vehicle vehicle,
    required String countryName,
    required List<FuelRecord> historyRecords,
    required double currentOdometer,
    required double fuelJumpPercent,
    double? latitude,
    double? longitude,
    bool simulateFast = false,
  }) async {
    final snapshot = await obdService.readStabilizedSnapshot(
      currentOdometerBaseline: currentOdometer,
      currentFuelPercentBaseline: vehicle.lastKnownFuelPercent ?? 30.0,
      simulatedFuelJump: fuelJumpPercent,
      simulateFast: simulateFast,
    );

    final lastFuel = vehicle.lastKnownFuelPercent ?? 30.0;
    final pctJump = snapshot.fuelPercent - lastFuel;
    if (pctJump < 10.0) return null; // Must be refuel event

    final station = StationAndPriceResolver.resolveStationName(
      latitude: latitude,
      longitude: longitude,
      countryName: countryName,
      historyRecords: historyRecords,
    );

    final priceInfo = StationAndPriceResolver.resolvePricePerLitre(
      stationName: station,
      vehicle: vehicle,
      countryName: countryName,
      historyRecords: historyRecords,
      latitude: latitude,
      longitude: longitude,
    );

    final deltaPercent = snapshot.fuelPercent - lastFuel;
    final volumeMilliliters = ((deltaPercent / 100.0) * vehicle.tankCapacityMilliliters).round();
    final rawLiters = volumeMilliliters / 1000.0;
    final liters = double.parse((rawLiters * vehicle.calibrationFactor).toStringAsFixed(2));

    final totalCost = StationAndPriceResolver.calculateTotalCost(
      litersAdded: liters,
      pricePerLitre: priceInfo.pricePerLitre,
    );

    return PendingAutoRefuel(
      id: 'auto-t2-${DateTime.now().millisecondsSinceEpoch}',
      vehicleId: vehicle.id,
      timestamp: snapshot.timestamp,
      latitude: latitude,
      longitude: longitude,
      detectedStationName: station,
      resolvedPricePerLitre: priceInfo.pricePerLitre,
      estimatedOdometer: snapshot.odometer,
      estimatedLiters: liters,
      estimatedTotalCost: totalCost,
      detectionTier: 2,
      status: 'AWAITING_USER_VERIFY',
      rawObdLiters: double.parse(rawLiters.toStringAsFixed(2)),
    );
  }

  /// Tier 5: Zero-Permission Delayed ECU Conservation Math
  PendingAutoRefuel? processTier5DelayedEcuMath({
    required Vehicle vehicle,
    required double currentOdometer,
    required double currentFuelPercent,
    required double avgLitersPer100Km,
    required String countryName,
    required List<FuelRecord> historyRecords,
    List<PitStopLog>? pitStops,
  }) {
    final result = DelayedEcuMathEngine.reconstructRefuel(
      vehicle: vehicle,
      currentOdometer: currentOdometer,
      currentFuelPercent: currentFuelPercent,
      avgLitersPer100Km: avgLitersPer100Km,
      countryName: countryName,
      historyRecords: historyRecords,
    );

    if (!result.isRefuelDetected) return null;

    // Check if Tier 4 motion pit stop can refine the timestamp and location!
    DateTime refuelTime = DateTime.now();
    double? stopLat;
    double? stopLon;
    int tierUsed = 5;

    if (pitStops != null && pitStops.isNotEmpty) {
      final matchedStop = MotionPitStopService.matchRefuelToPitStop(
        refuelDetectionTime: DateTime.now(),
        pitStops: pitStops,
      );
      if (matchedStop != null) {
        refuelTime = matchedStop.timestamp;
        stopLat = matchedStop.latitude;
        stopLon = matchedStop.longitude;
        tierUsed = 4; // Refined by Tier 4 Pit-Stop fingerprinting
      }
    }

    return PendingAutoRefuel(
      id: 'auto-t$tierUsed-${DateTime.now().millisecondsSinceEpoch}',
      vehicleId: vehicle.id,
      timestamp: refuelTime,
      latitude: stopLat,
      longitude: stopLon,
      detectedStationName: result.attributedStation,
      resolvedPricePerLitre: result.resolvedPricePerLitre,
      estimatedOdometer: result.estimatedPumpOdometer,
      estimatedLiters: result.reconstructedLitersAdded,
      estimatedTotalCost: result.estimatedTotalCost,
      detectionTier: tierUsed,
      status: 'AWAITING_USER_VERIFY',
      rawObdLiters: result.rawObdLiters,
    );
  }
}
