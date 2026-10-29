import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuel_records/main.dart';
import 'package:fuel_records/services/fuel_app_state.dart';
import 'package:fuel_records/services/obd_telemetry_service.dart';
import 'package:fuel_records/screens/obd_telemetry_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('OBD-II / ELM327 Telemetry & Local 1Hz Database Tests', () {
    test('ELM327 Mode 01 PID hex decoders parse RPM, Speed, Runtime, Fuel Status, and Fuel Level', () {
      // Mode 01 PID 0C: 41 0C 1A F8 -> ((26 * 256) + 248) / 4 = 1726 RPM
      expect(ObdTelemetryService.parseEngineRpm('41 0C 1A F8'), equals(1726.0));

      // Mode 01 PID 0D: 41 0D 55 -> 85 km/h
      expect(ObdTelemetryService.parseVehicleSpeed('41 0D 55'), equals(85.0));

      // Mode 01 PID 1F: 41 1F 01 2C -> (1 * 256) + 44 = 300 seconds
      expect(ObdTelemetryService.parseElapsedRuntime('41 1F 01 2C'), equals(300));

      // Mode 01 PID 03: Fuel System Status
      expect(ObdTelemetryService.parseFuelSystemStatus('41 03 01 00'), equals('Open Loop (Cold)'));
      expect(ObdTelemetryService.parseFuelSystemStatus('41 03 02 00'), equals('Closed Loop (O2)'));
      expect(ObdTelemetryService.parseFuelSystemStatus('41 03 04 00'), equals('Open Loop (Load)'));

      // Mode 01 PID 2F: 41 2F 80 -> 128 * 100 / 255 = 50.2%
      expect(ObdTelemetryService.parseFuelLevel('41 2F 80'), equals(50.2));
    });

    test('recordSample strictly throttles saves to 1 per second and persists to separate obd_telemetry_db.json', () async {
      final tempDir = Directory.systemTemp.createTempSync('obd_db_test_');
      final obdService = ObdTelemetryService(customStorageDir: tempDir);
      final baseTime = DateTime(2026, 10, 29, 18, 0, 0);

      final s1 = ObdTelemetryRecord(
        id: '1',
        vehicleId: 'v1',
        timestamp: baseTime,
        engineRpm: 1500,
        vehicleSpeedKmh: 60,
        elapsedRuntimeSec: 100,
        fuelSystemStatus: 'Closed Loop (O2)',
        fuelLevelPercent: 75.0,
      );

      // Sub-second samples (300ms and 950ms later) must be rejected to prevent overload
      final s2TooFast = ObdTelemetryRecord(
        id: '2',
        vehicleId: 'v1',
        timestamp: baseTime.add(const Duration(milliseconds: 300)),
        engineRpm: 1600,
        vehicleSpeedKmh: 62,
        elapsedRuntimeSec: 100,
        fuelSystemStatus: 'Closed Loop (O2)',
        fuelLevelPercent: 75.0,
      );
      final s3TooFast = ObdTelemetryRecord(
        id: '3',
        vehicleId: 'v1',
        timestamp: baseTime.add(const Duration(milliseconds: 950)),
        engineRpm: 1700,
        vehicleSpeedKmh: 64,
        elapsedRuntimeSec: 100,
        fuelSystemStatus: 'Closed Loop (O2)',
        fuelLevelPercent: 75.0,
      );

      // Sample exactly 1000ms (1 second) later must be accepted
      final s4Valid = ObdTelemetryRecord(
        id: '4',
        vehicleId: 'v1',
        timestamp: baseTime.add(const Duration(seconds: 1)),
        engineRpm: 1850,
        vehicleSpeedKmh: 68,
        elapsedRuntimeSec: 101,
        fuelSystemStatus: 'Closed Loop (O2)',
        fuelLevelPercent: 74.9,
      );

      expect(await obdService.recordSample(s1), isTrue);
      expect(await obdService.recordSample(s2TooFast), isFalse);
      expect(await obdService.recordSample(s3TooFast), isFalse);
      expect(await obdService.recordSample(s4Valid), isTrue);

      expect(obdService.allRecords.length, equals(2));

      // Verify separate local database file exists on disk
      final dbFile = File('${tempDir.path}/${ObdTelemetryService.dbFileName}');
      expect(dbFile.existsSync(), isTrue);

      // Reload into a new service instance and verify persistence
      final reloaded = ObdTelemetryService(customStorageDir: tempDir);
      await reloaded.loadFromStorage();
      expect(reloaded.allRecords.length, equals(2));
      expect(reloaded.allRecords.first.engineRpm, equals(1500.0));
      expect(reloaded.allRecords.last.engineRpm, equals(1850.0));
      expect(reloaded.allRecords.last.elapsedRuntimeSec, equals(101));

      obdService.dispose();
      reloaded.dispose();
      tempDir.deleteSync(recursive: true);
    });

    testWidgets('Home screen OBD-II Live Telemetry button opens screen with live readout, graph, and table', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final tempDir = Directory.systemTemp.createTempSync('obd_ui_test_');
      final appState = FuelAppState(customStorageDir: tempDir, autoLoad: false);
      await tester.runAsync(() async {
        await appState.loadFromStorage();
      });

      await tester.pumpWidget(FuelRecordApp(appState: appState));
      await tester.pumpAndSettle();

      // Verify Home Screen has the OBD-II Live Telemetry button
      expect(find.text('OBD-II Live Telemetry'), findsOneWidget);

      // Tap button to open ObdTelemetryScreen
      await tester.tap(find.text('OBD-II Live Telemetry'));
      await tester.pumpAndSettle();

      expect(find.byType(ObdTelemetryScreen), findsOneWidget);
      expect(find.text('Live Sensor Readout'), findsOneWidget);
      expect(find.text('Telemetry Trend Graph (1 Hz)'), findsOneWidget);
      expect(find.text('OBD-II Telemetry Database Table'), findsOneWidget);

      // Start detecting and streaming from ELM327 sensor
      await tester.runAsync(() async {
        await appState.obdService.detectAndStartLiveFeed(vehicleId: 'default_vehicle');
      });
      await tester.pump();

      expect(appState.obdService.isConnected, isTrue);
      expect(find.text('LIVE 1Hz'), findsOneWidget);
      expect(appState.obdService.allRecords.isNotEmpty, isTrue);

      // Stop live stream before teardown
      appState.obdService.disconnectSensor();
      await tester.pump();
      expect(appState.obdService.isConnected, isFalse);

      tempDir.deleteSync(recursive: true);
    });
  });
}
