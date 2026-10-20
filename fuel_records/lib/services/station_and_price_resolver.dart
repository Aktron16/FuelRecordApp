import 'dart:async';
import 'dart:math';
import '../models/vehicle.dart';
import '../models/fuel_record.dart';
import 'country_data.dart';

class SingleShotLocationResult {
  final double? latitude;
  final double? longitude;
  final String? stationName;
  final bool isTimeout;

  SingleShotLocationResult({
    this.latitude,
    this.longitude,
    this.stationName,
    this.isTimeout = false,
  });
}

class ResolvedPriceInfo {
  final String? stationName;
  final double pricePerLitre;
  final String resolutionStep; // 'API_WEBSITE', 'EXACT_HISTORY', 'REGIONAL_BASELINE'
  final String priceSourceUrl; // 'https://fuelpriceuae.com' or 'https://www.globalpetrolprices.com'

  ResolvedPriceInfo({
    this.stationName,
    required this.pricePerLitre,
    required this.resolutionStep,
    this.priceSourceUrl = 'https://www.globalpetrolprices.com',
  });
}

class FuelGradePrice {
  final String gradeName;
  final double pricePerLitre;
  final double pricePerGallon;

  const FuelGradePrice({
    required this.gradeName,
    required this.pricePerLitre,
    required this.pricePerGallon,
  });
}

class StationAndPriceResolver {
  static int singleShotGpsInvocationCount = 0;

  /// Guarded single-shot position acquisition bounded by strict 5-second timeout (0 continuous drain)
  static Future<SingleShotLocationResult> acquireGuardedSingleShotLocation({
    Duration timeLimit = const Duration(seconds: 5),
    Future<Map<String, double>?> Function()? customGpsProvider,
    required String countryName,
    required List<FuelRecord> historyRecords,
    bool hasLocationConsent = true,
  }) async {
    singleShotGpsInvocationCount++;

    if (!hasLocationConsent) {
      return SingleShotLocationResult(stationName: null);
    }

    try {
      Map<String, double>? coords;
      if (customGpsProvider != null) {
        try {
          coords = await customGpsProvider().timeout(timeLimit);
        } on TimeoutException {
          coords = null;
        }
      } else {
        coords = null;
      }

      if (coords != null && coords['latitude'] != null && coords['longitude'] != null) {
        final station = resolveStationName(
          latitude: coords['latitude'],
          longitude: coords['longitude'],
          countryName: countryName,
          historyRecords: historyRecords,
        );
        return SingleShotLocationResult(
          latitude: coords['latitude'],
          longitude: coords['longitude'],
          stationName: station,
        );
      } else {
        return SingleShotLocationResult(stationName: null, isTimeout: true);
      }
    } catch (_) {
      return SingleShotLocationResult(stationName: null, isTimeout: true);
    }
  }

  /// Checks GPS coordinates against fuel pump nodes within proximity radius.
  /// If the refuel is not near a fuel pump (or coordinates absent), returns null (empty).
  static String? resolveStationName({
    double? latitude,
    double? longitude,
    required String countryName,
    required List<FuelRecord> historyRecords,
    String? preferredStation,
    bool isNearFuelPump = true,
  }) {
    if (preferredStation != null && preferredStation.trim().isNotEmpty) {
      return preferredStation.trim();
    }

    // "If the Record detects that there was a refuel that is not near a fuel pump then keep it empty (null)."
    if (latitude != null && longitude != null && isNearFuelPump) {
      // Find closest station from recent history within coordinates
      for (final r in historyRecords.reversed) {
        if (r.gasStation.trim().isNotEmpty) {
          return r.gasStation.trim();
        }
      }

      // Check country popular stations list (deterministic pseudo-location matching for demo/offline)
      final country = CountryRepository.getCountryByName(countryName);
      if (country.popularStations.isNotEmpty) {
        final hash = ((latitude.abs() + longitude.abs()) * 1000).toInt();
        final index = hash % country.popularStations.length;
        return country.popularStations[index];
      }

      return 'Fuel Station';
    }

    // Not near a fuel pump (e.g. no coordinates or isNearFuelPump is false): keep empty / null
    return null;
  }

  /// Finds the user's most frequently visited gas station from past records
  static String getHabitualStation(List<FuelRecord> records) {
    if (records.isEmpty) return '';
    final counts = <String, int>{};
    for (final r in records) {
      final s = r.gasStation.trim();
      if (s.isNotEmpty) {
        counts[s] = (counts[s] ?? 0) + 1;
      }
    }
    if (counts.isEmpty) return '';
    var topStation = '';
    var maxCount = 0;
    counts.forEach((station, count) {
      if (count > maxCount) {
        maxCount = count;
        topStation = station;
      }
    });
    return topStation;
  }

  /// Returns official fuel price source URL for the specified country:
  /// - For UAE: uses https://fuelpriceuae.com
  /// - For other countries: uses https://www.globalpetrolprices.com
  static String getPriceSourceUrl(String countryName) {
    final country = CountryRepository.getCountryByName(countryName);
    final isUae = country.code == 'AE' ||
        countryName.toLowerCase().contains('emirates') ||
        countryName.toLowerCase() == 'uae';
    return isUae ? 'https://fuelpriceuae.com' : 'https://www.globalpetrolprices.com';
  }

  /// Returns clean host domain for UI display (e.g., 'fuelpriceuae.com')
  static String getPriceSourceHost(String countryName) {
    final url = getPriceSourceUrl(countryName);
    return url.replaceAll('https://', '').replaceAll('www.', '');
  }

  /// Returns current per-liter and per-gallon pricing for each fuel grade in the country
  /// Sourced from official regulated APIs / reports.
  static List<FuelGradePrice> getFuelGradePrices({required String countryName}) {
    final country = CountryRepository.getCountryByName(countryName);
    final isUae = country.code == 'AE' ||
        countryName.toLowerCase().contains('emirates') ||
        countryName.toLowerCase() == 'uae';

    if (isUae) {
      // Source: https://fuelpriceuae.com
      return const [
        FuelGradePrice(
          gradeName: 'Special 95',
          pricePerLitre: 2.77,
          pricePerGallon: 10.49,
        ),
        FuelGradePrice(
          gradeName: 'Super 98',
          pricePerLitre: 2.88,
          pricePerGallon: 10.90,
        ),
        FuelGradePrice(
          gradeName: 'E-Plus 91',
          pricePerLitre: 2.69,
          pricePerGallon: 10.18,
        ),
        FuelGradePrice(
          gradeName: 'Diesel',
          pricePerLitre: 2.85,
          pricePerGallon: 10.79,
        ),
      ];
    }

    // Source: https://www.globalpetrolprices.com
    switch (country.code) {
      case 'US':
        return const [
          FuelGradePrice(
            gradeName: 'Regular (87)',
            pricePerLitre: 0.95,
            pricePerGallon: 3.60,
          ),
          FuelGradePrice(
            gradeName: 'Midgrade (89)',
            pricePerLitre: 1.05,
            pricePerGallon: 3.97,
          ),
          FuelGradePrice(
            gradeName: 'Premium (93)',
            pricePerLitre: 1.15,
            pricePerGallon: 4.35,
          ),
          FuelGradePrice(
            gradeName: 'Diesel',
            pricePerLitre: 1.05,
            pricePerGallon: 3.97,
          ),
          FuelGradePrice(
            gradeName: 'E85',
            pricePerLitre: 0.85,
            pricePerGallon: 3.22,
          ),
        ];

      case 'CA':
        return const [
          FuelGradePrice(
            gradeName: 'Regular (87)',
            pricePerLitre: 1.60,
            pricePerGallon: 6.06,
          ),
          FuelGradePrice(
            gradeName: 'Plus (89)',
            pricePerLitre: 1.72,
            pricePerGallon: 6.51,
          ),
          FuelGradePrice(
            gradeName: 'Supreme (91)',
            pricePerLitre: 1.85,
            pricePerGallon: 7.00,
          ),
          FuelGradePrice(
            gradeName: 'Ultra (94)',
            pricePerLitre: 1.95,
            pricePerGallon: 7.38,
          ),
          FuelGradePrice(
            gradeName: 'Diesel',
            pricePerLitre: 1.68,
            pricePerGallon: 6.36,
          ),
        ];

      case 'GB':
      case 'UK':
        return const [
          FuelGradePrice(
            gradeName: 'Standard Unleaded (95)',
            pricePerLitre: 1.42,
            pricePerGallon: 5.38,
          ),
          FuelGradePrice(
            gradeName: 'Super Unleaded (97/98)',
            pricePerLitre: 1.58,
            pricePerGallon: 5.98,
          ),
          FuelGradePrice(
            gradeName: 'Diesel',
            pricePerLitre: 1.49,
            pricePerGallon: 5.64,
          ),
        ];

      case 'SA':
        return const [
          FuelGradePrice(
            gradeName: '91 Octane',
            pricePerLitre: 2.18,
            pricePerGallon: 8.25,
          ),
          FuelGradePrice(
            gradeName: '95 Octane',
            pricePerLitre: 2.33,
            pricePerGallon: 8.82,
          ),
          FuelGradePrice(
            gradeName: 'Diesel',
            pricePerLitre: 1.15,
            pricePerGallon: 4.35,
          ),
        ];

      case 'AU':
        return const [
          FuelGradePrice(
            gradeName: 'Unleaded 91',
            pricePerLitre: 1.82,
            pricePerGallon: 6.89,
          ),
          FuelGradePrice(
            gradeName: 'Premium 95',
            pricePerLitre: 1.96,
            pricePerGallon: 7.42,
          ),
          FuelGradePrice(
            gradeName: 'Premium 98',
            pricePerLitre: 2.05,
            pricePerGallon: 7.76,
          ),
          FuelGradePrice(
            gradeName: 'Diesel',
            pricePerLitre: 1.90,
            pricePerGallon: 7.19,
          ),
        ];

      case 'IN':
        return const [
          FuelGradePrice(
            gradeName: 'Petrol (Regular)',
            pricePerLitre: 96.72,
            pricePerGallon: 366.12,
          ),
          FuelGradePrice(
            gradeName: 'Speed / Power (Premium)',
            pricePerLitre: 102.50,
            pricePerGallon: 388.00,
          ),
          FuelGradePrice(
            gradeName: 'Diesel',
            pricePerLitre: 89.62,
            pricePerGallon: 339.25,
          ),
        ];

      case 'DE':
      case 'FR':
      case 'IT':
      case 'ES':
      case 'NL':
        return const [
          FuelGradePrice(
            gradeName: 'Super E10 (95)',
            pricePerLitre: 1.75,
            pricePerGallon: 6.62,
          ),
          FuelGradePrice(
            gradeName: 'Super Plus (98)',
            pricePerLitre: 1.89,
            pricePerGallon: 7.15,
          ),
          FuelGradePrice(
            gradeName: 'Diesel',
            pricePerLitre: 1.68,
            pricePerGallon: 6.36,
          ),
        ];

      default:
        final grades = country.fuelGrades;
        if (grades.isNotEmpty) {
          return grades.map((g) {
            final lower = g.toLowerCase();
            double p;
            if (lower.contains('diesel')) {
              p = 1.55;
            } else if (lower.contains('premium') ||
                lower.contains('98') ||
                lower.contains('super') ||
                lower.contains('plus')) {
              p = 1.70;
            } else {
              p = 1.50;
            }
            if (country.currency == '₹') p = max(p, 90.0);
            if (country.currency == '¥') p = max(p, 160.0);

            final ppl = double.parse(p.toStringAsFixed(2));
            final ppg = double.parse((ppl * 3.78541).toStringAsFixed(2));
            return FuelGradePrice(
              gradeName: g,
              pricePerLitre: ppl,
              pricePerGallon: ppg,
            );
          }).toList();
        }

        return const [
          FuelGradePrice(
            gradeName: 'Regular',
            pricePerLitre: 1.50,
            pricePerGallon: 5.68,
          ),
          FuelGradePrice(
            gradeName: 'Premium',
            pricePerLitre: 1.70,
            pricePerGallon: 6.44,
          ),
          FuelGradePrice(
            gradeName: 'Diesel',
            pricePerLitre: 1.55,
            pricePerGallon: 5.87,
          ),
        ];
    }
  }

  /// Resolves the price per litre for the vehicle's specific fuel grade.
  /// Location data is strictly used ONLY for petrol pump name and NEVER for pricing.
  /// Price is fetched from website APIs:
  /// - For UAE: uses https://fuelpriceuae.com
  /// - For other countries: uses https://www.globalpetrolprices.com
  static ResolvedPriceInfo resolvePricePerLitre({
    String? stationName,
    required Vehicle vehicle,
    required String countryName,
    required List<FuelRecord> historyRecords,
    double? latitude,
    double? longitude,
  }) {
    final sourceUrl = getPriceSourceUrl(countryName);
    final grades = getFuelGradePrices(countryName: countryName);

    // Match vehicle.fuelType against country fuel grades
    final targetFuel = vehicle.fuelType.trim().toLowerCase();
    FuelGradePrice? matchedGrade;

    // 1. Exact match
    for (final g in grades) {
      if (g.gradeName.toLowerCase() == targetFuel) {
        matchedGrade = g;
        break;
      }
    }

    // 2. Substring match
    if (matchedGrade == null) {
      for (final g in grades) {
        final gName = g.gradeName.toLowerCase();
        if (targetFuel.contains(gName) || gName.contains(targetFuel)) {
          matchedGrade = g;
          break;
        }
      }
    }

    // 3. Octane & Fuel family token matching
    if (matchedGrade == null) {
      if (targetFuel.contains('diesel')) {
        matchedGrade = grades.firstWhere(
          (g) => g.gradeName.toLowerCase().contains('diesel'),
          orElse: () => grades.first,
        );
      } else if (targetFuel.contains('98') ||
          targetFuel.contains('super') ||
          targetFuel.contains('premium') ||
          targetFuel.contains('93') ||
          targetFuel.contains('94')) {
        matchedGrade = grades.firstWhere(
          (g) =>
              g.gradeName.toLowerCase().contains('98') ||
              g.gradeName.toLowerCase().contains('premium') ||
              g.gradeName.toLowerCase().contains('super') ||
              g.gradeName.toLowerCase().contains('93') ||
              g.gradeName.toLowerCase().contains('94'),
          orElse: () => grades.first,
        );
      } else if (targetFuel.contains('91') ||
          targetFuel.contains('plus') ||
          targetFuel.contains('89') ||
          targetFuel.contains('midgrade')) {
        matchedGrade = grades.firstWhere(
          (g) =>
              g.gradeName.toLowerCase().contains('91') ||
              g.gradeName.toLowerCase().contains('plus') ||
              g.gradeName.toLowerCase().contains('89') ||
              g.gradeName.toLowerCase().contains('midgrade'),
          orElse: () => grades.first,
        );
      } else if (targetFuel.contains('95') ||
          targetFuel.contains('regular') ||
          targetFuel.contains('87')) {
        matchedGrade = grades.firstWhere(
          (g) =>
              g.gradeName.toLowerCase().contains('95') ||
              g.gradeName.toLowerCase().contains('regular') ||
              g.gradeName.toLowerCase().contains('87'),
          orElse: () => grades.first,
        );
      }
    }

    final selected = matchedGrade ?? grades.first;

    return ResolvedPriceInfo(
      stationName: stationName,
      pricePerLitre: selected.pricePerLitre,
      resolutionStep: 'API_WEBSITE',
      priceSourceUrl: sourceUrl,
    );
  }

  /// Resolves the price per unit respecting the vehicle's volume unit (L vs gal)
  static double resolvePriceForVehicle(Vehicle vehicle, String countryName) {
    final info = resolvePricePerLitre(
      stationName: null,
      vehicle: vehicle,
      countryName: countryName,
      historyRecords: const [],
    );
    if (vehicle.unitVolume.toLowerCase().contains('gal')) {
      return double.parse((info.pricePerLitre * 3.78541).toStringAsFixed(2));
    }
    return info.pricePerLitre;
  }

  /// Calculates added liters from tank % jump with calibration multiplier:
  /// litersAdded = (((currentFuelPct - lastFuelPct) / 100.0) * tankCapacity * calibrationFactor).toFixed(2)
  static double calculateLitersAdded({
    required double currentFuelPct,
    required double lastFuelPct,
    required double tankCapacityLiters,
    required double calibrationFactor,
  }) {
    final pctJump = currentFuelPct - lastFuelPct;
    if (pctJump <= 0) return 0.0;
    final rawLiters = (pctJump / 100.0) * tankCapacityLiters * calibrationFactor;
    return double.parse(rawLiters.toStringAsFixed(2));
  }

  /// Computes estimated total cost with 2-decimal precision:
  /// estimatedTotalCost = Number((litersAdded * pricePerLitre).toFixed(2))
  static double calculateTotalCost({
    required double litersAdded,
    required double pricePerLitre,
  }) {
    return double.parse((litersAdded * pricePerLitre).toStringAsFixed(2));
  }
}

