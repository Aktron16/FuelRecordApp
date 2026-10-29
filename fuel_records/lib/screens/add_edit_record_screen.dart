import 'package:flutter/material.dart';
import '../models/vehicle.dart';
import '../models/fuel_record.dart';
import '../models/record_calculation.dart';
import '../theme/app_theme.dart';
import '../widgets/vehicle_artwork.dart';
import '../utils/app_date_format.dart';
import '../services/fuel_app_state.dart';
import 'import_preview_screen.dart';

class AddEditRecordScreen extends StatefulWidget {
  final Vehicle vehicle;
  final FuelRecord? recordToEdit;
  final FuelRecord? previousRecord;
  final Function(FuelRecord) onSave;
  final Function(String)? onDelete;

  final List<String>? popularStations;
  final FuelAppState? appState;

  const AddEditRecordScreen({
    super.key,
    required this.vehicle,
    this.recordToEdit,
    this.previousRecord,
    required this.onSave,
    this.onDelete,
    this.popularStations,
    this.appState,
  });

  @override
  State<AddEditRecordScreen> createState() => _AddEditRecordScreenState();
}

class _AddEditRecordScreenState extends State<AddEditRecordScreen> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _selectedDateTime;
  late TextEditingController _odometerController;
  late TextEditingController _fuelAmountController;
  late TextEditingController _totalPriceController;
  late TextEditingController _gasStationController;
  late TextEditingController _notesController;

  late bool _isFullTank;

  final List<String> _commonStations = const [
    'Shell', 'Chevron', 'Exxon', 'Mobil', 'BP',
    'Costco', 'TotalEnergies', 'Circle K', 'Texaco', 'Speedway'
  ];

  @override
  void initState() {
    super.initState();
    final rec = widget.recordToEdit;
    _selectedDateTime = rec?.dateTime ?? DateTime.now();

    _odometerController = TextEditingController(
      text: rec != null ? rec.odometer.toStringAsFixed(1) : '',
    );
    _fuelAmountController = TextEditingController(
      text: rec != null ? rec.fuelAmount.toStringAsFixed(2) : '',
    );
    _totalPriceController = TextEditingController(
      text: rec != null ? rec.totalPrice.toStringAsFixed(2) : '',
    );
    _gasStationController = TextEditingController(text: rec?.gasStation ?? '');
    _notesController = TextEditingController(text: rec?.notes ?? '');

    _isFullTank = rec?.isFullTank ?? true;

    // Auto-prefill odometer with previous if available and new entry
    if (rec == null && widget.previousRecord != null) {
      // Keep empty to require conscious user entry, but hint in placeholder
    }
  }

  @override
  void dispose() {
    _odometerController.dispose();
    _fuelAmountController.dispose();
    _totalPriceController.dispose();
    _gasStationController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );

    if (pickedDate != null && mounted) {
      setState(() {
        _selectedDateTime = DateTime(
          pickedDate.year,
          pickedDate.month,
          pickedDate.day,
          12, // Default noon timestamp without requiring user to pick time
        );
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final id = widget.recordToEdit?.id ?? 'rec_${DateTime.now().millisecondsSinceEpoch}';
    final odo = double.parse(_odometerController.text.trim());
    final fuel = double.parse(_fuelAmountController.text.trim());
    final price = double.parse(_totalPriceController.text.trim());
    final isFull = _isFullTank ||
        (widget.vehicle.tankCapacityInUnit > 0 &&
            fuel >= (widget.vehicle.tankCapacityInUnit * 0.90));

    final record = FuelRecord(
      id: id,
      vehicleId: widget.vehicle.id,
      dateTime: _selectedDateTime,
      odometer: odo,
      fuelAmount: fuel,
      totalPrice: price,
      isFullTank: isFull,
      fuelType: widget.recordToEdit?.fuelType ?? widget.vehicle.fuelType,
      gasStation: _gasStationController.text.trim(),
      notes: _notesController.text.trim(),
    );

    Navigator.of(context).pop();
    widget.onSave(record);
  }

  void _confirmDelete() {
    bool createBackup = true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Delete Fuel Record?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Are you sure you want to delete this fuel record? This action cannot be undone.',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 16),
              InkWell(
                onTap: () => setDialogState(() => createBackup = !createBackup),
                child: Row(
                  children: [
                    Checkbox(
                      value: createBackup,
                      onChanged: (val) => setDialogState(() => createBackup = val ?? false),
                    ),
                    const Expanded(
                      child: Text(
                        'Create backup before deletion',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              onPressed: () async {
                Navigator.of(ctx).pop(); // Dismiss dialog
                if (createBackup && widget.appState != null) {
                  try {
                    await widget.appState!.saveBackupToFile();
                  } catch (_) {}
                }
                if (widget.onDelete != null && widget.recordToEdit != null) {
                  widget.onDelete!(widget.recordToEdit!.id);
                }
                if (mounted) {
                  Navigator.of(context).pop(); // Pop screen
                }
              },
              child: const Text('Delete'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.recordToEdit != null;
    final primaryColor = Color(widget.vehicle.colorValue);

    // Live computed values from current input
    final currentOdo = double.tryParse(_odometerController.text.trim());
    final currentFuel = double.tryParse(_fuelAmountController.text.trim());
    final currentPrice = double.tryParse(_totalPriceController.text.trim());

    final liveRecord = FuelRecord(
      id: 'temp',
      vehicleId: widget.vehicle.id,
      dateTime: _selectedDateTime,
      odometer: currentOdo ?? 0.0,
      fuelAmount: currentFuel ?? 0.0,
      totalPrice: currentPrice ?? 0.0,
      isFullTank: _isFullTank,
    );

    final liveCalc = RecordCalculation(
      current: liveRecord,
      previous: widget.previousRecord,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Change Record' : 'Add Fuel Record'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!isEditing && widget.appState != null)
            IconButton(
              icon: const Icon(Icons.auto_awesome, color: Color(0xFF16A34A)),
              tooltip: 'Import Fuel Data',
              onPressed: () async {
                final nav = Navigator.of(context);
                final imported = await nav.push<bool>(
                  MaterialPageRoute(
                    builder: (ctx) => ImportPreviewScreen(
                      vehicle: widget.vehicle,
                      appState: widget.appState!,
                    ),
                  ),
                );
                if (imported == true) {
                  nav.pop();
                }
              },
            ),
          if (isEditing && widget.onDelete != null)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              tooltip: 'Delete Record',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Vehicle Identification Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor(context),
                    borderRadius: BorderRadius.circular(AppRadii.lg),
                    border: Border.all(color: AppTheme.borderColor(context)),
                  ),
                  child: Row(
                    children: [
                      VehicleArtwork(
                        type: widget.vehicle.type,
                        bodyColor: primaryColor,
                        width: 70,
                        height: 40,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.vehicle.name,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              children: [
                                Text(
                                  widget.vehicle.brand,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppTheme.textSecondaryColor(context),
                                  ),
                                ),
                                if (widget.vehicle.licensePlate != null && widget.vehicle.licensePlate!.trim().isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(color: Colors.black, width: 1.8),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.12),
                                          blurRadius: 2,
                                          offset: const Offset(0, 1),
                                        ),
                                      ],
                                    ),
                                    child: Text(
                                      widget.vehicle.licensePlate!.trim().toUpperCase(),
                                      style: const TextStyle(
                                        fontFamily: 'monospace',
                                        color: Colors.black,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 10,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (widget.previousRecord != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'Last Logged',
                              style: theme.textTheme.labelSmall?.copyWith(color: AppTheme.textMutedColor(context)),
                            ),
                            Text(
                              '${widget.previousRecord!.odometer.toStringAsFixed(0)} ${widget.vehicle.unitDistance}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),

                // Import Fuel Data Button (for creating new records)
                if (!isEditing && widget.appState != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.success,
                      side: const BorderSide(color: AppColors.success, width: 1.4),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.md)),
                    ),
                    icon: const Icon(Icons.auto_awesome, size: 18),
                    label: const Text(
                      'Import Data (Spreadsheet / Text)',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    onPressed: () async {
                      final nav = Navigator.of(context);
                      final imported = await nav.push<bool>(
                        MaterialPageRoute(
                          builder: (ctx) => ImportPreviewScreen(
                            vehicle: widget.vehicle,
                            appState: widget.appState!,
                          ),
                        ),
                      );
                      if (imported == true) {
                        nav.pop();
                      }
                    },
                  ),
                ],

                const SizedBox(height: 18),

                // Live Calculation Feedback Banner
                if ((currentFuel != null && currentFuel > 0 && currentPrice != null && currentPrice > 0) ||
                    (currentOdo != null && widget.previousRecord != null))
                  Container(
                    margin: const EdgeInsets.only(bottom: 18),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor(context),
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      border: Border.all(color: primaryColor.withValues(alpha: 0.35), width: 1.2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.auto_graph, size: 18, color: primaryColor),
                            const SizedBox(width: 8),
                            Text(
                              'Live Instant Metrics Preview',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                                color: primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 12,
                          runSpacing: 10,
                          children: [
                            if (currentFuel != null && currentPrice != null && currentFuel > 0)
                              _buildMetricChip(
                                label: 'Price / ${widget.vehicle.unitVolume}',
                                value: '${widget.vehicle.currency}${liveCalc.pricePerUnit.toStringAsFixed(3)}',
                                color: AppColors.primary,
                              ),
                            if (liveCalc.distanceTraveled != null)
                              _buildMetricChip(
                                label: 'Trip Distance',
                                value: '+${liveCalc.distanceTraveled!.toStringAsFixed(1)} ${widget.vehicle.unitDistance}',
                                color: AppColors.success,
                              ),
                            if (liveCalc.fuelEfficiency != null)
                              _buildMetricChip(
                                label: 'Efficiency',
                                value: '${liveCalc.fuelEfficiency!.toStringAsFixed(2)} ${widget.vehicle.unitDistance}/${widget.vehicle.unitVolume}',
                                color: const Color(0xFF0D9488),
                              ),
                            if (liveCalc.daysSincePrevious != null)
                              _buildMetricChip(
                                label: 'Days Since Last',
                                value: '${liveCalc.daysSincePrevious!.toStringAsFixed(1)} d',
                                color: AppColors.orange,
                              ),
                            if (liveCalc.priceDifferencePerUnit != null)
                              _buildMetricChip(
                                label: 'Price Change',
                                value: '${liveCalc.priceDifferencePerUnit! >= 0 ? '+' : ''}${widget.vehicle.currency}${liveCalc.priceDifferencePerUnit!.toStringAsFixed(3)}',
                                color: liveCalc.priceDifferencePerUnit! > 0 ? AppColors.danger : AppColors.success,
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),

                // Date Picker Row (Date Only)
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(AppRadii.md),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppTheme.borderColor(context)),
                      borderRadius: BorderRadius.circular(AppRadii.md),
                      color: AppTheme.surfaceColor(context),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.calendar_month, color: primaryColor),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Record Date (Date Only)',
                                style: theme.textTheme.labelSmall?.copyWith(color: Colors.grey),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                AppDateUtils.format(_selectedDateTime),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'Change Date',
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 18),

                // Total Odometer Input
                TextFormField(
                  controller: _odometerController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Total Odometer Reading (${widget.vehicle.unitDistance}) *',
                    hintText: widget.previousRecord != null
                        ? 'e.g. ${(widget.previousRecord!.odometer + 450).toStringAsFixed(0)}'
                        : 'e.g. 45200',
                    prefixIcon: const Icon(Icons.speed),
                    suffixText: widget.vehicle.unitDistance,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter total ${widget.vehicle.unitDistance}';
                    }
                    final parsed = double.tryParse(val.trim());
                    if (parsed == null || parsed < 0) {
                      return 'Enter a valid positive number';
                    }
                    if (widget.previousRecord != null && parsed < widget.previousRecord!.odometer) {
                      return 'Must be >= previous reading (${widget.previousRecord!.odometer.toStringAsFixed(0)} ${widget.vehicle.unitDistance})';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 16),

                // Fuel Amount Filled & Total Price Row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fuel Amount
                    Expanded(
                      child: TextFormField(
                        controller: _fuelAmountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Fuel Amount (${widget.vehicle.unitVolume}) *',
                          hintText: 'e.g. 45.5',
                          prefixIcon: const Icon(Icons.local_gas_station),
                          suffixText: widget.vehicle.unitVolume,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Enter amount';
                          }
                          final parsed = double.tryParse(val.trim());
                          if (parsed == null || parsed <= 0) {
                            return '> 0 required';
                          }
                          return null;
                        },
                        onChanged: (val) {
                          final parsed = double.tryParse(val.trim());
                          if (parsed != null && widget.vehicle.tankCapacityInUnit > 0) {
                            if (parsed >= (widget.vehicle.tankCapacityInUnit * 0.90)) {
                              _isFullTank = true;
                            }
                          }
                          setState(() {});
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Total Price
                    Expanded(
                      child: TextFormField(
                        controller: _totalPriceController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(
                          labelText: 'Total Price (${widget.vehicle.currency}) *',
                          hintText: 'e.g. 82.50',
                          prefixIcon: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                            child: Text(
                              widget.vehicle.currency,
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: primaryColor,
                              ),
                            ),
                          ),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                          filled: true,
                        ),
                        validator: (val) {
                          if (val == null || val.trim().isEmpty) {
                            return 'Enter price';
                          }
                          final parsed = double.tryParse(val.trim());
                          if (parsed == null || parsed <= 0) {
                            return '> 0 required';
                          }
                          return null;
                        },
                        onChanged: (val) {
                          final parsed = double.tryParse(val.trim());
                          if (parsed != null && widget.vehicle.tankCapacityInUnit > 0) {
                            if (parsed >= (widget.vehicle.tankCapacityInUnit * 0.90)) {
                              _isFullTank = true;
                            }
                          }
                          setState(() {});
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Full Tank Switch
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Full Tank Fill-up', style: TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: const Text('Enables precise fuel efficiency calculations', style: TextStyle(fontSize: 12)),
                    value: _isFullTank,
                    activeColor: primaryColor,
                    onChanged: (val) => setState(() => _isFullTank = val),
                  ),
                ),

                const SizedBox(height: 16),

                // Gas Station Input & Suggestions
                TextFormField(
                  controller: _gasStationController,
                  decoration: InputDecoration(
                    labelText: 'Gas Station / Brand (Optional)',
                    hintText: 'e.g. Shell, BP, Costco',
                    prefixIcon: const Icon(Icons.store),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                  ),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: (widget.popularStations ?? _commonStations).map((st) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(st, style: const TextStyle(fontSize: 11)),
                          onPressed: () {
                            setState(() => _gasStationController.text = st);
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 16),

                // Notes
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Notes / Comments (Optional)',
                    hintText: 'e.g. AC running, highway driving, tire pressure 35 PSI',
                    prefixIcon: const Icon(Icons.note_alt_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                  ),
                ),

                const SizedBox(height: 28),

                // Action Button (Save / Update)
                ElevatedButton.icon(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 3,
                  ),
                  icon: Icon(isEditing ? Icons.save : Icons.add_circle_outline),
                  label: Text(
                    isEditing ? 'Update Fuel Record' : 'Save Fuel Record',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),

                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricChip({
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppRadii.sm),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

