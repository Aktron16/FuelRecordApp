/// Draft representation of a parsed fuel record prior to user confirmation.
class ParsedRecordDraft {
  DateTime dateTime;
  double? odometer;
  double? fuelAmount;
  double? totalPrice;
  String gasStation;
  String fuelType;
  bool isFullTank;
  String notes;

  ParsedRecordDraft({
    required this.dateTime,
    this.odometer,
    this.fuelAmount,
    this.totalPrice,
    this.gasStation = '',
    this.fuelType = 'Regular (87)',
    this.isFullTank = true,
    this.notes = '',
  });

  ParsedRecordDraft copyWith({
    DateTime? dateTime,
    double? odometer,
    double? fuelAmount,
    double? totalPrice,
    String? gasStation,
    String? fuelType,
    bool? isFullTank,
    String? notes,
  }) {
    return ParsedRecordDraft(
      dateTime: dateTime ?? this.dateTime,
      odometer: odometer ?? this.odometer,
      fuelAmount: fuelAmount ?? this.fuelAmount,
      totalPrice: totalPrice ?? this.totalPrice,
      gasStation: gasStation ?? this.gasStation,
      fuelType: fuelType ?? this.fuelType,
      isFullTank: isFullTank ?? this.isFullTank,
      notes: notes ?? this.notes,
    );
  }
}

/// Robust, zero-dependency offline parser that extracts fuel record entities
/// from free-form, unstructured text using extensive alternate synonym words,
/// regex heuristics, and normalization.
class UnstructuredTextParser {
  static const List<String> knownStations = [
    'Shell', 'Chevron', 'Exxon', 'Mobil', 'BP', 'Costco', 'TotalEnergies', 'Total',
    'Circle K', 'Texaco', 'Speedway', 'ENOC', 'ADNOC', 'IndianOil', 'HP',
    'Bharat Petroleum', 'Wawa', 'Sunoco', 'QuikTrip', 'Marathon', 'Valero',
    'Phillips 66', 'Esso', 'Aral', 'Repsol', 'Caltex', 'Petrobras', 'Sinopec',
    'Petronas', '7-Eleven', 'Pilot', 'Flying J', 'Buc-ee\'s', 'Casey\'s'
  ];

  static const List<String> knownFuelGrades = [
    'Regular (87)', 'Midgrade (89)', 'Premium (93)', 'Super (95)', 'Super (98)',
    'Diesel', 'Biodiesel', 'E85', 'LPG', 'CNG'
  ];

  /// Parses arbitrary raw text (single or multi-line) into a list of cleaned [ParsedRecordDraft]s.
  static List<ParsedRecordDraft> parse(String rawText, {String defaultFuelType = 'Regular (87)'}) {
    final cleaned = rawText.trim();
    if (cleaned.isEmpty) return [];

    final lines = cleaned
        .split(RegExp(r'\r?\n'))
        .map((l) => _cleanWhitespace(l))
        .where((l) => l.isNotEmpty)
        .toList();

    final List<ParsedRecordDraft> results = [];

    if (lines.length > 1) {
      for (final line in lines) {
        final draft = _parseSingleSegment(line, defaultFuelType);
        if (_hasAnyData(draft)) {
          results.add(draft);
        }
      }
    }

    // If multi-line parsing found nothing or text was a single paragraph
    if (results.isEmpty) {
      final draft = _parseSingleSegment(cleaned, defaultFuelType);
      if (_hasAnyData(draft)) {
        results.add(draft);
      }
    }

    return results;
  }

  /// Removes redundant spaces, tabs, and trims string.
  static String _cleanWhitespace(String text) {
    return text.replaceAll(RegExp(r'[\t\v\f\r ]+'), ' ').trim();
  }

  static bool _hasAnyData(ParsedRecordDraft d) {
    return d.odometer != null || d.fuelAmount != null || d.totalPrice != null || d.gasStation.isNotEmpty;
  }

  /// Parses a single segment or line of unstructured text into a [ParsedRecordDraft].
  static ParsedRecordDraft _parseSingleSegment(String rawSegment, String defaultFuelType) {
    String segment = _cleanWhitespace(rawSegment);
    final now = DateTime.now();

    DateTime recordDate = DateTime(now.year, now.month, now.day, 12);
    double? odometer;
    double? fuelAmount;
    double? totalPrice;
    String gasStation = '';
    String fuelType = defaultFuelType;
    bool isFullTank = true;
    String notes = '';

    // 1. Detect Date
    final dateResult = _extractDate(segment);
    if (dateResult != null) {
      recordDate = dateResult.date;
      segment = segment.replaceFirst(dateResult.matchedText, ' ');
      segment = _cleanWhitespace(segment);
    }

    // 2. Detect Full Tank status
    if (RegExp(r'\b(?:partial|not\s+full|half\s+tank|quarter\s+tank)\b', caseSensitive: false).hasMatch(segment)) {
      isFullTank = false;
    } else if (RegExp(r'\b(?:full|full\s+tank|topped\s+up|top\s+off|brimmed|fill\s+up)\b', caseSensitive: false).hasMatch(segment)) {
      isFullTank = true;
    }

    // 3. Detect Gas Station
    final stationResult = _extractGasStation(segment);
    if (stationResult != null) {
      gasStation = stationResult.station;
      segment = segment.replaceFirst(stationResult.matchedText, ' ');
      segment = _cleanWhitespace(segment);
    }

    // 4. Detect Fuel Grade / Type
    final gradeResult = _extractFuelGrade(segment);
    if (gradeResult != null) {
      fuelType = gradeResult.grade;
      segment = segment.replaceFirst(gradeResult.matchedText, ' ');
      segment = _cleanWhitespace(segment);
    }

    // 5. Detect Odometer (explicit keywords or unit indicators)
    final odoResult = _extractOdometer(segment);
    if (odoResult != null) {
      odometer = odoResult.value;
      segment = segment.replaceFirst(odoResult.matchedText, ' ');
      segment = _cleanWhitespace(segment);
    }

    // 6. Detect Fuel Volume (litres / gallons / volume words)
    final volResult = _extractVolume(segment);
    if (volResult != null) {
      fuelAmount = volResult.value;
      segment = segment.replaceFirst(volResult.matchedText, ' ');
      segment = _cleanWhitespace(segment);
    }

    // 7. Detect Total Price (currency symbols, price/cost words)
    final priceResult = _extractPrice(segment);
    if (priceResult != null) {
      totalPrice = priceResult.value;
      segment = segment.replaceFirst(priceResult.matchedText, ' ');
      segment = _cleanWhitespace(segment);
    }

    // 8. Fallback: Parse remaining unassigned numbers for missing metrics
    final remainingNumbers = _extractRemainingNumbers(segment);
    for (final numVal in remainingNumbers) {
      if (odometer == null && numVal >= 1000) {
        odometer = numVal;
      } else if (fuelAmount == null && numVal > 0 && numVal <= 300) {
        fuelAmount = numVal;
      } else if (totalPrice == null && numVal > 0) {
        totalPrice = numVal;
      }
    }

    // Remaining residual text becomes notes if any meaningful words remain
    final cleanedNotes = _cleanRemainingNotes(segment);
    if (cleanedNotes.isNotEmpty) {
      notes = cleanedNotes;
    }

    return ParsedRecordDraft(
      dateTime: recordDate,
      odometer: odometer,
      fuelAmount: fuelAmount,
      totalPrice: totalPrice,
      gasStation: gasStation,
      fuelType: fuelType,
      isFullTank: isFullTank,
      notes: notes,
    );
  }

  // --- Entity Extraction Methods ---

  static _DateExtraction? _extractDate(String text) {
    final now = DateTime.now();

    // Check relative keywords
    if (RegExp(r'\btoday\b', caseSensitive: false).hasMatch(text)) {
      final match = RegExp(r'\btoday\b', caseSensitive: false).firstMatch(text)!;
      return _DateExtraction(DateTime(now.year, now.month, now.day, 12), match.group(0)!);
    }
    if (RegExp(r'\byesterday\b', caseSensitive: false).hasMatch(text)) {
      final match = RegExp(r'\byesterday\b', caseSensitive: false).firstMatch(text)!;
      final y = now.subtract(const Duration(days: 1));
      return _DateExtraction(DateTime(y.year, y.month, y.day, 12), match.group(0)!);
    }

    // DD-MMM-YY or DD-MMM-YYYY (e.g. 16-Oct-26 or 16-Oct-2026)
    final dmyAbbrRegex = RegExp(r'\b(\d{1,2})[-/]([A-Za-z]{3})[-/](\d{2,4})\b');
    final dmyAbbrMatch = dmyAbbrRegex.firstMatch(text);
    if (dmyAbbrMatch != null) {
      try {
        final day = int.parse(dmyAbbrMatch.group(1)!);
        final monStr = dmyAbbrMatch.group(2)!;
        var yr = int.parse(dmyAbbrMatch.group(3)!);
        if (yr < 100) yr += 2000;
        final month = _monthFromAbbr(monStr);
        if (month != null) {
          return _DateExtraction(DateTime(yr, month, day, 12), dmyAbbrMatch.group(0)!);
        }
      } catch (_) {}
    }

    // YYYY-MM-DD or YYYY/MM/DD
    final isoRegex = RegExp(r'\b(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})\b');
    final isoMatch = isoRegex.firstMatch(text);
    if (isoMatch != null) {
      try {
        final yr = int.parse(isoMatch.group(1)!);
        final mo = int.parse(isoMatch.group(2)!);
        final da = int.parse(isoMatch.group(3)!);
        return _DateExtraction(DateTime(yr, mo, da, 12), isoMatch.group(0)!);
      } catch (_) {}
    }

    // DD/MM/YYYY or DD-MM-YYYY
    final dmyRegex = RegExp(r'\b(\d{1,2})[-/.](\d{1,2})[-/.](\d{2,4})\b');
    final dmyMatch = dmyRegex.firstMatch(text);
    if (dmyMatch != null) {
      try {
        final p1 = int.parse(dmyMatch.group(1)!);
        final p2 = int.parse(dmyMatch.group(2)!);
        var yr = int.parse(dmyMatch.group(3)!);
        if (yr < 100) yr += 2000;

        // If p1 > 12, p1 is day, p2 is month. Else treat as standard DD/MM/YYYY
        int da = p1;
        int mo = p2;
        if (mo > 12 && da <= 12) {
          da = p2;
          mo = p1;
        }
        return _DateExtraction(DateTime(yr, mo, da, 12), dmyMatch.group(0)!);
      } catch (_) {}
    }

    return null;
  }

  static int? _monthFromAbbr(String abbr) {
    const months = ['jan', 'feb', 'mar', 'apr', 'may', 'jun', 'jul', 'aug', 'sep', 'oct', 'nov', 'dec'];
    final idx = months.indexOf(abbr.toLowerCase());
    return idx != -1 ? idx + 1 : null;
  }

  static _StationExtraction? _extractGasStation(String text) {
    // 1. Check known brands first
    for (final station in knownStations) {
      final pattern = RegExp('\\b${RegExp.escape(station)}\\b', caseSensitive: false);
      final match = pattern.firstMatch(text);
      if (match != null) {
        return _StationExtraction(station, match.group(0)!);
      }
    }

    // 2. Check "at <Station>" or "station: <Station>"
    final atRegex = RegExp(
      r'(?:at|@|station|gas\s+station|pump|vendor)[\s:=]+([A-Za-z0-9&.\x27-]+(?:\s+[A-Za-z0-9&.\x27-]+){0,2})',
      caseSensitive: false,
    );
    final atMatch = atRegex.firstMatch(text);
    if (atMatch != null) {
      final cand = atMatch.group(1)!.trim();
      // Avoid capturing numeric metrics or keywords
      if (!RegExp(r'^(?:\d|odo|km|mi|l|gal|\$|regular|diesel)', caseSensitive: false).hasMatch(cand)) {
        return _StationExtraction(_toTitleCase(cand), atMatch.group(0)!);
      }
    }

    return null;
  }

  static _GradeExtraction? _extractFuelGrade(String text) {
    final lower = text.toLowerCase();
    if (lower.contains('diesel') || lower.contains('gasoil')) {
      final m = RegExp(r'\b(?:diesel|gasoil)\b', caseSensitive: false).firstMatch(text)!;
      return _GradeExtraction('Diesel', m.group(0)!);
    }
    if (lower.contains('premium') || lower.contains('93') || lower.contains('v-power') || lower.contains('supreme')) {
      final m = RegExp(r'\b(?:premium|93|v-power|supreme)\b', caseSensitive: false).firstMatch(text)!;
      return _GradeExtraction('Premium (93)', m.group(0)!);
    }
    if (lower.contains('super 98') || lower.contains('98 ron') || lower.contains('98')) {
      final m = RegExp(r'\b(?:super\s*98|98\s*ron|98)\b', caseSensitive: false).firstMatch(text)!;
      return _GradeExtraction('Super (98)', m.group(0)!);
    }
    if (lower.contains('super') || lower.contains('95') || lower.contains('95 ron')) {
      final m = RegExp(r'\b(?:super|95\s*ron|95)\b', caseSensitive: false).firstMatch(text)!;
      return _GradeExtraction('Super (95)', m.group(0)!);
    }
    if (lower.contains('midgrade') || lower.contains('89') || lower.contains('plus')) {
      final m = RegExp(r'\b(?:midgrade|89|plus)\b', caseSensitive: false).firstMatch(text)!;
      return _GradeExtraction('Midgrade (89)', m.group(0)!);
    }
    if (lower.contains('regular') || lower.contains('87') || lower.contains('unleaded')) {
      final m = RegExp(r'\b(?:regular|87|unleaded)\b', caseSensitive: false).firstMatch(text)!;
      return _GradeExtraction('Regular (87)', m.group(0)!);
    }
    if (lower.contains('e85') || lower.contains('ethanol')) {
      final m = RegExp(r'\b(?:e85|ethanol)\b', caseSensitive: false).firstMatch(text)!;
      return _GradeExtraction('E85', m.group(0)!);
    }

    return null;
  }

  static _NumericExtraction? _extractOdometer(String text) {
    // Keyword followed by number: odo: 54000, odometer 120500, reading = 45200, clock: 20000
    final keywordRegex = RegExp(
      r'\b(?:odometer|odo|reading|mileage|milage|dash|meter|clock)[\s:=#]+([\d,.]+)',
      caseSensitive: false,
    );
    final kwMatch = keywordRegex.firstMatch(text);
    if (kwMatch != null) {
      final val = _parseNumber(kwMatch.group(1)!);
      if (val != null) {
        return _NumericExtraction(val, kwMatch.group(0)!);
      }
    }

    // Number followed by km or miles: 54000 km, 120500km, 45000 miles, 30000 mi
    final unitRegex = RegExp(
      r'\b([\d,.]+)\s*(?:kms?|kilometers?|miles?|mi)\b',
      caseSensitive: false,
    );
    final unitMatch = unitRegex.firstMatch(text);
    if (unitMatch != null) {
      final val = _parseNumber(unitMatch.group(1)!);
      if (val != null) {
        return _NumericExtraction(val, unitMatch.group(0)!);
      }
    }

    // At symbol with high number: @ 54000 or at 54000
    final atRegex = RegExp(r'(?:at|@)\s*([\d,.]+)\s*(?:km|mi)?\b', caseSensitive: false);
    final atMatch = atRegex.firstMatch(text);
    if (atMatch != null) {
      final val = _parseNumber(atMatch.group(1)!);
      if (val != null && val >= 1000) {
        return _NumericExtraction(val, atMatch.group(0)!);
      }
    }

    return null;
  }

  static _NumericExtraction? _extractVolume(String text) {
    // Keyword followed by volume: filled 45.2L, pumped: 12 gal, qty: 50
    final keywordRegex = RegExp(
      r'\b(?:volume|vol|qty|quantity|filled|pumped|fuel|gas|petrol|litres?|liters?|gallons?)[\s:=#]+([\d,.]+)\s*(?:l|ltrs?|liters?|litres?|gal|gals?|gallons?)?',
      caseSensitive: false,
    );
    final kwMatch = keywordRegex.firstMatch(text);
    if (kwMatch != null) {
      final val = _parseNumber(kwMatch.group(1)!);
      if (val != null && val <= 500) {
        return _NumericExtraction(val, kwMatch.group(0)!);
      }
    }

    // Number followed by volume units: 45.5 L, 12.4gal, 50ltr, 60 liters
    final unitRegex = RegExp(
      r'\b([\d,.]+)\s*(?:liters?|litres?|ltrs?|lt\b|l\b|gallons?|gals?\b)',
      caseSensitive: false,
    );
    final unitMatch = unitRegex.firstMatch(text);
    if (unitMatch != null) {
      final val = _parseNumber(unitMatch.group(1)!);
      if (val != null) {
        return _NumericExtraction(val, unitMatch.group(0)!);
      }
    }

    return null;
  }

  static _NumericExtraction? _extractPrice(String text) {
    // Currency symbol followed by number: $75.50, €60.00, £50, ₹3500, AED 150
    final currRegex = RegExp(
      r'(?:[\$€£₹¥]|c\$|a\$|aed|rs\.?|inr|usd|cad|aud|gbp|eur|sar)\s*([\d,.]+)',
      caseSensitive: false,
    );
    final currMatch = currRegex.firstMatch(text);
    if (currMatch != null) {
      final val = _parseNumber(currMatch.group(1)!);
      if (val != null) {
        return _NumericExtraction(val, currMatch.group(0)!);
      }
    }

    // Number followed by currency code: 75.50 USD, 60 EUR, 150 AED
    final suffixCurrRegex = RegExp(
      r'\b([\d,.]+)\s*(?:[\$€£₹¥]|aed|rs\.?|inr|usd|cad|aud|gbp|eur|sar)\b',
      caseSensitive: false,
    );
    final suffixMatch = suffixCurrRegex.firstMatch(text);
    if (suffixMatch != null) {
      final val = _parseNumber(suffixMatch.group(1)!);
      if (val != null) {
        return _NumericExtraction(val, suffixMatch.group(0)!);
      }
    }

    // Price / Cost keywords: paid 75.50, cost: 60, total = 80, for $75
    final kwRegex = RegExp(
      r'\b(?:total|price|cost|paid|spent|amount|amt|bill|charge|sum|fee|for)[\s:=]+(?:[\$€£₹¥]\s*)?([\d,.]+)',
      caseSensitive: false,
    );
    final kwMatch = kwRegex.firstMatch(text);
    if (kwMatch != null) {
      final val = _parseNumber(kwMatch.group(1)!);
      if (val != null) {
        return _NumericExtraction(val, kwMatch.group(0)!);
      }
    }

    return null;
  }

  static List<double> _extractRemainingNumbers(String text) {
    final List<double> numbers = [];
    final matches = RegExp(r'\b\d+(?:[.,]\d+)?\b').allMatches(text);
    for (final m in matches) {
      final v = _parseNumber(m.group(0)!);
      if (v != null) numbers.add(v);
    }
    return numbers;
  }

  static double? _parseNumber(String raw) {
    var cleaned = raw.trim();
    // Remove trailing dots or commas
    cleaned = cleaned.replaceAll(RegExp(r'[^\d.,]'), '');
    if (cleaned.contains(',') && !cleaned.contains('.')) {
      // Could be European decimal like 45,5 or comma thousands like 54,000
      final parts = cleaned.split(',');
      if (parts.length == 2 && parts[1].length == 3 && int.parse(parts[0]) > 0) {
        cleaned = parts.join(''); // thousand separator
      } else if (parts.length == 2 && parts[1].length <= 2) {
        cleaned = '${parts[0]}.${parts[1]}'; // decimal separator
      } else {
        cleaned = cleaned.replaceAll(',', '');
      }
    } else {
      cleaned = cleaned.replaceAll(',', '');
    }

    return double.tryParse(cleaned);
  }

  static String _cleanRemainingNotes(String segment) {
    // Strip common punctuation leftovers and empty filler words
    var s = segment.replaceAll(RegExp(r'[,;:=|~*#]+'), ' ');
    s = _cleanWhitespace(s);
    // Ignore if only common stopwords remain
    if (RegExp(r'^(?:at|on|for|in|and|the|a|an|with|full|car|auto|vehicle)$', caseSensitive: false).hasMatch(s)) {
      return '';
    }
    return s;
  }

  static String _toTitleCase(String text) {
    if (text.isEmpty) return text;
    return text.split(' ').map((word) {
      if (word.isEmpty) return word;
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }
}

class _DateExtraction {
  final DateTime date;
  final String matchedText;
  _DateExtraction(this.date, this.matchedText);
}

class _StationExtraction {
  final String station;
  final String matchedText;
  _StationExtraction(this.station, this.matchedText);
}

class _GradeExtraction {
  final String grade;
  final String matchedText;
  _GradeExtraction(this.grade, this.matchedText);
}

class _NumericExtraction {
  final double value;
  final String matchedText;
  _NumericExtraction(this.value, this.matchedText);
}
