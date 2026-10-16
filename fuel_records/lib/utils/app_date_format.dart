import 'package:intl/intl.dart';

/// Centralized Date Formatting Utility
/// Formats dates uniformly across the Fuel Metrics app as DD-Month(abbreviation)-YY
/// Example: 16-Oct-26
class AppDateUtils {
  static final DateFormat _dateFormat = DateFormat('dd-MMM-yy');
  static final DateFormat _shortDateFormat = DateFormat('dd-MMM');

  /// Formats date to 'dd-MMM-yy', e.g. '16-Oct-26'
  static String format(DateTime dt) {
    return _dateFormat.format(dt);
  }

  /// Formats date to 'dd-MMM', e.g. '16-Oct' (useful for compact charts)
  static String formatShort(DateTime dt) {
    return _shortDateFormat.format(dt);
  }
}
