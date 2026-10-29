import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../services/fuel_app_state.dart';
import '../services/obd_telemetry_service.dart';
import '../theme/app_theme.dart';

enum ObdGraphMetric {
  rpm,
  speed,
  fuelLevel,
  runtime,
}

class ObdTelemetryScreen extends StatefulWidget {
  final FuelAppState appState;

  const ObdTelemetryScreen({
    super.key,
    required this.appState,
  });

  @override
  State<ObdTelemetryScreen> createState() => _ObdTelemetryScreenState();
}

class _ObdTelemetryScreenState extends State<ObdTelemetryScreen> {
  ObdGraphMetric _selectedMetric = ObdGraphMetric.rpm;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.appState,
      builder: (context, _) {
        final obd = widget.appState.obdService;
        final vehicle = widget.appState.activeVehicle;
        final vehicleId = vehicle?.id ?? 'default_vehicle';
        final unitDist = vehicle?.unitDistance ?? widget.appState.activeDistanceUnit;
        final speedUnit = unitDist.toLowerCase().contains('mi') ? 'mph' : 'km/h';
        final recordsAsc = obd.recordsForVehicle(vehicleId);
        final recordsDesc = recordsAsc.reversed.toList();
        final latest = recordsAsc.isNotEmpty ? recordsAsc.last : null;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          appBar: AppBar(
            title: const Text('OBD-II Live Telemetry'),
            actions: [
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (obd.isConnected ? AppColors.info : AppColors.warning)
                      .withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                  border: Border.all(
                    color: obd.isConnected ? AppColors.info : AppColors.warning,
                    width: 1.2,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      obd.isConnected ? Icons.sensors : Icons.sensors_off_outlined,
                      size: 14,
                      color: obd.isConnected ? AppColors.info : AppColors.warning,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      obd.isConnected ? 'LIVE 1Hz' : 'STANDBY',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.6,
                        color: obd.isConnected ? AppColors.info : AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
              if (recordsAsc.isNotEmpty)
                IconButton(
                  tooltip: 'Clear OBD Database',
                  icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.danger),
                  onPressed: () async {
                    await obd.clearDatabase(vehicleId: vehicleId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Cleared local OBD-II telemetry database')),
                      );
                    }
                  },
                ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Sensor Detection & 1Hz Stream Banner
                _buildSensorControlCard(context, obd, vehicleId, recordsAsc.length, isDark),
                const SizedBox(height: 16),

                // 2. Live Digital Cockpit Readout (5 OBD-II Parameters)
                _buildLiveCockpitReadout(context, latest, speedUnit, isDark),
                const SizedBox(height: 16),

                // 3. Interactive Telemetry Trend Graph
                _buildGraphCard(context, recordsAsc, speedUnit, isDark),
                const SizedBox(height: 16),

                // 4. Local Database Table Format (Live & Historical Rows)
                _buildTelemetryTableCard(context, recordsDesc, speedUnit, isDark),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSensorControlCard(
    BuildContext context,
    ObdTelemetryService obd,
    String vehicleId,
    int recordCount,
    bool isDark,
  ) {
    final accent = obd.isConnected
        ? AppColors.info
        : (isDark ? AppColors.primary : AppColors.primaryDark);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppTheme.borderColor(context), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Icon(Icons.bluetooth_connected, color: accent, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      obd.isConnected
                          ? (obd.detectedSensorName ?? 'ELM327 OBD-II Sensor')
                          : 'Nearby OBD-II / ELM327 Detector',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      obd.isConnected
                          ? 'Saving to local DB (${ObdTelemetryService.dbFileName}) every 1s • $recordCount rows'
                          : 'Detects nearby ELM327 sensors & logs at 1 Hz (1s interval) • $recordCount rows stored',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: obd.isConnected ? AppColors.danger : AppColors.info,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
              ),
              icon: Icon(
                obd.isConnected ? Icons.stop_circle_outlined : Icons.sensors,
                size: 19,
              ),
              label: Text(
                obd.isConnected
                    ? 'Stop Live Sensor Feed'
                    : 'Detect & Stream OBD2 Sensor (ELM327)',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5),
              ),
              onPressed: () async {
                if (obd.isConnected) {
                  obd.disconnectSensor();
                } else {
                  await obd.detectAndStartLiveFeed(vehicleId: vehicleId);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveCockpitReadout(
    BuildContext context,
    ObdTelemetryRecord? latest,
    String speedUnit,
    bool isDark,
  ) {
    final rpmText = latest != null ? '${latest.engineRpm.toStringAsFixed(0)} RPM' : '-- RPM';
    final speedText = latest != null
        ? '${latest.speedInUnit(speedUnit == 'mph' ? 'mi' : 'km').toStringAsFixed(1)} $speedUnit'
        : '-- $speedUnit';
    final runtimeText = latest != null
        ? '${latest.formattedRuntime} (${latest.elapsedRuntimeSec}s)'
        : '--:--';
    final fuelLevelText =
        latest != null ? '${latest.fuelLevelPercent.toStringAsFixed(1)}%' : '--%';
    final fuelStatusText = latest?.fuelSystemStatus ?? 'Waiting for Sensor';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppTheme.borderColor(context), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Live Sensor Readout',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              if (latest != null)
                Text(
                  DateFormat('HH:mm:ss').format(latest.timestamp),
                  style: AppTextStyles.tabularText.copyWith(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    color: AppColors.info,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context,
                  label: 'Engine RPM',
                  value: rpmText,
                  icon: Icons.speed,
                  color: AppColors.info,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  context,
                  label: 'Vehicle Speed',
                  value: speedText,
                  icon: Icons.directions_car_outlined,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  context,
                  label: 'Elapsed Runtime',
                  value: runtimeText,
                  icon: Icons.timer_outlined,
                  color: AppColors.orange,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildMetricTile(
                  context,
                  label: 'Fuel Level',
                  value: fuelLevelText,
                  icon: Icons.local_gas_station_outlined,
                  color: AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.elevatedSurfaceColor(context),
              borderRadius: BorderRadius.circular(AppRadii.md),
              border: Border.all(color: AppTheme.borderSubtleColor(context)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(Icons.memory, size: 17, color: AppColors.purple),
                    const SizedBox(width: 8),
                    Text(
                      'Fuel System Status',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondaryColor(context),
                      ),
                    ),
                  ],
                ),
                Text(
                  fuelStatusText,
                  style: AppTextStyles.telemetryNumber.copyWith(
                    fontSize: 13.5,
                    color: AppColors.purple,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(
    BuildContext context, {
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.elevatedSurfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadii.md),
        border: Border.all(color: AppTheme.borderSubtleColor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTextStyles.telemetryNumber.copyWith(
              fontSize: 16,
              color: AppTheme.textPrimaryColor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGraphCard(
    BuildContext context,
    List<ObdTelemetryRecord> recordsAsc,
    String speedUnit,
    bool isDark,
  ) {
    final window = recordsAsc.length > 30
        ? recordsAsc.sublist(recordsAsc.length - 30)
        : recordsAsc;

    Color lineColor;
    String unitLabel;
    List<double> values;

    switch (_selectedMetric) {
      case ObdGraphMetric.rpm:
        lineColor = AppColors.info;
        unitLabel = 'RPM';
        values = window.map((r) => r.engineRpm).toList();
        break;
      case ObdGraphMetric.speed:
        lineColor = AppColors.primary;
        unitLabel = speedUnit;
        values = window
            .map((r) => r.speedInUnit(speedUnit == 'mph' ? 'mi' : 'km'))
            .toList();
        break;
      case ObdGraphMetric.fuelLevel:
        lineColor = AppColors.success;
        unitLabel = '%';
        values = window.map((r) => r.fuelLevelPercent).toList();
        break;
      case ObdGraphMetric.runtime:
        lineColor = AppColors.orange;
        unitLabel = 'sec';
        values = window.map((r) => r.elapsedRuntimeSec.toDouble()).toList();
        break;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppTheme.borderColor(context), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Telemetry Trend Graph (1 Hz)',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              Text(
                unitLabel,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  color: lineColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildMetricChip('Engine RPM', ObdGraphMetric.rpm, AppColors.info),
                const SizedBox(width: 8),
                _buildMetricChip('Vehicle Speed', ObdGraphMetric.speed, AppColors.primary),
                const SizedBox(width: 8),
                _buildMetricChip('Fuel Level %', ObdGraphMetric.fuelLevel, AppColors.success),
                const SizedBox(width: 8),
                _buildMetricChip('Runtime (s)', ObdGraphMetric.runtime, AppColors.orange),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (values.isEmpty)
            Container(
              height: 180,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.elevatedSurfaceColor(context),
                borderRadius: BorderRadius.circular(AppRadii.md),
              ),
              child: Text(
                'No OBD-II data yet. Tap "Detect & Stream OBD2 Sensor" above.',
                style: TextStyle(
                  fontSize: 12.5,
                  color: AppTheme.textSecondaryColor(context),
                ),
              ),
            )
          else
            SizedBox(
              height: 190,
              child: _buildLineChart(context, values, window, lineColor),
            ),
        ],
      ),
    );
  }

  Widget _buildMetricChip(String label, ObdGraphMetric metric, Color color) {
    final selected = _selectedMetric == metric;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: selected ? Colors.white : AppTheme.textPrimaryColor(context),
        ),
      ),
      selected: selected,
      selectedColor: color,
      backgroundColor: AppTheme.elevatedSurfaceColor(context),
      onSelected: (_) => setState(() => _selectedMetric = metric),
    );
  }

  Widget _buildLineChart(
    BuildContext context,
    List<double> values,
    List<ObdTelemetryRecord> window,
    Color lineColor,
  ) {
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final range = maxVal - minVal;
    final pad = range == 0 ? (minVal.abs() * 0.1 + 1.0) : range * 0.2;
    final minY = minVal - pad;
    final maxY = maxVal + pad;

    final spots = <FlSpot>[
      for (int i = 0; i < values.length; i++) FlSpot(i.toDouble(), values[i]),
    ];

    return LineChart(
      LineChartData(
        minY: minY,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (_) => FlLine(
            color: AppTheme.borderSubtleColor(context),
            strokeWidth: 1,
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 46,
              getTitlesWidget: (val, _) => Text(
                val.toStringAsFixed(val.abs() >= 100 ? 0 : 1),
                style: AppTextStyles.tabularText.copyWith(
                  fontSize: 10,
                  color: AppTheme.textMutedColor(context),
                ),
              ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: (values.length / 4).clamp(1.0, 10.0),
              getTitlesWidget: (val, _) {
                final idx = val.toInt();
                if (idx < 0 || idx >= window.length) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    DateFormat('mm:ss').format(window[idx].timestamp),
                    style: AppTextStyles.tabularText.copyWith(
                      fontSize: 10,
                      color: AppTheme.textMutedColor(context),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: lineColor,
            barWidth: 2.8,
            dotData: FlDotData(show: values.length <= 15),
            belowBarData: BarAreaData(
              show: true,
              color: lineColor.withValues(alpha: 0.14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTelemetryTableCard(
    BuildContext context,
    List<ObdTelemetryRecord> recordsDesc,
    String speedUnit,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppTheme.borderColor(context), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'OBD-II Telemetry Database Table',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
              Text(
                '${recordsDesc.length} records',
                style: AppTextStyles.tabularText.copyWith(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondaryColor(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (recordsDesc.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No telemetry records saved in ${ObdTelemetryService.dbFileName}.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppTheme.textSecondaryColor(context),
                  ),
                ),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowHeight: 40,
                dataRowMinHeight: 36,
                dataRowMaxHeight: 42,
                columnSpacing: 18,
                headingRowColor: WidgetStateProperty.all(
                  AppTheme.elevatedSurfaceColor(context),
                ),
                columns: [
                  const DataColumn(
                    label: Text('Time', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                  const DataColumn(
                    label: Text('Engine RPM', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                  DataColumn(
                    label: Text('Speed ($speedUnit)', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                  const DataColumn(
                    label: Text('Runtime', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                  const DataColumn(
                    label: Text('Fuel System Status', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                  const DataColumn(
                    label: Text('Fuel Level', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12)),
                  ),
                ],
                rows: recordsDesc.take(100).map((r) {
                  final spd = r.speedInUnit(speedUnit == 'mph' ? 'mi' : 'km');
                  return DataRow(
                    cells: [
                      DataCell(
                        Text(
                          DateFormat('HH:mm:ss').format(r.timestamp),
                          style: AppTextStyles.tabularText.copyWith(fontSize: 12),
                        ),
                      ),
                      DataCell(
                        Text(
                          r.engineRpm.toStringAsFixed(0),
                          style: AppTextStyles.telemetryNumber.copyWith(
                            fontSize: 12.5,
                            color: AppColors.info,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          spd.toStringAsFixed(1),
                          style: AppTextStyles.telemetryNumber.copyWith(fontSize: 12.5),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${r.formattedRuntime} (${r.elapsedRuntimeSec}s)',
                          style: AppTextStyles.tabularText.copyWith(fontSize: 12),
                        ),
                      ),
                      DataCell(
                        Text(
                          r.fuelSystemStatus,
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(
                        Text(
                          '${r.fuelLevelPercent.toStringAsFixed(1)}%',
                          style: AppTextStyles.telemetryNumber.copyWith(
                            fontSize: 12.5,
                            color: AppColors.success,
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}
