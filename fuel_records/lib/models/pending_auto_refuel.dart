class PendingAutoRefuel {
  final String id;
  final String vehicleId;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final String? detectedStationName;
  final double resolvedPricePerLitre;
  final double estimatedOdometer;
  final double estimatedLiters;
  final double estimatedTotalCost;
  final int detectionTier; // 1 to 5
  final String status; // 'DRAFT_TIMESTAMP' | 'AWAITING_USER_VERIFY' | 'CONFIRMED'
  final double? rawObdLiters;
  final bool? isFullTank;
  final DateTime createdAt;

  PendingAutoRefuel({
    required this.id,
    required this.vehicleId,
    required this.timestamp,
    this.latitude,
    this.longitude,
    this.detectedStationName,
    required this.resolvedPricePerLitre,
    required this.estimatedOdometer,
    required this.estimatedLiters,
    required this.estimatedTotalCost,
    required this.detectionTier,
    required this.status,
    this.rawObdLiters,
    this.isFullTank,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vehicleId': vehicleId,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'detectedStationName': detectedStationName,
      'resolvedPricePerLitre': resolvedPricePerLitre,
      'estimatedOdometer': estimatedOdometer,
      'estimatedLiters': estimatedLiters,
      'estimatedTotalCost': estimatedTotalCost,
      'detectionTier': detectionTier,
      'status': status,
      'rawObdLiters': rawObdLiters,
      'isFullTank': isFullTank,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory PendingAutoRefuel.fromJson(Map<String, dynamic> json) {
    return PendingAutoRefuel(
      id: json['id'] as String,
      vehicleId: json['vehicleId'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      detectedStationName: json['detectedStationName'] as String?,
      resolvedPricePerLitre: (json['resolvedPricePerLitre'] as num?)?.toDouble() ?? 1.50,
      estimatedOdometer: (json['estimatedOdometer'] as num?)?.toDouble() ?? 0.0,
      estimatedLiters: (json['estimatedLiters'] as num?)?.toDouble() ?? 0.0,
      estimatedTotalCost: (json['estimatedTotalCost'] as num?)?.toDouble() ?? 0.0,
      detectionTier: (json['detectionTier'] as num?)?.toInt() ?? 2,
      status: json['status'] as String? ?? 'AWAITING_USER_VERIFY',
      rawObdLiters: (json['rawObdLiters'] as num?)?.toDouble(),
      isFullTank: json['isFullTank'] as bool?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  PendingAutoRefuel copyWith({
    String? id,
    String? vehicleId,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    String? detectedStationName,
    double? resolvedPricePerLitre,
    double? estimatedOdometer,
    double? estimatedLiters,
    double? estimatedTotalCost,
    int? detectionTier,
    String? status,
    double? rawObdLiters,
    bool? isFullTank,
    DateTime? createdAt,
  }) {
    return PendingAutoRefuel(
      id: id ?? this.id,
      vehicleId: vehicleId ?? this.vehicleId,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      detectedStationName: detectedStationName ?? this.detectedStationName,
      resolvedPricePerLitre: resolvedPricePerLitre ?? this.resolvedPricePerLitre,
      estimatedOdometer: estimatedOdometer ?? this.estimatedOdometer,
      estimatedLiters: estimatedLiters ?? this.estimatedLiters,
      estimatedTotalCost: estimatedTotalCost ?? this.estimatedTotalCost,
      detectionTier: detectionTier ?? this.detectionTier,
      status: status ?? this.status,
      rawObdLiters: rawObdLiters ?? this.rawObdLiters,
      isFullTank: isFullTank ?? this.isFullTank,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}

