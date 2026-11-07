import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuel_records/services/country_data.dart';
import 'package:fuel_records/services/station_and_price_resolver.dart';
import 'package:fuel_records/services/fuel_app_state.dart';
import 'package:fuel_records/models/vehicle.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('fuel_price.json Root Dataset Verification', () {
    test('fuel_price.json exists in project root and matches schema', () {
      final rootFile = File('../fuel_price.json');
      expect(rootFile.existsSync(), isTrue, reason: 'fuel_price.json must exist in project root directory');

      final content = rootFile.readAsStringSync();
      final Map<String, dynamic> data = jsonDecode(content);

      expect(data['schemaVersion'], equals(1));
      expect(data['month'], matches(RegExp(r'^\d{4}-\d{2}$')));
      expect(data['updatedAt'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));

      final Map<String, dynamic> countries = data['countries'];
      expect(countries.length, equals(45), reason: 'All 45 countries in CountryRepository must be present');

      for (final country in CountryRepository.countries) {
        expect(countries.containsKey(country.code), isTrue,
            reason: 'Country code ${country.code} (${country.name}) must be present in fuel_price.json');
        final cData = countries[country.code] as Map<String, dynamic>;
        expect(cData['currencyCode'], equals(country.currencyCode));

        final grades = cData['grades'] as Map<String, dynamic>;
        expect(grades.isNotEmpty, isTrue);

        for (final entry in grades.entries) {
          final price = double.tryParse(entry.value.toString());
          expect(price, isNotNull);
          expect(price! > 0, isTrue);
        }
      }
    });
  });

  group('StationAndPriceResolver JSON & GitHub Sync', () {
    test('loadCachedPriceJson successfully updates grade prices and month', () {
      const sampleJson = '''
{
  "schemaVersion": 1,
  "month": "2026-11",
  "updatedAt": "2026-11-01",
  "countries": {
    "AE": {
      "name": "United Arab Emirates",
      "currencyCode": "AED",
      "grades": {
        "Special 95": 2.77,
        "Super 98": 2.88,
        "Diesel": 2.85
      }
    },
    "US": {
      "name": "United States",
      "currencyCode": "USD",
      "grades": {
        "Regular (87)": 0.95,
        "Premium (93)": 1.15
      }
    }
  }
}
''';

      final loaded = StationAndPriceResolver.loadCachedPriceJson(sampleJson);
      expect(loaded, isTrue);
      expect(StationAndPriceResolver.activePriceMonth, equals('2026-11'));

      final uaeGrades = StationAndPriceResolver.getFuelGradePrices(countryName: 'United Arab Emirates');
      expect(uaeGrades.length, equals(3));
      final spec95 = uaeGrades.firstWhere((g) => g.gradeName == 'Special 95');
      expect(spec95.pricePerLitre, equals(2.77));
      expect(spec95.pricePerGallon, closeTo(2.77 * 3.78541, 0.02));

      // Test vehicle resolution in gallons
      final usCar = Vehicle(
        id: 'test-car',
        name: 'Test',
        brand: 'Ford',
        type: VehicleType.sedan,
        owner: 'Test Owner',
        fuelType: 'Regular (87)',
        unitVolume: 'gal',
        unitDistance: 'mi',
        currency: '\$',
        colorValue: 0xFF000000,
        createdAt: DateTime.now(),
      );
      final priceGal = StationAndPriceResolver.resolvePriceForVehicle(usCar, 'United States');
      expect(priceGal, closeTo(0.95 * 3.78541, 0.02));
    });

    test('formatYearMonth formats DateTime properly', () {
      expect(StationAndPriceResolver.formatYearMonth(DateTime(2026, 1, 15)), equals('2026-01'));
      expect(StationAndPriceResolver.formatYearMonth(DateTime(2026, 11, 7)), equals('2026-11'));
      expect(StationAndPriceResolver.formatYearMonth(DateTime(2027, 12, 31)), equals('2027-12'));
    });
  });

  group('FuelAppState Monthly GitHub API Sync Workflow', () {
    late Directory tempDir;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tempDir = Directory.systemTemp.createTempSync('fuel_sync_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('First app open syncs prices from GitHub API and records month', () async {
      int httpCallCount = 0;
      Future<String?> mockHttpFetcher(Uri uri) async {
        httpCallCount++;
        expect(uri.toString(), contains('contents/fuel_price.json'));
        return jsonEncode({
          'schemaVersion': 1,
          'month': '2026-11',
          'updatedAt': '2026-11-01',
          'countries': {
            'AE': {
              'name': 'United Arab Emirates',
              'currencyCode': 'AED',
              'grades': {'Special 95': 3.10}
            }
          }
        });
      }

      final appState = FuelAppState(customStorageDir: tempDir, autoLoad: false);
      await appState.loadFromStorage();

      final synced = await appState.checkAndSyncMonthlyFuelPrices(
        nowOverride: DateTime(2026, 11, 7),
        customHttpFetcher: mockHttpFetcher,
      );

      expect(synced, isTrue);
      expect(httpCallCount, equals(1));
      expect(StationAndPriceResolver.activePriceMonth, equals('2026-11'));

      final cachedFile = File('${tempDir.path}/fuel_price.json');
      expect(cachedFile.existsSync(), isTrue);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('fuel_app_last_price_sync_month'), equals('2026-11'));
    });

    test('Subsequent opens in same calendar month make ZERO API requests', () async {
      int httpCallCount = 0;
      Future<String?> mockHttpFetcher(Uri uri) async {
        httpCallCount++;
        return '{}';
      }

      SharedPreferences.setMockInitialValues({
        'fuel_app_last_price_sync_month': '2026-11',
      });

      final appState = FuelAppState(customStorageDir: tempDir, autoLoad: false);
      await appState.loadFromStorage();

      // Open on Nov 15 (same month)
      final syncedMidMonth = await appState.checkAndSyncMonthlyFuelPrices(
        nowOverride: DateTime(2026, 11, 15),
        customHttpFetcher: mockHttpFetcher,
      );
      expect(syncedMidMonth, isFalse);
      expect(httpCallCount, equals(0), reason: 'Must not call API if month has not changed');

      // Open on Nov 30 (end of month)
      final syncedEndMonth = await appState.checkAndSyncMonthlyFuelPrices(
        nowOverride: DateTime(2026, 11, 30),
        customHttpFetcher: mockHttpFetcher,
      );
      expect(syncedEndMonth, isFalse);
      expect(httpCallCount, equals(0), reason: 'Must not call API if month has not changed');
    });

    test('Opening in a new calendar month (regardless of day) triggers GitHub sync', () async {
      int httpCallCount = 0;
      Future<String?> mockHttpFetcher(Uri uri) async {
        httpCallCount++;
        return jsonEncode({
          'schemaVersion': 1,
          'month': '2026-12',
          'updatedAt': '2026-12-01',
          'countries': {
            'AE': {
              'name': 'United Arab Emirates',
              'currencyCode': 'AED',
              'grades': {'Special 95': 2.95}
            }
          }
        });
      }

      // Pre-set that November was synced
      SharedPreferences.setMockInitialValues({
        'fuel_app_last_price_sync_month': '2026-11',
      });

      final appState = FuelAppState(customStorageDir: tempDir, autoLoad: false);
      await appState.loadFromStorage();

      // App opened in December (e.g. Dec 3)
      final syncedDecember = await appState.checkAndSyncMonthlyFuelPrices(
        nowOverride: DateTime(2026, 12, 3),
        customHttpFetcher: mockHttpFetcher,
      );

      expect(syncedDecember, isTrue);
      expect(httpCallCount, equals(1));
      expect(StationAndPriceResolver.activePriceMonth, equals('2026-12'));

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('fuel_app_last_price_sync_month'), equals('2026-12'));

      final uaeGrades = StationAndPriceResolver.getFuelGradePrices(countryName: 'United Arab Emirates');
      expect(uaeGrades.firstWhere((g) => g.gradeName == 'Special 95').pricePerLitre, equals(2.95));
    });

    test('Network/offline failure gracefully maintains cached prices and allows retry', () async {
      Future<String?> failingHttpFetcher(Uri uri) async {
        throw const SocketException('No Internet Connection');
      }

      SharedPreferences.setMockInitialValues({
        'fuel_app_last_price_sync_month': '2026-11',
      });

      final appState = FuelAppState(customStorageDir: tempDir, autoLoad: false);
      await appState.loadFromStorage();

      // App opened in January 2027 while offline
      final syncResult = await appState.checkAndSyncMonthlyFuelPrices(
        nowOverride: DateTime(2027, 1, 1),
        customHttpFetcher: failingHttpFetcher,
      );

      expect(syncResult, isFalse, reason: 'Failed sync must return false without crashing');

      final prefs = await SharedPreferences.getInstance();
      // Must NOT update the sync month so that the next open retries!
      expect(prefs.getString('fuel_app_last_price_sync_month'), equals('2026-11'));
    });
  });
}
