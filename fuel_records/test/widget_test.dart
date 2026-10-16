import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuel_records/models/fuel_record.dart';
import 'package:fuel_records/models/record_calculation.dart';
import 'package:fuel_records/models/vehicle_stats.dart';
import 'package:fuel_records/services/fuel_app_state.dart';
import 'package:fuel_records/main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Fuel Calculations Tests', () {
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

    // App launches and shows welcome / add vehicle
    expect(find.text('Fuel Metrics'), findsWidgets);
  });
}
