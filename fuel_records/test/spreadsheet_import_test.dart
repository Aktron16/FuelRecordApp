import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fuel_records/models/vehicle.dart';
import 'package:fuel_records/models/fuel_record.dart';
import 'package:fuel_records/services/fuel_app_state.dart';
import 'package:fuel_records/services/file_parser_service.dart';
import 'package:fuel_records/services/header_auto_mapper.dart';

void main() {
  group('3-Layer Hybrid Import System Tests', () {
    late Directory tempDir;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      tempDir = Directory.systemTemp.createTempSync('hybrid_import_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    // Component A: Official Template Generator
    test('exportSampleTemplate creates valid CSV with canonical headers and realistic data', () async {
      final v = Vehicle(
        id: 'v1',
        name: 'Camry',
        type: VehicleType.sedan,
        brand: 'Toyota',
        owner: 'Alex',
        fuelType: 'Regular (87)',
        currency: 'AED',
        unitDistance: 'km',
        unitVolume: 'L',
      );

      final file = await FileParserService.exportSampleTemplate(vehicle: v, targetDir: tempDir);
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      final lines = content.split('\r\n').where((l) => l.isNotEmpty).toList();
      expect(lines.length, 2);

      // Verify canonical headers
      expect(lines[0], 'Date,Odometer,Fuel Volume,Price Per Unit,Total Cost,Gas Station,Fuel Grade,Full Tank,Notes');

      // Verify realistic example row
      expect(lines[1], contains('2026-10-15'));
      expect(lines[1], contains('84500'));
      expect(lines[1], contains('42.50'));
      expect(lines[1], contains('2.50'));
      expect(lines[1], contains('106.25'));
      expect(lines[1], contains('Shell'));
      expect(lines[1], contains('Regular (87)'));
    });

    // Component B.1: File Parsing and Header Skip
    test('Universal File Reader skips title banners and parses CSV/TSV correctly', () {
      const messyCsv = '''
Company Fuel Fleet Report
Generated on October 2026

Date,Odo,Volume,Price,Total,Station
2026-10-12,50000,40,2.00,80,Shell
2026-10-16,50450,42.5,2.10,89.25,BP
''';

      final table = FileParserService.parseSpreadsheetBytes(
        Uint8List.fromList(messyCsv.codeUnits),
        'FleetReport.csv',
      );

      expect(table.headers, ['Date', 'Odo', 'Volume', 'Price', 'Total', 'Station']);
      expect(table.dataRows.length, 2);
      expect(table.dataRows[0][0], '2026-10-12');
      expect(table.dataRows[0][1], '50000');
      expect(table.dataRows[1][1], '50450');
    });

    // Component B.2: Header Nickname Dictionary
    test('HeaderAutoMapper matches nicknames across messy column names', () {
      final headers = [
        'Transaction Date',
        'Mileage (KM)',
        'Ltrs Pumped',
        'Cost Per Liter',
        'Amount Paid',
        'Petrol Station',
        'Octane Grade',
        'Full Tank?',
        'Remarks'
      ];
      final mappings = HeaderAutoMapper.autoDetectMappings(
        headers: headers,
        sampleRows: [
          ['2026-10-15', '60000', '45', '2.5', '112.5', 'Shell', '95', 'Yes', 'Trip']
        ],
      );

      expect(mappings[0], FuelField.date);
      expect(mappings[1], FuelField.odometer);
      expect(mappings[2], FuelField.fuelVolume);
      expect(mappings[3], FuelField.pricePerUnit);
      expect(mappings[4], FuelField.totalCost);
      expect(mappings[5], FuelField.gasStation);
      expect(mappings[6], FuelField.fuelType);
      expect(mappings[7], FuelField.isFullTank);
      expect(mappings[8], FuelField.notes);
    });

    // Component B.3: Math Fallback Rule (|A * B - C| <= 0.05)
    test('Math Fallback Rule identifies volume, unit price, and total cost when headers are unknown', () {
      // Unlabeled headers
      final headers = ['Col_1', 'Col_2', 'Col_3', 'Col_4'];
      final sampleRows = [
        ['2026-10-15', '40.0', '2.50', '100.00'],
        ['2026-10-18', '35.0', '2.60', '91.00'],
      ];

      final mappings = HeaderAutoMapper.autoDetectMappings(
        headers: headers,
        sampleRows: sampleRows,
      );

      // Col_1 should be detected as Date
      expect(mappings[0], FuelField.date);
      // Triplet: 40 * 2.50 = 100.00
      // 2.50 is smaller -> pricePerUnit
      // 40.0 is larger -> fuelVolume
      // 100.00 is product -> totalCost
      expect(mappings[1], FuelField.fuelVolume);
      expect(mappings[2], FuelField.pricePerUnit);
      expect(mappings[3], FuelField.totalCost);
    });

    // Data Cleaning & Flexible Date Parsing
    test('Number and Date cleaner strips currencies, units, and parses diverse date formats', () {
      // Clean number
      expect(HeaderAutoMapper.cleanNumber('\$106.25'), 106.25);
      expect(HeaderAutoMapper.cleanNumber('AED 85.50'), 85.50);
      expect(HeaderAutoMapper.cleanNumber('€ 45,50'), 45.50);
      expect(HeaderAutoMapper.cleanNumber('45.2 Litres'), 45.2);
      expect(HeaderAutoMapper.cleanNumber('84,500 km'), 84500.0);

      // Flexible Date Parser
      final d1 = HeaderAutoMapper.parseFlexibleDate('2026-10-15');
      expect(d1?.year, 2026);
      expect(d1?.month, 10);
      expect(d1?.day, 15);

      final d2 = HeaderAutoMapper.parseFlexibleDate('15-Oct-26');
      expect(d2?.year, 2026);
      expect(d2?.month, 10);
      expect(d2?.day, 15);

      final d3 = HeaderAutoMapper.parseFlexibleDate('15/10/2026');
      expect(d3?.year, 2026);
      expect(d3?.month, 10);
      expect(d3?.day, 15);
    });

    // Component C: Staging & Quarantine
    test('Row staging flags valid rows and quarantines broken rows with raw content in notes', () {
      final rows = [
        ['2026-10-15', '84500', '42.5', '106.25', 'Shell'],
        ['INVALID_DATE', '84600', '40.0', '100.00', 'BP'],
        ['2026-10-18', '-500', '45.0', '110.00', 'Chevron'],
      ];
      final mappings = [
        FuelField.date,
        FuelField.odometer,
        FuelField.fuelVolume,
        FuelField.totalCost,
        FuelField.gasStation,
      ];

      final staged = HeaderAutoMapper.stageRows(
        dataRows: rows,
        columnMappings: mappings,
      );

      expect(staged.length, 3);

      // Row 1: Valid
      expect(staged[0].isValid, isTrue);
      expect(staged[0].odometer, 84500);
      expect(staged[0].fuelAmount, 42.5);
      expect(staged[0].totalPrice, 106.25);
      expect(staged[0].gasStation, 'Shell');

      // Row 2: Invalid Date -> Quarantined
      expect(staged[1].isValid, isFalse);
      expect(staged[1].validationError, contains('date'));
      expect(staged[1].notes, contains('Raw Date: INVALID_DATE'));

      // Row 3: Negative Odometer -> Quarantined
      expect(staged[2].isValid, isFalse);
      expect(staged[2].validationError, contains('odometer'));
    });

    // Component D: Database Atomic Batch Insert
    test('importSpreadsheetRecordsBatch commits records atomically to encrypted storage', () async {
      final appState = FuelAppState(customStorageDir: tempDir, autoLoad: false);
      final v = Vehicle(id: 'v_atomic', name: 'AtomicCar', type: VehicleType.compact, brand: 'Honda', owner: 'Sam');
      await appState.addVehicle(v);

      final records = [
        FuelRecord(
          id: 'rec_s1',
          vehicleId: 'v_atomic',
          dateTime: DateTime(2026, 10, 15),
          odometer: 60000,
          fuelAmount: 40,
          totalPrice: 80,
          gasStation: 'Shell',
        ),
        FuelRecord(
          id: 'rec_s2',
          vehicleId: 'v_atomic',
          dateTime: DateTime(2026, 10, 20),
          odometer: 60500,
          fuelAmount: 42,
          totalPrice: 84,
          gasStation: 'Chevron',
        ),
      ];

      final count = await appState.importSpreadsheetRecordsBatch(records);
      expect(count, 2);
      expect(appState.allRecords.length, 2);
      expect(appState.allRecords.first.gasStation, 'Shell');
      expect(appState.allRecords.last.gasStation, 'Chevron');

      // Verify encrypted file exists on disk
      final encFile = File('${tempDir.path}/records.enc');
      expect(encFile.existsSync(), isTrue);
      expect(encFile.lengthSync(), greaterThan(0));

      // Verify audit log has batch import record
      final auditFile = File('${tempDir.path}/audit_logs.txt');
      expect(auditFile.existsSync(), isTrue);
      expect(auditFile.readAsStringSync(), contains('Atomic spreadsheet batch import: committed 2 records'));
    });
  });
}
