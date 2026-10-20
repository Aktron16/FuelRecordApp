import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuel_records/models/vehicle.dart';
import 'package:fuel_records/models/fuel_record.dart';
import 'package:fuel_records/services/auto_refuel_orchestrator.dart';
import 'package:fuel_records/services/obd_ble_service.dart';
import 'package:fuel_records/services/photo_exif_draft_service.dart';
import 'package:fuel_records/services/motion_pit_stop_service.dart';
import 'package:fuel_records/services/delayed_ecu_math_engine.dart';
import 'package:fuel_records/services/station_and_price_resolver.dart';
import 'package:fuel_records/services/fuel_app_state.dart';

void main() {
  group('Auto Refuel 5-Tier Fallback Engine & GDPR Tests', () {
    late Vehicle testVehicle;
    late List<FuelRecord> historyRecords;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      testVehicle = Vehicle(
        id: 'veh_test_1',
        name: 'Test Car',
        type: VehicleType.sedan,
        brand: 'Honda',
        owner: 'Tester',
        tankCapacityLiters: 50.0,
        lastKnownOdometer: 20000.0,
        lastKnownFuelPercent: 20.0,
        calibrationFactor: 1.0,
      );

      historyRecords = [
        FuelRecord(
          id: 'rec_1',
          vehicleId: testVehicle.id,
          dateTime: DateTime.now().subtract(const Duration(days: 7)),
          odometer: 19500.0,
          fuelAmount: 40.0,
          totalPrice: 60.0, // 1.50 / L
          gasStation: 'Shell',
        ),
      ];
    });

    test('Pre-flight Sensor Readiness monitors hardware switches and consent', () {
      final orchestrator = AutoRefuelOrchestrator();

      // Consented to BT and Location, both hardware ON -> no alert
      orchestrator.setBluetoothHardwareState(true);
      orchestrator.setLocationHardwareState(true);
      var status = orchestrator.checkPreFlightReadiness(
        hasBluetoothConsent: true,
        hasLocationConsent: true,
      );
      expect(status.shouldAlertUser, isFalse);

      // Consented to Bluetooth, but Bluetooth hardware is OFF -> alert!
      orchestrator.setBluetoothHardwareState(false);
      status = orchestrator.checkPreFlightReadiness(
        hasBluetoothConsent: true,
        hasLocationConsent: true,
      );
      expect(status.shouldAlertUser, isTrue);
      expect(status.alertMessage.contains('Turn on Bluetooth'), isTrue);

      // Both OFF -> mentions both
      orchestrator.setLocationHardwareState(false);
      status = orchestrator.checkPreFlightReadiness(
        hasBluetoothConsent: true,
        hasLocationConsent: true,
      );
      expect(status.shouldAlertUser, isTrue);
      expect(status.alertMessage.contains('Bluetooth & Location'), isTrue);

      // Hardware is OFF, but user declined consent in Settings -> zero alert (respects choice)
      status = orchestrator.checkPreFlightReadiness(
        hasBluetoothConsent: false,
        hasLocationConsent: false,
      );
      expect(status.shouldAlertUser, isFalse);
    });

    test('Self-learning calibration formula adjusts factor smoothly and clamps safely', () {
      // oldFactor = 1.0, rawLiters = 40.0, price = 1.50, actual paid = 63.00 (actual = 42.0L)
      // ratio = 42.0 / 40.0 = 1.05
      // newFactor = 0.8 * 1.0 + 0.2 * 1.05 = 0.8 + 0.21 = 1.01
      final newFactor = AutoRefuelOrchestrator.updateCalibrationFactor(
        oldFactor: 1.0,
        actualAmountPaid: 63.00,
        pricePerLitre: 1.50,
        rawObdLiters: 40.0,
      );
      expect(newFactor, closeTo(1.01, 0.001));

      // Extreme test: actual much higher -> clamped to 1.15
      final clampedHigh = AutoRefuelOrchestrator.updateCalibrationFactor(
        oldFactor: 1.0,
        actualAmountPaid: 150.0,
        pricePerLitre: 1.50,
        rawObdLiters: 40.0,
      );
      expect(clampedHigh, equals(1.15));

      // Extreme test: actual much lower -> clamped to 0.85
      final clampedLow = AutoRefuelOrchestrator.updateCalibrationFactor(
        oldFactor: 1.0,
        actualAmountPaid: 15.0,
        pricePerLitre: 1.50,
        rawObdLiters: 40.0,
      );
      expect(clampedLow, equals(0.85));
    });

    test('Tier 1: Apple CarPlay / Android Auto tandem detection on ignition jump >= 10%', () {
      final orchestrator = AutoRefuelOrchestrator();

      // Jump from 20% to 90% (70% jump >= 10%)
      final refuel = orchestrator.processTier1CarPlayAndroidAuto(
        vehicle: testVehicle,
        countryName: 'United States',
        historyRecords: historyRecords,
        currentFuelPercent: 90.0,
        currentOdometer: 20100.0,
        latitude: 37.7749,
        longitude: -122.4194,
      );

      expect(refuel, isNotNull);
      expect(refuel!.detectionTier, equals(1));
      expect(refuel.status, equals('AWAITING_USER_VERIFY'));
      // 70% of 50L = 35L
      expect(refuel.estimatedLiters, closeTo(35.0, 0.1));
      expect(refuel.estimatedTotalCost, greaterThan(0.0));

      // Jump < 10% (e.g. 20% to 25% -> only 5% fuel slosh / small fluctuation) -> not a refuel
      final noRefuel = orchestrator.processTier1CarPlayAndroidAuto(
        vehicle: testVehicle,
        countryName: 'United States',
        historyRecords: historyRecords,
        currentFuelPercent: 25.0,
        currentOdometer: 20050.0,
      );
      expect(noRefuel, isNull);
    });

    test('Tier 2: Live OBD-II BLE anti-slosh 5-reading trimmed mean filter', () async {
      final obdService = ObdBleService();

      // Readings with outlier slosh values: [75, 80, 80, 81, 95] -> trimmed mean removes 75 and 95 -> mean(80, 80, 81) = 80.33
      final trimmed = ObdBleService.applyAntiSloshTrimmedMean([75.0, 80.0, 80.0, 81.0, 95.0]);
      expect(trimmed, closeTo(80.33, 0.05));

      final snapshot = await obdService.readStabilizedSnapshot(
        currentOdometerBaseline: 20000.0,
        currentFuelPercentBaseline: 20.0,
        simulatedFuelJump: 60.0,
        simulateFast: true,
      );

      expect(snapshot.fuelPercent, greaterThanOrEqualTo(75.0));
      expect(snapshot.odometer, equals(20000.0));
    });

    test('Tier 3: Quick Draft and Photo EXIF merger with deferred OBD injection', () {
      final draft = PhotoExifDraftService.createQuickPumpDraft(
        vehicle: testVehicle,
        countryName: 'United States',
        stationName: 'Chevron',
      );

      expect(draft.detectionTier, equals(3));
      expect(draft.status, equals('DRAFT_TIMESTAMP'));
      expect(draft.detectedStationName, equals('Chevron'));
      expect(draft.estimatedLiters, equals(0.0)); // Awaiting OBD reconnect

      // Deferred OBD merge: OBD reconnects later and injects back-calculated liters & odo
      final merged = PhotoExifDraftService.mergeObdTelemetryIntoDraft(
        draft: draft,
        backCalculatedOdometer: 20050.0,
        backCalculatedLiters: 42.0,
        rawObdLiters: 42.0,
      );

      expect(merged.status, equals('AWAITING_USER_VERIFY'));
      expect(merged.estimatedLiters, equals(42.0));
      expect(merged.estimatedOdometer, equals(20050.0));
      expect(merged.estimatedTotalCost, greaterThan(0.0));
    });

    test('Tier 4: Motion Pit-Stop Fingerprinting detects 3-10 min stops and matches refuel', () {
      final motionService = MotionPitStopService();

      // Vehicle is driving -> steps out at station
      final stopStart = DateTime.now().subtract(const Duration(minutes: 20));
      motionService.processTransition(
        newState: DrivingActivityState.inVehicle,
        timestamp: stopStart.subtract(const Duration(hours: 1)),
      );

      // Stop started
      motionService.processTransition(
        newState: DrivingActivityState.stillOrOnFoot,
        timestamp: stopStart,
      );

      // Driving resumed 6 minutes later (typical pump duration)
      final stopEnd = stopStart.add(const Duration(minutes: 6));
      final pitStop = motionService.processTransition(
        newState: DrivingActivityState.inVehicle,
        timestamp: stopEnd,
        latitude: 37.7749,
        longitude: -122.4194,
      );

      expect(pitStop, isNotNull);
      expect(pitStop!.durationMinutes, closeTo(6.0, 0.2));

      // Match refuel event to this pit stop
      final matched = MotionPitStopService.matchRefuelToPitStop(
        refuelDetectionTime: DateTime.now(),
        pitStops: [pitStop],
      );
      expect(matched, isNotNull);
      expect(matched!.id, equals(pitStop.id));
    });

    test('Tier 5: Delayed ECU Math distinguishes real refuel from slosh & back-calculates odometer', () {
      // 50L capacity: threshold is max(6.0, 0.12 * 50) = 6.0L
      // Last known: 20000 km, 20% (10L in tank)
      // Current: 20100 km (driven 100km, burned ~7.8L fuel), Current fuel level: 80% (40L)
      // Net tank change = 40L - 10L = +30L
      // Estimated fuel burned during 100km drive = 7.8L
      // Total reconstructed liters added = 30L + 7.8L = 37.8L (well above 6.0L threshold!)
      final result = DelayedEcuMathEngine.reconstructRefuel(
        vehicle: testVehicle,
        currentOdometer: 20100.0,
        currentFuelPercent: 80.0,
        avgLitersPer100Km: 7.8,
        countryName: 'United States',
        historyRecords: historyRecords,
      );

      expect(result.isRefuelDetected, isTrue);
      expect(result.reconstructedLitersAdded, closeTo(37.8, 0.5));
      expect(result.estimatedPumpOdometer, closeTo(20000.0, 10.0));
      expect(result.attributedStation, equals('Shell')); // Habitual match from history!

      // Non-fuel stop / tiny fluctuation: level went from 20% to 22% (1L added, below threshold)
      final noRefuelResult = DelayedEcuMathEngine.reconstructRefuel(
        vehicle: testVehicle,
        currentOdometer: 20010.0,
        currentFuelPercent: 21.0,
        avgLitersPer100Km: 7.8,
        countryName: 'United States',
        historyRecords: historyRecords,
      );
      expect(noRefuelResult.isRefuelDetected, isFalse);
    });

    test('FuelAppState full lifecycle: Simulate Tier refuel, confirm with custom amount, calibrate tank, and GDPR wipe', () async {
      final tempDir = Directory.systemTemp.createTempSync('fuel_auto_test_');
      final appState = FuelAppState(customStorageDir: tempDir, autoLoad: false);
      await appState.loadFromStorage();

      await appState.addVehicle(testVehicle);
      expect(appState.vehicles.length, equals(1));

      // Simulate a Tier 2 Refuel
      final pending = await appState.simulateTierRefuel(
        2,
        customLiters: 40.0,
        customPrice: 1.50,
        customStation: 'Exxon',
      );
      expect(pending, isNotNull);
      expect(appState.pendingAutoRefuels.length, equals(1));

      // User confirms with custom verified receipt amount: paid $63.00 instead of $60.00
      // Actual liters = 63.0 / 1.50 = 42.0L
      // Calibration factor updates from 1.0 to ~1.01
      await appState.confirmPendingAutoRefuel(pending!.id, customAmountPaid: 63.00);

      expect(appState.pendingAutoRefuels.length, equals(0));
      expect(appState.allRecords.length, equals(1));
      expect(appState.allRecords.first.totalPrice, equals(63.00));
      expect(appState.allRecords.first.fuelAmount, equals(42.00));
      expect(appState.activeVehicle!.calibrationFactor, greaterThan(1.0));

      // GDPR Right to Erasure
      await appState.deleteAllLocalAppData();
      expect(appState.vehicles.isEmpty, isTrue);
      expect(appState.allRecords.isEmpty, isTrue);
      expect(appState.pendingAutoRefuels.isEmpty, isTrue);
      expect(appState.carBluetoothObdSync, isFalse);
      expect(appState.hasCompletedDataConsent, isFalse);

      tempDir.deleteSync(recursive: true);
    });

    test('Station proximity and 90% full tank threshold rules', () {
      // 1. Not near a fuel pump -> station is null (empty)
      final noStation = StationAndPriceResolver.resolveStationName(
        countryName: 'United Arab Emirates',
        historyRecords: [],
        isNearFuelPump: false,
      );
      expect(noStation, isNull);

      // 2. UAE pricing source matches fuelpriceuae.com
      final uaePrice = StationAndPriceResolver.resolvePricePerLitre(
        stationName: null,
        vehicle: testVehicle.copyWith(fuelType: 'Special 95'),
        countryName: 'United Arab Emirates',
        historyRecords: [],
      );
      expect(uaePrice.priceSourceUrl, equals('https://fuelpriceuae.com'));
      expect(uaePrice.pricePerLitre, equals(2.77));

      // 3. Other country pricing source matches globalpetrolprices.com
      final usPrice = StationAndPriceResolver.resolvePricePerLitre(
        stationName: null,
        vehicle: testVehicle.copyWith(fuelType: 'Regular (87)'),
        countryName: 'United States',
        historyRecords: [],
      );
      expect(usPrice.priceSourceUrl, equals('https://www.globalpetrolprices.com'));
      expect(usPrice.pricePerLitre, equals(0.95));

      // 4. US vehicle in gallons scales price per gallon properly
      final usVehicleGallons = testVehicle.copyWith(unitVolume: 'gal', fuelType: 'Regular (87)');
      final pricePerGallon = StationAndPriceResolver.resolvePriceForVehicle(usVehicleGallons, 'United States');
      expect(pricePerGallon, closeTo(0.95 * 3.78541, 0.05));

      // 5. 90% threshold for full tank:
      // For a 50L tank: 12.5L (25%) is not full tank, 46L (92%) is full tank
      final capacityLiters = testVehicle.tankCapacityInUnit;
      expect((12.5 / capacityLiters) >= 0.90, isFalse);
      expect((46.0 / capacityLiters) >= 0.90, isTrue);
    });

    test('Fuel Grade Pricing and Location Decoupling', () {
      // 1. getFuelGradePrices returns all UAE fuel grades from fuelpriceuae.com
      final uaeGrades = StationAndPriceResolver.getFuelGradePrices(countryName: 'United Arab Emirates');
      expect(uaeGrades.length, equals(4));
      expect(uaeGrades.map((g) => g.gradeName), containsAll(['Special 95', 'Super 98', 'E-Plus 91', 'Diesel']));
      final super98 = uaeGrades.firstWhere((g) => g.gradeName == 'Super 98');
      expect(super98.pricePerLitre, equals(2.88));
      expect(super98.pricePerGallon, equals(10.90));

      // 2. Pricing strictly resolves to vehicle's specific fuel grade
      final carSuper98 = testVehicle.copyWith(fuelType: 'Super 98');
      final resSuper98 = StationAndPriceResolver.resolvePricePerLitre(
        vehicle: carSuper98,
        countryName: 'United Arab Emirates',
        historyRecords: [],
      );
      expect(resSuper98.pricePerLitre, equals(2.88));

      final carDiesel = testVehicle.copyWith(fuelType: 'Diesel');
      final resDiesel = StationAndPriceResolver.resolvePricePerLitre(
        vehicle: carDiesel,
        countryName: 'United Arab Emirates',
        historyRecords: [],
      );
      expect(resDiesel.pricePerLitre, equals(2.85));

      // 3. Location coords are completely decoupled from price calculation
      final withCoords = StationAndPriceResolver.resolvePricePerLitre(
        vehicle: carSuper98,
        countryName: 'United Arab Emirates',
        historyRecords: [],
        latitude: 25.2048,
        longitude: 55.2708,
      );
      final withoutCoords = StationAndPriceResolver.resolvePricePerLitre(
        vehicle: carSuper98,
        countryName: 'United Arab Emirates',
        historyRecords: [],
        latitude: null,
        longitude: null,
      );
      expect(withCoords.pricePerLitre, equals(withoutCoords.pricePerLitre));
      expect(withCoords.priceSourceUrl, equals(withoutCoords.priceSourceUrl));

      // 4. Total cost calculates based on that specific car's fuel grade
      final costSuper98 = StationAndPriceResolver.calculateTotalCost(
        litersAdded: 40.0,
        pricePerLitre: resSuper98.pricePerLitre,
      );
      expect(costSuper98, equals(double.parse((40.0 * 2.88).toStringAsFixed(2))));

      final costDiesel = StationAndPriceResolver.calculateTotalCost(
        litersAdded: 40.0,
        pricePerLitre: resDiesel.pricePerLitre,
      );
      expect(costDiesel, equals(double.parse((40.0 * 2.85).toStringAsFixed(2))));

      // 5. If location disabled or not near pump, station name is null
      final disabledLocationStation = StationAndPriceResolver.resolveStationName(
        latitude: null,
        longitude: null,
        countryName: 'United Arab Emirates',
        historyRecords: [],
      );
      expect(disabledLocationStation, isNull);

      // 6. PreFlightSensorStatus alert messages accurately describe location purpose
      final orchestrator = AutoRefuelOrchestrator();
      orchestrator.setBluetoothHardwareState(true);
      orchestrator.setLocationHardwareState(false);
      final locAlert = orchestrator.checkPreFlightReadiness(
        hasBluetoothConsent: true,
        hasLocationConsent: true,
      );
      expect(locAlert.alertMessage, contains('identify the petrol pump name'));
      expect(locAlert.alertMessage.contains('price'), isFalse);
    });
  });
}
