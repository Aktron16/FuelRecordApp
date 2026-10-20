enum VehicleType {
  sedan,
  suv,
  compact,
  truck,
  coupe,
  van,
  motorcycle,
  ev,
}

extension VehicleTypeExtension on VehicleType {
  String get displayName {
    switch (this) {
      case VehicleType.sedan:
        return 'Sedan';
      case VehicleType.suv:
        return 'SUV';
      case VehicleType.compact:
        return 'Compact / Hatchback';
      case VehicleType.truck:
        return 'Pickup Truck';
      case VehicleType.coupe:
        return 'Coupe / Sports';
      case VehicleType.van:
        return 'Van / Minivan';
      case VehicleType.motorcycle:
        return 'Motorcycle';
      case VehicleType.ev:
        return 'Electric / Hybrid';
    }
  }

  String get shortName {
    switch (this) {
      case VehicleType.sedan:
        return 'Sedan';
      case VehicleType.suv:
        return 'SUV';
      case VehicleType.compact:
        return 'Compact';
      case VehicleType.truck:
        return 'Truck';
      case VehicleType.coupe:
        return 'Coupe';
      case VehicleType.van:
        return 'Van';
      case VehicleType.motorcycle:
        return 'Moto';
      case VehicleType.ev:
        return 'EV / Hybrid';
    }
  }
}

class TelemetryCapabilityMask {
  static const int unknown = 0x00;
  static const int headUnitNativeFuel = 0x01;
  static const int headUnitNativeOdometer = 0x02;
  static const int headUnitRestrictedLegacy = 0x04;
  static const int obd2BleBound = 0x08;

  static bool isNativeSupported(int mask) =>
      (mask & headUnitNativeFuel != 0) && (mask & headUnitNativeOdometer != 0);

  static bool isLegacyRestricted(int mask) =>
      (mask & headUnitRestrictedLegacy != 0);

  static bool isObdBound(int mask) =>
      (mask & obd2BleBound != 0);
}

class Vehicle {
  final String id;
  final String name;
  final VehicleType type;
  final String brand;
  final String owner;
  final int colorValue; // ARGB int
  final String unitDistance; // 'km' or 'mi'
  final String unitVolume; // 'L' or 'gal'
  final String currency; // '$', '€', '₹', '£', etc.
  final String fuelType; // Default fuel grade/type for this vehicle
  final String? licensePlate;
  final String? profileImageUri;
  final String? bannerImageUri;
  final double? initialOdometer;
  final DateTime? dateBought; // Date vehicle was purchased
  final int tankCapacityMilliliters; // Exact physical fuel tank capacity in milliliters (e.g. 55000 mL)
  final int telemetryCapabilityMask; // Bitmask for hardware support (0x01=Fuel, 0x02=Odo, 0x04=Legacy, 0x08=OBD)
  final String? boundObdDeviceId; // Paired OBD-II BLE adapter MAC / UUID
  final double? lastKnownOdometer;
  final double? lastKnownFuelPercent; // 0.0 to 100.0
  final DateTime? lastObdSyncTime;
  final double calibrationFactor; // Self-learning tank percentage multiplier (default 1.0)
  final DateTime createdAt;

  Vehicle({
    required this.id,
    required this.name,
    required this.type,
    required this.brand,
    required this.owner,
    this.colorValue = 0xFF1E88E5, // Default nice Blue
    this.unitDistance = 'km',
    this.unitVolume = 'L',
    this.currency = '\$',
    this.fuelType = 'Regular (87)',
    this.licensePlate,
    this.profileImageUri,
    this.bannerImageUri,
    this.initialOdometer,
    this.dateBought,
    int? tankCapacityMilliliters,
    double? tankCapacityLiters,
    String? boundObdDeviceId,
    String? obdDeviceId,
    this.telemetryCapabilityMask = 0,
    this.lastKnownOdometer,
    this.lastKnownFuelPercent,
    this.lastObdSyncTime,
    this.calibrationFactor = 1.0,
    DateTime? createdAt,
  })  : tankCapacityMilliliters = tankCapacityMilliliters ??
            ((tankCapacityLiters ?? 55.0) * 1000).round(),
        boundObdDeviceId = boundObdDeviceId ?? obdDeviceId,
        createdAt = createdAt ?? DateTime.now();

  /// Backwards-compatible float getter for tank capacity in liters
  double get tankCapacityLiters => tankCapacityMilliliters / 1000.0;

  /// Tank capacity in the vehicle's configured volume unit (L or gal)
  double get tankCapacityInUnit {
    if (unitVolume.toLowerCase().contains('gal')) {
      return (tankCapacityMilliliters / 1000.0) * 0.264172;
    }
    return tankCapacityMilliliters / 1000.0;
  }

  /// Backwards-compatible alias for paired OBD device ID
  String? get obdDeviceId => boundObdDeviceId;

  /// Ownership duration description
  String get ownershipDuration {
    if (dateBought == null) return 'N/A';
    final now = DateTime.now();
    final days = now.difference(dateBought!).inDays;
    if (days < 0) return 'Future purchase date';
    final years = days ~/ 365;
    final remainingDays = days % 365;
    final months = remainingDays ~/ 30;

    if (years > 0) {
      return '$years yr${years > 1 ? 's' : ''}${months > 0 ? ', $months mo${months > 1 ? 's' : ''}' : ''}';
    } else if (months > 0) {
      return '$months month${months > 1 ? 's' : ''}';
    } else {
      return '$days day${days != 1 ? 's' : ''}';
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'brand': brand,
      'owner': owner,
      'colorValue': colorValue,
      'unitDistance': unitDistance,
      'unitVolume': unitVolume,
      'currency': currency,
      'fuelType': fuelType,
      'licensePlate': licensePlate,
      'profileImageUri': profileImageUri,
      'bannerImageUri': bannerImageUri,
      'initialOdometer': initialOdometer,
      'dateBought': dateBought?.toIso8601String(),
      'tankCapacityMilliliters': tankCapacityMilliliters,
      'tankCapacityLiters': tankCapacityLiters,
      'telemetryCapabilityMask': telemetryCapabilityMask,
      'boundObdDeviceId': boundObdDeviceId,
      'obdDeviceId': boundObdDeviceId,
      'lastKnownOdometer': lastKnownOdometer,
      'lastKnownFuelPercent': lastKnownFuelPercent,
      'lastObdSyncTime': lastObdSyncTime?.toIso8601String(),
      'calibrationFactor': calibrationFactor,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Vehicle.fromJson(Map<String, dynamic> json) {
    VehicleType parseType(String? val) {
      if (val == null) return VehicleType.sedan;
      return VehicleType.values.firstWhere(
        (e) => e.name.toLowerCase() == val.toLowerCase(),
        orElse: () => VehicleType.sedan,
      );
    }

    final ml = json['tankCapacityMilliliters'] as int?;
    final liters = (json['tankCapacityLiters'] as num?)?.toDouble();
    final effectiveMl = ml ?? ((liters ?? 55.0) * 1000).round();
    final boundId = json['boundObdDeviceId'] as String? ?? json['obdDeviceId'] as String?;
    final capMask = json['telemetryCapabilityMask'] as int? ?? 0;

    return Vehicle(
      id: json['id'] as String,
      name: json['name'] as String? ?? 'My Vehicle',
      type: parseType(json['type'] as String?),
      brand: json['brand'] as String? ?? 'Unknown',
      owner: json['owner'] as String? ?? 'Owner',
      colorValue: json['colorValue'] as int? ?? 0xFF1E88E5,
      unitDistance: json['unitDistance'] as String? ?? 'km',
      unitVolume: json['unitVolume'] as String? ?? 'L',
      currency: json['currency'] as String? ?? '\$',
      fuelType: json['fuelType'] as String? ?? 'Regular (87)',
      licensePlate: json['licensePlate'] as String?,
      profileImageUri: json['profileImageUri'] as String?,
      bannerImageUri: json['bannerImageUri'] as String?,
      initialOdometer: (json['initialOdometer'] as num?)?.toDouble(),
      dateBought: json['dateBought'] != null
          ? DateTime.tryParse(json['dateBought'] as String)
          : null,
      tankCapacityMilliliters: effectiveMl,
      telemetryCapabilityMask: capMask,
      boundObdDeviceId: boundId,
      lastKnownOdometer: (json['lastKnownOdometer'] as num?)?.toDouble(),
      lastKnownFuelPercent: (json['lastKnownFuelPercent'] as num?)?.toDouble(),
      lastObdSyncTime: json['lastObdSyncTime'] != null
          ? DateTime.tryParse(json['lastObdSyncTime'] as String)
          : null,
      calibrationFactor: (json['calibrationFactor'] as num?)?.toDouble() ?? 1.0,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Vehicle copyWith({
    String? name,
    VehicleType? type,
    String? brand,
    String? owner,
    int? colorValue,
    String? unitDistance,
    String? unitVolume,
    String? currency,
    String? fuelType,
    String? licensePlate,
    String? profileImageUri,
    String? bannerImageUri,
    double? initialOdometer,
    DateTime? dateBought,
    int? tankCapacityMilliliters,
    double? tankCapacityLiters,
    int? telemetryCapabilityMask,
    String? boundObdDeviceId,
    String? obdDeviceId,
    double? lastKnownOdometer,
    double? lastKnownFuelPercent,
    DateTime? lastObdSyncTime,
    double? calibrationFactor,
    bool clearProfileImage = false,
    bool clearBannerImage = false,
  }) {
    return Vehicle(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      brand: brand ?? this.brand,
      owner: owner ?? this.owner,
      colorValue: colorValue ?? this.colorValue,
      unitDistance: unitDistance ?? this.unitDistance,
      unitVolume: unitVolume ?? this.unitVolume,
      currency: currency ?? this.currency,
      fuelType: fuelType ?? this.fuelType,
      licensePlate: licensePlate ?? this.licensePlate,
      profileImageUri: clearProfileImage ? null : (profileImageUri ?? this.profileImageUri),
      bannerImageUri: clearBannerImage ? null : (bannerImageUri ?? this.bannerImageUri),
      initialOdometer: initialOdometer ?? this.initialOdometer,
      dateBought: dateBought ?? this.dateBought,
      tankCapacityMilliliters: tankCapacityMilliliters ??
          (tankCapacityLiters != null ? (tankCapacityLiters * 1000).round() : this.tankCapacityMilliliters),
      telemetryCapabilityMask: telemetryCapabilityMask ?? this.telemetryCapabilityMask,
      boundObdDeviceId: boundObdDeviceId ?? obdDeviceId ?? this.boundObdDeviceId,
      lastKnownOdometer: lastKnownOdometer ?? this.lastKnownOdometer,
      lastKnownFuelPercent: lastKnownFuelPercent ?? this.lastKnownFuelPercent,
      lastObdSyncTime: lastObdSyncTime ?? this.lastObdSyncTime,
      calibrationFactor: calibrationFactor ?? this.calibrationFactor,
      createdAt: createdAt,
    );
  }
}
