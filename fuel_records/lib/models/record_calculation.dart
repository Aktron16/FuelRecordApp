import 'fuel_record.dart';

class RecordCalculation {
  final FuelRecord current;
  final FuelRecord? previous;

  RecordCalculation({
    required this.current,
    this.previous,
  });

  /// Price per unit (e.g., $/L or $/gal) for the current record
  double get pricePerUnit => current.pricePerUnit;

  /// Price per unit for the previous record, if available
  double? get previousPricePerUnit => previous?.pricePerUnit;

  /// Price change per unit compared to previous record (+ for increase, - for decrease)
  double? get priceDifferencePerUnit {
    if (previous == null) return null;
    return pricePerUnit - previous!.pricePerUnit;
  }

  /// Percentage price change compared to previous record
  double? get priceDifferencePercentage {
    if (previous == null || previous!.pricePerUnit == 0) return null;
    return ((pricePerUnit - previous!.pricePerUnit) / previous!.pricePerUnit) * 100.0;
  }

  /// Total price difference between the two fill-ups
  double? get totalPriceDifference {
    if (previous == null) return null;
    return current.totalPrice - previous!.totalPrice;
  }

  /// Distance driven since previous record (km or mi)
  double? get distanceTraveled {
    if (previous == null) return null;
    final diff = current.odometer - previous!.odometer;
    return diff >= 0 ? diff : null; // Handle rollover or anomaly
  }

  /// Days elapsed since the previous fuel record
  double? get daysSincePrevious {
    if (previous == null) return null;
    final duration = current.dateTime.difference(previous!.dateTime);
    final days = duration.inMinutes / (24.0 * 60.0);
    return days >= 0 ? days : 0.0;
  }

  /// Fuel efficiency in distance per volume unit (km/L or MPG)
  /// Note: Best calculated when tank is filled full.
  double? get fuelEfficiency {
    final dist = distanceTraveled;
    if (dist == null || current.fuelAmount <= 0) return null;
    return dist / current.fuelAmount;
  }

  /// Fuel consumption in volume per 100 distance units (L/100km or gal/100mi)
  double? get consumptionPer100Units {
    final dist = distanceTraveled;
    if (dist == null || dist <= 0) return null;
    return (current.fuelAmount / dist) * 100.0;
  }

  /// Cost per unit of distance (e.g., $ per km or $ per mile)
  double? get costPerDistance {
    final dist = distanceTraveled;
    if (dist == null || dist <= 0) return null;
    return current.totalPrice / dist;
  }

  /// Average daily distance driven during this interval
  double? get dailyDistance {
    final dist = distanceTraveled;
    final days = daysSincePrevious;
    if (dist == null || days == null || days <= 0.01) return null;
    return dist / days;
  }
}

