import 'dart:io';
import 'package:flutter/material.dart';
import '../models/vehicle.dart';
import '../models/record_calculation.dart';
import '../models/pending_auto_refuel.dart';
import '../services/auto_refuel_orchestrator.dart';
import '../services/fuel_app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/vehicle_artwork.dart';
import '../utils/app_date_format.dart';
import 'add_edit_vehicle_sheet.dart';
import 'add_edit_record_screen.dart';
import 'records_list_screen.dart';
import 'records_table_screen.dart';
import 'stats_charts_screen.dart';
import 'services_screen.dart';
import 'vehicles_screen.dart';
import 'settings_screen.dart';
import 'obd_pairing_screen.dart';
import '../widgets/app_logo.dart';

class HomeScreen extends StatelessWidget {
  final FuelAppState appState;

  const HomeScreen({
    super.key,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final vehicle = appState.activeVehicle;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            FuelManLogo(size: 36, primaryColor: theme.colorScheme.primary),
            const SizedBox(width: 10),
            const Text(
              'Fuel Metrics',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20, letterSpacing: -0.5),
            ),
          ],
        ),
        actions: [
          // Table / Data Grid View
          if (vehicle != null)
            IconButton(
              icon: const Icon(Icons.table_chart_outlined),
              tooltip: 'Data Grid View',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (ctx) => RecordsTableScreen(appState: appState)),
                );
              },
            ),
          // Maintenance & Servicing
          if (vehicle != null)
            IconButton(
              icon: const Icon(Icons.car_repair_outlined),
              tooltip: 'Servicing',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (ctx) => ServicesScreen(appState: appState)),
                );
              },
            ),
          // Vehicles Garage
          IconButton(
            icon: const Icon(Icons.garage_outlined),
            tooltip: 'My Vehicles',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => VehiclesScreen(appState: appState)),
              );
            },
          ),
          // Settings (Country, Region, Units)
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings & Country',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => SettingsScreen(appState: appState)),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: vehicle == null
            ? _buildNoVehicleState(context)
            : _buildDashboard(context, vehicle, isDark),
      ),
    );
  }

  /// Empty state when no vehicle has been added yet
  Widget _buildNoVehicleState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FuelManLogo(
              size: 110,
              primaryColor: theme.colorScheme.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Fuel Metrics',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Keep a private record of your vehicle\'s fuel metrics, expenses, and periodic 6-month servicing.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),

            ElevatedButton.icon(
              onPressed: () {
                AddEditVehicleSheet.show(
                  context,
                  defaultDistanceUnit: appState.defaultDistanceUnit,
                  defaultVolumeUnit: appState.defaultVolumeUnit,
                  defaultCurrency: appState.defaultCurrency,
                  appState: appState,
                  onSave: (newVeh) => appState.addVehicle(newVeh),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.colorScheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                elevation: 3,
              ),
              icon: const Icon(Icons.add_circle_outline),
              label: const Text(
                'Add Vehicle Details',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 16),

            OutlinedButton.icon(
              onPressed: () => appState.loadSampleData(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              icon: const Icon(Icons.bolt, color: Colors.amber),
              label: const Text('Load Demo Vehicle & Records'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboard(BuildContext context, Vehicle vehicle, bool isDark) {
    final theme = Theme.of(context);
    final primaryColor = Color(vehicle.colorValue);
    final recordsAsc = appState.activeVehicleRecordsAscending;
    final recordsDesc = appState.activeVehicleRecordsDescending;
    final stats = appState.activeVehicleStats;
    final serviceStatus = appState.activeVehicleServiceStatus;

    final latestRecord = recordsAsc.isNotEmpty ? recordsAsc.last : null;
    final latestCalc = latestRecord != null ? appState.getCalculationForRecord(latestRecord) : null;

    return RefreshIndicator(
      onRefresh: () async => await appState.loadFromStorage(),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Vehicle Selector & Quick Add Row
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(AppRadii.md),
                    onTap: () => _showQuickVehiclePickerSheet(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceColor(context),
                        borderRadius: BorderRadius.circular(AppRadii.md),
                        border: Border.all(color: AppTheme.borderColor(context)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.directions_car, size: 18, color: primaryColor),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              vehicle.name,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(Icons.unfold_more, size: 18, color: AppTheme.textSecondaryColor(context)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filledTonal(
                  icon: const Icon(Icons.add, size: 20),
                  tooltip: 'Add Another Vehicle',
                  onPressed: () {
                    AddEditVehicleSheet.show(
                      context,
                      defaultDistanceUnit: appState.defaultDistanceUnit,
                      defaultVolumeUnit: appState.defaultVolumeUnit,
                      defaultCurrency: appState.defaultCurrency,
                      appState: appState,
                      onSave: (newVeh) => appState.addVehicle(newVeh),
                    );
                  },
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Vehicle Hero Cockpit Card
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor(context),
                borderRadius: BorderRadius.circular(AppRadii.xl),
                border: Border.all(color: AppTheme.borderColor(context), width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.xl - 1),
                child: Column(
                  children: [
                    if (vehicle.bannerImageUri != null && File(vehicle.bannerImageUri!).existsSync())
                      Stack(
                        children: [
                          Image.file(
                            File(vehicle.bannerImageUri!),
                            width: double.infinity,
                            height: 130,
                            fit: BoxFit.cover,
                          ),
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.black.withValues(alpha: 0.1),
                                    Colors.black.withValues(alpha: 0.8),
                                  ],
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    Padding(
                      padding: const EdgeInsets.all(18),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Car info
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    borderRadius: BorderRadius.circular(AppRadii.sm),
                                  ),
                                  child: Text(
                                    vehicle.type.displayName.toUpperCase(),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.6,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  vehicle.name,
                                  style: theme.textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Text(
                                      vehicle.brand,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: AppTheme.textSecondaryColor(context),
                                      ),
                                    ),
                                    if (vehicle.licensePlate != null && vehicle.licensePlate!.trim().isNotEmpty) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.black, width: 2.0),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.18),
                                              blurRadius: 3,
                                              offset: const Offset(0, 1.5),
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          vehicle.licensePlate!.trim().toUpperCase(),
                                          style: const TextStyle(
                                            fontFamily: 'monospace',
                                            color: Colors.black,
                                            fontWeight: FontWeight.w900,
                                            fontSize: 12,
                                            letterSpacing: 1.4,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                if (vehicle.dateBought != null) ...[
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Icon(Icons.shopping_bag_outlined, size: 12, color: AppTheme.textMutedColor(context)),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Bought: ${AppDateUtils.format(vehicle.dateBought!)} (${vehicle.ownershipDuration})',
                                        style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context), fontWeight: FontWeight.w500),
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 10),
                                if (latestRecord != null)
                                  Row(
                                    children: [
                                      Icon(Icons.speed, size: 15, color: primaryColor),
                                      const SizedBox(width: 5),
                                      Text(
                                        '${latestRecord.odometer.toStringAsFixed(0)} ${vehicle.unitDistance}',
                                        style: const TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.bold,
                                          fontFeatures: [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                      if (vehicle.tankCapacityMilliliters > 0) ...[
                                        const SizedBox(width: 10),
                                        Text(
                                          '• ${(vehicle.tankCapacityMilliliters / 1000.0).toStringAsFixed(0)} L Tank',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondaryColor(context),
                                            fontFeatures: const [FontFeature.tabularFigures()],
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          // Vehicle Artwork or Profile Photo
                          Column(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: vehicle.profileImageUri != null && File(vehicle.profileImageUri!).existsSync()
                                    ? Image.file(
                                        File(vehicle.profileImageUri!),
                                        width: 100,
                                        height: 75,
                                        fit: BoxFit.cover,
                                      )
                                    : VehicleArtwork(
                                        type: vehicle.type,
                                        bodyColor: primaryColor,
                                        width: 135,
                                        height: 75,
                                        showBadge: false,
                                      ),
                              ),
                              const SizedBox(height: 6),
                              InkWell(
                                onTap: () {
                                  AddEditVehicleSheet.show(
                                    context,
                                    vehicle: vehicle,
                                    defaultDistanceUnit: appState.defaultDistanceUnit,
                                    defaultVolumeUnit: appState.defaultVolumeUnit,
                                    defaultCurrency: appState.defaultCurrency,
                                    appState: appState,
                                    onSave: (updated) => appState.updateVehicle(updated),
                                  );
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.edit, size: 12, color: primaryColor),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Edit Car',
                                        style: TextStyle(
                                          color: primaryColor,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // In-App 6-Month Servicing Notification Banner (shown only inside app below vehicle details)
            if (serviceStatus != null && (serviceStatus['status'] == 'due_soon' || serviceStatus['status'] == 'overdue')) ...[
              const SizedBox(height: 12),
              _buildServiceNotificationBanner(context, vehicle, serviceStatus),
            ],

            // Head-Unit OEM Telemetry Advisory Banner (Case A or Case B)
            if (vehicle.telemetryCapabilityMask != 0) ...[
              const SizedBox(height: 12),
              _buildHeadUnitAdvisoryBanner(context, vehicle),
            ],

            // Pre-Flight Sensor Monitor Banner
            if (appState.preFlightStatus.shouldAlertUser) ...[
              const SizedBox(height: 12),
              _buildPreFlightSensorBanner(context, appState.preFlightStatus),
            ],

            // Pending Auto-Refuel Verification Cards
            if (appState.activeVehiclePendingRefuels.isNotEmpty) ...[
              const SizedBox(height: 12),
              ...appState.activeVehiclePendingRefuels.map(
                (pending) => _buildPendingAutoRefuelCard(context, pending, vehicle),
              ),
            ],

            const SizedBox(height: 16),

            // The Two Prominent Primary Action Buttons
            Row(
              children: [
                // Option 1: Add New Record
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      final lastRec = recordsAsc.isNotEmpty ? recordsAsc.last : null;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => AddEditRecordScreen(
                            vehicle: vehicle,
                            previousRecord: lastRec,
                            popularStations: appState.currentCountryInfo.popularStations,
                            appState: appState,
                            onSave: (newRec) => appState.addRecord(newRec),
                          ),
                        ),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                    icon: const Icon(Icons.add_circle, size: 20),
                    label: const Text(
                      'Add New Record',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Option 2: Change Pre-Existing Records
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => RecordsListScreen(appState: appState),
                        ),
                      );
                    },
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      side: BorderSide(color: primaryColor, width: 1.5),
                    ),
                    icon: Icon(Icons.edit_note, color: primaryColor, size: 22),
                    label: Text(
                      'Change Records',
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Quick Shortcut Row: Data Grid View & Servicing Log
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.table_chart, size: 16, color: Colors.green),
                    label: const Text('Data Grid View', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (ctx) => RecordsTableScreen(appState: appState)),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    icon: const Icon(Icons.build_circle_outlined, size: 16, color: Colors.orange),
                    label: const Text('Servicing', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (ctx) => ServicesScreen(appState: appState)),
                      );
                    },
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Overall Combined Average Stats Card for Selected Car
            _buildOverallCombinedStatsCard(context, vehicle, stats, primaryColor, isDark),

            const SizedBox(height: 22),

            // Latest Refuel Metrics Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Metrics',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => StatsChartsScreen(appState: appState)),
                    );
                  },
                  icon: const Icon(Icons.insights, size: 16),
                  label: const Text('Trends', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Instant Calculated Metrics Grid
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: 1.45,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              children: [
                // 1. Distance went since previous record
                _buildDashboardMetricTile(
                  context,
                  title: 'Distance Traveled',
                  value: latestCalc?.distanceTraveled != null
                      ? '+${latestCalc!.distanceTraveled!.toStringAsFixed(1)} ${vehicle.unitDistance}'
                      : (recordsAsc.isNotEmpty ? 'Base Record' : '--'),
                  subtitle: 'Since previous refuel',
                  icon: Icons.route,
                  iconColor: Colors.blueAccent,
                  badgeText: latestCalc?.dailyDistance != null
                      ? '~${latestCalc!.dailyDistance!.toStringAsFixed(0)} ${vehicle.unitDistance}/d'
                      : null,
                ),

                // 2. Price Increase
                _buildDashboardMetricTile(
                  context,
                  title: 'Price Increase / Change',
                  value: latestCalc?.priceDifferencePerUnit != null
                      ? '${latestCalc!.priceDifferencePerUnit! >= 0 ? '+' : ''}${vehicle.currency}${latestCalc.priceDifferencePerUnit!.toStringAsFixed(3)}'
                      : (recordsAsc.isNotEmpty ? 'Baseline' : '--'),
                  subtitle: latestCalc?.priceDifferencePercentage != null
                      ? '${latestCalc!.priceDifferencePercentage! >= 0 ? '+' : ''}${latestCalc.priceDifferencePercentage!.toStringAsFixed(1)}% vs prev'
                      : 'Per ${vehicle.unitVolume}',
                  icon: latestCalc?.priceDifferencePerUnit == null
                      ? Icons.price_check
                      : (latestCalc!.priceDifferencePerUnit! > 0 ? Icons.trending_up : Icons.trending_down),
                  iconColor: latestCalc?.priceDifferencePerUnit == null
                      ? (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)
                      : (latestCalc!.priceDifferencePerUnit! > 0 ? Colors.redAccent : Colors.green),
                  badgeText: latestCalc?.priceDifferencePerUnit != null && latestCalc!.priceDifferencePerUnit! > 0
                      ? 'Increased'
                      : (latestCalc?.priceDifferencePerUnit != null && latestCalc!.priceDifferencePerUnit! < 0 ? 'Decreased' : null),
                ),

                // 3. Fuel Efficiency for this Refuel (with on-the-fly unit switcher!)
                _buildEfficiencyInteractiveTile(context, vehicle, latestCalc, stats),

                // 4. Days since last fueled: DateTime.now() - latestRecord.dateTime
                () {
                  final daysSinceLastEntry = latestRecord != null
                      ? DateTime.now().difference(latestRecord.dateTime).inHours / 24.0
                      : null;
                  return _buildDashboardMetricTile(
                    context,
                    title: 'Days Since Last Refuel',
                    value: daysSinceLastEntry != null
                        ? '${daysSinceLastEntry.toStringAsFixed(1)} Days'
                        : '--',
                    subtitle: latestRecord != null
                        ? 'Last: ${AppDateUtils.format(latestRecord.dateTime)}'
                        : 'Time interval',
                    icon: Icons.hourglass_top_outlined,
                    iconColor: Colors.amber.shade800,
                    badgeText: stats.averageDaysBetweenFills != null
                        ? 'Avg: ${stats.averageDaysBetweenFills!.toStringAsFixed(1)}d'
                        : null,
                  );
                }(),

                // 5. Price per litre
                _buildDashboardMetricTile(
                  context,
                  title: 'Price per ${vehicle.unitVolume}',
                  value: latestRecord != null
                      ? '${vehicle.currency}${latestRecord.pricePerUnit.toStringAsFixed(3)}'
                      : '--',
                  subtitle: 'Latest unit price',
                  icon: Icons.local_gas_station_outlined,
                  iconColor: primaryColor,
                  badgeText: 'Avg: ${vehicle.currency}${stats.averagePricePerUnit.toStringAsFixed(2)}',
                ),

                // 6. Cost per distance
                _buildDashboardMetricTile(
                  context,
                  title: 'Cost / ${vehicle.unitDistance}',
                  value: stats.averageCostPerDistance != null
                      ? '${vehicle.currency}${stats.averageCostPerDistance!.toStringAsFixed(3)}'
                      : '--',
                  subtitle: 'Running distance cost',
                  icon: Icons.payments_outlined,
                  iconColor: Colors.deepPurpleAccent,
                  badgeText: '${stats.totalSpent.toStringAsFixed(0)} ${vehicle.currency} total',
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Recent Fuel Logs
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Entries',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (ctx) => RecordsListScreen(appState: appState)),
                    );
                  },
                  child: const Text('See All & Change', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (recordsDesc.isEmpty)
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceColor(context),
                  borderRadius: BorderRadius.circular(AppRadii.lg),
                  border: Border.all(color: AppTheme.borderColor(context)),
                ),
                child: Column(
                  children: [
                    Icon(Icons.edit_calendar_outlined, size: 36, color: primaryColor),
                    const SizedBox(height: 10),
                    const Text('No fuel logs yet for this vehicle', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text(
                      'Tap "Add New Record" above to record your odometer and fuel!',
                      style: TextStyle(fontSize: 12, color: AppTheme.textMutedColor(context)),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: recordsDesc.take(3).length,
                separatorBuilder: (context, index) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final rec = recordsDesc[index];
                  final calc = appState.getCalculationForRecord(rec);

                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.surfaceColor(context),
                      borderRadius: BorderRadius.circular(AppRadii.lg),
                      border: Border.all(color: AppTheme.borderColor(context)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(AppRadii.md),
                          ),
                          child: Icon(Icons.local_gas_station, color: primaryColor, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppDateUtils.format(rec.dateTime),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${rec.odometer.toStringAsFixed(0)} ${vehicle.unitDistance} • ${rec.fuelAmount.toStringAsFixed(1)} ${vehicle.unitVolume}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppTheme.textSecondaryColor(context),
                                  fontFeatures: const [FontFeature.tabularFigures()],
                                ),
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${vehicle.currency}${rec.totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              calc.distanceTraveled != null
                                  ? '+${calc.distanceTraveled!.toStringAsFixed(0)} ${vehicle.unitDistance}'
                                  : '${vehicle.currency}${calc.pricePerUnit.toStringAsFixed(2)}/${vehicle.unitVolume}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: calc.distanceTraveled != null
                                    ? (isDark ? AppColors.primaryLight : AppColors.primaryDark)
                                    : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          tooltip: 'Change record',
                          onPressed: () {
                            final sortedAsc = appState.activeVehicleRecordsAscending;
                            final recIdx = sortedAsc.indexWhere((r) => r.id == rec.id);
                            final prev = recIdx > 0 ? sortedAsc[recIdx - 1] : null;

                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => AddEditRecordScreen(
                                  vehicle: vehicle,
                                  recordToEdit: rec,
                                  previousRecord: prev,
                                  popularStations: appState.currentCountryInfo.popularStations,
                                  appState: appState,
                                  onSave: (updated) => appState.updateRecord(updated),
                                  onDelete: (id) => appState.deleteRecord(id),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  /// Head-Unit OEM Telemetry Advisory Banner (Modern Native vs Legacy Restricted)
  Widget _buildHeadUnitAdvisoryBanner(BuildContext context, Vehicle vehicle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isNative = TelemetryCapabilityMask.isNativeSupported(vehicle.telemetryCapabilityMask);
    final isLegacy = TelemetryCapabilityMask.isLegacyRestricted(vehicle.telemetryCapabilityMask);

    if (!isNative && !isLegacy) return const SizedBox.shrink();

    final Color accentColor = isNative ? const Color(0xFF10B981) : const Color(0xFFEA580C);
    final IconData icon = isNative ? Icons.check_circle_outline : Icons.info_outline;
    final String title = isNative ? 'Direct Telemetry Active' : 'Restricted Head-Unit Detected';
    final String message = isNative
        ? 'Your vehicle supports direct telemetry via Android Auto / CarPlay. You do not need an external OBD-II Bluetooth dongle.'
        : "Your vehicle's head-unit does not expose fuel and odometer sensors (common on older or restricted OEM models). We recommend connecting a Bluetooth OBD-II sensor for automatic fuel logging.";

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accentColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      title,
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: accentColor),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: accentColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isNative ? 'NATIVE HEAD-UNIT' : 'LEGACY OEM',
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w900, color: accentColor),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey[300] : Colors.grey[800],
                    height: 1.35,
                  ),
                ),
                if (isLegacy) ...[
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFEA580C),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    icon: const Icon(Icons.bluetooth_searching, size: 14),
                    label: const Text('Connect OBD-II Sensor', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold)),
                    onPressed: () => ObdPairingScreen.show(context, appState),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Pre-Flight Sensor Monitor Banner
  Widget _buildPreFlightSensorBanner(BuildContext context, PreFlightSensorStatus status) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: isDark ? 0.15 : 0.1),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFF59E0B).withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.sensors_off_outlined, color: Color(0xFFD97706), size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sensor Readiness Alert',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFFD97706)),
                ),
                const SizedBox(height: 3),
                Text(
                  status.alertMessage,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.amber.shade200 : const Color(0xFF92400E),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    InkWell(
                      onTap: () {
                        appState.updatePreFlightHardwareState(bluetooth: true, location: true);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Bluetooth & Location marked active')),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFD97706),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Turn On Sensors',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => SettingsScreen(appState: appState)),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                        child: Text(
                          'Settings',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.amber.shade300 : const Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Pending Auto-Refuel Verification Card with 1-Tap Confirmation and Custom Amount
  Widget _buildPendingAutoRefuelCard(BuildContext context, PendingAutoRefuel pending, Vehicle vehicle) {
    Color tierColor;
    switch (pending.detectionTier) {
      case 1:
        tierColor = AppColors.primary; // Warm Amber (Tandem)
        break;
      case 2:
        tierColor = AppColors.info; // Warm Desert Teal (OBD BLE)
        break;
      case 3:
        tierColor = AppColors.purple; // Warm Plum (EXIF)
        break;
      case 4:
        tierColor = AppColors.orange; // Warm Burnt Orange (Pit-stop)
        break;
      case 5:
      default:
        tierColor = AppColors.success; // Warm Emerald (ECU math)
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: tierColor.withValues(alpha: 0.6), width: 1.8),
        boxShadow: [
          BoxShadow(
            color: tierColor.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome, size: 12, color: tierColor),
                    const SizedBox(width: 4),
                    Text(
                      'TIER ${pending.detectionTier} AUTO-DETECTED',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: tierColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: const Icon(Icons.close, size: 18, color: Colors.grey),
                tooltip: 'Dismiss',
                onPressed: () => appState.dismissPendingAutoRefuel(pending.id),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: tierColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.local_gas_station, color: tierColor, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pending.detectedStationName.isNotEmpty ? pending.detectedStationName : 'Gas Station',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${pending.estimatedLiters.toStringAsFixed(2)} L @ ${vehicle.currency}${pending.resolvedPricePerLitre.toStringAsFixed(2)}/L • ${pending.estimatedOdometer.toStringAsFixed(0)} ${vehicle.unitDistance}',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondaryColor(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.elevatedSurfaceColor(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Did you pay ${vehicle.currency}${pending.estimatedTotalCost.toStringAsFixed(2)}?',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                ),
                Text(
                  AppDateUtils.format(pending.timestamp),
                  style: TextStyle(fontSize: 11, color: AppTheme.textMutedColor(context)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: const Text(
                    'Yes, Confirm',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  onPressed: () async {
                    await appState.confirmPendingAutoRefuel(pending.id);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Fuel record confirmed & tank calibration updated!')),
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 14),
                ),
                child: const Text('Edit Amount', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                onPressed: () => _showEditAmountDialog(context, pending, vehicle),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditAmountDialog(BuildContext context, PendingAutoRefuel pending, Vehicle vehicle) {
    final controller = TextEditingController(text: pending.estimatedTotalCost.toStringAsFixed(2));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Exact Amount Paid', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the exact amount paid. This will automatically calibrate your tank percentage multiplier for even higher accuracy next time.',
              style: TextStyle(
                fontSize: 12.5,
                color: Theme.of(ctx).brightness == Brightness.dark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              autofocus: true,
              decoration: InputDecoration(
                prefixText: '${vehicle.currency} ',
                labelText: 'Total Cost',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
            onPressed: () async {
              final parsed = double.tryParse(controller.text.trim());
              if (parsed != null && parsed > 0) {
                Navigator.of(ctx).pop();
                await appState.confirmPendingAutoRefuel(pending.id, customAmountPaid: parsed);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fuel record verified with exact amount! Calibration updated.')),
                  );
                }
              }
            },
            child: const Text('Confirm & Calibrate'),
          ),
        ],
      ),
    );
  }

  /// In-App 6-Month Servicing Notification Banner below vehicle overview
  Widget _buildServiceNotificationBanner(BuildContext context, Vehicle vehicle, Map<String, dynamic> serviceStatus) {
    final status = serviceStatus['status'] as String;
    final message = serviceStatus['message'] as String;
    final isOverdue = status == 'overdue';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isOverdue ? Colors.red.shade900.withValues(alpha: 0.18) : Colors.amber.shade900.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isOverdue ? Colors.redAccent : Colors.amber.shade700,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isOverdue ? Colors.redAccent : Colors.amber.shade700,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isOverdue ? Icons.warning_amber_rounded : Icons.access_time_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOverdue ? '⚠️ 6-MONTH SERVICE OVERDUE' : '🔔 6-MONTH SERVICE DUE SOON',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                    color: isOverdue ? Colors.redAccent : Colors.amber.shade800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12),
                ),
              ],
            ),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (ctx) => ServicesScreen(appState: appState)),
              );
            },
            child: const Text('Log Service', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  /// Overall Combined Lifetime Stats for Selected Car
  Widget _buildOverallCombinedStatsCard(
    BuildContext context,
    Vehicle vehicle,
    stats,
    Color primaryColor,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadii.xl),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.query_stats, size: 18, color: primaryColor),
                  const SizedBox(width: 8),
                  const Text(
                    'Overall Stats',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Text(
                  '${stats.totalRecords} Refuels',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w800,
                    color: primaryColor,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          Row(
            children: [
              Expanded(
                child: _overallStatTile(
                  label: 'Avg Efficiency',
                  value: stats.averageEfficiency != null
                      ? '${stats.averageEfficiency!.toStringAsFixed(2)} ${vehicle.unitDistance}/${vehicle.unitVolume}'
                      : '--',
                  color: AppColors.success,
                  isDark: isDark,
                ),
              ),
              Expanded(
                child: _overallStatTile(
                  label: 'Total Driven',
                  value: '${stats.totalDistance.toStringAsFixed(0)} ${vehicle.unitDistance}',
                  color: AppColors.primary,
                  isDark: isDark,
                ),
              ),
              Expanded(
                child: _overallStatTile(
                  label: 'Total Fuel',
                  value: '${stats.totalFuel.toStringAsFixed(0)} ${vehicle.unitVolume}',
                  color: AppColors.info,
                  isDark: isDark,
                ),
              ),
            ],
          ),

          Divider(height: 20, color: AppTheme.borderColor(context)),

          Row(
            children: [
              Expanded(
                child: _overallStatTile(
                  label: 'Total Spent',
                  value: '${vehicle.currency}${stats.totalCost.toStringAsFixed(2)}',
                  color: AppColors.warning,
                  isDark: isDark,
                ),
              ),
              Expanded(
                child: _overallStatTile(
                  label: 'Avg Cost / ${vehicle.unitDistance}',
                  value: stats.averageCostPerDistance != null
                      ? '${vehicle.currency}${stats.averageCostPerDistance!.toStringAsFixed(3)}'
                      : '--',
                  color: AppColors.purple,
                  isDark: isDark,
                ),
              ),
              Expanded(
                child: _overallStatTile(
                  label: 'Avg Interval',
                  value: stats.averageDaysBetweenFills != null
                      ? '${stats.averageDaysBetweenFills!.toStringAsFixed(1)} d'
                      : '--',
                  color: AppColors.orange,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _overallStatTile({required String label, required String value, required Color color, bool isDark = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  /// Interactive Tile allowing instant on-the-fly unit switching for this session
  Widget _buildEfficiencyInteractiveTile(
    BuildContext context,
    Vehicle vehicle,
    RecordCalculation? latestCalc,
    stats,
  ) {
    final activeUnit = appState.activeEfficiencyUnit;

    String displayVal = '--';
    String subtitle = 'Refuel efficiency (tap to switch)';

    if (latestCalc?.fuelEfficiency != null) {
      final baseKmPerL = latestCalc!.fuelEfficiency!;
      if (activeUnit == 'L/100km') {
        final l100 = (100.0 / baseKmPerL);
        displayVal = '${l100.toStringAsFixed(2)} L/100km';
      } else if (activeUnit == 'MPG') {
        final mpg = baseKmPerL * 2.35215;
        displayVal = '${mpg.toStringAsFixed(2)} MPG';
      } else {
        displayVal = '${baseKmPerL.toStringAsFixed(2)} km/L';
      }
    } else if (stats.averageEfficiency != null) {
      final base = stats.averageEfficiency!;
      if (activeUnit == 'L/100km') {
        displayVal = '${(100.0 / base).toStringAsFixed(2)} L/100km';
      } else if (activeUnit == 'MPG') {
        displayVal = '${(base * 2.35215).toStringAsFixed(2)} MPG';
      } else {
        displayVal = '${base.toStringAsFixed(2)} km/L';
      }
      subtitle = 'Overall average (tap to switch)';
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      onTap: () {
        // Cycle: km/L -> L/100km -> MPG -> km/L (instance only, reverts on restart)
        String nextUnit;
        if (activeUnit == 'km/L') {
          nextUnit = 'L/100km';
        } else if (activeUnit == 'L/100km') {
          nextUnit = 'MPG';
        } else {
          nextUnit = 'km/L';
        }
        appState.setTemporaryEfficiencyUnit(nextUnit);

        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched view unit to $nextUnit (instance only; reverts on restart)'),
            duration: const Duration(seconds: 2),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor(context),
          borderRadius: BorderRadius.circular(AppRadii.lg),
          border: Border.all(color: const Color(0xFF0D9488).withValues(alpha: 0.35), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
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
                    'Fuel Efficiency',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.info.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.swap_horiz, size: 10, color: AppColors.info),
                      const SizedBox(width: 2),
                      Text(
                        activeUnit,
                        style: const TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: AppColors.info),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Text(
              displayVal,
              style: const TextStyle(
                fontSize: 15.5,
                fontWeight: FontWeight.w800,
                color: AppColors.info,
                letterSpacing: -0.3,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
              overflow: TextOverflow.ellipsis,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardMetricTile(
    BuildContext context, {
    required String title,
    required String value,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    String? badgeText,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor(context),
        borderRadius: BorderRadius.circular(AppRadii.lg),
        border: Border.all(color: AppTheme.borderColor(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
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
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, size: 16, color: iconColor),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
              fontFeatures: [FontFeature.tabularFigures()],
            ),
            overflow: TextOverflow.ellipsis,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (badgeText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    badgeText,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: iconColor,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showQuickVehiclePickerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final vehicles = appState.vehicles;
        final activeId = appState.activeVehicleId;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
                    const Text(
                      'Select Vehicle to View',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => VehiclesScreen(appState: appState)),
                        );
                      },
                      icon: const Icon(Icons.garage, size: 16),
                      label: const Text('Manage Garage', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: vehicles.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final v = vehicles[index];
                      final isActive = v.id == activeId;
                      final vColor = Color(v.colorValue);

                      return ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                          side: BorderSide(
                            color: isActive ? vColor : Colors.grey.withValues(alpha: 0.2),
                            width: isActive ? 1.5 : 1,
                          ),
                        ),
                        tileColor: isActive ? vColor.withValues(alpha: 0.1) : null,
                        leading: SizedBox(
                          width: 50,
                          height: 30,
                          child: VehicleArtwork(
                            type: v.type,
                            bodyColor: vColor,
                            width: 50,
                            height: 30,
                          ),
                        ),
                        title: Text(
                          v.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: isActive ? vColor : null,
                          ),
                        ),
                        subtitle: Text('${v.brand} • ${v.owner}'),
                        trailing: isActive
                            ? Icon(Icons.check_circle, color: vColor)
                            : const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                        onTap: () {
                          // Single tap immediately switches car and takes user to its information
                          final targetId = v.id;
                          Navigator.of(ctx).pop();
                          appState.setActiveVehicle(targetId);
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(ctx).pop();
                    AddEditVehicleSheet.show(
                      context,
                      defaultDistanceUnit: appState.defaultDistanceUnit,
                      defaultVolumeUnit: appState.defaultVolumeUnit,
                      defaultCurrency: appState.defaultCurrency,
                      appState: appState,
                      onSave: (newVeh) => appState.addVehicle(newVeh),
                    );
                  },
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add Another Vehicle'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
