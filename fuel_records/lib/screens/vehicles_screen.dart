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
        title: const Text('My Garage & Vehicles', style: TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add Vehicle', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          AddEditVehicleSheet.show(
            context,
            defaultDistanceUnit: appState.defaultDistanceUnit,
            defaultVolumeUnit: appState.defaultVolumeUnit,
            defaultCurrency: appState.defaultCurrency,
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
                    borderRadius: BorderRadius.circular(22),
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
                    borderRadius: BorderRadius.circular(22),
                    onTap: () {
                      appState.setActiveVehicle(vehicle.id);
                      Navigator.of(context).pop(); // Single tap takes you directly to car's info
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              // Active Indicator / Switch Badge
                              if (isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: primaryColor,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.check, size: 14, color: Colors.white),
                                      SizedBox(width: 4),
                                      Text(
                                        'ACTIVE VEHICLE',
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

                          const SizedBox(height: 8),

                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Large Vehicle Artwork
                              VehicleArtwork(
                                type: vehicle.type,
                                bodyColor: primaryColor,
                                width: 110,
                                height: 60,
                                showBadge: false,
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      vehicle.name,
                                      style: theme.textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${vehicle.brand} • ${vehicle.type.displayName}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Icon(Icons.person_outline, size: 14, color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Text(
                                          vehicle.owner,
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(Icons.receipt_outlined, size: 14, color: Colors.grey.shade600),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$count records',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${vehicle.name}"?'),
        content: const Text(
          'Deleting this vehicle will also remove all associated fuel records. Are you sure you wish to proceed?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              Navigator.of(ctx).pop();
              appState.deleteVehicle(vehicle.id);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
