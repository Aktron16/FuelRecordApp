import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import '../models/vehicle.dart';

/// Parsed tabular output from a raw file or spreadsheet.
class RawTableData {
  final String sourceFileName;
  final List<String> headers;
  final List<List<String>> dataRows;
  final int skippedHeaderRowsCount;

  RawTableData({
    required this.sourceFileName,
    required this.headers,
    required this.dataRows,
    this.skippedHeaderRowsCount = 0,
  });

  bool get isEmpty => headers.isEmpty && dataRows.isEmpty;
  int get totalRows => dataRows.length;
  int get totalColumns => headers.length;
}

/// Universal file reader for .csv, .tsv, and .xlsx files, plus official template generation.
class FileParserService {
  /// Canonical database header names
  static const List<String> canonicalHeaders = [
    'Date',
    'Odometer',
    'Fuel Volume',
    'Price Per Unit',
    'Total Cost',
    'Gas Station',
    'Fuel Grade',
    'Full Tank',
    'Notes',
  ];

  /// Generates and saves a clean, official sample template CSV file.
  /// Row 1: Canonical database headers.
  /// Row 2: One realistic example row of fuel data.
  static Future<File> exportSampleTemplate({Vehicle? vehicle, Directory? targetDir}) async {
    final dir = targetDir ?? await _getTemplatesDirectory();
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final distUnit = vehicle?.unitDistance ?? 'km';
    final volUnit = vehicle?.unitVolume ?? 'L';
    final curr = vehicle?.currency ?? '\$';
    final grade = vehicle?.fuelType ?? 'Regular (87)';

    final templateRows = [
      canonicalHeaders,
      [
        '2026-10-15',
        '84500',
        '42.50',
        '2.50',
        '106.25',
        'Shell',
        grade,
        'Yes',
        'Commute ($distUnit, $volUnit, $curr)',
      ],
    ];

    final csvContent = const ListToCsvConverter().convert(templateRows);
    final filePath = '${dir.path}/FuelMetrics_Sample_Template.csv';
    final file = File(filePath);
    await file.writeAsString(csvContent, flush: true);
    return file;
  }

  /// Parses spreadsheet bytes (.csv, .tsv, or .xlsx) into structured [RawTableData].
  static RawTableData parseSpreadsheetBytes(
    Uint8List bytes,
    String fileName, {
    int sheetIndex = 0,
  }) {
    final lowerName = fileName.toLowerCase();
    List<List<String>> rawRows = [];

    if (lowerName.endsWith('.xlsx') || lowerName.endsWith('.xlsm')) {
      rawRows = _parseExcelBytes(bytes, sheetIndex: sheetIndex);
    } else {
      // Decode text as UTF-8 with latin1 fallback
      String textContent;
      try {
        textContent = utf8.decode(bytes);
      } catch (_) {
        textContent = latin1.decode(bytes);
      }
      final isTsv = lowerName.endsWith('.tsv') || (!textContent.contains(',') && textContent.contains('\t'));
      rawRows = parseTextToRows(textContent, isTsv: isTsv);
    }

    return _extractTableWithAutoHeaderSkip(rawRows, fileName);
  }

  /// Parses plain multiline text (CSV or TSV) into a 2D string matrix.
  static List<List<String>> parseTextToRows(String text, {bool isTsv = false}) {
    final delimiter = isTsv ? '\t' : ',';
    final converter = CsvToListConverter(
      fieldDelimiter: delimiter,
      shouldParseNumbers: false,
      eol: '\n',
    );

    // Normalize Windows CRLF to LF
    final normalized = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final result = converter.convert(normalized);

    // Cast and trim all cells
    return result.map((row) {
      return row.map((cell) => cell?.toString().trim() ?? '').toList();
    }).toList();
  }

  /// Parses Microsoft Excel (.xlsx) file bytes into 2D string matrix.
  static List<List<String>> _parseExcelBytes(Uint8List bytes, {int sheetIndex = 0}) {
    final excel = Excel.decodeBytes(bytes);
    if (excel.tables.isEmpty) return [];

    // Select target sheet: default to first non-empty sheet
    String? targetSheetName;
    final sheetNames = excel.tables.keys.toList();
    if (sheetIndex >= 0 && sheetIndex < sheetNames.length) {
      targetSheetName = sheetNames[sheetIndex];
    } else {
      for (final name in sheetNames) {
        final table = excel.tables[name];
        if (table != null && table.maxRows > 0) {
          targetSheetName = name;
          break;
        }
      }
    }

    if (targetSheetName == null) return [];
    final sheet = excel.tables[targetSheetName];
    if (sheet == null) return [];

    final List<List<String>> rows = [];
    for (final row in sheet.rows) {
      final List<String> stringRow = [];
      for (final cell in row) {
        if (cell == null || cell.value == null) {
          stringRow.add('');
        } else {
          stringRow.add(cell.value.toString().trim());
        }
      }
      rows.add(stringRow);
    }
    return rows;
  }

  /// Automatically skips empty rows or top title banners until a row with at least 3 populated columns is found.
  static RawTableData _extractTableWithAutoHeaderSkip(List<List<String>> rawRows, String fileName) {
    if (rawRows.isEmpty) {
      return RawTableData(sourceFileName: fileName, headers: [], dataRows: []);
    }

    int headerIndex = -1;
    for (int i = 0; i < rawRows.length; i++) {
      final populatedCount = rawRows[i].where((cell) => cell.trim().isNotEmpty).length;
      if (populatedCount >= 3) {
        headerIndex = i;
        break;
      }
    }

    // Fallback: if no row has >= 3 columns, find first row with at least 1 column
    if (headerIndex == -1) {
      for (int i = 0; i < rawRows.length; i++) {
        if (rawRows[i].any((c) => c.trim().isNotEmpty)) {
          headerIndex = i;
          break;
        }
      }
    }

    if (headerIndex == -1) {
      return RawTableData(sourceFileName: fileName, headers: [], dataRows: []);
    }

    final headers = rawRows[headerIndex];
    final dataRows = <List<String>>[];

    // Normalize column length of all subsequent rows to match headers length
    for (int i = headerIndex + 1; i < rawRows.length; i++) {
      final row = rawRows[i];
      // Skip completely blank rows
      if (row.every((cell) => cell.trim().isEmpty)) continue;

      if (row.length < headers.length) {
        final padded = List<String>.from(row);
        while (padded.length < headers.length) {
          padded.add('');
        }
        dataRows.add(padded);
      } else if (row.length > headers.length) {
        dataRows.add(row.sublist(0, headers.length));
      } else {
        dataRows.add(row);
      }
    }

    return RawTableData(
      sourceFileName: fileName,
      headers: headers,
      dataRows: dataRows,
      skippedHeaderRowsCount: headerIndex,
    );
  }

  static Future<Directory> _getTemplatesDirectory() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final tDir = Directory('${docsDir.path}/FuelMetricsData/Templates');
      if (!tDir.existsSync()) {
        tDir.createSync(recursive: true);
      }
      return tDir;
    } catch (_) {
      final tDir = Directory('${Directory.systemTemp.path}/FuelMetricsData/Templates');
      if (!tDir.existsSync()) {
        tDir.createSync(recursive: true);
      }
      return tDir;
    }
  }
}

