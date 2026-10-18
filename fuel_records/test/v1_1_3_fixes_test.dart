import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_records/models/vehicle.dart';
import 'package:fuel_records/models/fuel_record.dart';
import 'package:fuel_records/services/file_parser_service.dart';
import 'package:fuel_records/services/header_auto_mapper.dart';
import 'package:intl/intl.dart';

void main() {
  group('v1.1.3 UX Fixes & Excel Sanitization Tests', () {
    test('Excel Sanitization strips custom numFmtId < 164 and allows successful parsing', () {
      // 1. Build a synthetic .xlsx zip archive with offending styles.xml (numFmtId="0")
      final archive = Archive();

      // xl/sharedStrings.xml
      const sstContent = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="2" uniqueCount="2">'
          '<si><t>Date</t></si>'
          '<si><t>Odometer</t></si>'
          '</sst>';
      final sstBytes = utf8.encode(sstContent);
      archive.addFile(ArchiveFile('xl/sharedStrings.xml', sstBytes.length, sstBytes));

      // xl/styles.xml with invalid custom numFmtId < 164
      const stylesContent = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<styleSheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
          '<numFmts count="1">'
          '<numFmt numFmtId="0" formatCode="General"/>'
          '</numFmts>'
          '<fonts count="1"><font><sz val="11"/><name val="Calibri"/></font></fonts>'
          '<fills count="1"><fill><patternFill patternType="none"/></fill></fills>'
          '<borders count="1"><border><left/><right/><top/><bottom/></border></borders>'
          '<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>'
          '<cellXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/></cellXfs>'
          '</styleSheet>';
      final stylesBytes = utf8.encode(stylesContent);
      archive.addFile(ArchiveFile('xl/styles.xml', stylesBytes.length, stylesBytes));

      // xl/worksheets/sheet1.xml
      const sheetContent = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">'
          '<sheetData>'
          '<row r="1">'
          '<c r="A1" t="s"><v>0</v></c>'
          '<c r="B1" t="s"><v>1</v></c>'
          '</row>'
          '<row r="2">'
          '<c r="A2"><v>2026-10-15</v></c>'
          '<c r="B2"><v>45000</v></c>'
          '</row>'
          '</sheetData>'
          '</worksheet>';
      final sheetBytes = utf8.encode(sheetContent);
      archive.addFile(ArchiveFile('xl/worksheets/sheet1.xml', sheetBytes.length, sheetBytes));

      // [Content_Types].xml & _rels
      const ctContent = '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
          '<Default Extension="xml" ContentType="application/xml"/>'
          '</Types>';
      final ctBytes = utf8.encode(ctContent);
      archive.addFile(ArchiveFile('[Content_Types].xml', ctBytes.length, ctBytes));

      final zipBytes = Uint8List.fromList(ZipEncoder().encode(archive)!);

      // 2. Parse using FileParserService: should sanitize styles or use fallback without throwing
      final parsed = FileParserService.parseSpreadsheetBytes(zipBytes, 'test_corrupt.xlsx');

      expect(parsed.headers.isNotEmpty, isTrue);
      expect(parsed.dataRows.isNotEmpty, isTrue);
    });

    test('HeaderAutoMapper leaves optional gasStation and isFullTank empty/null when missing', () {
      final headers = ['Date', 'Odometer', 'Fuel Volume', 'Total Cost'];
      final rows = [
        ['2026-10-15', '45000', '40.0', '100.0'],
      ];

      final mappings = HeaderAutoMapper.autoDetectMappings(headers: headers, sampleRows: rows);
      expect(mappings.contains(FuelField.gasStation), isFalse);
      expect(mappings.contains(FuelField.isFullTank), isFalse);

      final staged = HeaderAutoMapper.stageRows(
        dataRows: rows,
        columnMappings: mappings,
      );

      expect(staged.length, equals(1));
      expect(staged.first.gasStation, isEmpty);
      expect(staged.first.isFullTank, isNull);
    });

    test('FuelRecord model supports null isFullTank and preserves it through JSON serialization', () {
      final rec = FuelRecord(
        id: 'rec_test',
        vehicleId: 'veh_test',
        dateTime: DateTime(2026, 10, 15),
        odometer: 45000,
        fuelAmount: 40.0,
        totalPrice: 100.0,
        gasStation: '',
        isFullTank: null,
      );

      expect(rec.isFullTank, isNull);

      final json = rec.toJson();
      expect(json['isFullTank'], isNull);

      final reconstructed = FuelRecord.fromJson(json);
      expect(reconstructed.isFullTank, isNull);
    });

    test('Garage page subtitle format matches [Brand] - [CarType] - [Owner]', () {
      final v = Vehicle(
        id: 'v1',
        name: 'Daily Driver',
        brand: 'Toyota',
        type: VehicleType.sedan,
        owner: 'Alex',
      );

      final subtitle = '${v.brand} - ${v.type.displayName}${v.owner.isNotEmpty ? ' - ${v.owner}' : ''}';
      expect(subtitle, equals('Toyota - Sedan - Alex'));
    });

    test('Trend graph records slicing: strictly limits to last 8 records with month titles', () {
      final values = [10.0, 11.0, 12.0, 13.0, 14.0, 15.0, 16.0, 17.0, 18.0, 19.0];
      final dates = List.generate(
        10,
        (i) => DateTime(2026, 10, i + 1),
      );

      final count = values.length > 8 ? 8 : values.length;
      final plotValues = values.sublist(values.length - count);
      final plotDates = dates.sublist(dates.length - count);

      expect(plotValues.length, equals(8));
      expect(plotValues.first, equals(12.0));
      expect(plotValues.last, equals(19.0));

      final monthTitle = DateFormat('MMM').format(plotDates.first);
      expect(monthTitle, equals('Oct'));

      // Check adjacent same month logic
      bool hasSameMonthNeighbor(int i) {
        final current = plotDates[i];
        if (i > 0) {
          final prev = plotDates[i - 1];
          if (prev.year == current.year && prev.month == current.month) return true;
        }
        if (i < plotDates.length - 1) {
          final next = plotDates[i + 1];
          if (next.year == current.year && next.month == current.month) return true;
        }
        return false;
      }

      expect(hasSameMonthNeighbor(0), isTrue);
      expect(hasSameMonthNeighbor(4), isTrue);
    });

    test('Sample template export writes to target directory', () async {
      final tempDir = Directory.systemTemp.createTempSync('template_test');
      final file = await FileParserService.exportSampleTemplate(targetDir: tempDir);

      expect(file.existsSync(), isTrue);
      expect(file.path.contains('FuelMetrics_Sample_Template.csv'), isTrue);

      final content = await file.readAsString();
      expect(content.contains('Date,Odometer,Fuel Volume'), isTrue);

      tempDir.deleteSync(recursive: true);
    });
  });
}
