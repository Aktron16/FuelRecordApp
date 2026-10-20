import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/fuel_app_state.dart';
import '../services/country_data.dart';
import '../widgets/app_logo.dart';
import 'auto_refuel_simulator_sheet.dart';
import 'obd_pairing_screen.dart';

class SettingsScreen extends StatefulWidget {
  final FuelAppState appState;

  const SettingsScreen({super.key, required this.appState});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _selectedCountry;
  late String _distanceUnit;
  late String _volumeUnit;
  late String _efficiencyUnit;
  late String _currency;
  late ThemeMode _themeMode;

  late bool _carBluetoothObdSync;
  late bool _locationStationPriceFinder;
  late bool _motionStopDetection;
  late bool _refuelVerificationAlerts;

  final List<String> _popularCurrencies = const [
    '\$', '€', '£', '₹', '¥', 'C\$', 'A\$', 'AED', 'R\$', 'Mex\$', 'R', 'kr', 'CHF', 'SAR', 'S\$'
  ];

  @override
  void initState() {
    super.initState();
    _selectedCountry = widget.appState.selectedCountry;
    _distanceUnit = widget.appState.defaultDistanceUnit;
    _volumeUnit = widget.appState.defaultVolumeUnit;
    _efficiencyUnit = widget.appState.defaultEfficiencyUnit;
    _currency = widget.appState.defaultCurrency;
    _themeMode = widget.appState.themeMode;

    _carBluetoothObdSync = widget.appState.carBluetoothObdSync;
    _locationStationPriceFinder = widget.appState.locationStationPriceFinder;
    _motionStopDetection = widget.appState.motionStopDetection;
    _refuelVerificationAlerts = widget.appState.refuelVerificationAlerts;
  }

  Future<void> _handleAutomationToggle(String type, bool newValue) async {
    if (newValue == true) {
      setState(() {
        if (type == 'bluetooth') _carBluetoothObdSync = true;
        if (type == 'location') _locationStationPriceFinder = true;
        if (type == 'motion') _motionStopDetection = true;
        if (type == 'alerts') _refuelVerificationAlerts = true;
      });
      await widget.appState.setAutomationPermission(
        carBluetoothObdSync: _carBluetoothObdSync,
        locationStationPriceFinder: _locationStationPriceFinder,
        motionStopDetection: _motionStopDetection,
        refuelVerificationAlerts: _refuelVerificationAlerts,
      );
      return;
    }

    // Confirmation modal with exact GDPR microcopy
    String title = '';
    String warningMessage = '';

    switch (type) {
      case 'bluetooth':
        title = 'Turn off Bluetooth Auto-Sync?';
        warningMessage =
            'We use Bluetooth only to read your car\'s fuel tank level and mileage from your car adapter so you don\'t have to type them in. If you turn this off, the app won\'t be able to read your car\'s fuel level automatically.';
        break;
      case 'location':
        title = 'Turn off Location Finder?';
        warningMessage =
            'We check your location only at the moment you refuel to find the name of the gas station you are at and look up the fuel price per liter in that area. If you turn this off, the app will guess the price using your past fill-ups instead.';
        break;
      case 'motion':
        title = 'Turn off Stop Detection?';
        warningMessage =
            'We use your phone\'s step and motion sensor to notice when you make a short 5-minute stop while driving, which helps fill in the right time and date if your Bluetooth was turned off at the gas pump. If you turn this off, missed fill-ups won\'t know the exact time you stopped.';
        break;
      case 'alerts':
        title = 'Turn off Refuel Alerts?';
        warningMessage =
            'We send you a quick alert after you refuel to let you confirm the total amount you paid with one tap, and to remind you if Bluetooth or Location is turned off. If you turn this off, you will need to open the app manually to review detected fill-ups.';
        break;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
        content: Text(warningMessage, style: const TextStyle(fontSize: 13.5, height: 1.4)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Keep On'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Turn Off'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() {
        if (type == 'bluetooth') _carBluetoothObdSync = false;
        if (type == 'location') _locationStationPriceFinder = false;
        if (type == 'motion') _motionStopDetection = false;
        if (type == 'alerts') _refuelVerificationAlerts = false;
      });
      await widget.appState.setAutomationPermission(
        carBluetoothObdSync: _carBluetoothObdSync,
        locationStationPriceFinder: _locationStationPriceFinder,
        motionStopDetection: _motionStopDetection,
        refuelVerificationAlerts: _refuelVerificationAlerts,
      );
    }
  }

  void _onCountryChanged(String? newCountry) {
    if (newCountry == null) return;
    final info = CountryRepository.getCountryByName(newCountry);
    setState(() {
      _selectedCountry = info.name;
      _currency = info.currency;
      _distanceUnit = info.defaultDistanceUnit;
      _volumeUnit = info.defaultVolumeUnit;
      _efficiencyUnit = info.defaultEfficiencyUnit;
    });

    widget.appState.setCountry(newCountry);
  }

  void _saveUnits() {
    widget.appState.setDefaultUnits(
      distanceUnit: _distanceUnit,
      volumeUnit: _volumeUnit,
      efficiencyUnit: _efficiencyUnit,
      currency: _currency,
    );
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Settings saved. Default currency and units updated everywhere.'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final countryInfo = CountryRepository.getCountryByName(_selectedCountry);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // App Header Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E28) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
            ),
            child: Row(
              children: [
                const FuelManLogo(size: 48),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Fuel Metrics',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: -0.3),
                      ),
                      Text(
                        'Version ${FuelAppState.appVersion} • Offline Fuel Tracker',
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.65)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // 1. Theme Mode (Light / Dark)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.palette_outlined, color: Colors.purple),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text('Choose Light or Dark mode', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<ThemeMode>(
                    value: _themeMode,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Theme Mode',
                      prefixIcon: Icon(
                        _themeMode == ThemeMode.dark
                            ? Icons.dark_mode
                            : (_themeMode == ThemeMode.light ? Icons.light_mode : Icons.brightness_auto),
                        color: Colors.purple,
                      ),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      filled: true,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text('System Default (Follow Device)', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text('Light Mode', overflow: TextOverflow.ellipsis),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text('Dark Mode', overflow: TextOverflow.ellipsis),
                      ),
                    ],
                    onChanged: (mode) {
                      if (mode != null) {
                        setState(() => _themeMode = mode);
                        widget.appState.setThemeMode(mode);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 2. Country Lived In
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.public, color: theme.colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Country', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text('Sets currency and popular gas stations', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<String>(
                    value: _selectedCountry,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Select Country',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      filled: true,
                    ),
                    items: CountryRepository.countries.map((c) {
                      return DropdownMenuItem(
                        value: c.name,
                        child: Text('${c.name} (${c.currency})', overflow: TextOverflow.ellipsis),
                      );
                    }).toList(),
                    onChanged: _onCountryChanged,
                  ),

                  const SizedBox(height: 14),

                  Text(
                    'Common Gas Stations in $_selectedCountry:',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: countryInfo.popularStations.map((st) {
                      return Chip(
                        padding: EdgeInsets.zero,
                        labelPadding: const EdgeInsets.symmetric(horizontal: 8),
                        label: Text(st, style: const TextStyle(fontSize: 11)),
                        backgroundColor: isDark ? Colors.grey.shade800 : Colors.grey.shade100,
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 3. Centralized Units & Currency
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.teal.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.tune, color: Colors.teal),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Units & Currency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text('Applies to all vehicles and records', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Distance Unit Dropdown
                  DropdownButtonFormField<String>(
                    value: _distanceUnit,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Distance Unit',
                      prefixIcon: const Icon(Icons.route_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      filled: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'km', child: Text('Kilometers (km)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'mi', child: Text('Miles (mi)', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _distanceUnit = val);
                        _saveUnits();
                      }
                    },
                  ),

                  const SizedBox(height: 14),

                  // Volume Unit Dropdown
                  DropdownButtonFormField<String>(
                    value: _volumeUnit,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Fuel Volume Unit',
                      prefixIcon: const Icon(Icons.local_gas_station_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      filled: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'L', child: Text('Litres (L)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'gal', child: Text('Gallons (gal)', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _volumeUnit = val);
                        _saveUnits();
                      }
                    },
                  ),

                  const SizedBox(height: 14),

                  // Fuel Efficiency Unit Dropdown
                  DropdownButtonFormField<String>(
                    value: _efficiencyUnit,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Default Fuel Efficiency',
                      prefixIcon: const Icon(Icons.eco_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      filled: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'km/L', child: Text('Kilometers per Litre (km/L)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'L/100km', child: Text('Litres per 100 Kilometers (L/100km)', overflow: TextOverflow.ellipsis)),
                      DropdownMenuItem(value: 'MPG', child: Text('Miles per Gallon (MPG)', overflow: TextOverflow.ellipsis)),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setState(() => _efficiencyUnit = val);
                        _saveUnits();
                      }
                    },
                  ),

                  const SizedBox(height: 14),

                  // Currency Symbol Dropdown & Custom Input
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _currency,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: 'Default Currency',
                            prefixIcon: const Icon(Icons.attach_money),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            filled: true,
                          ),
                          items: {..._popularCurrencies, _currency}.map((c) {
                            return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis));
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setState(() => _currency = val);
                              _saveUnits();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 10),
                      SizedBox(
                        width: 85,
                        child: TextFormField(
                          key: ValueKey(_currency),
                          initialValue: _currency,
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            labelText: 'Custom',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            filled: true,
                          ),
                          onChanged: (val) {
                            if (val.trim().isNotEmpty) {
                              setState(() => _currency = val.trim());
                              _saveUnits();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 4. Auto-Log & Permissions (GDPR Compliant)
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E88E5).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.auto_awesome, color: Color(0xFF1E88E5)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text('Auto-Log & Permissions', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                            Text('Hardware automation & refuel detection', style: TextStyle(color: Colors.grey, fontSize: 11)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Privacy banner
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            '100% Private: All telemetry stays on your phone. Zero cloud servers.',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: isDark ? const Color(0xFF34D399) : const Color(0xFF065F46),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Toggle 1: Car Bluetooth & OBD Auto-Sync
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2563EB).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.bluetooth_connected, color: Color(0xFF2563EB), size: 20),
                    ),
                    title: const Text('Car Bluetooth & OBD Auto-Sync', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Reads fuel tank level & odometer from your car adapter automatically.', style: TextStyle(fontSize: 12)),
                    value: _carBluetoothObdSync,
                    onChanged: (val) => _handleAutomationToggle('bluetooth', val),
                  ),
                  const Divider(height: 1),

                  // Toggle 2: Gas Station & Local Price Finder
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEA580C).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.location_on_outlined, color: Color(0xFFEA580C), size: 20),
                    ),
                    title: const Text('Gas Station & Local Price Finder', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Finds station name and local per-liter fuel price at refuel time.', style: TextStyle(fontSize: 12)),
                    value: _locationStationPriceFinder,
                    onChanged: (val) => _handleAutomationToggle('location', val),
                  ),
                  const Divider(height: 1),

                  // Toggle 3: Smart Driving Stop Detection
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.directions_car_outlined, color: Color(0xFF7C3AED), size: 20),
                    ),
                    title: const Text('Smart Driving Stop Detection', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Notices 3–10 minute driving stops to timestamp missed pit stops.', style: TextStyle(fontSize: 12)),
                    value: _motionStopDetection,
                    onChanged: (val) => _handleAutomationToggle('motion', val),
                  ),
                  const Divider(height: 1),

                  // Toggle 4: Refuel Verification Alerts
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    secondary: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF059669).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.notifications_active_outlined, color: Color(0xFF059669), size: 20),
                    ),
                    title: const Text('Refuel Verification Alerts', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                    subtitle: const Text('Quick alert to confirm total paid with one tap after refueling.', style: TextStyle(fontSize: 12)),
                    value: _refuelVerificationAlerts,
                    onChanged: (val) => _handleAutomationToggle('alerts', val),
                  ),
                  const SizedBox(height: 14),

                  // OBD-II Pairing Screen Launcher
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => ObdPairingScreen.show(context, widget.appState),
                      icon: const Icon(Icons.bluetooth_searching, size: 18),
                      label: const Text('Pair OBD-II Bluetooth Sensor'),
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Simulator Launcher
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => AutoRefuelSimulatorSheet.show(context, widget.appState),
                      icon: const Icon(Icons.tune, size: 18),
                      label: const Text('Open 5-Tier Auto-Refuel Simulator'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // 5. Data Backup & Management
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Backup & Data', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 6),
                  Text(
                    'Export or restore a complete snapshot of your vehicles, fuel records, and service logs.',
                    style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.65)),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonalIcon(
                          onPressed: () => _handleExportBackup(context),
                          icon: const Icon(Icons.backup_outlined, size: 18),
                          label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Backup Data')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _handleRestoreBackup(context),
                          icon: const Icon(Icons.settings_backup_restore, size: 18),
                          label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Restore Data')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            widget.appState.loadSampleData();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Sample demo data loaded')),
                            );
                          },
                          icon: const Icon(Icons.cloud_download_outlined, size: 18),
                          label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Demo Data')),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                          onPressed: () => _confirmClearData(context),
                          icon: const Icon(Icons.delete_forever, size: 18),
                          label: const FittedBox(fit: BoxFit.scaleDown, child: Text('Clear All')),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFDC2626),
                        side: const BorderSide(color: Color(0xFFDC2626)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => _confirmDeleteAllLocalAppData(context),
                      icon: const Icon(Icons.shield_outlined, size: 18),
                      label: const Text('Delete All Local App Data (GDPR Erasure)'),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Version Footer
          Center(
            child: Text(
              'Fuel Metrics • Version ${FuelAppState.appVersion}',
              style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
            ),
          ),

          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<void> _handleExportBackup(BuildContext context) async {
    try {
      final file = await widget.appState.saveBackupToFile();
      final jsonStr = widget.appState.exportAllDataBackup();
      await Clipboard.setData(ClipboardData(text: jsonStr));

      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 10),
              Text('Backup Created'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Your complete data backup has been created and copied to clipboard.'),
              const SizedBox(height: 12),
              const Text('Saved File Path:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
              const SizedBox(height: 4),
              SelectableText(
                file.path,
                style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup failed: $e')),
      );
    }
  }

  void _handleRestoreBackup(BuildContext context) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Restore Data Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Paste your backup JSON text below to restore your vehicles and fuel records:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: textController,
              maxLines: 6,
              style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
              decoration: const InputDecoration(
                hintText: '{\n  "version": "1.0.2",\n  "vehicles": [...]\n}',
                border: OutlineInputBorder(),
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
              final raw = textController.text.trim();
              if (raw.isEmpty) return;
              try {
                await widget.appState.importAllDataBackup(raw);
                if (!ctx.mounted) return;
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Data restored successfully!')),
                );
              } catch (e) {
                if (!ctx.mounted) return;
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('Failed to restore: $e')),
                );
              }
            },
            child: const Text('Restore'),
          ),
        ],
      ),
    );
  }

  void _confirmClearData(BuildContext context) {
    bool createBackup = true;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          title: Row(
            children: const [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Text('Clear All Data?', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('This will erase all vehicles, records, and service logs. Are you sure?'),
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
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
              onPressed: () async {
                Navigator.of(ctx).pop();
                if (createBackup) {
                  try {
                    await widget.appState.saveBackupToFile();
                  } catch (_) {}
                }
                await widget.appState.clearAllData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('All data has been cleared.')),
                  );
                }
              },
              child: const Text('Clear All'),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDeleteAllLocalAppData(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.shield_outlined, color: Color(0xFFDC2626)),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Delete All Local Data?',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'GDPR Right to Erasure: This will permanently wipe all vehicle profiles, fuel records, service history, pit-stop timestamps, consent choices, and local database files from your device.\n\nAll data is stored strictly on your phone, so once erased, it cannot be recovered without a previous backup.',
              style: TextStyle(fontSize: 13, height: 1.4),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await widget.appState.deleteAllLocalAppData();
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            },
            child: const Text('Permanently Erase Everything'),
          ),
        ],
      ),
    );
  }
}
