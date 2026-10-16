class ServiceRecord {
  final String id;
  final String vehicleId;
  final DateTime serviceDate;
  final double odometer;
  final String serviceType;
  final double cost;
  final String serviceCenter;
  final String notes;
  final DateTime createdTimestamp;
  final DateTime lastModifiedTimestamp;

  ServiceRecord({
    required this.id,
    required this.vehicleId,
    required this.serviceDate,
    required this.odometer,
    this.serviceType = 'Periodic 6-Month Maintenance',
    this.cost = 0.0,
    this.serviceCenter = '',
    this.notes = '',
    DateTime? createdTimestamp,
    DateTime? lastModifiedTimestamp,
  })  : createdTimestamp = createdTimestamp ?? DateTime.now(),
        lastModifiedTimestamp = lastModifiedTimestamp ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicleId': vehicleId,
      'serviceDate': serviceDate.toIso8601String(),
      'odometer': odometer,
      'serviceType': serviceType,
      'cost': cost,
      'serviceCenter': serviceCenter,
      'notes': notes,
      'createdTimestamp': createdTimestamp.toIso8601String(),
      'lastModifiedTimestamp': lastModifiedTimestamp.toIso8601String(),
    };
  }

  factory ServiceRecord.fromJson(Map<String, dynamic> json) {
    return ServiceRecord(
      id: json['id'] as String,
      vehicleId: json['vehicleId'] as String,
      serviceDate: DateTime.tryParse(json['serviceDate'] as String? ?? '') ?? DateTime.now(),
      odometer: (json['odometer'] as num?)?.toDouble() ?? 0.0,
      serviceType: json['serviceType'] as String? ?? 'Periodic 6-Month Maintenance',
      cost: (json['cost'] as num?)?.toDouble() ?? 0.0,
      serviceCenter: json['serviceCenter'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      createdTimestamp: json['createdTimestamp'] != null
          ? DateTime.tryParse(json['createdTimestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      lastModifiedTimestamp: json['lastModifiedTimestamp'] != null
          ? DateTime.tryParse(json['lastModifiedTimestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  ServiceRecord copyWith({
    String? vehicleId,
    DateTime? serviceDate,
    double? odometer,
    String? serviceType,
    double? cost,
    String? serviceCenter,
    String? notes,
  }) {
    return ServiceRecord(
      id: id,
      vehicleId: vehicleId ?? this.vehicleId,
      serviceDate: serviceDate ?? this.serviceDate,
      odometer: odometer ?? this.odometer,
      serviceType: serviceType ?? this.serviceType,
      cost: cost ?? this.cost,
      serviceCenter: serviceCenter ?? this.serviceCenter,
      notes: notes ?? this.notes,
      createdTimestamp: createdTimestamp,
      lastModifiedTimestamp: DateTime.now(),
    );
  }
}

