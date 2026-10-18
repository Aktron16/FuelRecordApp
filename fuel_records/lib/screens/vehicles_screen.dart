import 'dart:io';
import 'package:flutter/material.dart';
import '../models/vehicle.dart';
import '../services/fuel_app_state.dart';
import '../widgets/vehicle_artwork.dart';
import 'add_edit_vehicle_sheet.dart';

class VehiclesScreen extends StatelessWidget {
  final FuelAppState appState;

  const VehiclesScreen({
    super.key,
    required this.appState,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final vehicles = appState.vehicles;
    final activeId = appState.activeVehicleId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Garage', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        icon: const Icon(Icons.add),
        label: const Text('Add Vehicle', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          AddEditVehicleSheet.show(
            context,
            defaultDistanceUnit: appState.defaultDistanceUnit,
            defaultVolumeUnit: appState.defaultVolumeUnit,
            defaultCurrency: appState.defaultCurrency,
            appState: appState,
            onSave: (newVehicle) => appState.addVehicle(newVehicle),
          );
        },
      ),
      body: vehicles.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car_outlined, size: 72, color: Colors.grey.shade400),
                  const SizedBox(height: 16),
                  Text(
                    'No vehicles in your garage',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  const Text('Tap "+ Add Vehicle" below to get started.'),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
              itemCount: vehicles.length,
              separatorBuilder: (context, index) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final vehicle = vehicles[index];
                final isActive = vehicle.id == activeId;
                final primaryColor = Color(vehicle.colorValue);

                // Count records for this vehicle
                final count = appState.allRecords.where((r) => r.vehicleId == vehicle.id).length;

                return AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: [
                        primaryColor.withValues(alpha: isActive ? 0.22 : 0.08),
                        isDark ? const Color(0xFF1E1E28) : Colors.white,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: isActive ? primaryColor : Colors.grey.withValues(alpha: 0.2),
                      width: isActive ? 2 : 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: isActive ? primaryColor.withValues(alpha: 0.18) : Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      appState.setActiveVehicle(vehicle.id);
                      Navigator.of(context).pop();
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Active Indicator / Select Button
                              if (isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check, size: 14, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        'ACTIVE',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                TextButton(
                                  style: TextButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    minimumSize: Size.zero,
                                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () {
                                    appState.setActiveVehicle(vehicle.id);
                                    Navigator.of(context).pop();
                                  },
                                  child: const Text('Select Car', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                ),

                              const Spacer(),

                              // Edit Vehicle
                              IconButton(
                                icon: const Icon(Icons.edit_outlined, size: 20),
                                tooltip: 'Edit Vehicle',
                                onPressed: () {
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
                              ),

                              // Delete Vehicle
                              IconButton(
                                icon: const Icon(Icons.delete_outline, size: 20, color: Colors.red),
                                tooltip: 'Delete Vehicle',
                                onPressed: () => _confirmDeleteVehicle(context, vehicle),
                              ),
                            ],
                          ),

                          const SizedBox(height: 10),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Vehicle Avatar (PFP or Artwork)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(14),
                                child: vehicle.profileImageUri != null && File(vehicle.profileImageUri!).existsSync()
                                    ? Image.file(
                                        File(vehicle.profileImageUri!),
                                        width: 80,
                                        height: 60,
                                        fit: BoxFit.cover,
                                      )
                                    : VehicleArtwork(
                                        type: vehicle.type,
                                        bodyColor: primaryColor,
                                        width: 80,
                                        height: 50,
                                        showBadge: false,
                                      ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      vehicle.name,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 17,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${vehicle.brand} - ${vehicle.type.displayName}${vehicle.owner.isNotEmpty ? ' - ${vehicle.owner}' : ''}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        if (vehicle.licensePlate != null && vehicle.licensePlate!.isNotEmpty) ...[
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(color: Colors.black, width: 2.0),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withValues(alpha: 0.15),
                                                  blurRadius: 2.5,
                                                  offset: const Offset(0, 1),
                                                ),
                                              ],
                                            ),
                                            child: Text(
                                              vehicle.licensePlate!.toUpperCase(),
                                              style: const TextStyle(
                                                fontFamily: 'monospace',
                                                color: Colors.black,
                                                fontWeight: FontWeight.w900,
                                                fontSize: 11,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                        ],
                                        Text(
                                          '$count records',
                                          style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.6)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Units footer
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.black26 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Units: ${vehicle.unitDistance} • ${vehicle.unitVolume} • ${vehicle.currency}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                if (vehicle.initialOdometer != null)
                                  Text(
                                    'Initial: ${vehicle.initialOdometer!.toStringAsFixed(0)} ${vehicle.unitDistance}',
                                    style: const TextStyle(fontSize: 11, color: Colors.grey),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
    );
  }

  void _confirmDeleteVehicle(BuildContext context, Vehicle vehicle) {
    final fuelCount = appState.allRecords.where((r) => r.vehicleId == vehicle.id).length;
    final serviceCount = appState.allServices.where((s) => s.vehicleId == vehicle.id).length;
    bool createBackup = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (dialogCtx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text('Delete "${vehicle.name}"?'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'This will permanently delete this vehicle and all $fuelCount associated fuel records${serviceCount > 0 ? ' (and $serviceCount service records).' : '.'} This action cannot be undone.',
                style: const TextStyle(fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('Create backup before deletion', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                value: createBackup,
                onChanged: (val) => setDialogState(() => createBackup = val ?? false),
              ),
            ],
          ),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFDC2626),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              icon: const Icon(Icons.delete_forever, size: 16),
              label: const Text('Delete'),
              onPressed: () async {
                Navigator.of(ctx).pop();
                if (createBackup) {
                  try {
                    final backupFile = await appState.saveBackupToFile();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Backup saved before deletion: ${backupFile.path.split(Platform.pathSeparator).last}')),
                      );
                    }
                  } catch (_) {}
                }
                await appState.deleteVehicle(vehicle.id);
              },
            ),
          ],
        ),
      ),
    );
  }
}
