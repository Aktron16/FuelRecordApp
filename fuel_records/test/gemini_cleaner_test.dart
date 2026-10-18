import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuel_records/models/vehicle.dart';
import 'package:fuel_records/models/fuel_record.dart';
import 'package:fuel_records/services/gemini_cleaner_constants.dart';
import 'package:fuel_records/services/header_auto_mapper.dart';
import 'package:fuel_records/services/file_parser_service.dart';
import 'package:fuel_records/services/fuel_app_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Gemini Cleaner & Sanitization Tests', () {
    test('cleanMarkdownFences extracts CSV from markdown code block with ```csv', () {
      const rawGeminiOutput = '''
Here is your cleaned fuel data:
```csv
date,odometer,fuelVolume,pricePerUnit,totalCost,stationName,notes
2026-10-15,84500,42.5,2.50,106.25,Shell,
2026-10-16,84950,40.0,2.50,100.00,Chevron,Highway trip
```
Let me know if you need anything else!
''';

      final cleaned = cleanMarkdownFences(rawGeminiOutput);
      expect(cleaned.startsWith('date,odometer,fuelVolume'), isTrue);
      expect(cleaned.contains('Highway trip'), isTrue);
      expect(cleaned.contains('```'), isFalse);
      expect(cleaned.contains('Here is your cleaned'), isFalse);
    });

    test('cleanMarkdownFences handles plain ``` blocks and strips invisible unicode', () {
      const input = '\uFEFF```\ndate,odometer,fuelVolume,pricePerUnit,totalCost,stationName,notes\r\n2026-10-15,84500,42.5,2.50,106.25,Shell,\r\n```';
      final cleaned = cleanMarkdownFences(input);
      expect(cleaned.contains('\uFEFF'), isFalse);
      expect(cleaned.contains('\r'), isFalse);
      expect(cleaned.startsWith('date,odometer'), isTrue);
    });

    test('cleanMarkdownFences handles plain CSV without backticks', () {
      const input = 'date,odometer,fuelVolume,pricePerUnit,totalCost,stationName,notes\n2026-10-15,84500,42.5,2.50,106.25,Shell,';
      final cleaned = cleanMarkdownFences(input);
      expect(cleaned, input);
    });

    test('HeaderAutoMapper matches 100% of canonical Gemini CSV headers', () {
      const canonicalHeaders = [
        'date',
        'odometer',
        'fuelVolume',
        'pricePerUnit',
        'totalCost',
        'stationName',
        'notes',
      ];

      final mappings = HeaderAutoMapper.autoDetectMappings(
        headers: canonicalHeaders,
        sampleRows: [
          ['2026-10-15', '84500', '42.5', '2.50', '106.25', 'Shell', '']
        ],
      );

      expect(mappings, [
        FuelField.date,
        FuelField.odometer,
        FuelField.fuelVolume,
        FuelField.pricePerUnit,
        FuelField.totalCost,
        FuelField.gasStation,
        FuelField.notes,
      ]);
    });

    test('Full pipeline: clean AI text, parse table, auto-map headers, and stage valid records', () {
      const aiOutput = '''
```csv
date,odometer,fuelVolume,pricePerUnit,totalCost,stationName,notes
2026-10-14,84100,41.0,2.45,100.45,BP,Commute
2026-10-17,84580,43.2,2.50,108.00,Shell,Weekend drive
```
''';

      final cleanCsv = cleanMarkdownFences(aiOutput);
      final rawRows = FileParserService.parseTextToRows(cleanCsv);
      final headers = rawRows.first;
      final dataRows = rawRows.sublist(1);

      final mappings = HeaderAutoMapper.autoDetectMappings(
        headers: headers,
        sampleRows: dataRows,
      );

      final staged = HeaderAutoMapper.stageRows(
        dataRows: dataRows,
        columnMappings: mappings,
      );

      expect(staged.length, 2);
      expect(staged.every((r) => r.isValid), isTrue);
      expect(staged[0].odometer, 84100.0);
      expect(staged[0].gasStation, 'BP');
      expect(staged[1].odometer, 84580.0);
      expect(staged[1].gasStation, 'Shell');
    });
  });

  group('Fuel Grade Propagation & Backup Download Tests', () {
    test('Vehicle default fuelType change propagates across all records in database', () async {
      SharedPreferences.setMockInitialValues({});
      final tempDir = Directory.systemTemp.createTempSync('fuel_prop_test_');
      final appState = FuelAppState(customStorageDir: tempDir, autoLoad: false);

      final vehicle = Vehicle(
        id: 'v_grade',
        name: 'Sedan',
        type: VehicleType.sedan,
        brand: 'Honda',
        owner: 'Alex',
        fuelType: 'Regular (87)',
      );
      await appState.addVehicle(vehicle);

      final r1 = FuelRecord(
        id: 'r1',
        vehicleId: 'v_grade',
        dateTime: DateTime(2026, 10, 10),
        odometer: 10000,
        fuelAmount: 40,
        totalPrice: 80,
        fuelType: 'Regular (87)',
      );
      final r2 = FuelRecord(
        id: 'r2',
        vehicleId: 'v_grade',
        dateTime: DateTime(2026, 10, 15),
        odometer: 10500,
        fuelAmount: 42,
        totalPrice: 84,
        fuelType: 'Regular (87)',
      );
      await appState.addRecord(r1);
      await appState.addRecord(r2);

      // Verify initial state
      expect(appState.records.where((r) => r.vehicleId == 'v_grade').every((r) => r.fuelType == 'Regular (87)'), isTrue);

      // Update vehicle fuelType to Premium 93
      final updatedVehicle = vehicle.copyWith(fuelType: 'Premium (93)');
      await appState.updateVehicle(updatedVehicle);

      // Verify all records for this vehicle updated
      final updatedRecords = appState.records.where((r) => r.vehicleId == 'v_grade').toList();
      expect(updatedRecords.length, 2);
      expect(updatedRecords.every((r) => r.fuelType == 'Premium (93)'), isTrue);

      tempDir.deleteSync(recursive: true);
    });

    test('CSV and JSON backup export saves to target downloads directory', () async {
      SharedPreferences.setMockInitialValues({});
      final tempDir = Directory.systemTemp.createTempSync('fuel_dl_test_');
      final appState = FuelAppState(customStorageDir: tempDir, autoLoad: false);

      final vehicle = Vehicle(
        id: 'v_dl',
        name: 'Truck',
        type: VehicleType.truck,
        brand: 'Ford',
        owner: 'Alex',
      );
      await appState.addVehicle(vehicle);

      final r = FuelRecord(
        id: 'r_dl',
        vehicleId: 'v_dl',
        dateTime: DateTime(2026, 10, 12),
        odometer: 50000,
        fuelAmount: 50,
        totalPrice: 120,
      );
      await appState.addRecord(r);

      final csvFile = await appState.exportVehicleRecordsToCsvFile('v_dl');
      expect(csvFile.existsSync(), isTrue);
      expect(csvFile.readAsStringSync().contains('Date,Odometer'), isTrue);

      final backupFile = await appState.saveBackupToFile();
      expect(backupFile.existsSync(), isTrue);
      expect(backupFile.readAsStringSync().contains('"version": "${FuelAppState.appVersion}"'), isTrue);

      tempDir.deleteSync(recursive: true);
    });
  });
}
