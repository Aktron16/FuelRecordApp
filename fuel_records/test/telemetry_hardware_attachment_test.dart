import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuel_records/models/vehicle.dart';
import 'package:fuel_records/models/fuel_record.dart';
import 'package:fuel_records/services/head_unit_capability_probe.dart';
import 'package:fuel_records/services/telemetry_orchestrator.dart';
import 'package:fuel_records/services/obd_ble_session_manager.dart';
import 'package:fuel_records/services/fuel_app_state.dart';
import 'package:fuel_records/screens/home_screen.dart';
import 'package:fuel_records/screens/obd_pairing_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(const MethodChannel('fuel_metrics/headunit_probe'), null);
  });

  group('Telemetry Hardware Attachment, Failover & GDPR Schema Tests', () {
    test('Test 1: Modern Vehicle Attachment - Direct Telemetry Active, mask updated, BLE idle', () async {
      // 1. Mock platform channel returning STATUS_SUCCESS with valid fuel level and odometer
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('fuel_metrics/headunit_probe'), (MethodCall methodCall) async {
        if (methodCall.method == 'getAttachmentStatus') {
          return {'isAttached': true};
        } else if (methodCall.method == 'probeCapabilities') {
          return {
            'isAttached': true,
            'status': 'STATUS_SUCCESS',
            'fuelSupported': true,
            'odometerSupported': true,
            'currentFuelPercent': 82.5,
            'currentOdometerMeters': 45000000,
          };
        }
        return null;
      });

      final probe = HeadUnitCapabilityProbe();

      // Verify physical attachment
      final isAttached = await probe.isHeadUnitAttached();
      expect(isAttached, isTrue);

      // Probe capabilities within window
      final probeResult = await probe.probeCapabilities();

      // Assert advisory state resolves for modern vehicle
      expect(probeResult.isAttached, isTrue);
      expect(probeResult.status, 'STATUS_SUCCESS');
      expect(probeResult.isNativeSupported, isTrue);
      expect(probeResult.isLegacyRestricted, isFalse);
      expect(probeResult.fuelSupported, isTrue);
      expect(probeResult.odometerSupported, isTrue);
      expect(probeResult.currentFuelPercent, 82.5);
      expect(probeResult.currentOdometerMeters, 45000000);
      expect(probeResult.advisoryMessage.contains('supports direct telemetry'), isTrue);
      expect(probeResult.advisoryMessage.contains('do not need an external OBD-II Bluetooth dongle'), isTrue);

      // Assert telemetryCapabilityMask is updated to include 0x01 | 0x02
      final vehicle = Vehicle(
        id: 'veh_modern_1',
        name: 'Modern Civic',
        type: VehicleType.sedan,
        brand: 'Honda',
        owner: 'Alice',
        tankCapacityMilliliters: 50000,
        telemetryCapabilityMask: 0,
      );

      final updatedVehicle = HeadUnitCapabilityProbe.applyProbeOutcomeToVehicle(vehicle, probeResult);
      expect(TelemetryCapabilityMask.isNativeSupported(updatedVehicle.telemetryCapabilityMask), isTrue);
      expect(updatedVehicle.telemetryCapabilityMask & TelemetryCapabilityMask.headUnitNativeFuel,
          TelemetryCapabilityMask.headUnitNativeFuel);
      expect(updatedVehicle.telemetryCapabilityMask & TelemetryCapabilityMask.headUnitNativeOdometer,
          TelemetryCapabilityMask.headUnitNativeOdometer);
      expect(updatedVehicle.telemetryCapabilityMask & TelemetryCapabilityMask.headUnitRestrictedLegacy, 0);

      // Verify TelemetryOrchestrator routes directly to native head-unit
      final obdManager = ObdBleSessionManager();
      final orchestrator = TelemetryOrchestrator(
        headUnitProbe: probe,
        obdManager: obdManager,
      );

      final source = await orchestrator.determineInitialSource(updatedVehicle);
      expect(source, TelemetrySource.nativeHeadUnit);
      expect(orchestrator.activeSource, TelemetrySource.nativeHeadUnit);

      // Assert BLE peripheral scanner remains idle (saving battery)
      expect(obdManager.isConnected, isFalse);
      expect(obdManager.isScanning, isFalse);

      orchestrator.dispose();
      obdManager.dispose();
    });

    testWidgets('Test 2: Legacy / Restricted Vehicle Attachment - Warning advisory and ObdPairingScreen navigation',
        (WidgetTester tester) async {
      // 1. Mock platform channel returning STATUS_UNIMPLEMENTED
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(const MethodChannel('fuel_metrics/headunit_probe'), (MethodCall methodCall) async {
        if (methodCall.method == 'getAttachmentStatus') {
          return {'isAttached': true};
        } else if (methodCall.method == 'probeCapabilities') {
          return {
            'isAttached': true,
            'status': 'STATUS_UNIMPLEMENTED',
            'fuelSupported': false,
            'odometerSupported': false,
          };
        }
        return null;
      });

      final probe = HeadUnitCapabilityProbe();
      final probeResult = await probe.probeCapabilities();

      // Assert restricted legacy state
      expect(probeResult.isAttached, isTrue);
      expect(probeResult.isNativeSupported, isFalse);
      expect(probeResult.isLegacyRestricted, isTrue);
      expect(probeResult.advisoryMessage.contains('does not expose fuel and odometer sensors'), isTrue);
      expect(probeResult.advisoryMessage.contains('recommend connecting a Bluetooth OBD-II sensor'), isTrue);

      // Assert telemetryCapabilityMask is updated with 0x04 (Legacy Restricted)
      final legacyVehicle = Vehicle(
        id: 'veh_legacy_1',
        name: 'Legacy Corolla',
        type: VehicleType.compact,
        brand: 'Toyota',
        owner: 'Bob',
        tankCapacityMilliliters: 45000,
        telemetryCapabilityMask: 0,
      );

      final updatedVehicle = HeadUnitCapabilityProbe.applyProbeOutcomeToVehicle(legacyVehicle, probeResult);
      expect(TelemetryCapabilityMask.isLegacyRestricted(updatedVehicle.telemetryCapabilityMask), isTrue);
      expect(updatedVehicle.telemetryCapabilityMask & TelemetryCapabilityMask.headUnitRestrictedLegacy,
          TelemetryCapabilityMask.headUnitRestrictedLegacy);

      // 2. Test UI Advisory Banner & Navigation in HomeScreen
      final tempDir = Directory.systemTemp.createTempSync('telemetry_legacy_ui_test_');
      final appState = FuelAppState(customStorageDir: tempDir, autoLoad: false);
      await tester.runAsync(() async {
        await appState.addVehicle(updatedVehicle);
      });

      await tester.pumpWidget(MaterialApp(
        home: HomeScreen(appState: appState),
      ));
      await tester.pump();

      // Verify Advisory Warning Banner
      expect(find.text('Restricted Head-Unit Detected'), findsOneWidget);
      expect(find.text('LEGACY OEM'), findsOneWidget);
      expect(find.textContaining('does not expose fuel and odometer sensors'), findsOneWidget);

      // Verify Action Button
      final connectBtnFinder = find.widgetWithText(ElevatedButton, 'Connect OBD-II Sensor');
      expect(connectBtnFinder, findsOneWidget);

      // Tap 'Connect OBD-II Sensor' and verify navigation to ObdPairingScreen
      await tester.tap(connectBtnFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500)); // transition into ObdPairingScreen

      expect(find.byType(ObdPairingScreen), findsOneWidget);
      expect(find.text('Pair OBD-II BLE Dongle'), findsOneWidget);

      // Advance scanner timer to finish scanning cleanly
      await tester.pump(const Duration(milliseconds: 1600));

      tempDir.deleteSync(recursive: true);
    });

    test('Test 3: Mid-Session Hardware Failover - Head-unit drop fails over to OBD2_BLE in <2000ms', () async {
      final obdManager = ObdBleSessionManager();
      final orchestrator = TelemetryOrchestrator(obdManager: obdManager);

      final vehicle = Vehicle(
        id: 'veh_failover_1',
        name: 'Failover Outback',
        type: VehicleType.suv,
        brand: 'Subaru',
        owner: 'Charlie',
        tankCapacityMilliliters: 60000,
        boundObdDeviceId: 'AA:BB:CC:11:22:33',
        telemetryCapabilityMask:
            TelemetryCapabilityMask.headUnitNativeFuel | TelemetryCapabilityMask.headUnitNativeOdometer,
      );

      // 1. Start active session on NATIVE_HEAD_UNIT
      orchestrator.transitionToSource(TelemetrySource.nativeHeadUnit);
      expect(orchestrator.activeSource, TelemetrySource.nativeHeadUnit);

      // Ingest native telemetry frame
      orchestrator.onTelemetryFrameReceived(
        fuelPercent: 35.0,
        odometer: 42000.0,
        latitude: 25.2048,
        longitude: 55.2708,
      );

      expect(orchestrator.ephemeralState.initialFuelPercent, 35.0);
      expect(orchestrator.ephemeralState.latestFuelPercent, 35.0);
      expect(orchestrator.ephemeralState.lastKnownOdometer, 42000.0);
      expect(orchestrator.ephemeralState.ephemeralLat, 25.2048);
      expect(orchestrator.ephemeralState.ephemeralLon, 55.2708);

      // 2. Simulate head unit drop (cable unplugged / projection killed)
      final stopwatch = Stopwatch()..start();
      orchestrator.handleTelemetryTimeout(vehicle);
      stopwatch.stop();

      // Assert zero-drop failover to OBD2_BLE in under 2000ms
      expect(orchestrator.activeSource, TelemetrySource.obd2Ble);
      expect(stopwatch.elapsedMilliseconds, lessThan(2000));

      // Assert EphemeralRefuelState buffer is preserved across failover
      expect(orchestrator.ephemeralState.initialFuelPercent, 35.0);
      expect(orchestrator.ephemeralState.latestFuelPercent, 35.0);
      expect(orchestrator.ephemeralState.lastKnownOdometer, 42000.0);
      expect(orchestrator.ephemeralState.ephemeralLat, 25.2048);
      expect(orchestrator.ephemeralState.ephemeralLon, 55.2708);

      // 3. Ingest subsequent OBD-II BLE telemetry frames (fill complete)
      orchestrator.onTelemetryFrameReceived(
        fuelPercent: 88.0,
        odometer: 42000.0,
      );

      expect(orchestrator.ephemeralState.latestFuelPercent, 88.0);
      expect(orchestrator.ephemeralState.hasActiveRefuelPotential, isTrue);

      // 4. If OBD drops too on a vehicle without native capabilities, failover to PASSIVE_MANUAL_READY
      final unlinkedVehicle = vehicle.copyWith(
        telemetryCapabilityMask: 0,
        boundObdDeviceId: null,
      );
      orchestrator.handleTelemetryTimeout(unlinkedVehicle);
      expect(orchestrator.activeSource, TelemetrySource.passiveManualReady);

      orchestrator.dispose();
      obdManager.dispose();
    });

    test('Test 4: Relational Schema & GDPR Compliance - Exact 64-bit integer scaling & ephemeral purge', () {
      final vehicle = Vehicle(
        id: 'veh_gdpr_1',
        name: 'Eco Hybrid',
        type: VehicleType.sedan,
        brand: 'Toyota',
        owner: 'Dave',
        tankCapacityMilliliters: 55000, // 55.0 L
      );

      // 1. Calculate physical volume in milliliters using tank capacity and relative delta:
      // volumeMilliliters = ((deltaPercent / 100.0) * tankCapacityMilliliters).round()
      const double preFuelPercent = 20.0;
      const double postFuelPercent = 80.0;
      const double deltaPercent = postFuelPercent - preFuelPercent; // 60.0%
      final int volumeMilliliters = ((deltaPercent / 100.0) * vehicle.tankCapacityMilliliters).round();

      expect(volumeMilliliters, 33000); // Exact 33,000 mL (33.0 L)

      const int odometerMeters = 54200000; // 54,200.0 km
      const int totalCostCents = 4950; // $49.50
      const int epochSec = 1729426800; // 64-bit Unix Epoch

      // 2. Construct FuelRecord with exact 64-bit integer scaled fields
      final record = FuelRecord(
        id: 'rec_gdpr_test_1',
        vehicleId: vehicle.id,
        timestampEpochSec: epochSec,
        odometerMeters: odometerMeters,
        volumeMilliliters: volumeMilliliters,
        totalCostCents: totalCostCents,
        gasStation: 'Shell Autocenter',
        ingressSource: IngressSource.nativeHeadUnit.index,
      );

      // Assert integer storage
      expect(record.volumeMilliliters, 33000);
      expect(record.odometerMeters, 54200000);
      expect(record.totalCostCents, 4950);
      expect(record.timestampEpochSec, epochSec);
      expect(record.ingressSource, IngressSource.nativeHeadUnit.index);

      // Assert backward-compatible getters
      expect(record.fuelAmount, 33.0);
      expect(record.odometer, 54200.0);
      expect(record.totalPrice, 49.50);
      expect(record.pricePerUnit, closeTo(1.50, 0.001));
      expect(record.dateTime, DateTime.fromMillisecondsSinceEpoch(epochSec * 1000));

      // 3. Assert Relational SQLite Serialization & Strict Column Pruning (GDPR Data Minimization)
      final json = record.toJson();
      expect(json['volumeMilliliters'], 33000);
      expect(json['odometerMeters'], 54200000);
      expect(json['totalCostCents'], 4950);
      expect(json['timestampEpochSec'], epochSec);
      expect(json['ingressSource'], IngressSource.nativeHeadUnit.index);

      // Strictly verify no raw transient data is persisted
      expect(json.containsKey('rawObdFrames'), isFalse);
      expect(json.containsKey('vinString'), isFalse);
      expect(json.containsKey('gpsCoordinatesLatLon'), isFalse);
      expect(json.containsKey('latitude'), isFalse);
      expect(json.containsKey('longitude'), isFalse);
      expect(json.containsKey('preFuelPercent'), isFalse);
      expect(json.containsKey('postFuelPercent'), isFalse);
      expect(json.containsKey('engineRpm'), isFalse);

      // 4. Assert Ephemeral Memory Purge
      final ephemeralState = EphemeralRefuelState();
      ephemeralState.initialFuelPercent = 20.0;
      ephemeralState.latestFuelPercent = 80.0;
      ephemeralState.lastKnownOdometer = 54200.0;
      ephemeralState.ephemeralLat = 25.2048;
      ephemeralState.ephemeralLon = 55.2708;
      ephemeralState.sessionStartTime = DateTime.now();
      expect(ephemeralState.hasActiveRefuelPotential, isTrue);

      // Purge on session completion
      ephemeralState.clear();

      expect(ephemeralState.initialFuelPercent, isNull);
      expect(ephemeralState.latestFuelPercent, isNull);
      expect(ephemeralState.lastKnownOdometer, isNull);
      expect(ephemeralState.ephemeralLat, isNull);
      expect(ephemeralState.ephemeralLon, isNull);
      expect(ephemeralState.sessionStartTime, isNull);
      expect(ephemeralState.hasActiveRefuelPotential, isFalse);
    });
  });
}
