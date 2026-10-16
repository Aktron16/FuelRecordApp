import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/vehicle.dart';
import '../models/fuel_record.dart';
import '../models/record_calculation.dart';
import '../services/fuel_app_state.dart';
import 'add_edit_record_screen.dart';

class RecordsListScreen extends StatefulWidget {
  final FuelAppState appState;

  const RecordsListScreen({
    super.key,
    required this.appState,
  });

  @override
  State<RecordsListScreen> createState() => _RecordsListScreenState();
}

class _RecordsListScreenState extends State<RecordsListScreen> {
  String _searchQuery = '';
  String _sortOption = 'newest'; // 'newest', 'oldest', 'highest_price', 'highest_eff'

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.appState.activeVehicle;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (vehicle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Fuel Records')),
        body: const Center(
          child: Text('No active vehicle selected.'),
        ),
      );
    }

    final primaryColor = Color(vehicle.colorValue);
    final allRecords = widget.appState.activeVehicleRecordsAscending;

    // Filter by search query
    var filtered = allRecords.where((r) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return r.gasStation.toLowerCase().contains(q) ||
          r.fuelType.toLowerCase().contains(q) ||
          r.notes.toLowerCase().contains(q) ||
          r.odometer.toString().contains(q);
    }).toList();

    // Sort
    switch (_sortOption) {
      case 'oldest':
        // already ascending
        break;
      case 'highest_price':
        filtered.sort((a, b) => b.totalPrice.compareTo(a.totalPrice));
        break;
      case 'newest':
      default:
        filtered = filtered.reversed.toList();
        break;
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Fuel Records History', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(
              '${vehicle.name} • ${allRecords.length} entries',
              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withOpacity(0.6)),
            ),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort Records',
            onSelected: (val) => setState(() => _sortOption = val),
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: 'newest', child: Text('Sort: Newest First')),
              const PopupMenuItem(value: 'oldest', child: Text('Sort: Oldest First')),
              const PopupMenuItem(value: 'highest_price', child: Text('Sort: Highest Price')),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export CSV',
            onPressed: () {
              final csv = widget.appState.exportRecordsToCsv(vehicle.id);
              _showExportDialog(context, 'CSV Export for ${vehicle.name}', csv);
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Record', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          final sortedAsc = widget.appState.activeVehicleRecordsAscending;
          final lastRecord = sortedAsc.isNotEmpty ? sortedAsc.last : null;

          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => AddEditRecordScreen(
                vehicle: vehicle,
                previousRecord: lastRecord,
                popularStations: widget.appState.currentCountryInfo.popularStations,
                onSave: (newRec) => widget.appState.addRecord(newRec),
              ),
            ),
          );
        },
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search by station, grade, notes...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
              ),
              onChanged: (val) => setState(() => _searchQuery = val),
            ),
          ),

          // List of Records
          Expanded(
            child: filtered.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isEmpty ? 'No fuel records found' : 'No matching records',
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _searchQuery.isEmpty
                              ? 'Tap "+ Add Record" below to create your first entry!'
                              : 'Try adjusting your search keywords.',
                          style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final record = filtered[index];
                      final calc = widget.appState.getCalculationForRecord(record);

                      return _buildRecordCard(context, vehicle, record, calc, primaryColor, isDark);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordCard(
    BuildContext context,
    Vehicle vehicle,
    FuelRecord record,
    RecordCalculation calc,
    Color primaryColor,
    bool isDark,
  ) {
    final theme = Theme.of(context);
    final dateStr = DateFormat('EEE, MMM d, yyyy • hh:mm a').format(record.dateTime);

    return Card(
      elevation: 1.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Colors.grey.withOpacity(isDark ? 0.2 : 0.1)),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => _showRecordDetailsModal(context, vehicle, record, calc),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Header: Date and Edit Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(
                        dateStr,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface.withOpacity(0.75),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      // Change/Edit Button
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 14),
                        label: const Text('Change', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                        onPressed: () {
                          // Find chronological previous record
                          final sortedAsc = widget.appState.activeVehicleRecordsAscending;
                          final recIdx = sortedAsc.indexWhere((r) => r.id == record.id);
                          final prev = recIdx > 0 ? sortedAsc[recIdx - 1] : null;

                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (ctx) => AddEditRecordScreen(
                                vehicle: vehicle,
                                recordToEdit: record,
                                previousRecord: prev,
                                popularStations: widget.appState.currentCountryInfo.popularStations,
                                onSave: (updated) => widget.appState.updateRecord(updated),
                                onDelete: (id) => widget.appState.deleteRecord(id),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),

              const Divider(height: 18),

              // Main Numbers Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  // Total Price
                  Text(
                    '${vehicle.currency}${record.totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'for ${record.fuelAmount.toStringAsFixed(2)} ${vehicle.unitVolume}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: theme.colorScheme.onSurface.withOpacity(0.7),
                    ),
                  ),
                  const Spacer(),
                  // Price per litre/unit
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${vehicle.currency}${calc.pricePerUnit.toStringAsFixed(3)} / ${vehicle.unitVolume}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: primaryColor,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // Computed Metrics Grid
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.black.withOpacity(0.25) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.grey.withOpacity(0.15)),
                ),
                child: Row(
                  children: [
                    // Distance Traveled
                    Expanded(
                      child: _buildMetricTile(
                        icon: Icons.route,
                        label: 'Distance Went',
                        value: calc.distanceTraveled != null
                            ? '+${calc.distanceTraveled!.toStringAsFixed(1)} ${vehicle.unitDistance}'
                            : 'First Log',
                        color: Colors.blueAccent,
                      ),
                    ),
                    Container(height: 32, width: 1, color: Colors.grey.withOpacity(0.3)),
                    // Fuel Efficiency
                    Expanded(
                      child: _buildMetricTile(
                        icon: Icons.speed,
                        label: 'Efficiency',
                        value: calc.fuelEfficiency != null
                            ? '${calc.fuelEfficiency!.toStringAsFixed(2)} ${vehicle.unitDistance}/${vehicle.unitVolume}'
                            : 'Pending',
                        color: Colors.green,
                      ),
                    ),
                    Container(height: 32, width: 1, color: Colors.grey.withOpacity(0.3)),
                    // Price Increase / Decrease
                    Expanded(
                      child: _buildMetricTile(
                        icon: calc.priceDifferencePerUnit == null
                            ? Icons.horizontal_rule
                            : (calc.priceDifferencePerUnit! > 0 ? Icons.trending_up : Icons.trending_down),
                        label: 'Price Change',
                        value: calc.priceDifferencePerUnit != null
                            ? '${calc.priceDifferencePerUnit! >= 0 ? '+' : ''}${vehicle.currency}${calc.priceDifferencePerUnit!.toStringAsFixed(3)}'
                            : 'N/A',
                        color: calc.priceDifferencePerUnit == null
                            ? Colors.grey
                            : (calc.priceDifferencePerUnit! > 0 ? Colors.redAccent : Colors.green),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 10),

              // Bottom Info: Odometer, Days Since Last, Station
              Row(
                children: [
                  Icon(Icons.pin_drop_outlined, size: 14, color: Colors.grey.shade600),
                  const SizedBox(width: 4),
                  Text(
                    '${record.odometer.toStringAsFixed(1)} ${vehicle.unitDistance}',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 14),
                  if (calc.daysSincePrevious != null) ...[
                    Icon(Icons.hourglass_bottom, size: 14, color: Colors.orange.shade700),
                    const SizedBox(width: 4),
                    Text(
                      '${calc.daysSincePrevious!.toStringAsFixed(1)} days since last',
                      style: TextStyle(fontSize: 12, color: Colors.orange.shade700, fontWeight: FontWeight.w600),
                    ),
                  ],
                  const Spacer(),
                  if (record.gasStation.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        record.gasStation,
                        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 3),
            Flexible(
              child: Text(
                label,
                style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w600),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  void _showRecordDetailsModal(
    BuildContext context,
    Vehicle vehicle,
    FuelRecord record,
    RecordCalculation calc,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Full Record Calculations',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              _detailRow('Date & Time', DateFormat('yyyy-MM-dd HH:mm').format(record.dateTime)),
              _detailRow('Odometer Reading', '${record.odometer.toStringAsFixed(1)} ${vehicle.unitDistance}'),
              _detailRow('Fuel Filled', '${record.fuelAmount.toStringAsFixed(2)} ${vehicle.unitVolume}'),
              _detailRow('Total Cost', '${vehicle.currency}${record.totalPrice.toStringAsFixed(2)}'),
              _detailRow('Price per ${vehicle.unitVolume}', '${vehicle.currency}${calc.pricePerUnit.toStringAsFixed(3)}'),

              const Divider(height: 24),

              Text('Calculated Intervals & Metrics', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue.shade700)),
              const SizedBox(height: 8),

              _detailRow(
                'Distance Traveled Since Last',
                calc.distanceTraveled != null
                    ? '${calc.distanceTraveled!.toStringAsFixed(1)} ${vehicle.unitDistance}'
                    : 'N/A (First record)',
              ),
              _detailRow(
                'Days Since Last Fueled',
                calc.daysSincePrevious != null
                    ? '${calc.daysSincePrevious!.toStringAsFixed(1)} days'
                    : 'N/A',
              ),
              _detailRow(
                'Fuel Efficiency',
                calc.fuelEfficiency != null
                    ? '${calc.fuelEfficiency!.toStringAsFixed(2)} ${vehicle.unitDistance}/${vehicle.unitVolume}'
                    : 'N/A',
              ),
              _detailRow(
                'Consumption (per 100)',
                calc.consumptionPer100Units != null
                    ? '${calc.consumptionPer100Units!.toStringAsFixed(2)} ${vehicle.unitVolume}/100${vehicle.unitDistance}'
                    : 'N/A',
              ),
              _detailRow(
                'Price Change vs Previous',
                calc.priceDifferencePerUnit != null
                    ? '${calc.priceDifferencePerUnit! >= 0 ? '+' : ''}${vehicle.currency}${calc.priceDifferencePerUnit!.toStringAsFixed(3)} (${calc.priceDifferencePercentage?.toStringAsFixed(1)}%)'
                    : 'N/A',
              ),
              _detailRow(
                'Cost per ${vehicle.unitDistance}',
                calc.costPerDistance != null
                    ? '${vehicle.currency}${calc.costPerDistance!.toStringAsFixed(3)} / ${vehicle.unitDistance}'
                    : 'N/A',
              ),
              _detailRow(
                'Daily Distance Driven',
                calc.dailyDistance != null
                    ? '${calc.dailyDistance!.toStringAsFixed(1)} ${vehicle.unitDistance} / day'
                    : 'N/A',
              ),

              if (record.gasStation.isNotEmpty) _detailRow('Gas Station', record.gasStation),
              if (record.fuelType.isNotEmpty) _detailRow('Fuel Type', record.fuelType),
              if (record.notes.isNotEmpty) _detailRow('Notes', record.notes),

              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      ),
    );
  }

  void _showExportDialog(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              content,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
