import 'dart:math';

/// Canonical field types for fuel spreadsheet mapping.
enum FuelField {
  date('Date'),
  odometer('Odometer'),
  fuelVolume('Fuel Volume'),
  pricePerUnit('Price Per Unit'),
  totalCost('Total Cost'),
  gasStation('Gas Station'),
  fuelType('Fuel Grade'),
  isFullTank('Full Tank?'),
  notes('Notes'),
  ignore('Ignore Column');

  final String label;
  const FuelField(this.label);
}

/// Staged record representation parsed from a spreadsheet row.
class StagedFuelRecord {
  final int rowIndex;
  DateTime? dateTime;
  double? odometer;
  double? fuelAmount;
  double? totalPrice;
  double? pricePerUnit;
  String gasStation;
  String fuelType;
  bool isFullTank;
  String notes;
  bool isValid;
  String? validationError;
  final List<String> rawRow;

  StagedFuelRecord({
    required this.rowIndex,
    this.dateTime,
    this.odometer,
    this.fuelAmount,
    this.totalPrice,
    this.pricePerUnit,
    this.gasStation = '',
    this.fuelType = 'Regular (87)',
    this.isFullTank = true,
    this.notes = '',
    this.isValid = true,
    this.validationError,
    required this.rawRow,
  });

  StagedFuelRecord copyWith({
    DateTime? dateTime,
    double? odometer,
    double? fuelAmount,
    double? totalPrice,
    double? pricePerUnit,
    String? gasStation,
    String? fuelType,
    bool? isFullTank,
    String? notes,
    bool? isValid,
    String? validationError,
  }) {
    return StagedFuelRecord(
      rowIndex: rowIndex,
      dateTime: dateTime ?? this.dateTime,
      odometer: odometer ?? this.odometer,
      fuelAmount: fuelAmount ?? this.fuelAmount,
      totalPrice: totalPrice ?? this.totalPrice,
      pricePerUnit: pricePerUnit ?? this.pricePerUnit,
      gasStation: gasStation ?? this.gasStation,
      fuelType: fuelType ?? this.fuelType,
      isFullTank: isFullTank ?? this.isFullTank,
      notes: notes ?? this.notes,
      isValid: isValid ?? this.isValid,
      validationError: validationError ?? this.validationError,
      rawRow: rawRow,
    );
  }
}

/// Auto-mapping engine that uses nickname dictionaries, math rules, and cleaning heuristics.
class HeaderAutoMapper {
  /// Header nickname dictionary matching normalized column headers
  static const Map<FuelField, List<String>> nicknameDictionary = {
    FuelField.date: [
      'date', 'time', 'day', 'timestamp', 'when', 'fill date', 'transaction date',
      'refuel date', 'datum', 'entry date', 'log date'
    ],
    FuelField.odometer: [
      'odometer', 'odo', 'mileage', 'km', 'kms', 'miles', 'mi', 'distance',
      'dist', 'kilometer', 'kilometre', 'reading', 'readings', 'dash', 'counter'
    ],
    FuelField.fuelVolume: [
      'fuelvolume', 'fuel volume', 'liters', 'litres', 'gallons', 'gal', 'gals', 'l', 'ltr', 'ltrs', 'fuel',
      'volume', 'vol', 'qty', 'quantity', 'amount', 'petrol', 'diesel', 'gas',
      'fuel amount', 'pumped', 'dispensed'
    ],
    FuelField.pricePerUnit: [
      'priceperunit', 'price per unit', 'cost per liter', 'cost per litre', 'cost per gallon', 'cost per unit',
      'price per liter', 'price per litre', 'price per gallon',
      'unit price', 'rate', 'cost/l', 'cost l', 'price/l', 'price l',
      'price/gal', 'price gal', 'cost/gal', 'cost gal', 'ppg', 'ppl',
      'price', 'cost/unit', 'price/unit'
    ],
    FuelField.totalCost: [
      'totalcost', 'total cost', 'total price', 'amount paid', 'total amount', 'net amount',
      'total', 'cost', 'paid', 'expense', 'bill', 'spent', 'charge'
    ],
    FuelField.gasStation: [
      'stationname', 'station name', 'station', 'gas station', 'petrol station', 'vendor', 'brand',
      'location', 'pump', 'store'
    ],
    FuelField.fuelType: [
      'fuel grade', 'fuel type', 'grade', 'octane', 'type', 'fuel category'
    ],
    FuelField.isFullTank: [
      'full', 'full tank', 'filled tank', 'is full', 'topped up', 'full?'
    ],
    FuelField.notes: [
      'notes', 'note', 'comments', 'remarks', 'memo', 'description', 'details'
    ],
  };

  /// Normalizes header string for dictionary lookup.
  static String normalizeHeader(String header) {
    return header
        .toLowerCase()
        .replaceAll(RegExp(r'[\(\)\[\]\{\}\/\\:,\-_]+'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  /// Auto-detects the mapping for each column header.
  static List<FuelField> autoDetectMappings({
    required List<String> headers,
    required List<List<String>> sampleRows,
  }) {
    final List<FuelField> mappings = List.filled(headers.length, FuelField.ignore);
    final Set<FuelField> assignedFields = {};

    // Flatten and sort synonyms by length descending (longest phrase first)
    // Ensures specific multi-word phrases ("cost per liter", "amount paid")
    // match before single generic words ("cost", "amount").
    final allSynonyms = <MapEntry<FuelField, String>>[];
    for (final entry in nicknameDictionary.entries) {
      for (final syn in entry.value) {
        allSynonyms.add(MapEntry(entry.key, normalizeHeader(syn)));
      }
    }
    allSynonyms.sort((a, b) => b.value.length.compareTo(a.value.length));

    // 1. First Pass: Match by Header Nickname Dictionary
    for (int col = 0; col < headers.length; col++) {
      final norm = normalizeHeader(headers[col]);
      if (norm.isEmpty) continue;

      FuelField? bestMatch;

      // Exact match
      for (final item in allSynonyms) {
        if (assignedFields.contains(item.key)) continue;
        if (norm == item.value) {
          bestMatch = item.key;
          break;
        }
      }

      // Word boundary match (longest synonym first)
      if (bestMatch == null) {
        for (final item in allSynonyms) {
          if (assignedFields.contains(item.key)) continue;
          final syn = item.value;
          if (norm.startsWith('$syn ') || norm.endsWith(' $syn') || norm.contains(' $syn ')) {
            bestMatch = item.key;
            break;
          }
        }
      }

      // Substring match for longer synonyms (>= 3 chars)
      if (bestMatch == null) {
        for (final item in allSynonyms) {
          if (assignedFields.contains(item.key)) continue;
          final syn = item.value;
          if (syn.length >= 3 && norm.contains(syn)) {
            bestMatch = item.key;
            break;
          }
        }
      }

      if (bestMatch != null) {
        mappings[col] = bestMatch;
        assignedFields.add(bestMatch);
      }
    }

    // 2. Second Pass: Math Fallback Rule for Missing Financial/Volume Columns
    // If headers are missing/unrecognized, find numbers A, B, C where |A * B - C| <= 0.05
    final needsMathDetection = !assignedFields.contains(FuelField.totalCost) ||
        !assignedFields.contains(FuelField.fuelVolume) ||
        !assignedFields.contains(FuelField.pricePerUnit);

    if (needsMathDetection && sampleRows.isNotEmpty) {
      _applyMathRuleFallback(headers, sampleRows, mappings, assignedFields);
    }

    // 3. Third Pass: Odometer Heuristic for Unassigned Columns
    // If odometer is unmapped, look for column with large consistent numbers (> 1,000)
    if (!assignedFields.contains(FuelField.odometer) && sampleRows.isNotEmpty) {
      _applyOdometerHeuristic(sampleRows, mappings, assignedFields);
    }

    // 4. Fourth Pass: Date Heuristic for Unassigned Columns
    if (!assignedFields.contains(FuelField.date) && sampleRows.isNotEmpty) {
      _applyDateHeuristic(sampleRows, mappings, assignedFields);
    }

    return mappings;
  }

  /// Applies math rule: A * B ~ C (within 0.05 tolerance).
  /// Suggests C as totalCost, smaller of A/B as pricePerUnit, and larger of A/B as fuelVolume.
  static void _applyMathRuleFallback(
    List<String> headers,
    List<List<String>> sampleRows,
    List<FuelField> mappings,
    Set<FuelField> assignedFields,
  ) {
    // Find unmapped numeric column indices
    final candidateCols = <int>[];
    for (int col = 0; col < headers.length; col++) {
      if (mappings[col] == FuelField.ignore) {
        candidateCols.add(col);
      }
    }
    if (candidateCols.length < 2) return;

    // Inspect sample rows (up to 5 rows)
    final rowLimit = min(5, sampleRows.length);

    for (int i = 0; i < candidateCols.length; i++) {
      for (int j = i + 1; j < candidateCols.length; j++) {
        for (int k = 0; k < candidateCols.length; k++) {
          if (k == i || k == j) continue;

          final colA = candidateCols[i];
          final colB = candidateCols[j];
          final colC = candidateCols[k];

          int matchesCount = 0;
          int testedCount = 0;

          for (int r = 0; r < rowLimit; r++) {
            final row = sampleRows[r];
            if (colA >= row.length || colB >= row.length || colC >= row.length) continue;

            final valA = cleanNumber(row[colA]);
            final valB = cleanNumber(row[colB]);
            final valC = cleanNumber(row[colC]);

            if (valA != null && valB != null && valC != null && valA > 0 && valB > 0 && valC > 0) {
              testedCount++;
              if ((valA * valB - valC).abs() <= 0.05) {
                matchesCount++;
              }
            }
          }

          if (testedCount >= 1 && matchesCount == testedCount) {
            // Found triplet: A * B = C
            // Determine which is pricePerUnit vs fuelVolume by average value (unit price is typically smaller)
            final valA = cleanNumber(sampleRows[0][colA]) ?? 0;
            final valB = cleanNumber(sampleRows[0][colB]) ?? 0;

            final priceCol = valA <= valB ? colA : colB;
            final volCol = valA <= valB ? colB : colA;
            final costCol = colC;

            if (!assignedFields.contains(FuelField.totalCost)) {
              mappings[costCol] = FuelField.totalCost;
              assignedFields.add(FuelField.totalCost);
            }
            if (!assignedFields.contains(FuelField.fuelVolume)) {
              mappings[volCol] = FuelField.fuelVolume;
              assignedFields.add(FuelField.fuelVolume);
            }
            if (!assignedFields.contains(FuelField.pricePerUnit)) {
              mappings[priceCol] = FuelField.pricePerUnit;
              assignedFields.add(FuelField.pricePerUnit);
            }
            return;
          }
        }
      }
    }
  }

  /// Odometer heuristic: identifies 5-6 digit values across rows
  static void _applyOdometerHeuristic(
    List<List<String>> sampleRows,
    List<FuelField> mappings,
    Set<FuelField> assignedFields,
  ) {
    for (int col = 0; col < mappings.length; col++) {
      if (mappings[col] != FuelField.ignore) continue;

      int odoMatches = 0;
      for (final row in sampleRows) {
        if (col >= row.length) continue;
        final val = cleanNumber(row[col]);
        if (val != null && val >= 1000 && val <= 2000000) {
          odoMatches++;
        }
      }
      if (odoMatches >= max(1, (sampleRows.length * 0.6).floor())) {
        mappings[col] = FuelField.odometer;
        assignedFields.add(FuelField.odometer);
        break;
      }
    }
  }

  /// Date heuristic: tests unmapped columns against date parser
  static void _applyDateHeuristic(
    List<List<String>> sampleRows,
    List<FuelField> mappings,
    Set<FuelField> assignedFields,
  ) {
    for (int col = 0; col < mappings.length; col++) {
      if (mappings[col] != FuelField.ignore) continue;

      int dateMatches = 0;
      for (final row in sampleRows) {
        if (col >= row.length) continue;
        if (parseFlexibleDate(row[col]) != null) {
          dateMatches++;
        }
      }
      if (dateMatches >= max(1, (sampleRows.length * 0.6).floor())) {
        mappings[col] = FuelField.date;
        assignedFields.add(FuelField.date);
        break;
      }
    }
  }

  /// Strips currency symbols, unit suffixes, and formatting noise to parse valid double.
  static double? cleanNumber(String raw) {
    if (raw.trim().isEmpty) return null;

    var cleaned = raw.trim();
    // Strip common currency symbols and codes
    cleaned = cleaned.replaceAll(RegExp(r'(?:[\$€£₹¥]|c\$|a\$|aed|rs\.?|inr|usd|cad|aud|gbp|eur|sar|qar|kwd|omr|bhd)', caseSensitive: false), '');
    // Strip common units
    cleaned = cleaned.replaceAll(RegExp(r'\b(?:liters?|litres?|ltrs?|lt|l|gallons?|gals?|gal|kms?|kilometers?|kilometres?|miles?|mi)\b', caseSensitive: false), '');
    // Remove unwanted chars except digits, comma, period, minus
    cleaned = cleaned.replaceAll(RegExp(r'[^\d.,-]'), '').trim();

    if (cleaned.isEmpty) return null;

    // Handle European comma decimals vs thousand commas
    if (cleaned.contains(',') && !cleaned.contains('.')) {
      final parts = cleaned.split(',');
      if (parts.length == 2 && parts[1].length <= 2) {
        cleaned = '${parts[0]}.${parts[1]}';
      } else {
        cleaned = cleaned.replaceAll(',', '');
      }
    } else {
      cleaned = cleaned.replaceAll(',', '');
    }

    return double.tryParse(cleaned);
  }

  /// Multi-format flexible date parser supporting:
  /// - YYYY-MM-DD, YYYY/MM/DD
  /// - DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY
  /// - MM/DD/YYYY
  /// - DD-MMM-YY, DD-MMM-YYYY (e.g. 15-Oct-26, 15-Oct-2026)
  /// - ISO 8601 strings
  static DateTime? parseFlexibleDate(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;

    // 1. Direct DateTime.tryParse (ISO 8601: YYYY-MM-DD)
    final direct = DateTime.tryParse(text);
    if (direct != null && direct.year >= 1990 && direct.year <= 2100) {
      return DateTime(direct.year, direct.month, direct.day, 12);
    }

    // 2. DD-MMM-YY or DD-MMM-YYYY (e.g. 15-Oct-26 or 15-Oct-2026)
    final abbrMatch = RegExp(r'\b(\d{1,2})[-/\s]([A-Za-z]{3,9})[-/\s](\d{2,4})\b').firstMatch(text);
    if (abbrMatch != null) {
      try {
        final day = int.parse(abbrMatch.group(1)!);
        final monthStr = abbrMatch.group(2)!.toLowerCase();
        var year = int.parse(abbrMatch.group(3)!);
        if (year < 100) year += 2000;

        final month = _monthNameToInt(monthStr);
        if (month != null) {
          return DateTime(year, month, day, 12);
        }
      } catch (_) {}
    }

    // 3. Delimited numeric dates: YYYY/MM/DD, DD/MM/YYYY, MM/DD/YYYY
    final numMatch = RegExp(r'\b(\d{1,4})[-/.](\d{1,2})[-/.](\d{1,4})\b').firstMatch(text);
    if (numMatch != null) {
      try {
        final p1 = int.parse(numMatch.group(1)!);
        final p2 = int.parse(numMatch.group(2)!);
        final p3 = int.parse(numMatch.group(3)!);

        if (p1 >= 1990 && p1 <= 2100) {
          // YYYY-MM-DD
          return DateTime(p1, p2, p3, 12);
        } else if (p3 >= 1990 || p3 < 100) {
          // Either DD/MM/YYYY or MM/DD/YYYY
          var year = p3;
          if (year < 100) year += 2000;

          if (p1 > 12 && p2 <= 12) {
            // Unambiguous DD/MM/YYYY
            return DateTime(year, p2, p1, 12);
          } else if (p2 > 12 && p1 <= 12) {
            // Unambiguous MM/DD/YYYY
            return DateTime(year, p1, p2, 12);
          } else {
            // Default to international DD/MM/YYYY
            return DateTime(year, p2, p1, 12);
          }
        }
      } catch (_) {}
    }

    return null;
  }

  static int? _monthNameToInt(String m) {
    const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    for (int i = 0; i < months.length; i++) {
      if (m.startsWith(months[i])) return i + 1;
    }
    return null;
  }

  /// Parses all raw rows into staged objects, applies mapping, flags validation,
  /// and attaches any unparseable raw data to notes.
  static List<StagedFuelRecord> stageRows({
    required List<List<String>> dataRows,
    required List<FuelField> columnMappings,
    String defaultFuelType = 'Regular (87)',
    String defaultStation = 'Shell',
  }) {
    final List<StagedFuelRecord> staged = [];

    for (int r = 0; r < dataRows.length; r++) {
      final row = dataRows[r];
      DateTime? date;
      double? odometer;
      double? fuelVolume;
      double? pricePerUnit;
      double? totalCost;
      String station = defaultStation;
      String grade = defaultFuelType;
      bool isFull = true;
      final List<String> notesParts = [];
      final List<String> unmappedResidual = [];

      for (int c = 0; c < row.length && c < columnMappings.length; c++) {
        final cell = row[c].trim();
        if (cell.isEmpty) continue;

        switch (columnMappings[c]) {
          case FuelField.date:
            date = parseFlexibleDate(cell);
            if (date == null) unmappedResidual.add('Raw Date: $cell');
            break;
          case FuelField.odometer:
            odometer = cleanNumber(cell);
            if (odometer == null) unmappedResidual.add('Raw Odo: $cell');
            break;
          case FuelField.fuelVolume:
            fuelVolume = cleanNumber(cell);
            if (fuelVolume == null) unmappedResidual.add('Raw Vol: $cell');
            break;
          case FuelField.pricePerUnit:
            pricePerUnit = cleanNumber(cell);
            if (pricePerUnit == null) unmappedResidual.add('Raw PPU: $cell');
            break;
          case FuelField.totalCost:
            totalCost = cleanNumber(cell);
            if (totalCost == null) unmappedResidual.add('Raw Cost: $cell');
            break;
          case FuelField.gasStation:
            if (cell.isNotEmpty) station = cell;
            break;
          case FuelField.fuelType:
            if (cell.isNotEmpty) grade = cell;
            break;
          case FuelField.isFullTank:
            final lower = cell.toLowerCase();
            isFull = !lower.contains('no') && !lower.contains('part') && !lower.contains('false');
            break;
          case FuelField.notes:
            notesParts.add(cell);
            break;
          case FuelField.ignore:
            unmappedResidual.add(cell);
            break;
        }
      }

      // If pricePerUnit and fuelVolume exist but totalCost is missing, compute it
      if (totalCost == null && fuelVolume != null && pricePerUnit != null) {
        totalCost = double.parse((fuelVolume * pricePerUnit).toStringAsFixed(2));
      }
      // If totalCost and fuelVolume exist but pricePerUnit is missing, compute it
      if (pricePerUnit == null && totalCost != null && fuelVolume != null && fuelVolume > 0) {
        pricePerUnit = double.parse((totalCost / fuelVolume).toStringAsFixed(3));
      }
      // If totalCost and pricePerUnit exist but fuelVolume is missing, compute it
      if (fuelVolume == null && totalCost != null && pricePerUnit != null && pricePerUnit > 0) {
        fuelVolume = double.parse((totalCost / pricePerUnit).toStringAsFixed(2));
      }

      // Assemble final notes
      if (unmappedResidual.isNotEmpty) {
        notesParts.add('Import: ${unmappedResidual.join(', ')}');
      }
      final finalNotes = notesParts.join('; ');

      // Validation Check
      bool isValid = true;
      String? error;

      if (date == null) {
        isValid = false;
        error = 'Missing or invalid date';
      } else if (odometer == null || odometer < 0) {
        isValid = false;
        error = 'Invalid odometer reading';
      } else if (fuelVolume == null || fuelVolume <= 0) {
        isValid = false;
        error = 'Invalid fuel quantity';
      } else if (totalCost == null || totalCost < 0) {
        isValid = false;
        error = 'Invalid total cost';
      }

      staged.add(StagedFuelRecord(
        rowIndex: r + 1,
        dateTime: date,
        odometer: odometer,
        fuelAmount: fuelVolume,
        totalPrice: totalCost,
        pricePerUnit: pricePerUnit,
        gasStation: station,
        fuelType: grade,
        isFullTank: isFull,
        notes: finalNotes,
        isValid: isValid,
        validationError: error,
        rawRow: row,
      ));
    }

    return staged;
  }
}
