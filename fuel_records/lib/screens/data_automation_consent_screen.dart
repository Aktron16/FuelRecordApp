import 'package:flutter/material.dart';
import '../services/fuel_app_state.dart';
import '../widgets/app_logo.dart';
import '../theme/app_theme.dart';

class DataAutomationConsentScreen extends StatefulWidget {
  final FuelAppState appState;

  const DataAutomationConsentScreen({super.key, required this.appState});

  @override
  State<DataAutomationConsentScreen> createState() => _DataAutomationConsentScreenState();
}

class _DataAutomationConsentScreenState extends State<DataAutomationConsentScreen> {
  bool _btObd = false;
  bool _locPrice = false;
  bool _motionStop = false;
  bool _alerts = false;

  @override
  void initState() {
    super.initState();
    // GDPR Requirement: strictly opt-in, no pre-ticked hidden boxes
    _btObd = widget.appState.carBluetoothObdSync;
    _locPrice = widget.appState.locationStationPriceFinder;
    _motionStop = widget.appState.motionStopDetection;
    _alerts = widget.appState.refuelVerificationAlerts;
  }

  Future<void> _completeWithPreferences(bool manualModeOnly) async {
    if (manualModeOnly) {
      await widget.appState.setAutomationPermission(
        carBluetoothObdSync: false,
        locationStationPriceFinder: false,
        motionStopDetection: false,
        refuelVerificationAlerts: false,
      );
    } else {
      await widget.appState.setAutomationPermission(
        carBluetoothObdSync: _btObd,
        locationStationPriceFinder: _locPrice,
        motionStopDetection: _motionStop,
        refuelVerificationAlerts: _alerts,
      );
    }
    await widget.appState.setHasCompletedDataConsent(true);
  }

  Widget _buildToggleTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required bool value,
    required ValueChanged<bool> onChanged,
    required bool isDark,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: value
              ? iconColor.withValues(alpha: 0.6)
              : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
          width: value ? 1.5 : 1.0,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch(
            value: value,
            activeTrackColor: iconColor,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(height: 12),
                      FuelManLogo(size: 64, primaryColor: theme.colorScheme.primary),
                      const SizedBox(height: 16),
                      const Text(
                        'Data & Automation Setup',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: -0.5),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      // GDPR Privacy Notice (Prominently displayed)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'All your car and fuel data stays privately on your phone and is never sold or uploaded to external servers.',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: isDark ? const Color(0xFF34D399) : const Color(0xFF065F46),
                                  height: 1.35,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'OPTIONAL AUTOMATION PERMISSIONS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: isDark ? AppColors.darkTextMuted : AppColors.lightTextMuted,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      _buildToggleTile(
                        icon: Icons.bluetooth_connected,
                        iconColor: AppColors.info, // Warm Desert Teal
                        title: 'Car Bluetooth & OBD Auto-Sync',
                        description: 'Connects to your OBD-II BLE adapter to read fuel level & odometer automatically.',
                        value: _btObd,
                        onChanged: (val) => setState(() => _btObd = val),
                        isDark: isDark,
                      ),
                      _buildToggleTile(
                        icon: Icons.local_gas_station_outlined,
                        iconColor: AppColors.primary, // Tachometer Amber
                        title: 'Gas Station & Local Price Finder',
                        description: 'Locates nearby pump brands and resolves local per-liter fuel pricing at fill-up time.',
                        value: _locPrice,
                        onChanged: (val) => setState(() => _locPrice = val),
                        isDark: isDark,
                      ),
                      _buildToggleTile(
                        icon: Icons.directions_car_filled_outlined,
                        iconColor: AppColors.purple,
                        title: 'Smart Driving Stop Detection',
                        description: 'Detects 3–10 minute driving stops to automatically timestamp missed fuel pit-stops.',
                        value: _motionStop,
                        onChanged: (val) => setState(() => _motionStop = val),
                        isDark: isDark,
                      ),
                      _buildToggleTile(
                        icon: Icons.notifications_active_outlined,
                        iconColor: AppColors.success, // Warm Emerald
                        title: 'Refuel Verification Alerts',
                        description: 'Sends a polite prompt to confirm the total amount paid with one quick tap.',
                        value: _alerts,
                        onChanged: (val) => setState(() => _alerts = val),
                        isDark: isDark,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Action Buttons
              Column(
                children: [
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => _completeWithPreferences(false),
                      child: const Text(
                        'Save Preferences & Continue',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: () => _completeWithPreferences(true),
                      child: const Text(
                        'Continue with Manual Mode',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                      ),
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
}

