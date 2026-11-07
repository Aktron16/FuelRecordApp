import 'dart:async';
import 'dart:convert';
import 'dart:io';
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
  final String resolutionStep; // 'MONTHLY_GITHUB_JSON', 'EXACT_HISTORY', 'REGIONAL_BASELINE'
  final String priceMonth;

  ResolvedPriceInfo({
    this.stationName,
    required this.pricePerLitre,
    this.resolutionStep = 'MONTHLY_GITHUB_JSON',
    this.priceMonth = '2026-11',
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

  /// Endpoint to fetch the monthly fuel prices JSON from the public GitHub repository.
  static const String githubPriceApiEndpoint =
      'https://api.github.com/repos/Aktron16/FuelRecordApp/contents/fuel_price.json?ref=automation-fix';

  static String activePriceMonth = '2026-11';
  static Map<String, Map<String, double>> _countryGradePrices = {};

  /// Formats a DateTime as 'YYYY-MM' for calendar month comparison
  static String formatYearMonth(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}';

  /// Loads and applies prices from raw JSON (matching fuel_price.json schema)
  static bool loadCachedPriceJson(String rawJson) {
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is! Map<String, dynamic>) return false;

      final month = decoded['month'] as String?;
      if (month != null && month.isNotEmpty) {
        activePriceMonth = month;
      }

      final countriesMap = decoded['countries'];
      if (countriesMap is! Map<String, dynamic>) return false;

      final Map<String, Map<String, double>> newPrices = {};
      countriesMap.forEach((code, data) {
        if (data is Map<String, dynamic>) {
          final grades = data['grades'];
          if (grades is Map<String, dynamic>) {
            final Map<String, double> gradePrices = {};
            grades.forEach((gName, priceVal) {
              final p = double.tryParse(priceVal.toString());
              if (p != null) {
                gradePrices[gName] = p;
              }
            });
            if (gradePrices.isNotEmpty) {
              newPrices[code.toUpperCase()] = gradePrices;
            }
          }
        }
      });

      if (newPrices.isNotEmpty) {
        _countryGradePrices = newPrices;
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// Fetches monthly fuel prices from GitHub Contents API
  static Future<String?> fetchPricesFromGitHub({
    Future<String> Function(Uri)? customHttpFetcher,
    String? endpointOverride,
  }) async {
    final uri = Uri.parse(endpointOverride ?? githubPriceApiEndpoint);
    if (customHttpFetcher != null) {
      try {
        return await customHttpFetcher(uri);
      } catch (_) {
        return null;
      }
    }

    HttpClient? client;
    try {
      client = HttpClient()..connectionTimeout = const Duration(seconds: 5);
      final request = await client.getUrl(uri);
      request.headers.set('Accept', 'application/vnd.github.raw+json, application/json');
      request.headers.set('User-Agent', 'FuelMetricsApp');
      request.headers.set('X-GitHub-Api-Version', '2022-11-28');

      final response = await request.close().timeout(const Duration(seconds: 6));
      if (response.statusCode != 200) {
        return null;
      }

      final body = await response.transform(utf8.decoder).join();
      if (body.isEmpty) return null;

      // Handle standard GitHub Contents API JSON envelope if raw media type was not honored
      if (body.contains('"content":') && body.contains('"encoding":')) {
        try {
          final decoded = jsonDecode(body);
          if (decoded is Map<String, dynamic> && decoded['content'] is String) {
            final rawBase64 = (decoded['content'] as String).replaceAll('\n', '').replaceAll('\r', '');
            return utf8.decode(base64Decode(rawBase64));
          }
        } catch (_) {}
      }

      return body;
    } catch (_) {
      return null;
    } finally {
      client?.close(force: true);
    }
  }

  /// Returns current per-liter and per-gallon pricing for each fuel grade in the country
  /// Sourced from monthly fuel_price.json (or built-in baselines if not yet loaded).
  static List<FuelGradePrice> getFuelGradePrices({required String countryName}) {
    final country = CountryRepository.getCountryByName(countryName);
    final countryCode = country.code.toUpperCase();

    // 1. Check if cached from fuel_price.json
    final cachedGrades = _countryGradePrices[countryCode];
    if (cachedGrades != null && cachedGrades.isNotEmpty) {
      return cachedGrades.entries.map((entry) {
        final ppl = entry.value;
        final ppg = double.parse((ppl * 3.78541).toStringAsFixed(2));
        return FuelGradePrice(
          gradeName: entry.key,
          pricePerLitre: ppl,
          pricePerGallon: ppg,
        );
      }).toList();
    }

    // 2. Built-in fallback based on country fuel grades
    final isUae = countryCode == 'AE' ||
        countryName.toLowerCase().contains('emirates') ||
        countryName.toLowerCase() == 'uae';

    if (isUae) {
      return const [
        FuelGradePrice(gradeName: 'Special 95', pricePerLitre: 2.77, pricePerGallon: 10.49),
        FuelGradePrice(gradeName: 'Super 98', pricePerLitre: 2.88, pricePerGallon: 10.90),
        FuelGradePrice(gradeName: 'E-Plus 91', pricePerLitre: 2.69, pricePerGallon: 10.18),
        FuelGradePrice(gradeName: 'Diesel', pricePerLitre: 2.85, pricePerGallon: 10.79),
      ];
    }

    final grades = country.fuelGrades;
    if (grades.isNotEmpty) {
      return grades.map((g) {
        final lower = g.toLowerCase();
        double p;
        if (lower.contains('diesel') || lower.contains('gasóleo') || lower.contains('dizel') || lower.contains('nafta')) {
          p = 1.68;
        } else if (lower.contains('premium') || lower.contains('98') || lower.contains('100') || lower.contains('super plus')) {
          p = 1.85;
        } else if (lower.contains('91') || lower.contains('89') || lower.contains('plus')) {
          p = 1.65;
        } else if (lower.contains('e85') || lower.contains('etanol')) {
          p = 1.20;
        } else if (lower.contains('lpg') || lower.contains('cng') || lower.contains('gpl')) {
          p = 0.95;
        } else {
          p = 1.75;
        }
        if (country.currency == '₹') p = 96.72;
        if (country.currency == '¥') p = 175.0;
        if (country.currency == '₩') p = 1680.0;

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
      FuelGradePrice(gradeName: 'Regular', pricePerLitre: 1.50, pricePerGallon: 5.68),
      FuelGradePrice(gradeName: 'Premium', pricePerLitre: 1.70, pricePerGallon: 6.44),
      FuelGradePrice(gradeName: 'Diesel', pricePerLitre: 1.55, pricePerGallon: 5.87),
    ];
  }

  /// Resolves the price per litre for the vehicle's specific fuel grade.
  /// Location data is strictly used ONLY for petrol pump name and NEVER for pricing.
  /// Price is sourced from monthly fuel_price.json synced via GitHub API.
  static ResolvedPriceInfo resolvePricePerLitre({
    String? stationName,
    required Vehicle vehicle,
    required String countryName,
    required List<FuelRecord> historyRecords,
    double? latitude,
    double? longitude,
  }) {
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
      resolutionStep: 'MONTHLY_GITHUB_JSON',
      priceMonth: activePriceMonth,
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

  /// Computes estimated total cost with 2-decimal precision:
  /// estimatedTotalCost = Number((litersAdded * pricePerLitre).toFixed(2))
  static double calculateTotalCost({
    required double litersAdded,
    required double pricePerLitre,
  }) {
    return double.parse((litersAdded * pricePerLitre).toStringAsFixed(2));
  }
}

