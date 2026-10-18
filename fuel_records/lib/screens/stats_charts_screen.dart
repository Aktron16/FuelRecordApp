import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/vehicle.dart';
import '../services/fuel_app_state.dart';
import '../utils/app_date_format.dart';

class StatsChartsScreen extends StatefulWidget {
  final FuelAppState appState;

  const StatsChartsScreen({
    super.key,
    required this.appState,
  });

  @override
  State<StatsChartsScreen> createState() => _StatsChartsScreenState();
}

class _StatsChartsScreenState extends State<StatsChartsScreen> {
  int _selectedChartTab = 0; // 0: Efficiency, 1: Price / L, 2: Distance

  @override
  Widget build(BuildContext context) {
    final vehicle = widget.appState.activeVehicle;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (vehicle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Metrics & Statistics')),
        body: const Center(child: Text('No active vehicle')),
      );
    }

    final stats = widget.appState.activeVehicleStats;
    final recordsAsc = widget.appState.activeVehicleRecordsAscending;
    final primaryColor = Color(vehicle.colorValue);

    return Scaffold(
      appBar: AppBar(
        title: Text('${vehicle.name} Analytics'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Hero KPI Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    primaryColor,
                    Color.lerp(primaryColor, Colors.black, 0.4)!,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: primaryColor.withValues(alpha: 0.35),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Lifetime Metrics',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${stats.totalRecords} Logs',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            stats.averageEfficiency != null
                                ? stats.averageEfficiency!.toStringAsFixed(2)
                                : '--',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                          ),
                          Text(
                            'Average ${vehicle.unitDistance}/${vehicle.unitVolume}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.85),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      if (stats.averageConsumption100 != null)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${stats.averageConsumption100!.toStringAsFixed(1)} ${vehicle.unitVolume}/100${vehicle.unitDistance}',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Consumption',
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.75),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(color: Colors.white24),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _kpiMiniStat('Total Distance', '${stats.totalDistance.toStringAsFixed(0)} ${vehicle.unitDistance}'),
                      _kpiMiniStat('Total Spent', '${vehicle.currency}${stats.totalCost.toStringAsFixed(0)}'),
                      _kpiMiniStat('Total Fuel', '${stats.totalFuel.toStringAsFixed(0)} ${vehicle.unitVolume}'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Interactive Chart Section
            Text(
              'Trends',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            // Chart Tabs
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text('Efficiency (${vehicle.unitDistance}/${vehicle.unitVolume})')),
                ButtonSegment(value: 1, label: Text('Price (${vehicle.currency}/${vehicle.unitVolume})')),
                ButtonSegment(value: 2, label: Text('Distance (+${vehicle.unitDistance})')),
              ],
              selected: {_selectedChartTab},
              onSelectionChanged: (set) => setState(() => _selectedChartTab = set.first),
            ),

            const SizedBox(height: 16),

            // Chart Container
            Container(
              height: 240,
              padding: const EdgeInsets.fromLTRB(12, 20, 16, 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: recordsAsc.length < 2
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.show_chart, size: 40, color: Colors.grey.shade400),
                          const SizedBox(height: 8),
                          const Text('Need at least 2 fuel records to plot trend lines'),
                        ],
                      ),
                    )
                  : _buildChart(recordsAsc, vehicle, primaryColor),
            ),

            const SizedBox(height: 24),

            // Detailed Calculated Metrics Breakdown
            Text(
              'Key Metrics',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.55,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              children: [
                _buildMetricCard(
                  title: 'Price Increase / Avg',
                  value: '${vehicle.currency}${stats.averagePricePerUnit.toStringAsFixed(3)}',
                  subtitle: stats.latestCalculation?.priceDifferencePerUnit != null
                      ? 'Latest: ${stats.latestCalculation!.priceDifferencePerUnit! >= 0 ? '+' : ''}${vehicle.currency}${stats.latestCalculation!.priceDifferencePerUnit!.toStringAsFixed(3)}'
                      : 'Per ${vehicle.unitVolume}',
                  icon: Icons.attach_money,
                  color: Colors.blueAccent,
                ),
                _buildMetricCard(
                  title: 'Cost / ${vehicle.unitDistance}',
                  value: stats.averageCostPerDistance != null
                      ? '${vehicle.currency}${stats.averageCostPerDistance!.toStringAsFixed(3)}'
                      : '--',
                  subtitle: 'Running avg cost per ${vehicle.unitDistance}',
                  icon: Icons.toll_outlined,
                  color: Colors.amber.shade800,
                ),
                _buildMetricCard(
                  title: 'Days Between Fills',
                  value: stats.averageDaysBetweenFills != null
                      ? '${stats.averageDaysBetweenFills!.toStringAsFixed(1)} days'
                      : '--',
                  subtitle: stats.latestCalculation?.daysSincePrevious != null
                      ? 'Latest: ${stats.latestCalculation!.daysSincePrevious!.toStringAsFixed(1)} days'
                      : 'Average interval',
                  icon: Icons.calendar_month_outlined,
                  color: Colors.purpleAccent,
                ),
                _buildMetricCard(
                  title: 'Best Efficiency',
                  value: stats.bestEfficiency != null
                      ? '${stats.bestEfficiency!.toStringAsFixed(2)} ${vehicle.unitDistance}/${vehicle.unitVolume}'
                      : '--',
                  subtitle: stats.worstEfficiency != null
                      ? 'Worst: ${stats.worstEfficiency!.toStringAsFixed(2)}'
                      : 'Optimal trip',
                  icon: Icons.star_outline,
                  color: Colors.green,
                ),
                _buildMetricCard(
                  title: 'Min / Max Fuel Price',
                  value: stats.minPricePerUnit != null
                      ? '${vehicle.currency}${stats.minPricePerUnit!.toStringAsFixed(2)} - ${vehicle.currency}${stats.maxPricePerUnit!.toStringAsFixed(2)}'
                      : '--',
                  subtitle: 'Historical range',
                  icon: Icons.price_change_outlined,
                  color: Colors.teal,
                ),
                _buildMetricCard(
                  title: 'Latest Fill Odometer',
                  value: stats.latestRecord != null
                      ? '${stats.latestRecord!.odometer.toStringAsFixed(0)} ${vehicle.unitDistance}'
                      : '--',
                  subtitle: stats.latestCalculation?.distanceTraveled != null
                      ? '+${stats.latestCalculation!.distanceTraveled!.toStringAsFixed(0)} ${vehicle.unitDistance} last trip'
                      : 'Total mileage',
                  icon: Icons.speed,
                  color: primaryColor,
                ),
              ],
            ),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  Widget _kpiMiniStat(String title, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 11)),
        const SizedBox(height: 2),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 16, color: color),
            ],
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            subtitle,
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildChart(List recordsAsc, Vehicle vehicle, Color primaryColor) {
    final spots = <FlSpot>[];

    for (int i = 0; i < recordsAsc.length; i++) {
      final rec = recordsAsc[i];
      final calc = widget.appState.getCalculationForRecord(rec);

      double yVal = 0.0;
      if (_selectedChartTab == 0) {
        // Efficiency
        yVal = calc.fuelEfficiency ?? 0.0;
      } else if (_selectedChartTab == 1) {
        // Price per unit
        yVal = calc.pricePerUnit;
      } else {
        // Distance
        yVal = calc.distanceTraveled ?? 0.0;
      }

      spots.add(FlSpot(i.toDouble(), yVal));
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
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
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                 final int idx = value.toInt();
                if (idx < 0 || idx >= recordsAsc.length) return const SizedBox.shrink();
                final r = recordsAsc[idx];
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    AppDateUtils.formatShort(r.dateTime),
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 36,
              getTitlesWidget: (value, meta) {
                return Text(
                  value.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 9, color: Colors.grey),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: primaryColor,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: primaryColor.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}

