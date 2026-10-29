import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:fuel_records/models/vehicle.dart';
import 'package:fuel_records/models/fuel_record.dart';
import 'package:fuel_records/models/record_calculation.dart';
import 'package:fuel_records/models/vehicle_stats.dart';
import 'package:fuel_records/services/fuel_app_state.dart';
import 'package:fuel_records/screens/text_import_screen.dart';
import 'package:fuel_records/screens/import_preview_screen.dart';
import 'package:fuel_records/utils/app_date_format.dart';
import 'package:fuel_records/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fuel Metrics Core Tests', () {
    test('Date formatting conforms strictly to DD-Month(abbreviation)-YY', () {
      final dt = DateTime(2026, 10, 16, 15, 30);
      expect(AppDateUtils.format(dt), '16-Oct-26');
      expect(AppDateUtils.formatShort(dt), '16-Oct');

      final dtJan = DateTime(2025, 1, 5);
      expect(AppDateUtils.format(dtJan), '05-Jan-25');
    });

    test('Vehicle model preserves backwards compatibility for stored records', () {
      // Legacy JSON without fuelType
      final legacyJson = {
        'id': 'v_legacy',
        'name': 'Old Car',
        'type': 'sedan',
        'brand': 'Toyota',
        'owner': 'Owner',
        'colorValue': 0xFF1E88E5,
        'unitDistance': 'km',
        'unitVolume': 'L',
        'currency': '\$',
      };

      final vehicle = Vehicle.fromJson(legacyJson);
      expect(vehicle.fuelType, 'Regular (87)'); // Defaults safely

      // Updated vehicle with explicit fuelType
      final modernVehicle = vehicle.copyWith(fuelType: 'Premium (93)');
      expect(modernVehicle.fuelType, 'Premium (93)');
      final modernJson = modernVehicle.toJson();
      expect(modernJson['fuelType'], 'Premium (93)');
      final deserialized = Vehicle.fromJson(modernJson);
      expect(deserialized.fuelType, 'Premium (93)');
    });

    test('Calculates distance, price per unit, price diff, days, and efficiency correctly', () {
      final now = DateTime(2026, 10, 16, 10, 0);

      final rec1 = FuelRecord(
        id: '1',
        vehicleId: 'v1',
        dateTime: now.subtract(const Duration(days: 7)),
        odometer: 10000.0,
        fuelAmount: 40.0,
        totalPrice: 60.0, // 1.50 / L
      );

      final rec2 = FuelRecord(
        id: '2',
        vehicleId: 'v1',
        dateTime: now,
        odometer: 10500.0,
        fuelAmount: 42.0,
        totalPrice: 65.10, // 1.55 / L (+0.05 / L)
      );

      final calc1 = RecordCalculation(current: rec1);
      expect(calc1.pricePerUnit, closeTo(1.50, 0.001));
      expect(calc1.distanceTraveled, isNull);

      final calc2 = RecordCalculation(current: rec2, previous: rec1);
      // Distance traveled: 10500 - 10000 = 500
      expect(calc2.distanceTraveled, 500.0);

      // Price per unit: 65.10 / 42 = 1.55
      expect(calc2.pricePerUnit, closeTo(1.55, 0.001));

      // Price difference: 1.55 - 1.50 = +0.05
      expect(calc2.priceDifferencePerUnit, closeTo(0.05, 0.001));

      // Fuel efficiency: 500 / 42 = 11.904... km/L
      expect(calc2.fuelEfficiency, closeTo(11.904, 0.01));

      // Days since last fueled: 7.0 days
      expect(calc2.daysSincePrevious, closeTo(7.0, 0.01));

      // Vehicle stats aggregation
      final stats = VehicleStats.fromRecords([rec1, rec2]);
      expect(stats.totalRecords, 2);
      expect(stats.totalDistance, 500.0);
      expect(stats.totalFuel, 82.0);
      expect(stats.totalCost, closeTo(125.10, 0.01));
    });

    test('CSV export writes standalone file containing all metrics and formatted dates', () async {
      SharedPreferences.setMockInitialValues({});
      final tempDir = Directory.systemTemp.createTempSync('fuel_csv_test_');
      final appState = FuelAppState(customStorageDir: tempDir, autoLoad: false);

      final vehicle = Vehicle(
        id: 'test_veh',
        name: 'Speedster',
        type: VehicleType.sedan,
        brand: 'Honda',
        owner: 'Alice',
        fuelType: 'Premium (93)',
      );
      await appState.addVehicle(vehicle);

      final rec = FuelRecord(
        id: 'rec_1',
        vehicleId: 'test_veh',
        dateTime: DateTime(2026, 10, 16),
        odometer: 12000,
        fuelAmount: 45,
        totalPrice: 90,
        fuelType: 'Premium (93)',
        gasStation: 'Shell',
      );
      await appState.addRecord(rec);

      final file = await appState.exportVehicleRecordsToCsvFile('test_veh');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      expect(content.contains('Date,Odometer (km),Distance Travelled (km)'), isTrue);
      expect(content.contains('16-Oct-26'), isTrue);
      expect(content.contains('12000.0'), isTrue);
      expect(content.contains('"Premium (93)"'), isTrue);
      expect(content.contains('"Shell"'), isTrue);

      tempDir.deleteSync(recursive: true);
    });

    test('Full JSON backup and restore functions accurately', () async {
      SharedPreferences.setMockInitialValues({});
      final tempDir = Directory.systemTemp.createTempSync('fuel_backup_test_');
      final appState = FuelAppState(customStorageDir: tempDir, autoLoad: false);

      final v = Vehicle(id: 'v_bak', name: 'Cruiser', type: VehicleType.suv, brand: 'Toyota', owner: 'Bob', fuelType: 'Diesel');
      await appState.addVehicle(v);

      final r = FuelRecord(
        id: 'r_bak',
        vehicleId: 'v_bak',
        dateTime: DateTime(2026, 10, 16),
        odometer: 50000,
        fuelAmount: 60,
        totalPrice: 120,
        fuelType: 'Diesel',
        gasStation: 'BP',
      );
      await appState.addRecord(r);

      final backupStr = appState.exportAllDataBackup();
      expect(backupStr.contains('Cruiser'), isTrue);
      expect(backupStr.contains('50000'), isTrue);

      final file = await appState.saveBackupToFile();
      expect(file.existsSync(), isTrue);

      // Now clear and restore
      await appState.clearAllData();
      expect(appState.vehicles.isEmpty, isTrue);

      await appState.importAllDataBackup(backupStr);
      expect(appState.vehicles.length, 1);
      expect(appState.vehicles.first.name, 'Cruiser');
      expect(appState.allRecords.length, 1);
      expect(appState.allRecords.first.odometer, 50000);

      tempDir.deleteSync(recursive: true);
    });

    testWidgets('TextImportScreen displays description, examples, and triggers parsing', (tester) async {
      final v = Vehicle(id: 'v_text', name: 'Tester', type: VehicleType.sedan, brand: 'Honda', owner: 'Sam', fuelType: 'Regular (87)');
      final appState = FuelAppState(customStorageDir: Directory.systemTemp, autoLoad: false);

      await tester.pumpWidget(MaterialApp(
        home: TextImportScreen(vehicle: v, appState: appState),
      ));
      await tester.pumpAndSettle();

      // Verify description card (1-paragraph simple non-technical explanation)
      expect(find.textContaining('Easily add your past fill-ups all at once'), findsOneWidget);

      // Verify template example chips
      expect(find.text('SMS / Receipt Note'), findsOneWidget);
      expect(find.text('Gallons / US Style'), findsOneWidget);

      // Tap an example chip
      await tester.tap(find.text('SMS / Receipt Note'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Shell'), findsWidgets);
    });

    testWidgets('ImportPreviewScreen handles text input and displays red Cancel and green Accept buttons', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final v = Vehicle(id: 'v_grid', name: 'GridCar', type: VehicleType.compact, brand: 'Toyota', owner: 'Alex', fuelType: 'Regular (87)');
      final tempDir = Directory.systemTemp.createTempSync('fuel_grid_test_');
      final appState = FuelAppState(customStorageDir: tempDir, autoLoad: false);

      await tester.pumpWidget(MaterialApp(
        home: ImportPreviewScreen(
          vehicle: v,
          appState: appState,
          initialText: '2026-10-16, 44000, 38.5, 1.68, 65.0, Shell',
        ),
      ));
      await tester.pumpAndSettle();

      // Verify Red Cancel and Green Accept buttons exist at top
      final cancelFinder = find.widgetWithText(FilledButton, 'Cancel');
      final acceptFinder = find.widgetWithText(FilledButton, 'Accept');
      expect(cancelFinder, findsOneWidget);
      expect(acceptFinder, findsOneWidget);

      final cancelBtn = tester.widget<FilledButton>(cancelFinder);
      expect(cancelBtn.style?.backgroundColor?.resolve({}), const Color(0xFFDC2626)); // Red

      final acceptBtn = tester.widget<FilledButton>(acceptFinder);
      expect(acceptBtn.style?.backgroundColor?.resolve({}), const Color(0xFF16A34A)); // Green

      // Verify staged record summary exists
      expect(find.textContaining('ready to import'), findsOneWidget);

      tempDir.deleteSync(recursive: true);
    });

    testWidgets('ImportPreviewScreen displays 1-paragraph explanation, template button, and top Red/Green buttons', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final v = Vehicle(id: 'v_prev', name: 'PrevCar', type: VehicleType.compact, brand: 'Toyota', owner: 'Alex');
      final tempDir = Directory.systemTemp.createTempSync('fuel_prev_test_');
      final appState = FuelAppState(customStorageDir: tempDir, autoLoad: false);

      await tester.pumpWidget(MaterialApp(
        home: ImportPreviewScreen(
          vehicle: v,
          appState: appState,
          initialText: 'Date,Odometer,Fuel Volume,Total Cost,Gas Station\n2026-10-15,50000,40,100,Shell',
        ),
      ));
      await tester.pump();

      // Verify simple 1-paragraph non-technical explanation
      expect(find.textContaining('Easily add your past fill-ups all at once'), findsOneWidget);

      // Verify Red Cancel and Green Accept buttons
      final cancelFinder = find.widgetWithText(FilledButton, 'Cancel');
      final acceptFinder = find.widgetWithText(FilledButton, 'Accept (1)');
      expect(cancelFinder, findsOneWidget);
      expect(acceptFinder, findsOneWidget);

      final cancelBtn = tester.widget<FilledButton>(cancelFinder);
      expect(cancelBtn.style?.backgroundColor?.resolve({}), const Color(0xFFDC2626)); // Red

      final acceptBtn = tester.widget<FilledButton>(acceptFinder);
      expect(acceptBtn.style?.backgroundColor?.resolve({}), const Color(0xFF16A34A)); // Green

      // Verify Template and Pick File buttons
      expect(find.text('Template'), findsOneWidget);
      expect(find.text('Change File'), findsOneWidget);

      tempDir.deleteSync(recursive: true);
    });

    test('addRecordsBatch commits multiple parsed records to storage', () async {
      SharedPreferences.setMockInitialValues({});
      final tempDir = Directory.systemTemp.createTempSync('fuel_batch_test_');
      final appState = FuelAppState(customStorageDir: tempDir, autoLoad: false);

      final recs = [
        FuelRecord(
          id: 'b1',
          vehicleId: 'v1',
          dateTime: DateTime(2026, 10, 16),
          odometer: 44000,
          fuelAmount: 38.5,
          totalPrice: 65.0,
          gasStation: 'Shell',
        ),
      ];

      await appState.addRecordsBatch(recs);
      expect(appState.allRecords.length, 1);
      expect(appState.allRecords.first.odometer, 44000);
      expect(appState.allRecords.first.fuelAmount, 38.5);

      tempDir.deleteSync(recursive: true);
    });
  });

  testWidgets('FuelRecordApp smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final tempDir = Directory.systemTemp.createTempSync('fuel_metrics_test_');
    final appState = FuelAppState(customStorageDir: tempDir, autoLoad: false);
    await tester.runAsync(() async {
      await appState.loadFromStorage();
    });
    await tester.pumpWidget(FuelRecordApp(appState: appState));
    await tester.pump();

    // App launches directly into HomeScreen
    await tester.pumpAndSettle();
    expect(find.text('Fuel Metrics'), findsWidgets);
    tempDir.deleteSync(recursive: true);
  });
}
