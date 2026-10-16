import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/record_calculation.dart';
import '../services/fuel_app_state.dart';

class RecordsTableScreen extends StatefulWidget {
  final FuelAppState appState;

  const RecordsTableScreen({super.key, required this.appState});

  @override
  State<RecordsTableScreen> createState() => _RecordsTableScreenState();
}

class _RecordsTableScreenState extends State<RecordsTableScreen> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    super.dispose();
  }

  void _openColumnGraphModal(
    BuildContext context, {
    required String columnTitle,
    required String unit,
    required List<double> values,
    required List<DateTime> dates,
    required Color color,
  }) {
    if (values.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least 2 records are required to plot a trend graph.')),
      );
      return;
    }

    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final avgVal = values.reduce((a, b) => a + b) / values.length;
    final diff = values.last - values.first;
    final isIncrease = diff >= 0;

    final spots = <FlSpot>[];
    for (int i = 0; i < values.length; i++) {
      spots.add(FlSpot(i.toDouble(), values[i]));
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 14),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$columnTitle Trend',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Graph of increase / decrease over time ($unit)',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // KPI Summary row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _statBox('Average', avgVal.toStringAsFixed(2), color),
                  _statBox('Min', minVal.toStringAsFixed(2), Colors.blueGrey),
                  _statBox('Max', maxVal.toStringAsFixed(2), Colors.purple),
                  _statBox(
                    'Net Change',
                    '${isIncrease ? '+' : ''}${diff.toStringAsFixed(2)}',
                    isIncrease ? Colors.green : Colors.redAccent,
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Interactive fl_chart LineChart
              Container(
                height: 220,
                padding: const EdgeInsets.fromLTRB(10, 16, 16, 10),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E28) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: false,
                      getDrawingHorizontalLine: (_) => FlLine(
                        color: Colors.grey.withValues(alpha: 0.15),
                        strokeWidth: 1,
                      ),
                    ),
                    titlesData: FlTitlesData(
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 22,
                          getTitlesWidget: (val, _) {
                            final idx = val.toInt();
                            if (idx < 0 || idx >= dates.length) return const SizedBox.shrink();
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                DateFormat('M/d').format(dates[idx]),
                                style: const TextStyle(fontSize: 9, color: Colors.grey),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 40,
                          getTitlesWidget: (val, _) => Text(
                            val.toStringAsFixed(1),
                            style: const TextStyle(fontSize: 9, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                    borderData: FlBorderData(show: false),
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: color,
                        barWidth: 3,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: true),
                        belowBarData: BarAreaData(
                          show: true,
                          color: color.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.appState.activeVehicle;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (vehicle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Excel Table View')),
        body: const Center(child: Text('No active vehicle')),
      );
    }

    final records = widget.appState.activeVehicleRecordsAscending;
    final calculations = <RecordCalculation>[];
    for (int i = 0; i < records.length; i++) {
      final prev = i > 0 ? records[i - 1] : null;
      calculations.add(RecordCalculation(current: records[i], previous: prev));
    }

    // Prepare lists for column click graph visualizer
    final dates = records.map((r) => r.dateTime).toList();
    final odometers = records.map((r) => r.odometer).toList();
    final fuelAmounts = records.map((r) => r.fuelAmount).toList();
    final totalPrices = records.map((r) => r.totalPrice).toList();
    final pricesPerUnit = records.map((r) => r.pricePerUnit).toList();

    final distances = <double>[];
    final distanceDates = <DateTime>[];
    final efficiencies = <double>[];
    final effDates = <DateTime>[];
    final consumptions = <double>[];
    final daysList = <double>[];

    for (final c in calculations) {
      if (c.distanceTraveled != null) {
        distances.add(c.distanceTraveled!);
        distanceDates.add(c.current.dateTime);
      }
      if (c.fuelEfficiency != null) {
        efficiencies.add(c.fuelEfficiency!);
        effDates.add(c.current.dateTime);
      }
      if (c.consumptionPer100Units != null) {
        consumptions.add(c.consumptionPer100Units!);
      }
      if (c.daysSincePrevious != null) {
        daysList.add(c.daysSincePrevious!);
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Excel / Table Metrics View', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text('${vehicle.name} • Tap any column title to graph it!', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export CSV',
            onPressed: () {
              final csv = widget.appState.exportRecordsToCsv(vehicle.id);
              _showExportModal(context, 'Exported CSV Data', csv);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Unit quick toggle bar on the fly
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: isDark ? Colors.black26 : Colors.blue.withValues(alpha: 0.05),
            child: Row(
              children: [
                const Icon(Icons.swap_horiz, size: 16, color: Colors.blueAccent),
                const SizedBox(width: 8),
                const Text('View Units (Instance Switch):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                const Spacer(),
                SegmentedButton<String>(
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: const [
                    ButtonSegment(value: 'km/L', label: Text('km/L', style: TextStyle(fontSize: 10))),
                    ButtonSegment(value: 'L/100km', label: Text('L/100km', style: TextStyle(fontSize: 10))),
                    ButtonSegment(value: 'MPG', label: Text('MPG', style: TextStyle(fontSize: 10))),
                  ],
                  selected: {widget.appState.activeEfficiencyUnit},
                  onSelectionChanged: (set) => widget.appState.setTemporaryEfficiencyUnit(set.first),
                ),
              ],
            ),
          ),

          // Scrollable Excel Data Table
          Expanded(
            child: records.isEmpty
                ? const Center(child: Text('No fuel records to display in table.'))
                : Scrollbar(
                    controller: _horizontalController,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _horizontalController,
                      scrollDirection: Axis.horizontal,
                      child: Scrollbar(
                        controller: _verticalController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _verticalController,
                          scrollDirection: Axis.vertical,
                          child: DataTable(
                            headingRowColor: WidgetStateProperty.all(
                              isDark ? const Color(0xFF262838) : Colors.blueGrey.shade100,
                            ),
                            dataRowColor: WidgetStateProperty.resolveWith<Color?>((Set<WidgetState> states) {
                              return null; // auto zebra
                            }),
                            columns: [
                              _buildGraphableColumn(
                                label: 'Date',
                                tooltip: 'Date of fill-up',
                                icon: Icons.calendar_today,
                                onTap: null,
                              ),
                              _buildGraphableColumn(
                                label: 'Odometer (${vehicle.unitDistance})',
                                tooltip: 'Tap to graph odometer increase',
                                icon: Icons.speed,
                                onTap: () => _openColumnGraphModal(
                                  context,
                                  columnTitle: 'Odometer Reading',
                                  unit: vehicle.unitDistance,
                                  values: odometers,
                                  dates: dates,
                                  color: Colors.blue,
                                ),
                              ),
                              _buildGraphableColumn(
                                label: 'Fuel (${vehicle.unitVolume})',
                                tooltip: 'Tap to graph fuel filled',
                                icon: Icons.local_gas_station,
                                onTap: () => _openColumnGraphModal(
                                  context,
                                  columnTitle: 'Fuel Filled',
                                  unit: vehicle.unitVolume,
                                  values: fuelAmounts,
                                  dates: dates,
                                  color: Colors.teal,
                                ),
                              ),
                              _buildGraphableColumn(
                                label: 'Total Cost (${vehicle.currency})',
                                tooltip: 'Tap to graph total spent',
                                icon: Icons.attach_money,
                                onTap: () => _openColumnGraphModal(
                                  context,
                                  columnTitle: 'Total Cost',
                                  unit: vehicle.currency,
                                  values: totalPrices,
                                  dates: dates,
                                  color: Colors.amber.shade800,
                                ),
                              ),
                              _buildGraphableColumn(
                                label: 'Price / ${vehicle.unitVolume}',
                                tooltip: 'Tap to graph fuel price trend',
                                icon: Icons.price_change,
                                onTap: () => _openColumnGraphModal(
                                  context,
                                  columnTitle: 'Price per ${vehicle.unitVolume}',
                                  unit: '${vehicle.currency}/${vehicle.unitVolume}',
                                  values: pricesPerUnit,
                                  dates: dates,
                                  color: Colors.redAccent,
                                ),
                              ),
                              _buildGraphableColumn(
                                label: 'Distance Went (+${vehicle.unitDistance})',
                                tooltip: 'Tap to graph trip distance',
                                icon: Icons.route,
                                onTap: () => _openColumnGraphModal(
                                  context,
                                  columnTitle: 'Distance Traveled Since Last',
                                  unit: vehicle.unitDistance,
                                  values: distances,
                                  dates: distanceDates,
                                  color: Colors.indigo,
                                ),
                              ),
                              _buildGraphableColumn(
                                label: 'Efficiency (${widget.appState.activeEfficiencyUnit})',
                                tooltip: 'Tap to graph fuel efficiency',
                                icon: Icons.auto_graph,
                                onTap: () => _openColumnGraphModal(
                                  context,
                                  columnTitle: 'Fuel Efficiency for Refuel',
                                  unit: widget.appState.activeEfficiencyUnit,
                                  values: efficiencies,
                                  dates: effDates,
                                  color: Colors.green,
                                ),
                              ),
                              _buildGraphableColumn(
                                label: 'L/100km',
                                tooltip: 'Tap to graph consumption',
                                icon: Icons.eco,
                                onTap: () => _openColumnGraphModal(
                                  context,
                                  columnTitle: 'Fuel Consumption',
                                  unit: 'L/100km',
                                  values: consumptions,
                                  dates: effDates,
                                  color: Colors.cyan,
                                ),
                              ),
                              _buildGraphableColumn(
                                label: 'Days Since Last',
                                tooltip: 'Days elapsed between fill-ups',
                                icon: Icons.hourglass_bottom,
                                onTap: () => _openColumnGraphModal(
                                  context,
                                  columnTitle: 'Days Between Refuels',
                                  unit: 'days',
                                  values: daysList,
                                  dates: effDates,
                                  color: Colors.deepOrange,
                                ),
                              ),
                              const DataColumn(label: Text('Gas Station')),
                              const DataColumn(label: Text('Fuel Grade')),
                              const DataColumn(label: Text('Full Tank')),
                              const DataColumn(label: Text('Notes')),
                            ],
                            rows: List<DataRow>.generate(records.length, (index) {
                              final rec = records[index];
                              final calc = calculations[index];

                              // Convert efficiency to active temporary unit if requested
                              String effDisplay = 'N/A';
                              if (calc.fuelEfficiency != null) {
                                final effBaseKmPerL = calc.fuelEfficiency!;
                                if (widget.appState.activeEfficiencyUnit == 'L/100km') {
                                  effDisplay = calc.consumptionPer100Units != null
                                      ? '${calc.consumptionPer100Units!.toStringAsFixed(2)} L/100km'
                                      : 'N/A';
                                } else if (widget.appState.activeEfficiencyUnit == 'MPG') {
                                  final mpg = effBaseKmPerL * 2.35215;
                                  effDisplay = '${mpg.toStringAsFixed(2)} MPG';
                                } else {
                                  effDisplay = '${effBaseKmPerL.toStringAsFixed(2)} km/L';
                                }
                              }

                              return DataRow(
                                color: WidgetStateProperty.resolveWith<Color?>((states) {
                                  if (index.isEven) {
                                    return isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.withValues(alpha: 0.06);
                                  }
                                  return null;
                                }),
                                cells: [
                                  DataCell(Text(DateFormat('yyyy-MM-dd').format(rec.dateTime), style: const TextStyle(fontWeight: FontWeight.bold))),
                                  DataCell(Text(rec.odometer.toStringAsFixed(1))),
                                  DataCell(Text(rec.fuelAmount.toStringAsFixed(2))),
                                  DataCell(Text('${vehicle.currency}${rec.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600))),
                                  DataCell(Text('${vehicle.currency}${calc.pricePerUnit.toStringAsFixed(3)}')),
                                  DataCell(Text(
                                    calc.distanceTraveled != null ? '+${calc.distanceTraveled!.toStringAsFixed(1)}' : 'First Log',
                                    style: TextStyle(
                                      color: calc.distanceTraveled != null ? Colors.blueAccent : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )),
                                  DataCell(Text(effDisplay, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                                  DataCell(Text(calc.consumptionPer100Units != null ? calc.consumptionPer100Units!.toStringAsFixed(2) : '-')),
                                  DataCell(Text(calc.daysSincePrevious != null ? '${calc.daysSincePrevious!.toStringAsFixed(1)} d' : '-')),
                                  DataCell(Text(rec.gasStation.isNotEmpty ? rec.gasStation : '-')),
                                  DataCell(Text(rec.fuelType)),
                                  DataCell(Icon(rec.isFullTank ? Icons.check_circle : Icons.radio_button_unchecked, size: 16, color: rec.isFullTank ? Colors.green : Colors.grey)),
                                  DataCell(Text(rec.notes.isNotEmpty ? rec.notes : '-')),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  DataColumn _buildGraphableColumn({
    required String label,
    required String tooltip,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return DataColumn(
      tooltip: tooltip,
      label: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
              if (onTap != null) ...[
                const SizedBox(width: 4),
                const Icon(Icons.show_chart, size: 14, color: Colors.blueAccent),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showExportModal(BuildContext context, String title, String content) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(content, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }
}
