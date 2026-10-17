import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import '../models/vehicle.dart';
import '../models/fuel_record.dart';
import '../services/fuel_app_state.dart';
import '../services/file_parser_service.dart';
import '../services/header_auto_mapper.dart';
import '../utils/app_date_format.dart';

/// Screen implementing the 3-Layer Hybrid Import Architecture:
/// 1. Official Template Generator
/// 2. Universal File Reader & Auto-Header Detector
/// 3. Interactive Column-Mapper & Quarantine Staging Preview UI
class ImportPreviewScreen extends StatefulWidget {
  final Vehicle vehicle;
  final FuelAppState appState;
  final String? initialText;

  const ImportPreviewScreen({
    super.key,
    required this.vehicle,
    required this.appState,
    this.initialText,
  });

  @override
  State<ImportPreviewScreen> createState() => _ImportPreviewScreenState();
}

class _ImportPreviewScreenState extends State<ImportPreviewScreen> {
  // Input State
  String _sourceFileName = '';
  List<String> _rawHeaders = [];
  List<List<String>> _rawDataRows = [];
  List<FuelField> _columnMappings = [];
  List<StagedFuelRecord> _stagedRecords = [];

  // Manual Text Input Controller
  final TextEditingController _pasteController = TextEditingController();
  bool _showPasteArea = false;

  // Quarantine & Filter State
  String _activeFilter = 'all'; // 'all', 'invalid', 'valid'
  bool _skipInvalidRows = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialText != null && widget.initialText!.trim().isNotEmpty) {
      _pasteController.text = widget.initialText!;
      _processRawText(widget.initialText!);
    }
  }

  @override
  void dispose() {
    _pasteController.dispose();
    super.dispose();
  }

  // --- File & Text Loaders ---

  Future<void> _pickFile() async {
    try {
      setState(() => _isLoading = true);
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv', 'tsv', 'xlsx', 'xlsm', 'xls', 'txt'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final bytes = file.bytes ?? (file.path != null ? await File(file.path!).readAsBytes() : null);

        if (bytes != null) {
          final table = FileParserService.parseSpreadsheetBytes(bytes, file.name);
          _applyParsedTable(table);
        }
      }
    } catch (e) {
      _showSnackbar('Failed to read file: $e', isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _downloadSampleTemplate() async {
    try {
      final file = await FileParserService.exportSampleTemplate(vehicle: widget.vehicle);
      if (!mounted) return;

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.download_done, color: Color(0xFF16A34A)),
              SizedBox(width: 8),
              Text('Official Template Ready', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A clean template with the exact column headers has been saved to your device. You can open it in Excel, Google Sheets, or fill it out directly:',
                style: TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  file.path,
                  style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy File Path'),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: file.path));
                Navigator.of(ctx).pop();
                _showSnackbar('File path copied to clipboard!');
              },
            ),
          ],
        ),
      );
    } catch (e) {
      _showSnackbar('Could not generate template: $e', isError: true);
    }
  }

  void _processRawText(String text) {
    if (text.trim().isEmpty) return;
    final table = FileParserService.parseSpreadsheetBytes(
      Uint8List.fromList(text.codeUnits),
      'PastedText.csv',
    );
    _applyParsedTable(table);
  }

  void _applyParsedTable(RawTableData table) {
    if (table.isEmpty) {
      _showSnackbar('No tabular data could be found in the file or text.', isError: true);
      return;
    }

    final autoMappings = HeaderAutoMapper.autoDetectMappings(
      headers: table.headers,
      sampleRows: table.dataRows,
    );

    setState(() {
      _sourceFileName = table.sourceFileName;
      _rawHeaders = table.headers;
      _rawDataRows = table.dataRows;
      _columnMappings = autoMappings;
      _recomputeStagedRecords();
      _showPasteArea = false;
    });
  }

  void _recomputeStagedRecords() {
    _stagedRecords = HeaderAutoMapper.stageRows(
      dataRows: _rawDataRows,
      columnMappings: _columnMappings,
      defaultFuelType: widget.vehicle.fuelType,
      defaultStation: widget.appState.currentCountryInfo.popularStations.firstOrNull ?? 'Shell',
    );
  }

  void _onColumnMappingChanged(int columnIndex, FuelField? newField) {
    if (newField == null) return;
    setState(() {
      _columnMappings[columnIndex] = newField;
      _recomputeStagedRecords();
    });
  }

  // --- Inline Editing for Staged Records ---

  void _editStagedRecord(int index) {
    final record = _stagedRecords[index];
    final dateCtrl = TextEditingController(
      text: record.dateTime != null ? AppDateUtils.format(record.dateTime!) : '',
    );
    final odoCtrl = TextEditingController(
      text: record.odometer != null ? record.odometer!.toStringAsFixed(1) : '',
    );
    final fuelCtrl = TextEditingController(
      text: record.fuelAmount != null ? record.fuelAmount!.toStringAsFixed(2) : '',
    );
    final priceCtrl = TextEditingController(
      text: record.totalPrice != null ? record.totalPrice!.toStringAsFixed(2) : '',
    );
    final stationCtrl = TextEditingController(text: record.gasStation);
    final notesCtrl = TextEditingController(text: record.notes);
    String selectedGrade = record.fuelType;
    bool isFull = record.isFullTank;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Text('Edit Row #${record.rowIndex}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 340,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: dateCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Date (e.g. 15-Oct-26 or 2026-10-15)',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: odoCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Odometer (${widget.vehicle.unitDistance})',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: fuelCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Fuel Amount (${widget.vehicle.unitVolume})',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: priceCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Total Price (${widget.vehicle.currency})',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: stationCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Gas Station',
                      isDense: true,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedGrade,
                    decoration: const InputDecoration(labelText: 'Fuel Grade', isDense: true),
                    items: const [
                      'Regular (87)',
                      'Midgrade (89)',
                      'Premium (93)',
                      'Super (95)',
                      'Super (98)',
                      'Diesel',
                      'E85'
                    ].map((g) => DropdownMenuItem(value: g, child: Text(g, style: const TextStyle(fontSize: 13)))).toList(),
                    onChanged: (val) {
                      if (val != null) setDialogState(() => selectedGrade = val);
                    },
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    dense: true,
                    title: const Text('Full Tank?', style: TextStyle(fontSize: 13)),
                    value: isFull,
                    onChanged: (val) => setDialogState(() => isFull = val),
                  ),
                  TextField(
                    controller: notesCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Notes',
                      isDense: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final parsedDate = HeaderAutoMapper.parseFlexibleDate(dateCtrl.text);
                final parsedOdo = HeaderAutoMapper.cleanNumber(odoCtrl.text);
                final parsedFuel = HeaderAutoMapper.cleanNumber(fuelCtrl.text);
                final parsedPrice = HeaderAutoMapper.cleanNumber(priceCtrl.text);

                setState(() {
                  record.dateTime = parsedDate;
                  record.odometer = parsedOdo;
                  record.fuelAmount = parsedFuel;
                  record.totalPrice = parsedPrice;
                  record.gasStation = stationCtrl.text.trim();
                  record.fuelType = selectedGrade;
                  record.isFullTank = isFull;
                  record.notes = notesCtrl.text.trim();

                  // Re-evaluate validity
                  if (record.dateTime == null) {
                    record.isValid = false;
                    record.validationError = 'Missing or invalid date';
                  } else if (record.odometer == null || record.odometer! < 0) {
                    record.isValid = false;
                    record.validationError = 'Invalid odometer reading';
                  } else if (record.fuelAmount == null || record.fuelAmount! <= 0) {
                    record.isValid = false;
                    record.validationError = 'Invalid fuel quantity';
                  } else if (record.totalPrice == null || record.totalPrice! < 0) {
                    record.isValid = false;
                    record.validationError = 'Invalid total price';
                  } else {
                    record.isValid = true;
                    record.validationError = null;
                  }
                });
                Navigator.of(ctx).pop();
              },
              child: const Text('Save Row'),
            ),
          ],
        ),
      ),
    );
  }

  // --- Top Actions: Cancel (Red) & Accept (Green) ---

  void _handleCancel() {
    if (_stagedRecords.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Imported Data?'),
        content: const Text('None of the imported spreadsheet records will be added to your car logs.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              Navigator.of(ctx).pop();
              Navigator.of(context).pop();
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAccept() async {
    final validRecords = _stagedRecords.where((r) => r.isValid).toList();
    final invalidRecords = _stagedRecords.where((r) => !r.isValid).toList();

    if (validRecords.isEmpty) {
      _showSnackbar('There are no valid records ready for import. Please review and fix required fields.', isError: true);
      return;
    }

    if (invalidRecords.isNotEmpty && !_skipInvalidRows) {
      _showSnackbar('There are ${invalidRecords.length} rows that need attention. Fix them or toggle "Skip invalid rows" to proceed.', isError: true);
      return;
    }

    final timestampBase = DateTime.now().millisecondsSinceEpoch;
    final List<FuelRecord> recordsToCommit = [];

    for (int i = 0; i < validRecords.length; i++) {
      final item = validRecords[i];
      recordsToCommit.add(FuelRecord(
        id: 'rec_${timestampBase}_$i',
        vehicleId: widget.vehicle.id,
        dateTime: item.dateTime!,
        odometer: item.odometer!,
        fuelAmount: item.fuelAmount!,
        totalPrice: item.totalPrice!,
        isFullTank: item.isFullTank,
        fuelType: item.fuelType.isNotEmpty ? item.fuelType : widget.vehicle.fuelType,
        gasStation: item.gasStation.isNotEmpty ? item.gasStation : 'Gas Station',
        notes: item.notes,
      ));
    }

    // Component D: Atomic Database Batch Insert
    final count = await widget.appState.importSpreadsheetRecordsBatch(recordsToCommit);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Successfully imported $count fuel records into ${widget.vehicle.name}!',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF16A34A),
      ),
    );

    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  void _showSnackbar(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
      ),
    );
  }

  // --- UI Builder ---

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final validCount = _stagedRecords.where((r) => r.isValid).length;
    final invalidCount = _stagedRecords.length - validCount;

    final displayedRecords = _stagedRecords.where((r) {
      if (_activeFilter == 'valid') return r.isValid;
      if (_activeFilter == 'invalid') return !r.isValid;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Import Fuel Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Top Action Buttons Bar: Cancel (Red) & Accept (Green)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.18)),
                ),
              ),
              child: Row(
                children: [
                  // Cancel Button in RED Background
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: _handleCancel,
                      icon: const Icon(Icons.close, size: 18, color: Colors.white),
                      label: const Text(
                        'Cancel',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.2),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Accept Button in GREEN Background
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF16A34A),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: _handleAccept,
                      icon: const Icon(Icons.check, size: 18, color: Colors.white),
                      label: Text(
                        _stagedRecords.isEmpty ? 'Accept' : 'Accept ($validCount)',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Simple 1-Paragraph Non-Technical Explanation
            Container(
              margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.22)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 20, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Easily add your past fill-ups all at once. Choose a spreadsheet file (.csv, .xlsx) or paste your notes, match your columns using the dropdowns, and review everything before saving.',
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: theme.textTheme.bodyMedium?.color?.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Action Buttons: File Picker & Sample Template Generator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: _isLoading ? null : _pickFile,
                      icon: const Icon(Icons.file_open_outlined, size: 18),
                      label: Text(
                        _sourceFileName.isEmpty ? 'Pick File (.csv, .xlsx)' : 'Change File',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: _downloadSampleTemplate,
                    icon: const Icon(Icons.download_outlined, size: 18),
                    label: const Text('Template', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    icon: Icon(_showPasteArea ? Icons.table_chart : Icons.paste),
                    tooltip: _showPasteArea ? 'Show Table' : 'Paste Raw Text',
                    onPressed: () {
                      setState(() => _showPasteArea = !_showPasteArea);
                    },
                  ),
                ],
              ),
            ),

            // Optional Manual Paste Area
            if (_showPasteArea)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF22222E) : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _pasteController,
                      maxLines: 4,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        hintText: 'Paste CSV, TSV, or notes here...\ne.g. 2026-10-15, 84500, 42.5, 2.50, 106.25, Shell',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: () => _processRawText(_pasteController.text),
                      child: const Text('Parse Staged Table'),
                    ),
                  ],
                ),
              ),

            // Staging Table & Quarantine Section
            if (_rawHeaders.isNotEmpty) ...[
              // Quarantine & Filter Summary Bar
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: invalidCount > 0 ? const Color(0xFFFEF2F2) : const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: invalidCount > 0 ? const Color(0xFFFCA5A5) : const Color(0xFF86EFAC),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      invalidCount > 0 ? Icons.warning_amber_rounded : Icons.check_circle_outline,
                      size: 18,
                      color: invalidCount > 0 ? const Color(0xFFDC2626) : const Color(0xFF16A34A),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        invalidCount > 0
                            ? '$validCount valid records ready, $invalidCount rows need attention.'
                            : 'All $validCount records are valid and ready to import.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: invalidCount > 0 ? const Color(0xFF991B1B) : const Color(0xFF166534),
                        ),
                      ),
                    ),
                    if (invalidCount > 0)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Skip invalid', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
                          Checkbox(
                            value: _skipInvalidRows,
                            visualDensity: VisualDensity.compact,
                            onChanged: (val) {
                              setState(() => _skipInvalidRows = val ?? false);
                            },
                          ),
                        ],
                      ),
                  ],
                ),
              ),

              // Filter Chips: All, Needs Attention, Valid
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('All (${_stagedRecords.length})', style: const TextStyle(fontSize: 11)),
                      selected: _activeFilter == 'all',
                      onSelected: (_) => setState(() => _activeFilter = 'all'),
                    ),
                    const SizedBox(width: 6),
                    if (invalidCount > 0)
                      ChoiceChip(
                        label: Text('Needs Attention ($invalidCount)', style: const TextStyle(fontSize: 11, color: Colors.red)),
                        selected: _activeFilter == 'invalid',
                        onSelected: (_) => setState(() => _activeFilter = 'invalid'),
                      ),
                    const SizedBox(width: 6),
                    ChoiceChip(
                      label: Text('Valid ($validCount)', style: const TextStyle(fontSize: 11)),
                      selected: _activeFilter == 'valid',
                      onSelected: (_) => setState(() => _activeFilter = 'valid'),
                    ),
                  ],
                ),
              ),

              // Interactive Column-Mapper and Staged Table
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.vertical,
                  padding: const EdgeInsets.only(bottom: 24),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: DataTable(
                        columnSpacing: 12,
                        horizontalMargin: 8,
                        headingRowHeight: 88,
                        headingRowColor: WidgetStatePropertyAll(
                          isDark ? const Color(0xFF282836) : const Color(0xFFF1F5F9),
                        ),
                        border: TableBorder.all(
                          color: Colors.grey.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        // Columns with Interactive Mapping Dropdowns
                        columns: [
                          const DataColumn(label: Text('Row / Status', style: TextStyle(fontWeight: FontWeight.bold))),
                          ...List.generate(_rawHeaders.length, (colIdx) {
                            return DataColumn(
                              label: SizedBox(
                                width: 145,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _rawHeaders[colIdx],
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    const SizedBox(height: 4),
                                    Container(
                                      height: 34,
                                      padding: const EdgeInsets.symmetric(horizontal: 6),
                                      decoration: BoxDecoration(
                                        color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.5)),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<FuelField>(
                                          value: _columnMappings[colIdx],
                                          isExpanded: true,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? Colors.white : Colors.black87,
                                          ),
                                          items: FuelField.values.map((field) {
                                            return DropdownMenuItem(
                                              value: field,
                                              child: Text(field.label, overflow: TextOverflow.ellipsis),
                                            );
                                          }).toList(),
                                          onChanged: (val) => _onColumnMappingChanged(colIdx, val),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                          const DataColumn(label: Text('Action', style: TextStyle(fontWeight: FontWeight.bold))),
                        ],
                        // Data Rows with Quarantine Highlights
                        rows: List.generate(displayedRecords.length, (idx) {
                          final staged = displayedRecords[idx];
                          final originalIndex = _stagedRecords.indexOf(staged);
                          final isRowValid = staged.isValid;

                          return DataRow(
                            color: WidgetStatePropertyAll(
                              !isRowValid
                                  ? (isDark ? const Color(0xFF3B1E1E) : const Color(0xFFFFF1F2))
                                  : null,
                            ),
                            cells: [
                              // Status cell
                              DataCell(
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isRowValid ? Icons.check_circle : Icons.error_outline,
                                      size: 16,
                                      color: isRowValid ? const Color(0xFF16A34A) : const Color(0xFFDC2626),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '#${staged.rowIndex}',
                                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                    ),
                                    if (!isRowValid && staged.validationError != null)
                                      Padding(
                                        padding: const EdgeInsets.only(left: 4),
                                        child: Tooltip(
                                          message: staged.validationError!,
                                          child: const Icon(Icons.info, size: 14, color: Color(0xFFDC2626)),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              // Raw Cell Values
                              ...List.generate(_rawHeaders.length, (colIdx) {
                                final text = colIdx < staged.rawRow.length ? staged.rawRow[colIdx] : '';
                                return DataCell(
                                  Text(
                                    text,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: !isRowValid ? const Color(0xFFDC2626) : null,
                                      fontWeight: !isRowValid ? FontWeight.w600 : FontWeight.normal,
                                    ),
                                  ),
                                );
                              }),
                              // Edit Action
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.edit_note, size: 20),
                                  tooltip: 'Edit Staged Values',
                                  onPressed: () => _editStagedRecord(originalIndex),
                                ),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                ),
              ),
            ] else ...[
              // Empty State Placeholder
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.table_chart_outlined, size: 64, color: Colors.grey.withValues(alpha: 0.5)),
                      const SizedBox(height: 16),
                      const Text(
                        'No spreadsheet loaded yet',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Tap "Pick File" to load .csv or .xlsx, or tap "Template" to download a sample.',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                      const SizedBox(height: 20),
                      FilledButton.icon(
                        onPressed: _pickFile,
                        icon: const Icon(Icons.file_upload),
                        label: const Text('Pick Spreadsheet File'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

