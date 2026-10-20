import 'package:flutter/material.dart';
import '../services/fuel_app_state.dart';
import '../models/pending_auto_refuel.dart';
import '../models/vehicle.dart';

class AutoRefuelSimulatorSheet extends StatefulWidget {
  final FuelAppState appState;

  const AutoRefuelSimulatorSheet({super.key, required this.appState});

  static Future<void> show(BuildContext context, FuelAppState appState) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AutoRefuelSimulatorSheet(appState: appState),
    );
  }

  @override
  State<AutoRefuelSimulatorSheet> createState() => _AutoRefuelSimulatorSheetState();
}

class _AutoRefuelSimulatorSheetState extends State<AutoRefuelSimulatorSheet> {
  bool _isProcessing = false;
  String? _statusMessage;
  PendingAutoRefuel? _lastResult;

  final double _simLiters = 42.5;
  final double _simPrice = 1.45;
  final String _simStation = 'Shell';

  Future<void> _triggerTier(int tier) async {
    setState(() {
      _isProcessing = true;
      _statusMessage = 'Running Tier $tier simulation...';
      _lastResult = null;
    });

    try {
      final res = await widget.appState.simulateTierRefuel(
        tier,
        customLiters: _simLiters,
        customPrice: _simPrice,
        customStation: _simStation,
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
          _lastResult = res;
          _statusMessage = res != null
              ? 'Tier $tier Refuel Generated! (${res.estimatedLiters} L @ ${widget.appState.defaultCurrency}${res.resolvedPricePerLitre}/L = ${widget.appState.defaultCurrency}${res.estimatedTotalCost})'
              : 'Tier $tier refuel could not be generated (no active vehicle or threshold unmet).';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _statusMessage = 'Simulation error: $e';
        });
      }
    }
  }

  Widget _buildTierButton({
    required int tier,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isDark ? const Color(0xFF1E1E28) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _isProcessing ? null : () => _triggerTier(tier),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'TIER $tier',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                                color: color,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              title,
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 11.5,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.play_circle_outline, color: Colors.grey, size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeVehicle = widget.appState.activeVehicle;
    final preFlight = widget.appState.preFlightStatus;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF101018) : const Color(0xFFF4F6FB),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 8),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.auto_awesome, color: Color(0xFF1E88E5), size: 22),
                    SizedBox(width: 8),
                    Text(
                      '5-Tier Auto-Refuel Simulator',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, letterSpacing: -0.3),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Vehicle Telemetry Info Card
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            activeVehicle?.name ?? 'No vehicle selected',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E88E5).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Calibration: ${activeVehicle?.calibrationFactor.toStringAsFixed(3) ?? "1.000"}x',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E88E5),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Tank: ${activeVehicle?.tankCapacityLiters ?? 55.0}L • Last Odo: ${activeVehicle?.lastKnownOdometer?.toStringAsFixed(1) ?? "0"} • Fuel %: ${activeVehicle?.lastKnownFuelPercent?.toStringAsFixed(1) ?? "30.0"}%',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Hardware Switch Simulation (Pre-flight guard testing)
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'PRE-FLIGHT SENSOR SWITCHES',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.bluetooth, size: 18, color: Colors.blue),
                              SizedBox(width: 8),
                              Text('Bluetooth Hardware Switch', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                          Switch(
                            value: widget.appState.orchestrator.isBluetoothHardwareOn,
                            onChanged: (val) {
                              setState(() {
                                widget.appState.updatePreFlightHardwareState(bluetooth: val);
                              });
                            },
                          ),
                        ],
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.location_on, size: 18, color: Colors.orange),
                              SizedBox(width: 8),
                              Text('Location Hardware Switch', style: TextStyle(fontSize: 13)),
                            ],
                          ),
                          Switch(
                            value: widget.appState.orchestrator.isLocationHardwareOn,
                            onChanged: (val) {
                              setState(() {
                                widget.appState.updatePreFlightHardwareState(location: val);
                              });
                            },
                          ),
                        ],
                      ),
                      if (preFlight.shouldAlertUser) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  'Pre-Flight Alert Active: Switch is OFF while user consented in Settings',
                                  style: TextStyle(fontSize: 11, color: isDark ? Colors.amber[200] : Colors.amber[900]),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // OEM Head-Unit Capability Probe Simulation
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'HEAD-UNIT OEM CAPABILITY PROBE',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Simulate whether the connected car OEM bus exposes fuel and odometer sensors natively or requires an external OBD-II dongle.',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.grey[400] : Colors.grey[600]),
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
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.check_circle_outline, size: 16),
                              label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Modern Vehicle (Native)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              onPressed: () async {
                                final v = widget.appState.activeVehicle;
                                if (v != null) {
                                  final updated = v.copyWith(
                                    telemetryCapabilityMask: TelemetryCapabilityMask.headUnitNativeFuel |
                                        TelemetryCapabilityMask.headUnitNativeOdometer,
                                  );
                                  await widget.appState.updateVehicle(updated);
                                  setState(() {
                                    _statusMessage =
                                        'Modern Vehicle Probe: STATUS_SUCCESS. Direct telemetry active — no OBD-II dongle needed.';
                                  });
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFEA580C),
                                side: const BorderSide(color: Color(0xFFEA580C)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.info_outline, size: 16),
                              label: const FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text('Legacy / Restricted', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              ),
                              onPressed: () async {
                                final v = widget.appState.activeVehicle;
                                if (v != null) {
                                  final updated = v.copyWith(
                                    telemetryCapabilityMask: TelemetryCapabilityMask.headUnitRestrictedLegacy,
                                  );
                                  await widget.appState.updateVehicle(updated);
                                  setState(() {
                                    _statusMessage =
                                        'Legacy Vehicle Probe: STATUS_UNIMPLEMENTED. Advisory active: recommended to pair OBD-II sensor.';
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                const Text(
                  'TRIGGER PIPELINE TIERS',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5),
                ),
                const SizedBox(height: 8),

                _buildTierButton(
                  tier: 1,
                  title: 'Apple CarPlay & Android Auto',
                  subtitle: 'Head-unit sensor fusion + ignition jump prompt',
                  icon: Icons.directions_car,
                  color: const Color(0xFF2563EB),
                  isDark: isDark,
                ),

                _buildTierButton(
                  tier: 2,
                  title: 'Live OBD-II BLE + GPS Price',
                  subtitle: 'ELM327 handshake + 5-reading anti-slosh filter',
                  icon: Icons.bluetooth_connected,
                  color: const Color(0xFF0284C7),
                  isDark: isDark,
                ),

                _buildTierButton(
                  tier: 3,
                  title: 'Camera Receipt / Quick Draft',
                  subtitle: 'Instant timestamp draft & deferred OBD merge',
                  icon: Icons.camera_alt_outlined,
                  color: const Color(0xFF7C3AED),
                  isDark: isDark,
                ),

                _buildTierButton(
                  tier: 4,
                  title: 'Motion Pit-Stop Fingerprint',
                  subtitle: '3-10 min driving stop matched with ECU refuel',
                  icon: Icons.timer_outlined,
                  color: const Color(0xFFEA580C),
                  isDark: isDark,
                ),

                _buildTierButton(
                  tier: 5,
                  title: 'Zero-Permission Delayed ECU',
                  subtitle: 'Volume conservation math + habitual station',
                  icon: Icons.calculate_outlined,
                  color: const Color(0xFF059669),
                  isDark: isDark,
                ),

                if (_isProcessing) ...[
                  const SizedBox(height: 16),
                  const Center(child: CircularProgressIndicator()),
                ],

                if (_statusMessage != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _lastResult != null
                          ? const Color(0xFF10B981).withValues(alpha: 0.12)
                          : Colors.grey.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _lastResult != null
                            ? const Color(0xFF10B981).withValues(alpha: 0.3)
                            : Colors.grey.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      _statusMessage!,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: _lastResult != null ? const Color(0xFF10B981) : (isDark ? Colors.grey[300] : Colors.grey[800]),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
