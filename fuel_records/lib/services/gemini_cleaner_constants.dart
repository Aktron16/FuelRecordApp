/// Constants and data sanitization utilities for the AI Data Cleaner (Convert via Gemini) fallback.
library;

/// The exact prompt instructions sent to Gemini / ChatGPT.
const String kGeminiCleanerPrompt = '''You are the Data Formatting Assistant for FuelRecordApp. 
I need to convert messy, unstructured fuel records (such as raw text notes, SMS bank alerts, OCR receipt text, or broken CSV tables) into a strict, clean CSV format that my app's parser can import with 100% accuracy.

### YOUR STEP 1 (DO THIS NOW):
Do not generate any CSV yet. Reply ONLY with a short, friendly message asking me to paste or upload my messy fuel records, and ask me what my default date format (e.g., DD/MM/YYYY or MM/DD/YYYY) is if it's ambiguous.

### YOUR STEP 2 (ONCE I GIVE YOU MY DATA):
Analyze my messy data and output ONLY a single markdown ```csv code block following these strict rules:
1. Exact Header Row: Your very first line inside the code block MUST be:
   date,odometer,fuelVolume,pricePerUnit,totalCost,stationName,notes
2. Date Normalization: Convert all dates to strict ISO format `YYYY-MM-DD`. If the year is missing, assume the current year.
3. Clean Numbers Only: Strip all currency symbols (\$, AED, €, £, etc.), commas inside thousands (write `84500`, NOT `84,500`), and unit labels (`L`, `gal`, `km`, `mi`). Output pure decimals or integers.
4. Auto-Calculate Missing Math:
   - If `totalCost` and `fuelVolume` are present, but `pricePerUnit` is missing, calculate `pricePerUnit = round(totalCost / fuelVolume, 3)`.
   - If `fuelVolume` and `pricePerUnit` are present, but `totalCost` is missing, calculate `totalCost = round(fuelVolume * pricePerUnit, 2)`.
5. Handle Missing Optional Fields: If `odometer`, `stationName`, or `notes` are missing from a record, leave the CSV cell empty between the commas (e.g., `2026-10-15,,40.5,2.50,101.25,Shell,`). Never write "N/A" or "null".
6. Escaping: If `stationName` or `notes` contains a comma, wrap that text in double quotes.''';

/// Direct web links for AI assistants
const String kGeminiWebUrl = 'https://gemini.google.com/app';

String getChatGptUrl([String prompt = kGeminiCleanerPrompt]) {
  return 'https://chatgpt.com/?q=${Uri.encodeComponent(prompt)}';
}

/// Sanitizes and cleans raw text received from an AI assistant or clipboard before parsing.
///
/// 1. Strips invisible unicode / zero-width characters.
/// 2. Extracts content from markdown code fences (```csv ... ``` or ``` ... ```).
/// 3. Normalizes CRLF / CR to standard Unix newlines.
/// 4. Removes outer conversational padding / chat commentary.
String cleanMarkdownFences(String input) {
  if (input.trim().isEmpty) return '';

  // 1. Remove zero-width spaces and byte-order-marks
  var sanitized = input
      .replaceAll('\uFEFF', '')
      .replaceAll('\u200B', '')
      .replaceAll('\u200E', '')
      .replaceAll('\u200F', '')
      .replaceAll('\r\n', '\n')
      .replaceAll('\r', '\n');

  // 2. Check for markdown code fences (```csv ... ``` or ``` ... ```)
  final fenceRegex = RegExp(r'```(?:csv|tsv|text)?\s*([\s\S]*?)\s*```', caseSensitive: false);
  final match = fenceRegex.firstMatch(sanitized);

  if (match != null && match.group(1) != null) {
    sanitized = match.group(1)!.trim();
  } else {
    // If no complete closing fence, strip any dangling leading/trailing backticks
    sanitized = sanitized.replaceAll(RegExp(r'^`{1,4}(?:csv|tsv)?\s*', multiLine: true), '');
    sanitized = sanitized.replaceAll(RegExp(r'\s*`{1,4}$', multiLine: true), '');
  }

  // 3. Trim leading/trailing blank lines
  final lines = sanitized.split('\n');
  final cleanLines = <String>[];
  bool started = false;

  for (final line in lines) {
    final trimmed = line.trim();
    if (!started) {
      // Find the first line that looks like a header or CSV record (contains commas or tabs)
      if (trimmed.contains(',') || trimmed.contains('\t')) {
        started = true;
        cleanLines.add(trimmed);
      }
    } else {
      if (trimmed.isNotEmpty) {
        cleanLines.add(trimmed);
      }
    }
  }

  // If filtered lines found, join; otherwise fallback to sanitized text
  return cleanLines.isNotEmpty ? cleanLines.join('\n') : sanitized.trim();
}
