class PitStopLog {
  final String id;
  final DateTime timestamp;
  final double? latitude;
  final double? longitude;
  final double durationMinutes;
  final String? matchedToRefuelId;

  PitStopLog({
    required this.id,
    required this.timestamp,
    this.latitude,
    this.longitude,
    required this.durationMinutes,
    this.matchedToRefuelId,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'timestamp': timestamp.toIso8601String(),
      'latitude': latitude,
      'longitude': longitude,
      'durationMinutes': durationMinutes,
      'matchedToRefuelId': matchedToRefuelId,
    };
  }

  factory PitStopLog.fromJson(Map<String, dynamic> json) {
    return PitStopLog(
      id: json['id'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      durationMinutes: (json['durationMinutes'] as num?)?.toDouble() ?? 5.0,
      matchedToRefuelId: json['matchedToRefuelId'] as String?,
    );
  }

  PitStopLog copyWith({
    String? id,
    DateTime? timestamp,
    double? latitude,
    double? longitude,
    double? durationMinutes,
    String? matchedToRefuelId,
  }) {
    return PitStopLog(
      id: id ?? this.id,
      timestamp: timestamp ?? this.timestamp,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      durationMinutes: durationMinutes ?? this.durationMinutes,
      matchedToRefuelId: matchedToRefuelId ?? this.matchedToRefuelId,
    );
  }
}

