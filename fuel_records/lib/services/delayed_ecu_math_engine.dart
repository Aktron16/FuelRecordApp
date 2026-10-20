import 'dart:math';
import '../models/vehicle.dart';
import '../models/fuel_record.dart';
import 'station_and_price_resolver.dart';

class ReconstructedRefuelResult {
  final bool isRefuelDetected;
  final double reconstructedLitersAdded;
  final double rawObdLiters;
  final double estimatedPumpOdometer;
  final String? attributedStation;
  final double resolvedPricePerLitre;
  final double estimatedTotalCost;

  ReconstructedRefuelResult({
    required this.isRefuelDetected,
    required this.reconstructedLitersAdded,
    required this.rawObdLiters,
    required this.estimatedPumpOdometer,
    this.attributedStation,
    required this.resolvedPricePerLitre,
    required this.estimatedTotalCost,
  });
}

class DelayedEcuMathEngine {
  /// Pure mathematical reconstruction of fuel added during disconnected periods.
  /// Uses Conservation of Volume and vehicle average consumption.
  static ReconstructedRefuelResult reconstructRefuel({
    required Vehicle vehicle,
    required double currentOdometer,
    required double currentFuelPercent,
    required double avgLitersPer100Km,
    required String countryName,
    required List<FuelRecord> historyRecords,
    double targetFillPercent = 95.0, // Assumes full or near-full tank top-up
  }) {
    final lastOdo = vehicle.lastKnownOdometer ?? (vehicle.initialOdometer ?? currentOdometer);
    final lastFuelPct = vehicle.lastKnownFuelPercent ?? currentFuelPercent;

    // 1. Calculate Disconnected Distance & Fuel Burned
    final distanceDeltaKm = max(0.0, currentOdometer - lastOdo);
    final effectiveAvgL100k = avgLitersPer100Km > 0 ? avgLitersPer100Km : 7.8; // default ~7.8 L/100km
    final fuelBurnedLiters = (distanceDeltaKm / 100.0) * effectiveAvgL100k;

    // 2. Conservation of Volume Equation using exact integer milliliters
    final rawNetTankChangeMl = (((currentFuelPercent - lastFuelPct) / 100.0) * vehicle.tankCapacityMilliliters).round();
    final rawNetTankChangeLiters = rawNetTankChangeMl / 1000.0;
    final netTankChangeLiters = rawNetTankChangeLiters * vehicle.calibrationFactor;
    final rawReconstructedLiters = rawNetTankChangeLiters + fuelBurnedLiters;
    final reconstructedLitersAdded = double.parse(
      (netTankChangeLiters + fuelBurnedLiters).toStringAsFixed(2),
    );

    // 3. Distinguish a Fuel Pump from a Non-Fuel Stop:
    // Minimum threshold: at least 6.0 L OR 12% of tank capacity
    final minThreshold = max(6.0, 0.12 * vehicle.tankCapacityLiters);
    final isRefuel = reconstructedLitersAdded >= minThreshold;

    if (!isRefuel) {
      return ReconstructedRefuelResult(
        isRefuelDetected: false,
        reconstructedLitersAdded: 0.0,
        rawObdLiters: 0.0,
        estimatedPumpOdometer: currentOdometer,
        attributedStation: '',
        resolvedPricePerLitre: 0.0,
        estimatedTotalCost: 0.0,
      );
    }

    // 4. Back-Calculate the Exact Pump Odometer
    // Distance driven since the fuel tank was topped up at the pump:
    final fillLevel = max(currentFuelPercent, targetFillPercent);
    final litersBurnedSincePump = max(0.0, ((fillLevel - currentFuelPercent) / 100.0) * vehicle.tankCapacityLiters);
    final kmDrivenSincePump = (litersBurnedSincePump / effectiveAvgL100k) * 100.0;
    final estimatedPumpOdo = (currentOdometer - kmDrivenSincePump).clamp(lastOdo, currentOdometer);
    final roundedPumpOdo = double.parse(estimatedPumpOdo.toStringAsFixed(1));

    // 5. Habitual Station & Price Attribution
    final habitualStation = StationAndPriceResolver.getHabitualStation(historyRecords);
    final resolvedStation = habitualStation.isNotEmpty
        ? habitualStation
        : StationAndPriceResolver.resolveStationName(
            countryName: countryName,
            historyRecords: historyRecords,
          );

    final priceInfo = StationAndPriceResolver.resolvePricePerLitre(
      stationName: resolvedStation,
      vehicle: vehicle,
      countryName: countryName,
      historyRecords: historyRecords,
    );

    final totalCost = StationAndPriceResolver.calculateTotalCost(
      litersAdded: reconstructedLitersAdded,
      pricePerLitre: priceInfo.pricePerLitre,
    );

    return ReconstructedRefuelResult(
      isRefuelDetected: true,
      reconstructedLitersAdded: reconstructedLitersAdded,
      rawObdLiters: double.parse(rawReconstructedLiters.toStringAsFixed(2)),
      estimatedPumpOdometer: roundedPumpOdo,
      attributedStation: resolvedStation,
      resolvedPricePerLitre: priceInfo.pricePerLitre,
      estimatedTotalCost: totalCost,
    );
  }
}

