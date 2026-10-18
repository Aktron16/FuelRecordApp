import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/vehicle.dart';
import '../models/record_calculation.dart';
import '../services/fuel_app_state.dart';
import '../utils/app_date_format.dart';

class RecordsTableScreen extends StatefulWidget {
  final FuelAppState appState;

  const RecordsTableScreen({super.key, required this.appState});

  @override
  State<RecordsTableScreen> createState() => _RecordsTableScreenState();
}

class _RecordsTableScreenState extends State<RecordsTableScreen> {
  final ScrollController _headerHorizontalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _leftVerticalController = ScrollController();
  final ScrollController _rightVerticalController = ScrollController();
  Set<String> _selectedRecordIds = <String>{};
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _headerHorizontalController.addListener(() {
      if (!_isSyncing && _headerHorizontalController.hasClients && _horizontalController.hasClients) {
        _isSyncing = true;
        _horizontalController.jumpTo(_headerHorizontalController.offset);
        _isSyncing = false;
      }
    });
    _horizontalController.addListener(() {
      if (!_isSyncing && _horizontalController.hasClients && _headerHorizontalController.hasClients) {
        _isSyncing = true;
        _headerHorizontalController.jumpTo(_horizontalController.offset);
        _isSyncing = false;
      }
    });
    _leftVerticalController.addListener(() {
      if (!_isSyncing && _leftVerticalController.hasClients && _rightVerticalController.hasClients) {
        _isSyncing = true;
        _rightVerticalController.jumpTo(_leftVerticalController.offset);
        _isSyncing = false;
      }
    });
    _rightVerticalController.addListener(() {
      if (!_isSyncing && _rightVerticalController.hasClients && _leftVerticalController.hasClients) {
        _isSyncing = true;
        _leftVerticalController.jumpTo(_rightVerticalController.offset);
        _isSyncing = false;
      }
    });
  }

  @override
  void dispose() {
    _headerHorizontalController.dispose();
    _horizontalController.dispose();
    _leftVerticalController.dispose();
    _rightVerticalController.dispose();
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

    final count = values.length > 8 ? 8 : values.length;
    final plotValues = values.sublist(values.length - count);
    final plotDates = dates.sublist(dates.length - count);

    final minVal = plotValues.reduce((a, b) => a < b ? a : b);
    final maxVal = plotValues.reduce((a, b) => a > b ? a : b);
    final avgVal = plotValues.reduce((a, b) => a + b) / plotValues.length;
    final diff = plotValues.last - plotValues.first;
    final isIncrease = diff >= 0;

    // Adjust y-axis range with headroom and footroom so the trend curve never dips into bottom axis text
    final valRange = maxVal - minVal;
    final yMargin = valRange == 0
        ? (minVal == 0 ? 1.0 : (minVal.abs() * 0.15).clamp(1.0, 50.0))
        : valRange * 0.20;
    final minY = minVal - yMargin;
    final maxY = maxVal + yMargin;

    final spots = <FlSpot>[];
    for (int i = 0; i < plotValues.length; i++) {
      spots.add(FlSpot(i.toDouble(), plotValues[i]));
    }

    bool hasSameMonthNeighbor(int i) {
      final current = plotDates[i];
      if (i > 0) {
        final prev = plotDates[i - 1];
        if (prev.year == current.year && prev.month == current.month) return true;
      }
      if (i < plotDates.length - 1) {
        final next = plotDates[i + 1];
        if (next.year == current.year && next.month == current.month) return true;
      }
      return false;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        final axisTextColor = isDark ? const Color(0xFFE2E8F0) : const Color(0xFF1E293B);

        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(ctx).padding.bottom + 48),
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
                    minY: minY,
                    maxY: maxY,
                    clipData: const FlClipData.all(),
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
                          reservedSize: 38,
                          interval: 1,
                          getTitlesWidget: (val, _) {
                            final idx = val.toInt();
                            if (idx < 0 || idx >= plotDates.length) return const SizedBox.shrink();
                            final showDate = hasSameMonthNeighbor(idx);
                            final monthStr = DateFormat('MMM').format(plotDates[idx]);
                            final label = showDate ? '$monthStr\n${plotDates[idx].day}' : monthStr;
                            return Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Text(
                                label,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  color: axisTextColor,
                                  height: 1.15,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 42,
                          getTitlesWidget: (val, _) => Text(
                            val.toStringAsFixed(1),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: axisTextColor,
                            ),
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
                        dotData: FlDotData(
                          show: true,
                          getDotPainter: (spot, percent, barData, index) {
                            return FlDotCirclePainter(
                              radius: 4,
                              color: color,
                              strokeColor: isDark ? const Color(0xFF1E1E28) : Colors.white,
                              strokeWidth: 2,
                            );
                          },
                        ),
                        belowBarData: BarAreaData(
                          show: true,
                          color: color.withValues(alpha: 0.15),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
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

  /// Builds metric value with formatted and color-coded delta
  /// Green if increased, orange if decreased
  Widget _buildValueWithDelta({
    required String valueStr,
    required double? delta,
    Color baseColor = Colors.green,
  }) {
    if (delta == null) {
      return Text(
        valueStr,
        style: TextStyle(color: baseColor, fontWeight: FontWeight.bold),
      );
    }

    final isIncrease = delta > 0.005;
    final isDecrease = delta < -0.005;
    final deltaSign = isIncrease ? '+' : '';
    final deltaColor = isIncrease
        ? Colors.green
        : (isDecrease ? Colors.orange.shade800 : Colors.grey);

    return RichText(
      text: TextSpan(
        style: const TextStyle(fontSize: 13, fontFamily: 'Roboto'),
        children: [
          TextSpan(
            text: '$valueStr ',
            style: TextStyle(color: baseColor, fontWeight: FontWeight.bold),
          ),
          TextSpan(
            text: '($deltaSign${delta.toStringAsFixed(2)})',
            style: TextStyle(color: deltaColor, fontWeight: FontWeight.w700),
          ),
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
        appBar: AppBar(title: const Text('Data Grid View')),
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

    final isMi = vehicle.unitDistance == 'mi';
    final effUnit = isMi ? 'MPG' : 'km/L';
    final effMultiplier = isMi ? 2.35215 : 1.0;

    for (final c in calculations) {
      if (c.distanceTraveled != null) {
        distances.add(c.distanceTraveled!);
        distanceDates.add(c.current.dateTime);
      }
      if (c.fuelEfficiency != null) {
        efficiencies.add(c.fuelEfficiency! * effMultiplier);
        effDates.add(c.current.dateTime);
      }
      if (c.consumptionPer100Units != null) {
        consumptions.add(c.consumptionPer100Units!);
      }
      if (c.daysSincePrevious != null) {
        daysList.add(c.daysSincePrevious!);
      }
    }

    final headerColumns = [
      _buildGraphableColumn(
        width: 105,
        label: 'Date',
        tooltip: 'Date of fill-up',
        icon: Icons.calendar_today,
        onTap: null,
      ),
      _buildGraphableColumn(
        width: 125,
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
        width: 150,
        label: 'Distance Travelled (${vehicle.unitDistance})',
        tooltip: 'Tap to graph trip distance',
        icon: Icons.route,
        onTap: () => _openColumnGraphModal(
          context,
          columnTitle: 'Distance Travelled',
          unit: vehicle.unitDistance,
          values: distances,
          dates: distanceDates,
          color: Colors.indigo,
        ),
      ),
      _buildGraphableColumn(
        width: 110,
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
        width: 120,
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
        width: 110,
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
        width: 145,
        label: 'Efficiency ($effUnit)',
        tooltip: 'Tap to graph fuel efficiency',
        icon: Icons.auto_graph,
        onTap: () => _openColumnGraphModal(
          context,
          columnTitle: 'Fuel Efficiency for Refuel',
          unit: effUnit,
          values: efficiencies,
          dates: effDates,
          color: Colors.green,
        ),
      ),
      _buildGraphableColumn(
        width: 155,
        label: 'Consumption (L/100km)',
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
        width: 120,
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
      const DataColumn(
        label: SizedBox(
          width: 130,
          child: Text('Gas Station', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      const DataColumn(
        label: SizedBox(
          width: 80,
          child: Text('Full Tank', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
      const DataColumn(
        label: SizedBox(
          width: 160,
          child: Text('Notes', style: TextStyle(fontWeight: FontWeight.bold)),
        ),
      ),
    ];

    final dataRows = List<DataRow>.generate(records.length, (index) {
      final rec = records[index];
      final calc = calculations[index];
      final isSelected = _selectedRecordIds.contains(rec.id);

      final currentEff = calc.fuelEfficiency != null
          ? calc.fuelEfficiency! * effMultiplier
          : null;
      final prevEff = (index > 0 && calculations[index - 1].fuelEfficiency != null)
          ? calculations[index - 1].fuelEfficiency! * effMultiplier
          : null;
      final effDelta = (currentEff != null && prevEff != null)
          ? (currentEff - prevEff)
          : null;

      final currentCons = calc.consumptionPer100Units;
      final prevCons = index > 0 ? calculations[index - 1].consumptionPer100Units : null;
      final consDelta = (currentCons != null && prevCons != null)
          ? (currentCons - prevCons)
          : null;

      return DataRow(
        selected: isSelected,
        color: WidgetStateProperty.resolveWith<Color?>((states) {
          if (isSelected) {
            return theme.colorScheme.primary.withValues(alpha: 0.12);
          }
          if (index.isEven) {
            return isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.withValues(alpha: 0.06);
          }
          return null;
        }),
        cells: [
          DataCell(SizedBox(
            width: 105,
            child: Text(AppDateUtils.format(rec.dateTime), style: const TextStyle(fontWeight: FontWeight.bold)),
          )),
          DataCell(SizedBox(
            width: 125,
            child: Text(rec.odometer.toStringAsFixed(1)),
          )),
          DataCell(SizedBox(
            width: 150,
            child: Text(
              calc.distanceTraveled != null ? '+${calc.distanceTraveled!.toStringAsFixed(1)}' : 'First Log',
              style: TextStyle(
                color: calc.distanceTraveled != null ? Colors.blueAccent : Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          )),
          DataCell(SizedBox(
            width: 110,
            child: Text(rec.fuelAmount.toStringAsFixed(2)),
          )),
          DataCell(SizedBox(
            width: 120,
            child: Text('${vehicle.currency}${rec.totalPrice.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.w600)),
          )),
          DataCell(SizedBox(
            width: 110,
            child: Text('${vehicle.currency}${calc.pricePerUnit.toStringAsFixed(3)}'),
          )),
          DataCell(SizedBox(
            width: 145,
            child: currentEff != null
                ? _buildValueWithDelta(
                    valueStr: '${currentEff.toStringAsFixed(2)} $effUnit',
                    delta: effDelta,
                    baseColor: Colors.green.shade700,
                  )
                : const Text('-'),
          )),
          DataCell(SizedBox(
            width: 155,
            child: currentCons != null
                ? _buildValueWithDelta(
                    valueStr: '${currentCons.toStringAsFixed(2)} L/100km',
                    delta: consDelta,
                    baseColor: isDark ? Colors.cyanAccent : Colors.teal.shade700,
                  )
                : const Text('-'),
          )),
          DataCell(SizedBox(
            width: 120,
            child: Text(calc.daysSincePrevious != null ? '${calc.daysSincePrevious!.toStringAsFixed(1)} d' : '-'),
          )),
          DataCell(SizedBox(
            width: 130,
            child: Text(rec.gasStation.isNotEmpty ? rec.gasStation : '-', overflow: TextOverflow.ellipsis),
          )),
          DataCell(SizedBox(
            width: 80,
            child: rec.isFullTank == null
                ? const Text('-')
                : Icon(
                    rec.isFullTank! ? Icons.check_circle : Icons.radio_button_unchecked,
                    size: 16,
                    color: rec.isFullTank! ? Colors.green : Colors.grey,
                  ),
          )),
          DataCell(SizedBox(
            width: 160,
            child: Text(rec.notes.isNotEmpty ? rec.notes : '-', overflow: TextOverflow.ellipsis),
          )),
        ],
      );
    });

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Data Grid View', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            Text('${vehicle.name} • Tap any column title to graph it!', style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download_outlined),
            tooltip: 'Export CSV File',
            onPressed: () async {
              try {
                final file = await widget.appState.exportVehicleRecordsToCsvFile(vehicle.id);
                if (!context.mounted) return;
                _showExportModal(context, vehicle, file);
              } catch (e) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to export CSV: $e')),
                );
              }
            },
          ),
        ],
      ),
      body: records.isEmpty
          ? const Center(child: Text('No fuel records to display in grid.'))
          : Column(
              children: [
                // Pinned Header Row - Remains fixed at top during vertical scroll, scrolls horizontally
                Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF262838) : Colors.blueGrey.shade100,
                    border: Border(
                      bottom: BorderSide(
                        color: Colors.grey.withValues(alpha: 0.3),
                        width: 1.5,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Pinned Top-Left Checkbox Container (~52px wide)
                      Container(
                        width: 52,
                        height: 56,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          border: Border(
                            right: BorderSide(
                              color: Colors.grey.withValues(alpha: 0.25),
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: SizedBox(
                          width: 36,
                          child: Checkbox(
                            value: records.isEmpty
                                ? false
                                : (_selectedRecordIds.length == records.length
                                    ? true
                                    : (_selectedRecordIds.isNotEmpty ? null : false)),
                            tristate: true,
                            onChanged: (val) {
                              setState(() {
                                if (val == true || (val == null && _selectedRecordIds.length < records.length)) {
                                  _selectedRecordIds = records.map((r) => r.id).toSet();
                                } else {
                                  _selectedRecordIds.clear();
                                }
                              });
                            },
                          ),
                        ),
                      ),

                      // Horizontally scrolling header table
                      Expanded(
                        child: SingleChildScrollView(
                          controller: _headerHorizontalController,
                          scrollDirection: Axis.horizontal,
                          physics: const ClampingScrollPhysics(),
                          child: DataTable(
                            headingRowHeight: 56,
                            dataRowMinHeight: 0,
                            dataRowMaxHeight: 0,
                            horizontalMargin: 12,
                            columnSpacing: 16,
                            headingRowColor: WidgetStateProperty.all(
                              isDark ? const Color(0xFF262838) : Colors.blueGrey.shade100,
                            ),
                            columns: headerColumns,
                            rows: const [],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Horizontally & Vertically Scrolling Data Rows
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Sticky Leftmost Checkbox Column (~52px wide)
                      Container(
                        width: 52,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                          border: Border(
                            right: BorderSide(
                              color: Colors.grey.withValues(alpha: 0.25),
                              width: 1.5,
                            ),
                          ),
                        ),
                        child: SingleChildScrollView(
                          controller: _leftVerticalController,
                          scrollDirection: Axis.vertical,
                          padding: const EdgeInsets.only(bottom: 120),
                          child: DataTable(
                            headingRowHeight: 0,
                            dataRowMinHeight: 48,
                            dataRowMaxHeight: 48,
                            horizontalMargin: 8,
                            columnSpacing: 0,
                            columns: const [
                              DataColumn(label: SizedBox(width: 36)),
                            ],
                            rows: List<DataRow>.generate(records.length, (index) {
                              final rec = records[index];
                              final isSelected = _selectedRecordIds.contains(rec.id);
                              return DataRow(
                                selected: isSelected,
                                color: WidgetStateProperty.resolveWith<Color?>((states) {
                                  if (isSelected) {
                                    return theme.colorScheme.primary.withValues(alpha: 0.12);
                                  }
                                  if (index.isEven) {
                                    return isDark ? Colors.white.withValues(alpha: 0.02) : Colors.grey.withValues(alpha: 0.06);
                                  }
                                  return null;
                                }),
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: 36,
                                      child: Checkbox(
                                        value: isSelected,
                                        onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              _selectedRecordIds.add(rec.id);
                                            } else {
                                              _selectedRecordIds.remove(rec.id);
                                            }
                                          });
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }),
                          ),
                        ),
                      ),

                      // Horizontally & Vertically Scrolling Data Columns
                      Expanded(
                        child: Scrollbar(
                          controller: _horizontalController,
                          thumbVisibility: true,
                          child: SingleChildScrollView(
                            controller: _horizontalController,
                            scrollDirection: Axis.horizontal,
                            child: Scrollbar(
                              controller: _rightVerticalController,
                              thumbVisibility: true,
                              child: SingleChildScrollView(
                                controller: _rightVerticalController,
                                scrollDirection: Axis.vertical,
                                padding: const EdgeInsets.only(bottom: 120),
                                child: DataTable(
                                  headingRowHeight: 0,
                                  dataRowMinHeight: 48,
                                  dataRowMaxHeight: 48,
                                  horizontalMargin: 12,
                                  columnSpacing: 16,
                                  columns: headerColumns,
                                  rows: dataRows,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
      bottomNavigationBar: _selectedRecordIds.isNotEmpty
          ? Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 12,
                    offset: const Offset(0, -3),
                  ),
                ],
                border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_selectedRecordIds.length} selected',
                      style: TextStyle(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _selectedRecordIds.clear()),
                    child: const Text('Deselect All'),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC2626),
                      foregroundColor: Colors.white,
                      elevation: 2,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => _confirmBulkDelete(context),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('Delete Selected', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ],
              ),
            )
          : null,
    );
  }

  Future<void> _confirmBulkDelete(BuildContext context) async {
    bool createBackup = true;
    final count = _selectedRecordIds.length;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Delete Records', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to permanently delete $count fuel record${count > 1 ? 's' : ''}?\nThis action cannot be undone.',
                style: const TextStyle(fontSize: 14),
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
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text('Delete $count Record${count > 1 ? 's' : ''}'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true) {
      if (createBackup) {
        try {
          final backupFile = await widget.appState.saveBackupToFile();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Backup saved to ${backupFile.path}')),
            );
          }
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Warning: Backup could not be created: $e')),
            );
          }
        }
      }

      final deletedCount = await widget.appState.deleteRecordsBatch(_selectedRecordIds.toList());
      setState(() {
        _selectedRecordIds.clear();
      });
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted $deletedCount fuel records.')),
        );
      }
    }
  }

  DataColumn _buildGraphableColumn({
    required double width,
    required String label,
    required String tooltip,
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return DataColumn(
      tooltip: tooltip,
      label: SizedBox(
        width: width,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(8),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (onTap != null) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.show_chart, size: 14, color: Colors.blueAccent),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showExportModal(BuildContext context, Vehicle vehicle, File file) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: const [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('CSV File Exported', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your fuel records have been exported into a separate CSV file on your device:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
              ),
              child: SelectableText(
                file.path,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.copy, size: 14),
                  label: const Text('Copy Path', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: file.path));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('File path copied to clipboard!')),
                    );
                  },
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.file_copy, size: 14),
                  label: const Text('Copy CSV', style: TextStyle(fontSize: 12)),
                  onPressed: () {
                    final content = file.readAsStringSync();
                    Clipboard.setData(ClipboardData(text: content));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('CSV content copied to clipboard!')),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}
