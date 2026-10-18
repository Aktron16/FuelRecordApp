import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../services/fuel_app_state.dart';
import '../services/country_data.dart';
import '../widgets/app_logo.dart';

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
                        'Version 1.1.2 • Offline Fuel Tracker',
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
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Appearance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('Choose Light or Dark mode', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  DropdownButtonFormField<ThemeMode>(
                    value: _themeMode,
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
                        child: Text('System Default (Follow Device)'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text('Light Mode'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text('Dark Mode'),
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
                    decoration: InputDecoration(
                      labelText: 'Select Country',
                      prefixIcon: const Icon(Icons.location_on_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      filled: true,
                    ),
                    items: CountryRepository.countries.map((c) {
                      return DropdownMenuItem(
                        value: c.name,
                        child: Text('${c.name} (${c.currency})'),
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
                      const Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Units & Currency', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          Text('Applies to all vehicles and records', style: TextStyle(color: Colors.grey, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Distance Unit Dropdown
                  DropdownButtonFormField<String>(
                    value: _distanceUnit,
                    decoration: InputDecoration(
                      labelText: 'Distance Unit',
                      prefixIcon: const Icon(Icons.route_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      filled: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'km', child: Text('Kilometers (km)')),
                      DropdownMenuItem(value: 'mi', child: Text('Miles (mi)')),
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
                    decoration: InputDecoration(
                      labelText: 'Fuel Volume Unit',
                      prefixIcon: const Icon(Icons.local_gas_station_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      filled: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'L', child: Text('Litres (L)')),
                      DropdownMenuItem(value: 'gal', child: Text('Gallons (gal)')),
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
                    decoration: InputDecoration(
                      labelText: 'Default Fuel Efficiency',
                      prefixIcon: const Icon(Icons.eco_outlined),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                      filled: true,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'km/L', child: Text('Kilometers per Litre (km/L)')),
                      DropdownMenuItem(value: 'L/100km', child: Text('Litres per 100 Kilometers (L/100km)')),
                      DropdownMenuItem(value: 'MPG', child: Text('Miles per Gallon (MPG)')),
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
                          decoration: InputDecoration(
                            labelText: 'Default Currency',
                            prefixIcon: const Icon(Icons.attach_money),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                            filled: true,
                          ),
                          items: {..._popularCurrencies, _currency}.map((c) {
                            return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontWeight: FontWeight.bold)));
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

          // 4. Data Backup & Management
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
                          label: const Text('Backup Data'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _handleRestoreBackup(context),
                          icon: const Icon(Icons.settings_backup_restore, size: 18),
                          label: const Text('Restore Data'),
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
                          label: const Text('Demo Data'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                        onPressed: () => _confirmClearData(context),
                        icon: const Icon(Icons.delete_forever, size: 18),
                        label: const Text('Clear All'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Version Footer
          Center(
            child: Text(
              'Fuel Metrics • Version 1.1.2',
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
}
