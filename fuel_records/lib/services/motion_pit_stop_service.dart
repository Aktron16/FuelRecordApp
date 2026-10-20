import '../models/pit_stop_log.dart';

enum DrivingActivityState {
  inVehicle,
  stillOrOnFoot,
  unknown,
}

class MotionPitStopService {
  DrivingActivityState _lastState = DrivingActivityState.unknown;
  DateTime? _stopStartTime;

  DrivingActivityState get lastState => _lastState;
  DateTime? get stopStartTime => _stopStartTime;

  /// Processes an activity transition event.
  /// When vehicle transitions IN_VEHICLE -> STILL/ON_FOOT for 3 to 10 minutes -> IN_VEHICLE,
  /// a pit-stop log is created with the stationary duration.
  PitStopLog? processTransition({
    required DrivingActivityState newState,
    required DateTime timestamp,
    double? latitude,
    double? longitude,
    double simulatedMinutesStopped = 5.0,
  }) {
    PitStopLog? recordedStop;

    if (_lastState == DrivingActivityState.inVehicle &&
        newState == DrivingActivityState.stillOrOnFoot) {
      // Driver parked / stepped out of car at gas station
      _stopStartTime = timestamp;
    } else if (_lastState == DrivingActivityState.stillOrOnFoot &&
        newState == DrivingActivityState.inVehicle) {
      // Driver resumed driving
      if (_stopStartTime != null) {
        final durationMins = timestamp.difference(_stopStartTime!).inSeconds / 60.0;
        final effectiveDuration = durationMins > 0 ? durationMins : simulatedMinutesStopped;

        // Pit stop fingerprinting: typical refuel stop lasts 3 to 10 minutes
        if (effectiveDuration >= 2.5 && effectiveDuration <= 15.0) {
          recordedStop = PitStopLog(
            id: 'stop-${timestamp.millisecondsSinceEpoch}',
            timestamp: _stopStartTime!,
            latitude: latitude,
            longitude: longitude,
            durationMinutes: double.parse(effectiveDuration.toStringAsFixed(1)),
          );
        }
      }
      _stopStartTime = null;
    }

    _lastState = newState;
    return recordedStop;
  }

  /// Matches a newly detected refuel event with the closest recorded PitStopLog
  static PitStopLog? matchRefuelToPitStop({
    required DateTime refuelDetectionTime,
    required List<PitStopLog> pitStops,
    Duration maxTimeWindow = const Duration(hours: 4),
  }) {
    if (pitStops.isEmpty) return null;

    PitStopLog? bestMatch;
    Duration minDiff = const Duration(days: 999);

    for (final stop in pitStops) {
      if (stop.matchedToRefuelId != null) continue; // already matched
      final diff = refuelDetectionTime.difference(stop.timestamp).abs();
      if (diff <= maxTimeWindow && diff < minDiff) {
        minDiff = diff;
        bestMatch = stop;
      }
    }

    return bestMatch;
  }

  /// Creates a simulated pit stop log for testing or Tier 4 simulation
  static PitStopLog createSimulatedPitStop({
    double stopDurationMinutes = 5.0,
    double? latitude,
    double? longitude,
    DateTime? timestamp,
  }) {
    final time = timestamp ?? DateTime.now().subtract(const Duration(minutes: 15));
    return PitStopLog(
      id: 'stop-sim-${time.millisecondsSinceEpoch}',
      timestamp: time,
      latitude: latitude ?? 37.7749,
      longitude: longitude ?? -122.4194,
      durationMinutes: stopDurationMinutes,
    );
  }
}
