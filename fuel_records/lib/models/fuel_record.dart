class FuelRecord {
  final String id;
  final String vehicleId;
  final DateTime dateTime;
  final double odometer; // Total kms / miles
  final double fuelAmount; // Volume filled in litres or gallons
  final double totalPrice; // Total price paid
  final bool isFullTank; // Whether tank was filled completely
  final String fuelType; // Regular, Premium, Diesel, etc.
  final String gasStation; // Shell, BP, Exxon, etc.
  final String notes;

  /// Private internal tamper-audit timestamps
  /// Not accessible, changeable, or viewable by the user in edit forms
  final DateTime createdTimestamp;
  final DateTime lastModifiedTimestamp;

  FuelRecord({
    required this.id,
    required this.vehicleId,
    required this.dateTime,
    required this.odometer,
    required this.fuelAmount,
    required this.totalPrice,
    this.isFullTank = true,
    this.fuelType = 'Regular',
    this.gasStation = '',
    this.notes = '',
    DateTime? createdTimestamp,
    DateTime? lastModifiedTimestamp,
  })  : createdTimestamp = createdTimestamp ?? DateTime.now(),
        lastModifiedTimestamp = lastModifiedTimestamp ?? DateTime.now();

  /// Price per unit (e.g., price per litre or price per gallon)
  double get pricePerUnit => fuelAmount > 0 ? totalPrice / fuelAmount : 0.0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicleId': vehicleId,
      'dateTime': dateTime.toIso8601String(),
      'odometer': odometer,
      'fuelAmount': fuelAmount,
      'totalPrice': totalPrice,
      'isFullTank': isFullTank,
      'fuelType': fuelType,
      'gasStation': gasStation,
      'notes': notes,
      'createdTimestamp': createdTimestamp.toIso8601String(),
      'lastModifiedTimestamp': lastModifiedTimestamp.toIso8601String(),
    };
  }

  factory FuelRecord.fromJson(Map<String, dynamic> json) {
    return FuelRecord(
      id: json['id'] as String,
      vehicleId: json['vehicleId'] as String,
      dateTime: DateTime.tryParse(json['dateTime'] as String? ?? '') ?? DateTime.now(),
      odometer: (json['odometer'] as num?)?.toDouble() ?? 0.0,
      fuelAmount: (json['fuelAmount'] as num?)?.toDouble() ?? 0.0,
      totalPrice: (json['totalPrice'] as num?)?.toDouble() ?? 0.0,
      isFullTank: json['isFullTank'] as bool? ?? true,
      fuelType: json['fuelType'] as String? ?? 'Regular',
      gasStation: json['gasStation'] as String? ?? '',
      notes: json['notes'] as String? ?? '',
      createdTimestamp: json['createdTimestamp'] != null
          ? DateTime.tryParse(json['createdTimestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
      lastModifiedTimestamp: json['lastModifiedTimestamp'] != null
          ? DateTime.tryParse(json['lastModifiedTimestamp'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  FuelRecord copyWith({
    String? vehicleId,
    DateTime? dateTime,
    double? odometer,
    double? fuelAmount,
    double? totalPrice,
    bool? isFullTank,
    String? fuelType,
    String? gasStation,
    String? notes,
    DateTime? lastModifiedTimestamp,
  }) {
    return FuelRecord(
      id: id,
      vehicleId: vehicleId ?? this.vehicleId,
      dateTime: dateTime ?? this.dateTime,
      odometer: odometer ?? this.odometer,
      fuelAmount: fuelAmount ?? this.fuelAmount,
      totalPrice: totalPrice ?? this.totalPrice,
      isFullTank: isFullTank ?? this.isFullTank,
      fuelType: fuelType ?? this.fuelType,
      gasStation: gasStation ?? this.gasStation,
      notes: notes ?? this.notes,
      createdTimestamp: createdTimestamp,
      lastModifiedTimestamp: lastModifiedTimestamp ?? DateTime.now(),
    );
  }
}
