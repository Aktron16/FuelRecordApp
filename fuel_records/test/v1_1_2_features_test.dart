import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuel_records/models/vehicle.dart';
import 'package:fuel_records/models/fuel_record.dart';
import 'package:fuel_records/services/country_data.dart';
import 'package:fuel_records/services/fuel_app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Version 1.1.2 Features Tests', () {
    test('Vehicle model stores licensePlate, profileImageUri, and bannerImageUri', () {
      final now = DateTime.now();
      final vehicle = Vehicle(
        id: 'v-test-1',
        name: 'Camry Hybrid',
        brand: 'Toyota',
        type: VehicleType.sedan,
        owner: 'Jordan',
        colorValue: 0xFF1976D2,
        unitDistance: 'km',
        unitVolume: 'L',
        currency: '\$',
        licensePlate: 'ABC-1234',
        profileImageUri: '/data/user/0/app/files/pfp_v-test-1.jpg',
        bannerImageUri: '/data/user/0/app/files/banner_v-test-1.jpg',
        createdAt: now,
      );

      final json = vehicle.toJson();
      expect(json['licensePlate'], 'ABC-1234');
      expect(json['profileImageUri'], '/data/user/0/app/files/pfp_v-test-1.jpg');
      expect(json['bannerImageUri'], '/data/user/0/app/files/banner_v-test-1.jpg');

      final deserialized = Vehicle.fromJson(json);
      expect(deserialized.licensePlate, 'ABC-1234');
      expect(deserialized.profileImageUri, '/data/user/0/app/files/pfp_v-test-1.jpg');
      expect(deserialized.bannerImageUri, '/data/user/0/app/files/banner_v-test-1.jpg');

      // Test copyWith image removal and updates
      final updated = deserialized.copyWith(
        licensePlate: 'XYZ-9999',
        clearProfileImage: true,
      );
      expect(updated.licensePlate, 'XYZ-9999');
      expect(updated.profileImageUri, isNull);
      expect(updated.bannerImageUri, '/data/user/0/app/files/banner_v-test-1.jpg');
    });

    test('CountryRepository provides 45 countries with ISO codes, currencies, and fuel grades', () {
      final countries = CountryRepository.countries;
      expect(countries.length, greaterThanOrEqualTo(45));

      final us = CountryRepository.getCountryByCode('US');
      expect(us.name, 'United States');
      expect(us.currency, '\$');
      expect(us.currencyCode, 'USD');
      expect(us.defaultDistanceUnit, 'mi');
      expect(us.defaultVolumeUnit, 'gal');
      expect(us.fuelGrades, contains('Regular (87)'));

      final de = CountryRepository.getCountryByCode('DE');
      expect(de.name, 'Germany');
      expect(de.currency, '€');
      expect(de.currencyCode, 'EUR');
      expect(de.defaultDistanceUnit, 'km');
      expect(de.defaultVolumeUnit, 'L');
      expect(de.fuelGrades, contains('Super E10 (95)'));

      final jp = CountryRepository.getCountryByCode('JP');
      expect(jp.name, 'Japan');
      expect(jp.currency, '¥');
      expect(jp.currencyCode, 'JPY');

      final lookupByName = CountryRepository.getCountryByName('United Kingdom');
      expect(lookupByName.code, 'GB');
      expect(lookupByName.currency, '£');
    });

    test('FuelAppState in-memory index, memoized cache, and batch record deletion', () async {
      SharedPreferences.setMockInitialValues({});
      final tempDir = Directory.systemTemp.createTempSync('fuel_v12_test_');
      final appState = FuelAppState(customStorageDir: tempDir);
      await appState.loadFromStorage();

      final v = Vehicle(
        id: 'v_batch',
        name: 'Batch Car',
        brand: 'Ford',
        type: VehicleType.truck,
        owner: 'Batch Owner',
        unitDistance: 'km',
        unitVolume: 'L',
        currency: '\$',
        createdAt: DateTime.now(),
      );
      await appState.addVehicle(v);

      final r1 = FuelRecord(
        id: 'r_b1',
        vehicleId: 'v_batch',
        dateTime: DateTime(2026, 10, 1),
        odometer: 1000,
        fuelAmount: 40,
        totalPrice: 80,
      );
      final r2 = FuelRecord(
        id: 'r_b2',
        vehicleId: 'v_batch',
        dateTime: DateTime(2026, 10, 5),
        odometer: 1500,
        fuelAmount: 45,
        totalPrice: 90,
      );
      final r3 = FuelRecord(
        id: 'r_b3',
        vehicleId: 'v_batch',
        dateTime: DateTime(2026, 10, 10),
        odometer: 2000,
        fuelAmount: 42,
        totalPrice: 84,
      );

      await appState.addRecord(r1);
      await appState.addRecord(r2);
      await appState.addRecord(r3);

      expect(appState.activeVehicleRecordsAscending.length, 3);
      final statsBefore = appState.activeVehicleStats;
      expect(statsBefore.totalFuel, 127.0);

      // Batch delete r1 and r2
      final deleted = await appState.deleteRecordsBatch(['r_b1', 'r_b2']);
      expect(deleted, 2);
      expect(appState.activeVehicleRecordsAscending.length, 1);
      expect(appState.activeVehicleRecordsAscending.first.id, 'r_b3');

      // Stats cache invalidated and recomputed accurately
      final statsAfter = appState.activeVehicleStats;
      expect(statsAfter.totalFuel, 42.0);

      tempDir.deleteSync(recursive: true);
    });
  });
}
