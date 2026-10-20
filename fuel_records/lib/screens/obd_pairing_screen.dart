import 'package:flutter/material.dart';
import '../services/fuel_app_state.dart';
import '../services/obd_ble_session_manager.dart';
import '../models/vehicle.dart';

class ObdPairingScreen extends StatefulWidget {
  final FuelAppState appState;

  const ObdPairingScreen({super.key, required this.appState});

  static Future<void> show(BuildContext context, FuelAppState appState) {
    return Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ObdPairingScreen(appState: appState)),
    );
  }

  @override
  State<ObdPairingScreen> createState() => _ObdPairingScreenState();
}

class _ObdPairingScreenState extends State<ObdPairingScreen> {
  final ObdBleSessionManager _sessionManager = ObdBleSessionManager();
  List<DiscoveredObdDevice> _devices = [];
  bool _isScanning = false;
  bool _showAllNearby = false;
  bool _showDiagnosticLog = false;
  String? _selectedDeviceId;

  @override
  void initState() {
    super.initState();
    _startScan();
  }

  @override
  void dispose() {
    _sessionManager.dispose();
    super.dispose();
  }

  Future<void> _startScan() async {
    setState(() => _isScanning = true);
    final results = await _sessionManager.scanForDevices(showAllNearby: _showAllNearby);
    if (mounted) {
      setState(() {
        _devices = results;
        _isScanning = false;
      });
    }
  }

  Future<void> _connectAndVerify(DiscoveredObdDevice device) async {
    setState(() => _selectedDeviceId = device.id);
    final success = await _sessionManager.connectAndHandshake(device.id);
    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${device.name} verified! You can now bind it to your vehicle.'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Handshake failed. Ensure the car ignition is ON.'),
          backgroundColor: Color(0xFFDC2626),
        ),
      );
    }
  }

  Future<void> _bindDeviceToActiveVehicle(DiscoveredObdDevice device) async {
    final activeVeh = widget.appState.activeVehicle;
    if (activeVeh == null) return;

    final updated = activeVeh.copyWith(
      boundObdDeviceId: device.id,
      telemetryCapabilityMask: activeVeh.telemetryCapabilityMask | TelemetryCapabilityMask.obd2BleBound,
    );
    await widget.appState.updateVehicle(updated);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully bound ${device.name} to ${activeVeh.name}!'),
          backgroundColor: const Color(0xFF10B981),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  Widget _buildRssiBars(int rssi) {
    int bars = 1;
    if (rssi > -65) {
      bars = 4;
    } else if (rssi > -75) {
      bars = 3;
    } else if (rssi > -85) {
      bars = 2;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(4, (index) {
        final active = index < bars;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 1.5),
          width: 3.5,
          height: 8.0 + (index * 3.5),
          decoration: BoxDecoration(
            color: active ? const Color(0xFF10B981) : Colors.grey.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(1.5),
          ),
        );
      }),
    );
  }

  Widget _buildStatusChip(ObdConnectionState state) {
    Color color;
    String label;
    IconData icon;

    switch (state) {
      case ObdConnectionState.verified:
        color = const Color(0xFF10B981);
        label = 'Verified';
        icon = Icons.check_circle;
        break;
      case ObdConnectionState.handshaking:
        color = const Color(0xFFF59E0B);
        label = 'Handshaking';
        icon = Icons.sync;
        break;
      case ObdConnectionState.initializing:
        color = const Color(0xFF2563EB);
        label = 'Initializing AT PIDs';
        icon = Icons.hourglass_top;
        break;
      case ObdConnectionState.connecting:
        color = const Color(0xFF6366F1);
        label = 'Connecting GATT';
        icon = Icons.bluetooth_searching;
        break;
      case ObdConnectionState.failed:
        color = const Color(0xFFDC2626);
        label = 'Handshake Failed';
        icon = Icons.error_outline;
        break;
      case ObdConnectionState.scanning:
        color = const Color(0xFF0284C7);
        label = 'Scanning';
        icon = Icons.radar;
        break;
      case ObdConnectionState.disconnected:
        color = Colors.grey;
        label = 'Ready to Pair';
        icon = Icons.bluetooth;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final activeVeh = widget.appState.activeVehicle;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pair OBD-II BLE Dongle', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: _isScanning
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.refresh),
            onPressed: _isScanning ? null : _startScan,
          ),
        ],
      ),
      body: StreamBuilder<ObdConnectionState>(
        stream: _sessionManager.stateStream,
        initialData: _sessionManager.state,
        builder: (context, stateSnap) {
          final currentState = stateSnap.data ?? ObdConnectionState.disconnected;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Target Vehicle Overview Card
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E88E5).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.directions_car, color: Color(0xFF1E88E5), size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activeVeh?.name ?? 'No Active Car',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            activeVeh?.boundObdDeviceId != null
                                ? 'Currently Bound: ${activeVeh!.boundObdDeviceId}'
                                : 'No OBD sensor bound yet',
                            style: TextStyle(
                              fontSize: 12,
                              color: activeVeh?.boundObdDeviceId != null ? const Color(0xFF10B981) : Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusChip(currentState),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Filter Switch
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'DISCOVERED OBD-II BLUETOOTH DEVICES',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.6),
                  ),
                  Row(
                    children: [
                      Text(
                        'Show All Nearby',
                        style: TextStyle(fontSize: 11, color: isDark ? Colors.grey[400] : Colors.grey[600]),
                      ),
                      Switch(
                        value: _showAllNearby,
                        onChanged: (val) {
                          setState(() => _showAllNearby = val);
                          _startScan();
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Devices List
              if (_devices.isEmpty && !_isScanning) ...[
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Center(
                    child: Text(
                      'No OBD-II devices detected. Plug your ELM327 adapter into your car OBD-II port and turn ignition ON.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey),
                    ),
                  ),
                ),
              ] else ...[
                ..._devices.map((dev) {
                  final isSelected = dev.id == _selectedDeviceId;
                  final isVerified = isSelected && currentState == ObdConnectionState.verified;
                  final isBusy = isSelected &&
                      (currentState == ObdConnectionState.connecting ||
                          currentState == ObdConnectionState.handshaking ||
                          currentState == ObdConnectionState.initializing);

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E1E28) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isVerified
                            ? const Color(0xFF10B981)
                            : (isSelected ? const Color(0xFF1E88E5) : Colors.grey.withValues(alpha: 0.18)),
                        width: isSelected ? 1.8 : 1.0,
                      ),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: (dev.isKnownObdService ? const Color(0xFF0284C7) : Colors.grey)
                                    .withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                dev.isKnownObdService ? Icons.bluetooth_connected : Icons.bluetooth,
                                color: dev.isKnownObdService ? const Color(0xFF0284C7) : Colors.grey,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          dev.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      _buildRssiBars(dev.rssi),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '${dev.id} • ${dev.rssi} dBm',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontFamily: 'monospace',
                                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isVerified)
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1E88E5),
                                  foregroundColor: Colors.white,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: isBusy ? null : () => _connectAndVerify(dev),
                                child: isBusy
                                    ? const SizedBox(
                                        width: 16,
                                        height: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Text('Test & Handshake', style: TextStyle(fontSize: 12)),
                              ),
                          ],
                        ),
                        if (isVerified) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF10B981),
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              icon: const Icon(Icons.link, size: 18),
                              label: Text('Bind to ${activeVeh?.name ?? "Vehicle"}'),
                              onPressed: () => _bindDeviceToActiveVehicle(dev),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                }),
              ],
              const SizedBox(height: 14),

              // Expandable Diagnostic Log
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.18)),
                ),
                child: Material(
                  color: isDark ? const Color(0xFF161620) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  child: ExpansionTile(
                    initiallyExpanded: _showDiagnosticLog,
                    onExpansionChanged: (exp) => setState(() => _showDiagnosticLog = exp),
                    leading: const Icon(Icons.terminal, color: Color(0xFF6366F1)),
                    title: const Text('Live Diagnostic Handshake Log', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                    children: [
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        color: isDark ? const Color(0xFF101018) : const Color(0xFFF8F9FD),
                        child: StreamBuilder<String>(
                          stream: _sessionManager.logStream,
                          builder: (ctx, _) {
                            final logs = _sessionManager.diagnosticLog;
                            if (logs.isEmpty) {
                              return const Text('Log is empty. Start scanning or handshake to view AT command stream.', style: TextStyle(fontSize: 11, color: Colors.grey));
                            }
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: logs
                                  .map((l) => Text(
                                        l,
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                          color: l.contains('[ERR]')
                                              ? Colors.red
                                              : (l.contains('[RX]') ? Colors.green : (isDark ? Colors.grey[300] : Colors.grey[800])),
                                        ),
                                      ))
                                  .toList(),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
