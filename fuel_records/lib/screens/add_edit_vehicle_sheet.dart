import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/vehicle.dart';
import '../widgets/vehicle_artwork.dart';

class AddEditVehicleSheet extends StatefulWidget {
  final Vehicle? vehicleToEdit;
  final Function(Vehicle) onSave;

  final String defaultDistanceUnit;
  final String defaultVolumeUnit;
  final String defaultCurrency;

  const AddEditVehicleSheet({
    super.key,
    this.vehicleToEdit,
    required this.onSave,
    this.defaultDistanceUnit = 'km',
    this.defaultVolumeUnit = 'L',
    this.defaultCurrency = '\$',
  });

  static Future<void> show(
    BuildContext context, {
    Vehicle? vehicle,
    required Function(Vehicle) onSave,
    String defaultDistanceUnit = 'km',
    String defaultVolumeUnit = 'L',
    String defaultCurrency = '\$',
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

  late VehicleType _selectedType;
  late Color _selectedColor;
  late String _unitDistance;
  late String _unitVolume;
  late String _currency;
  DateTime? _dateBought;

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

    _selectedType = v?.type ?? VehicleType.suv;
    _selectedColor = v != null ? Color(v.colorValue) : _availableColors.first;
    _unitDistance = v?.unitDistance ?? widget.defaultDistanceUnit;
    _unitVolume = v?.unitVolume ?? widget.defaultVolumeUnit;
    _currency = widget.defaultCurrency;
    _dateBought = v?.dateBought;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _ownerController.dispose();
    _initialOdoController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final id = widget.vehicleToEdit?.id ?? 'veh_${DateTime.now().millisecondsSinceEpoch}';
    final initialOdo = double.tryParse(_initialOdoController.text.trim());

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
      initialOdometer: initialOdo,
      dateBought: _dateBought,
      createdAt: widget.vehicleToEdit?.createdAt,
    );

    widget.onSave(vehicle);
    Navigator.of(context).pop();
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
      padding: EdgeInsets.only(
        top: 12,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Title Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _selectedColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.directions_car, color: _selectedColor),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEditing ? 'Edit Vehicle' : 'Add New Vehicle',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Configure car details and vehicle type image',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // Live Vehicle Graphic Preview Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _selectedColor.withValues(alpha: 0.18),
                      isDark ? const Color(0xFF1E1E28) : Colors.grey.shade100,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: _selectedColor.withValues(alpha: 0.35),
                    width: 1.5,
                  ),
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
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _selectedType.displayName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          _brandController.text.isEmpty ? 'Brand Preview' : _brandController.text,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: VehicleArtwork(
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

              const SizedBox(height: 20),

              // Vehicle Type Selector (SUV, Sedan, Compact, Truck, etc.)
              Text(
                'Select Vehicle Type (Image / Category)',
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
                      onTap: () {
                        setState(() {
                          _selectedType = type;
                        });
                      },
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

              const SizedBox(height: 20),

              // Color Swatches
              Text(
                'Vehicle Color Theme',
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

              const SizedBox(height: 20),

              // Car Name Input
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Car Name / Nickname *',
                  hintText: 'e.g. Daily Commuter, Silver Bullet',
                  prefixIcon: const Icon(Icons.drive_file_rename_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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

              // Brand Input with suggestions
              TextFormField(
                controller: _brandController,
                decoration: InputDecoration(
                  labelText: 'Brand / Make *',
                  hintText: 'e.g. Toyota, Honda, Ford',
                  prefixIcon: const Icon(Icons.apartment),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
                  hintText: 'e.g. John Doe, Family',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
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
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                ),
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
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.shopping_bag_outlined, color: Colors.blueAccent),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Date Bought / Purchased (Optional)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(
                            _dateBought != null ? DateFormat('yyyy-MM-dd (MMM d, yyyy)').format(_dateBought!) : 'Not specified',
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

              const SizedBox(height: 26),

              // Save Button
              ElevatedButton.icon(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 2,
                ),
                icon: Icon(isEditing ? Icons.check_circle : Icons.add_circle),
                label: Text(
                  isEditing ? 'Save Changes' : 'Create Vehicle & Start Logging',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
