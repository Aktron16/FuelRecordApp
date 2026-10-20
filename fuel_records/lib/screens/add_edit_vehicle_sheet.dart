import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import '../models/vehicle.dart';
import '../widgets/vehicle_artwork.dart';
import '../utils/app_date_format.dart';
import '../services/fuel_app_state.dart';

class AddEditVehicleSheet extends StatefulWidget {
  final Vehicle? vehicleToEdit;
  final Function(Vehicle) onSave;

  final String defaultDistanceUnit;
  final String defaultVolumeUnit;
  final String defaultCurrency;
  final List<String>? availableFuelGrades;
  final FuelAppState? appState;

  const AddEditVehicleSheet({
    super.key,
    this.vehicleToEdit,
    required this.onSave,
    this.defaultDistanceUnit = 'km',
    this.defaultVolumeUnit = 'L',
    this.defaultCurrency = '\$',
    this.availableFuelGrades,
    this.appState,
  });

  static Future<void> show(
    BuildContext context, {
    Vehicle? vehicle,
    required Function(Vehicle) onSave,
    String defaultDistanceUnit = 'km',
    String defaultVolumeUnit = 'L',
    String defaultCurrency = '\$',
    List<String>? availableFuelGrades,
    FuelAppState? appState,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddEditVehicleSheet(
        vehicleToEdit: vehicle,
        onSave: onSave,
        defaultDistanceUnit: defaultDistanceUnit,
        defaultVolumeUnit: defaultVolumeUnit,
        defaultCurrency: defaultCurrency,
        availableFuelGrades: availableFuelGrades,
        appState: appState,
      ),
    );
  }

  @override
  State<AddEditVehicleSheet> createState() => _AddEditVehicleSheetState();
}

class _AddEditVehicleSheetState extends State<AddEditVehicleSheet> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _brandController;
  late TextEditingController _ownerController;
  late TextEditingController _initialOdoController;
  late TextEditingController _licensePlateController;
  late TextEditingController _tankCapacityController;

  late VehicleType _selectedType;
  late Color _selectedColor;
  late String _unitDistance;
  late String _unitVolume;
  late String _currency;
  late String _selectedFuelType;
  DateTime? _dateBought;
  String? _profileImageUri;
  String? _bannerImageUri;

  late List<String> _fuelTypes;

  final List<Color> _availableColors = const [
    Color(0xFF1E88E5), // Blue
    Color(0xFF2E7D32), // Emerald Green
    Color(0xFFC62828), // Deep Red
    Color(0xFFEF6C00), // Amber Orange
    Color(0xFF6A1B9A), // Purple
    Color(0xFF37474F), // Charcoal Slate
    Color(0xFF00838F), // Cyan Teal
    Color(0xFF4E342E), // Brown
  ];

  final List<String> _popularBrands = const [
    'Toyota', 'Honda', 'Ford', 'BMW', 'Hyundai',
    'Tesla', 'Mercedes', 'Audi', 'Volkswagen', 'Chevrolet', 'Kia'
  ];

  @override
  void initState() {
    super.initState();
    final v = widget.vehicleToEdit;
    _nameController = TextEditingController(text: v?.name ?? '');
    _brandController = TextEditingController(text: v?.brand ?? '');
    _ownerController = TextEditingController(text: v?.owner ?? '');
    _initialOdoController = TextEditingController(
      text: v?.initialOdometer != null ? v!.initialOdometer!.toStringAsFixed(0) : '',
    );
    _licensePlateController = TextEditingController(text: v?.licensePlate ?? '');
    _tankCapacityController = TextEditingController(
      text: v != null ? v.tankCapacityLiters.toStringAsFixed(1) : '55.0',
    );

    _selectedType = v?.type ?? VehicleType.suv;
    _selectedColor = v != null ? Color(v.colorValue) : _availableColors.first;
    _unitDistance = v?.unitDistance ?? widget.defaultDistanceUnit;
    _unitVolume = v?.unitVolume ?? widget.defaultVolumeUnit;
    _currency = widget.defaultCurrency;
    _profileImageUri = v?.profileImageUri;
    _bannerImageUri = v?.bannerImageUri;
    _dateBought = v?.dateBought;

    final countryGrades = widget.availableFuelGrades ?? widget.appState?.currentCountryInfo.fuelGrades;
    _fuelTypes = countryGrades != null && countryGrades.isNotEmpty
        ? countryGrades
        : const [
            'Regular (87)',
            'Midgrade (89)',
            'Premium (93)',
            'Diesel',
            'E85 / Flex Fuel',
            'Electric / Other',
          ];

    _selectedFuelType = v?.fuelType ?? _fuelTypes.first;
    if (!_fuelTypes.contains(_selectedFuelType)) {
      _fuelTypes = [_selectedFuelType, ..._fuelTypes];
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _ownerController.dispose();
    _initialOdoController.dispose();
    _licensePlateController.dispose();
    _tankCapacityController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required bool isBanner}) async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isBanner ? 'Select Banner Image' : 'Select Car Profile Picture',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 12),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Take Photo with Camera'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Choose from Gallery'),
                onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
              ),
            ],
          ),
        ),
      ),
    );

    if (source == null) return;

    try {
      final picked = await picker.pickImage(
        source: source,
        maxWidth: isBanner ? 1280 : 512,
        maxHeight: isBanner ? 720 : 512,
        imageQuality: isBanner ? 80 : 85,
      );

      if (picked != null) {
        Directory imagesDir;
        if (widget.appState != null) {
          imagesDir = await widget.appState!.getVehicleImagesDirectory();
        } else {
          final docs = await getApplicationDocumentsDirectory();
          imagesDir = Directory('${docs.path}/FuelMetricsData/vehicle_images');
          if (!imagesDir.existsSync()) imagesDir.createSync(recursive: true);
        }

        final ext = picked.name.split('.').last;
        final targetPath = '${imagesDir.path}/${isBanner ? 'banner' : 'pfp'}_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await File(picked.path).copy(targetPath);

        setState(() {
          if (isBanner) {
            _bannerImageUri = targetPath;
          } else {
            _profileImageUri = targetPath;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final id = widget.vehicleToEdit?.id ?? 'veh_${DateTime.now().millisecondsSinceEpoch}';
    final initialOdo = double.tryParse(_initialOdoController.text.trim());
    final plate = _licensePlateController.text.trim();

    final vehicle = Vehicle(
      id: id,
      name: _nameController.text.trim(),
      type: _selectedType,
      brand: _brandController.text.trim().isEmpty ? 'General' : _brandController.text.trim(),
      owner: _ownerController.text.trim().isEmpty ? 'Owner' : _ownerController.text.trim(),
      colorValue: _selectedColor.value,
      unitDistance: _unitDistance,
      unitVolume: _unitVolume,
      currency: _currency,
      fuelType: _selectedFuelType,
      licensePlate: plate.isNotEmpty ? plate : null,
      profileImageUri: _profileImageUri,
      bannerImageUri: _bannerImageUri,
      initialOdometer: initialOdo,
      dateBought: _dateBought,
      tankCapacityLiters: double.tryParse(_tankCapacityController.text.trim()) ??
          (widget.vehicleToEdit?.tankCapacityLiters ?? 55.0),
      obdDeviceId: widget.vehicleToEdit?.obdDeviceId,
      lastKnownOdometer: widget.vehicleToEdit?.lastKnownOdometer ?? initialOdo,
      lastKnownFuelPercent: widget.vehicleToEdit?.lastKnownFuelPercent,
      lastObdSyncTime: widget.vehicleToEdit?.lastObdSyncTime,
      calibrationFactor: widget.vehicleToEdit?.calibrationFactor ?? 1.0,
      createdAt: widget.vehicleToEdit?.createdAt,
    );

    Navigator.of(context).pop();
    widget.onSave(vehicle);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isEditing = widget.vehicleToEdit != null;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),

                // Sheet Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isEditing ? 'Edit Vehicle' : 'Add Vehicle',
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // Vehicle Live Preview Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: _selectedColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _selectedColor.withValues(alpha: 0.3), width: 1.5),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _selectedColor,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              _selectedType.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (_licensePlateController.text.trim().isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
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
                                _licensePlateController.text.trim().toUpperCase(),
                                style: const TextStyle(
                                  fontFamily: 'monospace',
                                  color: Colors.black,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                  letterSpacing: 1.2,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Center(
                        child: _profileImageUri != null && File(_profileImageUri!).existsSync()
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Image.file(
                                  File(_profileImageUri!),
                                  width: 130,
                                  height: 85,
                                  fit: BoxFit.cover,
                                ),
                              )
                            : VehicleArtwork(
                                type: _selectedType,
                                bodyColor: _selectedColor,
                                width: 190,
                                height: 95,
                                showBadge: false,
                              ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _nameController.text.isEmpty ? 'Vehicle Name' : _nameController.text,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // Photo Selection Section (PFP & Banner)
                Text(
                  'Photos & Artwork',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Profile Photo
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF232533) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Profile Photo',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                            ),
                            const SizedBox(height: 8),
                            if (_profileImageUri != null && File(_profileImageUri!).existsSync()) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(12),
                                child: Image.file(
                                  File(_profileImageUri!),
                                  width: 64,
                                  height: 64,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  InkWell(
                                    onTap: () => _pickImage(isBanner: false),
                                    child: const Text('Change', style: TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => setState(() => _profileImageUri = null),
                                    child: const Text('Remove', style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ] else ...[
                              IconButton.outlined(
                                icon: const Icon(Icons.add_a_photo_outlined),
                                onPressed: () => _pickImage(isBanner: false),
                              ),
                              const SizedBox(height: 4),
                              const Text('Add Avatar', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Banner Photo
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF232533) : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Banner Image',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.colorScheme.onSurface),
                            ),
                            const SizedBox(height: 8),
                            if (_bannerImageUri != null && File(_bannerImageUri!).existsSync()) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.file(
                                  File(_bannerImageUri!),
                                  width: 90,
                                  height: 48,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  InkWell(
                                    onTap: () => _pickImage(isBanner: true),
                                    child: const Text('Change', style: TextStyle(fontSize: 11, color: Colors.blueAccent, fontWeight: FontWeight.bold)),
                                  ),
                                  const SizedBox(width: 8),
                                  InkWell(
                                    onTap: () => setState(() => _bannerImageUri = null),
                                    child: const Text('Remove', style: TextStyle(fontSize: 11, color: Colors.redAccent, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ] else ...[
                              IconButton.outlined(
                                icon: const Icon(Icons.add_photo_alternate_outlined),
                                onPressed: () => _pickImage(isBanner: true),
                              ),
                              const SizedBox(height: 4),
                              const Text('Add Banner', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Vehicle Type Selector
                Text(
                  'Vehicle Type',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 102,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: VehicleType.values.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 10),
                    itemBuilder: (context, index) {
                      final type = VehicleType.values[index];
                      final isSelected = type == _selectedType;

                      return InkWell(
                        onTap: () => setState(() => _selectedType = type),
                        borderRadius: BorderRadius.circular(16),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 110,
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? _selectedColor.withValues(alpha: 0.14)
                                : (isDark ? Colors.grey.shade900 : Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? _selectedColor : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 65,
                                height: 38,
                                child: VehicleArtwork(
                                  type: type,
                                  bodyColor: isSelected ? _selectedColor : Colors.grey.shade600,
                                  width: 65,
                                  height: 38,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                type.shortName,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  color: isSelected ? _selectedColor : null,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),

                const SizedBox(height: 18),

                // Color Swatches
                Text(
                  'Color Theme',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _availableColors.map((color) {
                    final isSelected = color.value == _selectedColor.value;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedColor = color),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? Colors.white : Colors.transparent,
                            width: 3,
                          ),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: color.withValues(alpha: 0.6),
                                blurRadius: 8,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 18),

                // Car Name Input
                TextFormField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Car Name / Nickname *',
                    hintText: 'e.g. Daily Commuter, Silver Bullet',
                    prefixIcon: const Icon(Icons.drive_file_rename_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter a name for your car';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 14),

                // License Plate Input
                TextFormField(
                  controller: _licensePlateController,
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'License Plate (Optional)',
                    hintText: 'e.g. ABC-1234',
                    prefixIcon: const Icon(Icons.pin_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 14),

                // Brand Input with suggestions
                TextFormField(
                  controller: _brandController,
                  decoration: InputDecoration(
                    labelText: 'Brand / Make *',
                    hintText: 'e.g. Toyota, Honda, Ford',
                    prefixIcon: const Icon(Icons.apartment),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please enter the vehicle brand';
                    }
                    return null;
                  },
                  onChanged: (_) => setState(() {}),
                ),

                const SizedBox(height: 8),

                // Brand Suggestion Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _popularBrands.map((b) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ActionChip(
                          label: Text(b, style: const TextStyle(fontSize: 11)),
                          onPressed: () {
                            setState(() {
                              _brandController.text = b;
                            });
                          },
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 14),

                // Owner Input
                TextFormField(
                  controller: _ownerController,
                  decoration: InputDecoration(
                    labelText: 'Owner Name *',
                    hintText: 'e.g. Alex Morgan, Family',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Please specify the vehicle owner';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 14),

                // Initial Odometer
                TextFormField(
                  controller: _initialOdoController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Initial Odometer (Optional)',
                    hintText: 'e.g. 25000',
                    suffixText: _unitDistance,
                    prefixIcon: const Icon(Icons.speed),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                ),

                const SizedBox(height: 14),

                // Fuel Tank Capacity
                TextFormField(
                  controller: _tankCapacityController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: 'Fuel Tank Capacity (Liters)',
                    hintText: 'e.g. 55.0',
                    suffixText: 'L',
                    prefixIcon: const Icon(Icons.local_gas_station_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                ),

                const SizedBox(height: 14),

                // Fuel Grade / Type Selector
                DropdownButtonFormField<String>(
                  value: _fuelTypes.contains(_selectedFuelType) ? _selectedFuelType : _fuelTypes.first,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Default Fuel Grade',
                    prefixIcon: const Icon(Icons.local_gas_station),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                  ),
                  items: _fuelTypes.map((t) => DropdownMenuItem(value: t, child: Text(t, overflow: TextOverflow.ellipsis))).toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _selectedFuelType = val);
                  },
                ),

                const SizedBox(height: 14),

                // Date Bought (Purchase Date)
                InkWell(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _dateBought ?? DateTime.now(),
                      firstDate: DateTime(1980),
                      lastDate: DateTime.now().add(const Duration(days: 30)),
                    );
                    if (picked != null) {
                      setState(() => _dateBought = picked);
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_bag_outlined, color: Colors.blueAccent),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Date Purchased (Optional)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                            Text(
                              _dateBought != null ? AppDateUtils.format(_dateBought!) : 'Not specified',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: _dateBought != null ? null : Colors.grey),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          _dateBought != null ? 'Change' : 'Set Date',
                          style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Save Button (Elevated 12px)
                ElevatedButton.icon(
                  onPressed: _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _selectedColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 3,
                    shadowColor: _selectedColor.withValues(alpha: 0.4),
                  ),
                  icon: Icon(isEditing ? Icons.check_circle : Icons.add_circle),
                  label: Text(
                    isEditing ? 'Save Changes' : 'Create Vehicle & Start Logging',
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
