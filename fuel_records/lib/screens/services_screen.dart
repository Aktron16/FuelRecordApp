import 'package:flutter/material.dart';
import '../models/vehicle.dart';
import '../models/service_record.dart';
import '../services/fuel_app_state.dart';
import '../theme/app_theme.dart';
import '../utils/app_date_format.dart';

class ServicesScreen extends StatefulWidget {
  final FuelAppState appState;

  const ServicesScreen({super.key, required this.appState});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  @override
  Widget build(BuildContext context) {
    final vehicle = widget.appState.activeVehicle;
    final theme = Theme.of(context);

    if (vehicle == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Maintenance & Servicing')),
        body: const Center(child: Text('No active vehicle')),
      );
    }

    final services = widget.appState.activeVehicleServicesDescending;
    final serviceStatus = widget.appState.activeVehicleServiceStatus;
    final primaryColor = Color(vehicle.colorValue);

    final status = serviceStatus?['status'] as String? ?? 'ok';
    final message = serviceStatus?['message'] as String? ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Vehicle Servicing Logs', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text('${vehicle.name} • 6-Month Schedule', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.build),
        label: const Text('Log Service', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () => _openAddEditServiceDialog(context, vehicle),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        children: [
          // 6-Month Status Banner
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: status == 'overdue'
                    ? [Colors.red.shade900.withValues(alpha: 0.8), Colors.red.shade700]
                    : (status == 'due_soon'
                        ? [Colors.amber.shade900.withValues(alpha: 0.8), Colors.amber.shade700]
                        : [primaryColor.withValues(alpha: 0.85), primaryColor]),
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: (status == 'overdue' ? Colors.red : primaryColor).withValues(alpha: 0.3),
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
                    Row(
                      children: [
                        Icon(
                          status == 'overdue'
                              ? Icons.warning_amber_rounded
                              : (status == 'due_soon' ? Icons.access_time_rounded : Icons.verified),
                          color: Colors.white,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          status == 'overdue'
                              ? 'SERVICE OVERDUE'
                              : (status == 'due_soon' ? 'SERVICE DUE SOON' : 'SERVICING UP TO DATE'),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Every 6 Months',
                        style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                Text(
                  'Regular servicing every 6 months preserves engine efficiency, warranty compliance, and road safety.',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 11),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          Text('Service & Maintenance History', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),

          if (services.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.elevatedSurfaceColor(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppTheme.borderColor(context)),
              ),
              child: Column(
                children: [
                  Icon(Icons.car_repair_outlined, size: 48, color: Colors.grey.shade400),
                  const SizedBox(height: 12),
                  const Text('No servicing logs recorded yet', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text(
                    'Log your periodic 6-month maintenance, oil changes, or repairs using the button below.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: services.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final srv = services[index];
                final dateStr = AppDateUtils.format(srv.serviceDate);

                return Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            Row(
                              children: [
                                if (srv.cost > 0)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(alpha: 0.12),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${vehicle.currency}${srv.cost.toStringAsFixed(2)}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green),
                                    ),
                                  ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(Icons.edit_outlined, size: 18),
                                  onPressed: () => _openAddEditServiceDialog(context, vehicle, serviceToEdit: srv),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const Divider(height: 12),
                        Text(
                          srv.serviceType,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.speed, size: 14, color: Colors.grey.shade600),
                            const SizedBox(width: 4),
                            Text('${srv.odometer.toStringAsFixed(0)} ${vehicle.unitDistance}', style: const TextStyle(fontSize: 12)),
                            if (srv.serviceCenter.isNotEmpty) ...[
                              const SizedBox(width: 12),
                              Icon(Icons.storefront, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(srv.serviceCenter, style: const TextStyle(fontSize: 12)),
                            ],
                          ],
                        ),
                        if (srv.notes.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(srv.notes, style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurface.withValues(alpha: 0.7))),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  void _openAddEditServiceDialog(BuildContext context, Vehicle vehicle, {ServiceRecord? serviceToEdit}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _AddEditServiceModal(
        vehicle: vehicle,
        serviceToEdit: serviceToEdit,
        onSave: (record) {
          if (serviceToEdit != null) {
            widget.appState.updateServiceRecord(record);
          } else {
            widget.appState.addServiceRecord(record);
          }
        },
        onDelete: serviceToEdit != null
            ? () => widget.appState.deleteServiceRecord(serviceToEdit.id)
            : null,
      ),
    );
  }
}

class _AddEditServiceModal extends StatefulWidget {
  final Vehicle vehicle;
  final ServiceRecord? serviceToEdit;
  final Function(ServiceRecord) onSave;
  final VoidCallback? onDelete;

  const _AddEditServiceModal({
    required this.vehicle,
    this.serviceToEdit,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<_AddEditServiceModal> createState() => _AddEditServiceModalState();
}

class _AddEditServiceModalState extends State<_AddEditServiceModal> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _selectedDate;
  late TextEditingController _odometerController;
  late TextEditingController _costController;
  late TextEditingController _serviceCenterController;
  late TextEditingController _notesController;
  late String _serviceType;

  final List<String> _servicePresets = const [
    'Periodic 6-Month Maintenance',
    'Oil & Filter Change',
    'Brake Pad & Fluid Service',
    'Tire Rotation & Wheel Alignment',
    'Major Inspection & Spark Plugs',
    'Battery & Electrical Check',
    'Air Conditioning Service',
    'General Repair',
  ];

  @override
  void initState() {
    super.initState();
    final s = widget.serviceToEdit;
    _selectedDate = s?.serviceDate ?? DateTime.now();
    _odometerController = TextEditingController(
      text: s != null ? s.odometer.toStringAsFixed(0) : '',
    );
    _costController = TextEditingController(
      text: s != null && s.cost > 0 ? s.cost.toStringAsFixed(2) : '',
    );
    _serviceCenterController = TextEditingController(text: s?.serviceCenter ?? '');
    _notesController = TextEditingController(text: s?.notes ?? '');
    _serviceType = s?.serviceType ?? 'Periodic 6-Month Maintenance';
  }

  @override
  void dispose() {
    _odometerController.dispose();
    _costController.dispose();
    _serviceCenterController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final id = widget.serviceToEdit?.id ?? 'srv_${DateTime.now().millisecondsSinceEpoch}';
    final odo = double.parse(_odometerController.text.trim());
    final cost = double.tryParse(_costController.text.trim()) ?? 0.0;

    final srv = ServiceRecord(
      id: id,
      vehicleId: widget.vehicle.id,
      serviceDate: _selectedDate,
      odometer: odo,
      serviceType: _serviceType,
      cost: cost,
      serviceCenter: _serviceCenterController.text.trim(),
      notes: _notesController.text.trim(),
    );

    Navigator.of(context).pop();
    widget.onSave(srv);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isEditing = widget.serviceToEdit != null;

    return Container(
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        top: 14,
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

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEditing ? 'Edit Service Record' : 'Log Vehicle Service',
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  if (isEditing && widget.onDelete != null)
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      onPressed: () {
                        widget.onDelete!();
                        Navigator.of(context).pop();
                      },
                    ),
                ],
              ),

              const SizedBox(height: 16),

              // Date Picker (Date Only)
              InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade400),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, color: Colors.blueAccent),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Service Date (Date Only)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                          Text(AppDateUtils.format(_selectedDate),
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                      const Spacer(),
                      const Text('Change', style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 14),

              // Service Type Dropdown
              DropdownButtonFormField<String>(
                value: _serviceType,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: 'Service Type / Category',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                ),
                items: _servicePresets.map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis))).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _serviceType = val);
                },
              ),

              const SizedBox(height: 14),

              // Odometer Reading
              TextFormField(
                controller: _odometerController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Odometer at Service (${widget.vehicle.unitDistance}) *',
                  suffixText: widget.vehicle.unitDistance,
                  prefixIcon: const Icon(Icons.speed),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Enter odometer';
                  if (double.tryParse(val.trim()) == null) return 'Valid number required';
                  return null;
                },
              ),

              const SizedBox(height: 14),

              // Service Cost & Center
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _costController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Cost (${widget.vehicle.currency})',
                        prefixIcon: const Icon(Icons.receipt_outlined),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        filled: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _serviceCenterController,
                      decoration: InputDecoration(
                        labelText: 'Service Center',
                        hintText: 'e.g. Dealer, Jiffy',
                        prefixIcon: const Icon(Icons.store),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                        filled: true,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 14),

              // Notes
              TextFormField(
                controller: _notesController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Service Notes & Parts Replaced',
                  hintText: 'e.g. Synthetic 0W-20 oil, brake inspection, fluid top-up',
                  prefixIcon: const Icon(Icons.notes),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
                  filled: true,
                ),
              ),

              const SizedBox(height: 22),

              ElevatedButton.icon(
                onPressed: _submit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(widget.vehicle.colorValue),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.check_circle_outline),
                label: Text(
                  isEditing ? 'Save Changes' : 'Log 6-Month Maintenance',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
