import 'dart:async';
import '../models/vehicle.dart';
import 'head_unit_capability_probe.dart';
import 'obd_ble_session_manager.dart';

enum TelemetrySource {
  nativeHeadUnit,
  obd2Ble,
  passiveManualReady,
}

enum PowerLifecycleState {
  dormantSuspended,
  activeCruiseTelemetry,
  refuelWatchWindow,
  teardownAndScrub,
}

class EphemeralRefuelState {
  double? initialFuelPercent;
  double? latestFuelPercent;
  double? lastKnownOdometer;
  double? ephemeralLat;
  double? ephemeralLon;
  DateTime? sessionStartTime;

  bool get hasActiveRefuelPotential {
    if (initialFuelPercent == null || latestFuelPercent == null) return false;
    return (latestFuelPercent! - initialFuelPercent!) >= 10.0;
  }

  /// GDPR Data Minimization: Purge all raw transient percentages & GPS coordinates
  void clear() {
    initialFuelPercent = null;
    latestFuelPercent = null;
    lastKnownOdometer = null;
    ephemeralLat = null;
    ephemeralLon = null;
    sessionStartTime = null;
  }
}

class TelemetryOrchestrator {
  final HeadUnitCapabilityProbe headUnitProbe;
  final ObdBleSessionManager obdManager;

  TelemetrySource _activeSource = TelemetrySource.passiveManualReady;
  PowerLifecycleState _powerState = PowerLifecycleState.dormantSuspended;

  final EphemeralRefuelState _ephemeralState = EphemeralRefuelState();
  final StreamController<TelemetrySource> _sourceController =
      StreamController<TelemetrySource>.broadcast();
  final StreamController<PowerLifecycleState> _powerStateController =
      StreamController<PowerLifecycleState>.broadcast();

  Timer? _watchdogTimer;
  Timer? _refuelWatchTimer;
  int _refuelWatchSecondsRemaining = 180;
  DateTime _lastFrameTimestamp = DateTime.now();
  static const Duration watchdogThreshold = Duration(milliseconds: 5000);

  /// Injectable single-shot location lookup guarded by 5-second boundary
  Future<Map<String, double>?> Function({Duration timeLimit})? singleShotGpsResolver;

  /// Hook for confirmed refuel event commit
  Future<void> Function(double fuelPercent, double odometer, {double? lat, double? lon})?
      onRefuelConfirmed;

  TelemetryOrchestrator({
    HeadUnitCapabilityProbe? headUnitProbe,
    ObdBleSessionManager? obdManager,
    this.singleShotGpsResolver,
    this.onRefuelConfirmed,
  })  : headUnitProbe = headUnitProbe ?? HeadUnitCapabilityProbe(),
        obdManager = obdManager ?? ObdBleSessionManager();

  TelemetrySource get activeSource => _activeSource;
  PowerLifecycleState get powerState => _powerState;
  EphemeralRefuelState get ephemeralState => _ephemeralState;
  Stream<TelemetrySource> get activeSourceStream => _sourceController.stream;
  Stream<PowerLifecycleState> get powerStateStream => _powerStateController.stream;
  int get refuelWatchSecondsRemaining => _refuelWatchSecondsRemaining;

  void _setActiveSource(TelemetrySource source) {
    if (_activeSource != source) {
      _activeSource = source;
      _sourceController.add(source);
    }
  }

  /// Deterministic power state transitions with race condition guards
  void transitionPowerState(PowerLifecycleState newState) {
    if (_powerState == newState) return;
    _powerState = newState;
    _powerStateController.add(newState);

    switch (newState) {
      case PowerLifecycleState.dormantSuspended:
        _watchdogTimer?.cancel();
        _watchdogTimer = null;
        _refuelWatchTimer?.cancel();
        _refuelWatchTimer = null;
        obdManager.force1HzPolling(false);
        break;
      case PowerLifecycleState.activeCruiseTelemetry:
        _refuelWatchTimer?.cancel();
        _refuelWatchTimer = null;
        obdManager.force1HzPolling(false);
        break;
      case PowerLifecycleState.refuelWatchWindow:
        _startRefuelWatchWindow();
        break;
      case PowerLifecycleState.teardownAndScrub:
        _executeTeardownAndScrub();
        break;
    }
  }

  void _startRefuelWatchWindow() {
    _refuelWatchTimer?.cancel();
    _refuelWatchSecondsRemaining = 180;
    obdManager.force1HzPolling(true);

    _refuelWatchTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _refuelWatchSecondsRemaining--;
      if (_refuelWatchSecondsRemaining <= 0) {
        timer.cancel();
        _refuelWatchTimer = null;
        transitionPowerState(PowerLifecycleState.teardownAndScrub);
      }
    });
  }

  void _executeTeardownAndScrub() {
    _watchdogTimer?.cancel();
    _watchdogTimer = null;

    _refuelWatchTimer?.cancel();
    _refuelWatchTimer = null;

    obdManager.force1HzPolling(false);
    obdManager.disconnect();

    _ephemeralState.clear();

    _powerState = PowerLifecycleState.dormantSuspended;
    _powerStateController.add(PowerLifecycleState.dormantSuspended);
  }

  /// Determines optimal telemetry routing according to 3-tier priority:
  /// Priority 1: NATIVE_HEAD_UNIT (if capable and attached)
  /// Priority 2: OBD2_BLE (if vehicle has bound OBD dongle)
  /// Priority 3: PASSIVE_MANUAL_READY
  Future<TelemetrySource> determineInitialSource(Vehicle vehicle) async {
    final isAttached = await headUnitProbe.isHeadUnitAttached();
    if (isAttached) {
      final probeResult = await headUnitProbe.probeCapabilities();
      if (probeResult.isNativeSupported) {
        // Mutual exclusion: Head unit natively provides fuel & odometer.
        // Suppress and power down OBD-II BLE so the BLE radio draws zero power.
        obdManager.disconnect();
        _setActiveSource(TelemetrySource.nativeHeadUnit);
        _startWatchdog(vehicle);
        transitionPowerState(PowerLifecycleState.activeCruiseTelemetry);
        return TelemetrySource.nativeHeadUnit;
      }
    }

    if (vehicle.boundObdDeviceId != null && vehicle.boundObdDeviceId!.isNotEmpty) {
      _setActiveSource(TelemetrySource.obd2Ble);
      _startWatchdog(vehicle);
      transitionPowerState(PowerLifecycleState.activeCruiseTelemetry);
      return TelemetrySource.obd2Ble;
    }

    _setActiveSource(TelemetrySource.passiveManualReady);
    transitionPowerState(PowerLifecycleState.dormantSuspended);
    return TelemetrySource.passiveManualReady;
  }

  /// Notifies the orchestrator of incoming telemetry frame (resets watchdog timer)
  void onTelemetryFrameReceived({
    required double fuelPercent,
    required double odometer,
    double? latitude,
    double? longitude,
    double? rpm,
  }) {
    _lastFrameTimestamp = DateTime.now();

    // Cache in ephemeral in-memory buffer
    _ephemeralState.initialFuelPercent ??= fuelPercent;
    _ephemeralState.latestFuelPercent = fuelPercent;
    _ephemeralState.lastKnownOdometer = odometer;
    _ephemeralState.sessionStartTime ??= DateTime.now();
    if (latitude != null && longitude != null) {
      _ephemeralState.ephemeralLat = latitude;
      _ephemeralState.ephemeralLon = longitude;
    }

    // Motion & power state evaluation
    if (rpm != null) {
      if (rpm > 0) {
        if (_powerState == PowerLifecycleState.refuelWatchWindow) {
          // Driver was stopped at traffic light and resumed motion!
          transitionPowerState(PowerLifecycleState.activeCruiseTelemetry);
        } else if (_powerState == PowerLifecycleState.dormantSuspended) {
          transitionPowerState(PowerLifecycleState.activeCruiseTelemetry);
        }
      } else if (rpm == 0) {
        if (_powerState == PowerLifecycleState.activeCruiseTelemetry ||
            _powerState == PowerLifecycleState.dormantSuspended) {
          transitionPowerState(PowerLifecycleState.refuelWatchWindow);
        }
      }
    }

    // Guarded refuel verification inside REFUEL_WATCH_WINDOW:
    // Requires BOTH RPM == 0 AND deltaFuelPercent >= +15.0%
    if (_powerState == PowerLifecycleState.refuelWatchWindow) {
      final initial = _ephemeralState.initialFuelPercent ?? fuelPercent;
      final delta = fuelPercent - initial;
      if (delta >= 15.0) {
        _triggerGuardedRefuelCommit();
      }
    }
  }

  Future<void> _triggerGuardedRefuelCommit() async {
    // 5-second bounded single-shot GPS acquisition
    if (singleShotGpsResolver != null) {
      final coords = await singleShotGpsResolver!(timeLimit: const Duration(seconds: 5));
      if (coords != null) {
        _ephemeralState.ephemeralLat = coords['latitude'];
        _ephemeralState.ephemeralLon = coords['longitude'];
      }
    }

    if (onRefuelConfirmed != null &&
        _ephemeralState.latestFuelPercent != null &&
        _ephemeralState.lastKnownOdometer != null) {
      await onRefuelConfirmed!(
        _ephemeralState.latestFuelPercent!,
        _ephemeralState.lastKnownOdometer!,
        lat: _ephemeralState.ephemeralLat,
        lon: _ephemeralState.ephemeralLon,
      );
    }

    transitionPowerState(PowerLifecycleState.teardownAndScrub);
  }

  /// Starts the 5000ms watchdog monitoring frame continuity
  void _startWatchdog(Vehicle vehicle) {
    _watchdogTimer?.cancel();
    _watchdogTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      final elapsed = DateTime.now().difference(_lastFrameTimestamp);
      if (elapsed > watchdogThreshold) {
        handleTelemetryTimeout(vehicle);
      }
    });
  }

  /// Zero-drop failover handover
  void handleTelemetryTimeout(Vehicle vehicle) {
    if (_activeSource == TelemetrySource.nativeHeadUnit) {
      // Head-Unit dropped mid-drive. Seamlessly fail over to OBD2_BLE if bound!
      if (vehicle.boundObdDeviceId != null) {
        _setActiveSource(TelemetrySource.obd2Ble);
        obdManager.connectAndHandshake(vehicle.boundObdDeviceId!);
      } else {
        _setActiveSource(TelemetrySource.passiveManualReady);
        transitionPowerState(PowerLifecycleState.teardownAndScrub);
      }
    } else if (_activeSource == TelemetrySource.obd2Ble) {
      // OBD dropped. Check if native head unit can resume
      if (TelemetryCapabilityMask.isNativeSupported(vehicle.telemetryCapabilityMask)) {
        _setActiveSource(TelemetrySource.nativeHeadUnit);
      } else {
        _setActiveSource(TelemetrySource.passiveManualReady);
        transitionPowerState(PowerLifecycleState.teardownAndScrub);
      }
    }
  }

  /// Immediate manual/simulated handover (for testing & event channels)
  void transitionToSource(TelemetrySource newSource) {
    _setActiveSource(newSource);
  }

  void dispose() {
    _watchdogTimer?.cancel();
    _refuelWatchTimer?.cancel();
    _sourceController.close();
    _powerStateController.close();
  }
}
