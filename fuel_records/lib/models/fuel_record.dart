enum IngressSource {
  manual(0),
  nativeHeadUnit(1),
  obd2Ble(2);

  final int value;
  const IngressSource(this.value);

  static IngressSource fromInt(int val) {
    switch (val) {
      case 1:
        return IngressSource.nativeHeadUnit;
      case 2:
        return IngressSource.obd2Ble;
      default:
        return IngressSource.manual;
    }
  }
}

class FuelRecord {
  final String id;
  final String vehicleId;
  final int timestampEpochSec; // Exact 64-bit Unix Epoch Seconds
  final int odometerMeters; // Exact integer meters (e.g. 25000.5 km -> 25000500 m)
  final int volumeMilliliters; // Exact integer fuel volume in milliliters (e.g. 42.50 L -> 42500 mL)
  final int totalCostCents; // Exact minor currency units / cents (e.g. $63.75 -> 6375 cents)
  final int ingressSource; // Provenance audit: 0 = MANUAL, 1 = NATIVE_HEAD_UNIT, 2 = OBD2_BLE
  final bool? isFullTank; // Whether tank was filled completely
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
    DateTime? dateTime,
    int? timestampEpochSec,
    double? odometer,
    int? odometerMeters,
    double? fuelAmount,
    int? volumeMilliliters,
    double? totalPrice,
    int? totalCostCents,
    this.isFullTank,
    this.fuelType = 'Regular',
    this.gasStation = '',
    this.notes = '',
    int? ingressSource,
    DateTime? createdTimestamp,
    DateTime? lastModifiedTimestamp,
  })  : timestampEpochSec = timestampEpochSec ??
            ((dateTime ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000),
        odometerMeters = odometerMeters ?? ((odometer ?? 0.0) * 1000).round(),
        volumeMilliliters = volumeMilliliters ?? ((fuelAmount ?? 0.0) * 1000).round(),
        totalCostCents = totalCostCents ?? ((totalPrice ?? 0.0) * 100).round(),
        ingressSource = ingressSource ?? 0,
        createdTimestamp = createdTimestamp ?? DateTime.now(),
        lastModifiedTimestamp = lastModifiedTimestamp ?? DateTime.now();

  /// Backwards-compatible getters (eliminated floating-point drift in storage)
  DateTime get dateTime => DateTime.fromMillisecondsSinceEpoch(timestampEpochSec * 1000);
  double get odometer => odometerMeters / 1000.0;
  double get fuelAmount => volumeMilliliters / 1000.0;
  double get totalPrice => totalCostCents / 100.0;

  /// Price per unit (e.g., price per litre or price per gallon)
  double get pricePerUnit => volumeMilliliters > 0 ? (totalCostCents / 100.0) / (volumeMilliliters / 1000.0) : 0.0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicleId': vehicleId,
      'timestampEpochSec': timestampEpochSec,
      'odometerMeters': odometerMeters,
      'volumeMilliliters': volumeMilliliters,
      'totalCostCents': totalCostCents,
      'ingressSource': ingressSource,
      // Legacy mirrors for existing JSON readers and backwards compatibility
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
    final epochSec = json['timestampEpochSec'] as int? ??
        (DateTime.tryParse(json['dateTime'] as String? ?? '')?.millisecondsSinceEpoch ??
                DateTime.now().millisecondsSinceEpoch) ~/
            1000;
    final odoMeters = json['odometerMeters'] as int? ??
        (((json['odometer'] as num?)?.toDouble() ?? 0.0) * 1000).round();
    final volMl = json['volumeMilliliters'] as int? ??
        (((json['fuelAmount'] as num?)?.toDouble() ?? 0.0) * 1000).round();
    final costCents = json['totalCostCents'] as int? ??
        (((json['totalPrice'] as num?)?.toDouble() ?? 0.0) * 100).round();
    final source = json['ingressSource'] as int? ?? 0;

    return FuelRecord(
      id: json['id'] as String,
      vehicleId: json['vehicleId'] as String,
      timestampEpochSec: epochSec,
      odometerMeters: odoMeters,
      volumeMilliliters: volMl,
      totalCostCents: costCents,
      ingressSource: source,
      isFullTank: json['isFullTank'] as bool?,
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
    int? timestampEpochSec,
    double? odometer,
    int? odometerMeters,
    double? fuelAmount,
    int? volumeMilliliters,
    double? totalPrice,
    int? totalCostCents,
    int? ingressSource,
    bool? isFullTank,
    String? fuelType,
    String? gasStation,
    String? notes,
    DateTime? lastModifiedTimestamp,
  }) {
    return FuelRecord(
      id: id,
      vehicleId: vehicleId ?? this.vehicleId,
      timestampEpochSec: timestampEpochSec ??
          (dateTime != null ? dateTime.millisecondsSinceEpoch ~/ 1000 : this.timestampEpochSec),
      odometerMeters: odometerMeters ??
          (odometer != null ? (odometer * 1000).round() : this.odometerMeters),
      volumeMilliliters: volumeMilliliters ??
          (fuelAmount != null ? (fuelAmount * 1000).round() : this.volumeMilliliters),
      totalCostCents: totalCostCents ??
          (totalPrice != null ? (totalPrice * 100).round() : this.totalCostCents),
      ingressSource: ingressSource ?? this.ingressSource,
      isFullTank: isFullTank ?? this.isFullTank,
      fuelType: fuelType ?? this.fuelType,
      gasStation: gasStation ?? this.gasStation,
      notes: notes ?? this.notes,
      createdTimestamp: createdTimestamp,
      lastModifiedTimestamp: lastModifiedTimestamp ?? DateTime.now(),
    );
  }
}
