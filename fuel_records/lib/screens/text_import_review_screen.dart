import 'package:flutter/material.dart';
import '../models/vehicle.dart';
import '../models/fuel_record.dart';
import '../services/fuel_app_state.dart';
import '../services/unstructured_text_parser.dart';
import '../utils/app_date_format.dart';

/// Screen displaying extracted unstructured text records in an editable grid format
/// with top Cancel (red) and Accept (green) buttons before committing to storage.
class TextImportReviewScreen extends StatefulWidget {
  final Vehicle vehicle;
  final FuelAppState appState;
  final List<ParsedRecordDraft> parsedDrafts;

  const TextImportReviewScreen({
    super.key,
    required this.vehicle,
    required this.appState,
    required this.parsedDrafts,
  });

  @override
  State<TextImportReviewScreen> createState() => _TextImportReviewScreenState();
}

class _TextImportReviewScreenState extends State<TextImportReviewScreen> {
  late List<_EditableDraftRow> _rows;

  @override
  void initState() {
    super.initState();
    _rows = widget.parsedDrafts.map((draft) => _EditableDraftRow.fromDraft(draft)).toList();
  }

  @override
  void dispose() {
    for (final row in _rows) {
      row.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _rows.add(_EditableDraftRow(
        dateTime: DateTime.now(),
        odometerController: TextEditingController(),
        fuelController: TextEditingController(),
        priceController: TextEditingController(),
        stationController: TextEditingController(text: 'Shell'),
        fuelType: widget.vehicle.fuelType,
        isFullTank: true,
      ));
    });
  }

  void _removeRow(int index) {
    if (_rows.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one row is required. Or tap Cancel to discard.')),
      );
      return;
    }
    setState(() {
      final removed = _rows.removeAt(index);
      removed.dispose();
    });
  }

  Future<void> _pickDateForRow(int index) async {
    final current = _rows[index].dateTime;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && mounted) {
      setState(() {
        _rows[index].dateTime = DateTime(picked.year, picked.month, picked.day, 12);
      });
    }
  }

  void _handleCancel() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Discard Imported Data?'),
        content: const Text('None of the parsed records will be saved to your car history.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Keep Editing'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () {
              Navigator.of(ctx).pop(); // dialog
              Navigator.of(context).pop(); // review screen
            },
            child: const Text('Discard'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAccept() async {
    // Validate each row
    final List<FuelRecord> recordsToCommit = [];
    final timestampBase = DateTime.now().millisecondsSinceEpoch;

    for (int i = 0; i < _rows.length; i++) {
      final row = _rows[i];
      final odoText = row.odometerController.text.trim();
      final fuelText = row.fuelController.text.trim();
      final priceText = row.priceController.text.trim();

      final odo = double.tryParse(odoText.replaceAll(',', ''));
      final fuel = double.tryParse(fuelText.replaceAll(',', ''));
      final price = double.tryParse(priceText.replaceAll(',', ''));

      if (odo == null || odo < 0) {
        _showValidationError('Row #${i + 1}: Please enter a valid odometer reading.');
        return;
      }
      if (fuel == null || fuel <= 0) {
        _showValidationError('Row #${i + 1}: Please enter a valid fuel quantity.');
        return;
      }
      if (price == null || price < 0) {
        _showValidationError('Row #${i + 1}: Please enter a valid total price.');
        return;
      }

      final station = row.stationController.text.trim();

      recordsToCommit.add(FuelRecord(
        id: 'rec_${timestampBase}_$i',
        vehicleId: widget.vehicle.id,
        dateTime: row.dateTime,
        odometer: odo,
        fuelAmount: fuel,
        totalPrice: price,
        isFullTank: row.isFullTank,
        fuelType: row.fuelType,
        gasStation: station.isNotEmpty ? station : 'Gas Station',
        notes: row.notesController.text.trim(),
      ));
    }

    if (recordsToCommit.isEmpty) {
      _showValidationError('No records to import.');
      return;
    }

    // Commit to app state and disk storage
    await widget.appState.addRecordsBatch(recordsToCommit);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Successfully imported ${recordsToCommit.length} fuel records!'),
        backgroundColor: const Color(0xFF16A34A),
      ),
    );

    // Pop review screen and return success
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  void _showValidationError(String msg) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: const Color(0xFFDC2626),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Parsed Data Grid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
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
                        backgroundColor: const Color(0xFFDC2626), // Red background
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
                        backgroundColor: const Color(0xFF16A34A), // Green background
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 0,
                      ),
                      onPressed: _handleAccept,
                      icon: const Icon(Icons.check, size: 18, color: Colors.white),
                      label: const Text(
                        'Accept',
                        style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15, letterSpacing: 0.2),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Header instructions & row count banner
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: theme.colorScheme.primary.withValues(alpha: 0.08),
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${_rows.length} record${_rows.length == 1 ? '' : 's'} parsed. Edit any values directly in the grid below.',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: _addRow,
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Add Row', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ),
            ),

            // Data Grid View (Scrollable horizontally and vertically)
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                padding: const EdgeInsets.only(bottom: 30),
                child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: DataTable(
                        columnSpacing: 16,
                        horizontalMargin: 12,
                        headingRowColor: WidgetStatePropertyAll(
                          isDark ? const Color(0xFF282836) : const Color(0xFFEEF2F6),
                        ),
                        headingTextStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        border: TableBorder.all(
                          color: Colors.grey.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        columns: [
                          const DataColumn(label: Text('#')),
                          const DataColumn(label: Text('Date')),
                          DataColumn(label: Text('Odometer (${widget.vehicle.unitDistance})')),
                          DataColumn(label: Text('Fuel (${widget.vehicle.unitVolume})')),
                          DataColumn(label: Text('Price (${widget.vehicle.currency})')),
                          const DataColumn(label: Text('Gas Station')),
                          const DataColumn(label: Text('Fuel Grade')),
                          const DataColumn(label: Text('Full?')),
                          const DataColumn(label: Text('Notes')),
                          const DataColumn(label: Text('Action')),
                        ],
                        rows: List.generate(_rows.length, (index) {
                          final row = _rows[index];
                          return DataRow(
                            cells: [
                              // Row Number
                              DataCell(
                                Center(
                                  child: Text('${index + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                ),
                              ),
                              // Date Picker Chip
                              DataCell(
                                InkWell(
                                  onTap: () => _pickDateForRow(index),
                                  borderRadius: BorderRadius.circular(8),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.primary.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.calendar_today, size: 13, color: theme.colorScheme.primary),
                                        const SizedBox(width: 6),
                                        Text(
                                          AppDateUtils.format(row.dateTime),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: theme.colorScheme.primary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              // Odometer Input
                              DataCell(
                                SizedBox(
                                  width: 95,
                                  child: TextField(
                                    controller: row.odometerController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ),
                              // Fuel Amount Input
                              DataCell(
                                SizedBox(
                                  width: 85,
                                  child: TextField(
                                    controller: row.fuelController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ),
                              // Price Input
                              DataCell(
                                SizedBox(
                                  width: 85,
                                  child: TextField(
                                    controller: row.priceController,
                                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ),
                              // Gas Station Input
                              DataCell(
                                SizedBox(
                                  width: 120,
                                  child: TextField(
                                    controller: row.stationController,
                                    style: const TextStyle(fontSize: 13),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ),
                              // Fuel Grade Dropdown
                              DataCell(
                                DropdownButton<String>(
                                  value: _cleanFuelType(row.fuelType),
                                  isDense: true,
                                  underline: const SizedBox.shrink(),
                                  style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface),
                                  items: const [
                                    DropdownMenuItem(value: 'Regular (87)', child: Text('Regular (87)')),
                                    DropdownMenuItem(value: 'Midgrade (89)', child: Text('Midgrade (89)')),
                                    DropdownMenuItem(value: 'Premium (93)', child: Text('Premium (93)')),
                                    DropdownMenuItem(value: 'Super (95)', child: Text('Super (95)')),
                                    DropdownMenuItem(value: 'Super (98)', child: Text('Super (98)')),
                                    DropdownMenuItem(value: 'Diesel', child: Text('Diesel')),
                                    DropdownMenuItem(value: 'E85', child: Text('E85')),
                                  ],
                                  onChanged: (val) {
                                    if (val != null) setState(() => row.fuelType = val);
                                  },
                                ),
                              ),
                              // Full Tank Checkbox
                              DataCell(
                                Center(
                                  child: Checkbox(
                                    value: row.isFullTank,
                                    onChanged: (val) {
                                      if (val != null) setState(() => row.isFullTank = val);
                                    },
                                  ),
                                ),
                              ),
                              // Notes Input
                              DataCell(
                                SizedBox(
                                  width: 110,
                                  child: TextField(
                                    controller: row.notesController,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: const InputDecoration(
                                      isDense: true,
                                      hintText: 'Notes',
                                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                                      border: OutlineInputBorder(),
                                    ),
                                  ),
                                ),
                              ),
                              // Delete Button
                              DataCell(
                                IconButton(
                                  icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                  tooltip: 'Delete Row',
                                  onPressed: () => _removeRow(index),
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
          ],
        ),
      ),
    );
  }

  String _cleanFuelType(String raw) {
    const valid = ['Regular (87)', 'Midgrade (89)', 'Premium (93)', 'Super (95)', 'Super (98)', 'Diesel', 'E85'];
    if (valid.contains(raw)) return raw;
    final lower = raw.toLowerCase();
    if (lower.contains('diesel')) return 'Diesel';
    if (lower.contains('premium') || lower.contains('93')) return 'Premium (93)';
    if (lower.contains('super') || lower.contains('95')) return 'Super (95)';
    if (lower.contains('98')) return 'Super (98)';
    if (lower.contains('midgrade') || lower.contains('89')) return 'Midgrade (89)';
    if (lower.contains('e85')) return 'E85';
    return 'Regular (87)';
  }
}

class _EditableDraftRow {
  DateTime dateTime;
  final TextEditingController odometerController;
  final TextEditingController fuelController;
  final TextEditingController priceController;
  final TextEditingController stationController;
  final TextEditingController notesController;
  String fuelType;
  bool isFullTank;

  _EditableDraftRow({
    required this.dateTime,
    required this.odometerController,
    required this.fuelController,
    required this.priceController,
    required this.stationController,
    TextEditingController? notesController,
    this.fuelType = 'Regular (87)',
    this.isFullTank = true,
  }) : notesController = notesController ?? TextEditingController();

  factory _EditableDraftRow.fromDraft(ParsedRecordDraft d) {
    return _EditableDraftRow(
      dateTime: d.dateTime,
      odometerController: TextEditingController(
        text: d.odometer != null ? d.odometer!.toStringAsFixed(1) : '',
      ),
      fuelController: TextEditingController(
        text: d.fuelAmount != null ? d.fuelAmount!.toStringAsFixed(2) : '',
      ),
      priceController: TextEditingController(
        text: d.totalPrice != null ? d.totalPrice!.toStringAsFixed(2) : '',
      ),
      stationController: TextEditingController(text: d.gasStation),
      notesController: TextEditingController(text: d.notes),
      fuelType: d.fuelType,
      isFullTank: d.isFullTank,
    );
  }

  void dispose() {
    odometerController.dispose();
    fuelController.dispose();
    priceController.dispose();
    stationController.dispose();
    notesController.dispose();
  }
}
