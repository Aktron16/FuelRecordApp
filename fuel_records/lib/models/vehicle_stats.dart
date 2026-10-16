import 'fuel_record.dart';
import 'record_calculation.dart';

class VehicleStats {
  final int totalRecords;
  final double totalDistance;
  final double totalFuel;
  final double totalCost;
  double get totalSpent => totalCost;
  final double? averageEfficiency; // km/L or MPG
  final double? averageConsumption100; // L/100km
  final double averagePricePerUnit;
  final double? averageCostPerDistance;
  final double? averageDaysBetweenFills;
  final FuelRecord? latestRecord;
  final RecordCalculation? latestCalculation;
  final double? bestEfficiency;
  final double? worstEfficiency;
  final double? minPricePerUnit;
  final double? maxPricePerUnit;

  VehicleStats({
    required this.totalRecords,
    required this.totalDistance,
    required this.totalFuel,
    required this.totalCost,
    this.averageEfficiency,
    this.averageConsumption100,
    required this.averagePricePerUnit,
    this.averageCostPerDistance,
    this.averageDaysBetweenFills,
    this.latestRecord,
    this.latestCalculation,
    this.bestEfficiency,
    this.worstEfficiency,
    this.minPricePerUnit,
    this.maxPricePerUnit,
  });

  factory VehicleStats.fromRecords(List<FuelRecord> sortedRecords) {
    if (sortedRecords.isEmpty) {
      return VehicleStats(
        totalRecords: 0,
        totalDistance: 0.0,
        totalFuel: 0.0,
        totalCost: 0.0,
        averagePricePerUnit: 0.0,
      );
    }

    double totalFuel = 0.0;
    double totalCost = 0.0;
    double? minPrice;
    double? maxPrice;

    for (final r in sortedRecords) {
      totalFuel += r.fuelAmount;
      totalCost += r.totalPrice;
      final ppu = r.pricePerUnit;
      if (minPrice == null || ppu < minPrice) minPrice = ppu;
      if (maxPrice == null || ppu > maxPrice) maxPrice = ppu;
    }

    final avgPrice = totalFuel > 0 ? totalCost / totalFuel : 0.0;

    // Calculate intervals between sorted records (sorted by dateTime ascending)
    double totalValidDistance = 0.0;
    double totalValidFuelForDistance = 0.0;
    double totalDays = 0.0;
    int intervalCount = 0;

    double? bestEff;
    double? worstEff;

    RecordCalculation? latestCalc;

    for (int i = 1; i < sortedRecords.length; i++) {
      final prev = sortedRecords[i - 1];
      final curr = sortedRecords[i];
      final calc = RecordCalculation(current: curr, previous: prev);

      final dist = calc.distanceTraveled;
      if (dist != null && dist > 0) {
        totalValidDistance += dist;
        totalValidFuelForDistance += curr.fuelAmount;

        final eff = calc.fuelEfficiency;
        if (eff != null && eff > 0) {
          if (bestEff == null || eff > bestEff) bestEff = eff;
          if (worstEff == null || eff < worstEff) worstEff = eff;
        }
      }

      final days = calc.daysSincePrevious;
      if (days != null) {
        totalDays += days;
        intervalCount++;
      }

      if (i == sortedRecords.length - 1) {
        latestCalc = calc;
      }
    }

    if (sortedRecords.length == 1) {
      latestCalc = RecordCalculation(current: sortedRecords.first);
    }

    final avgEff = (totalValidFuelForDistance > 0 && totalValidDistance > 0)
        ? totalValidDistance / totalValidFuelForDistance
        : null;

    final avgCons100 = (avgEff != null && avgEff > 0)
        ? 100.0 / avgEff
        : null;

    final avgCostDist = (totalValidDistance > 0)
        ? totalCost / totalValidDistance
        : null;

    final avgDays = (intervalCount > 0)
        ? totalDays / intervalCount
        : null;

    return VehicleStats(
      totalRecords: sortedRecords.length,
      totalDistance: totalValidDistance,
      totalFuel: totalFuel,
      totalCost: totalCost,
      averageEfficiency: avgEff,
      averageConsumption100: avgCons100,
      averagePricePerUnit: avgPrice,
      averageCostPerDistance: avgCostDist,
      averageDaysBetweenFills: avgDays,
      latestRecord: sortedRecords.last,
      latestCalculation: latestCalc,
      bestEfficiency: bestEff,
      worstEfficiency: worstEff,
      minPricePerUnit: minPrice,
      maxPricePerUnit: maxPrice,
    );
  }
}
