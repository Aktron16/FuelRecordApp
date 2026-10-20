import 'dart:async';
import 'package:flutter/services.dart';
import '../models/vehicle.dart';

class HeadUnitProbeResult {
  final bool isAttached;
  final String status;
  final bool fuelSupported;
  final bool odometerSupported;
  final double? currentFuelPercent;
  final int? currentOdometerMeters;
  final String advisoryMessage;
  final bool isNativeSupported;
  final bool isLegacyRestricted;

  HeadUnitProbeResult({
    required this.isAttached,
    required this.status,
    required this.fuelSupported,
    required this.odometerSupported,
    this.currentFuelPercent,
    this.currentOdometerMeters,
    required this.advisoryMessage,
    required this.isNativeSupported,
    required this.isLegacyRestricted,
  });

  static HeadUnitProbeResult unattached() {
    return HeadUnitProbeResult(
      isAttached: false,
      status: 'DETACHED',
      fuelSupported: false,
      odometerSupported: false,
      advisoryMessage: 'No head-unit connected.',
      isNativeSupported: false,
      isLegacyRestricted: false,
    );
  }
}

class HeadUnitCapabilityProbe {
  static const MethodChannel _probeChannel = MethodChannel('fuel_metrics/headunit_probe');
  static const EventChannel _telemetryChannel = EventChannel('fuel_metrics/headunit_telemetry');

  Stream<Map<dynamic, dynamic>>? _telemetryStream;

  Stream<Map<dynamic, dynamic>> get telemetryStream {
    _telemetryStream ??= _telemetryChannel
        .receiveBroadcastStream()
        .map((event) => event is Map ? event : <dynamic, dynamic>{});
    return _telemetryStream!;
  }

  /// Checks if physical USB or wireless projection is currently attached
  Future<bool> isHeadUnitAttached() async {
    try {
      final res = await _probeChannel.invokeMapMethod<String, dynamic>('getAttachmentStatus');
      return res?['isAttached'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Probes OEM bus telemetry capabilities within a 3000ms window
  Future<HeadUnitProbeResult> probeCapabilities({
    Duration timeout = const Duration(milliseconds: 3000),
  }) async {
    try {
      final res = await _probeChannel
          .invokeMapMethod<String, dynamic>('probeCapabilities', {'timeoutMs': timeout.inMilliseconds})
          .timeout(timeout, onTimeout: () => {'status': 'TIMEOUT', 'isAttached': true});

      final isAttached = res?['isAttached'] as bool? ?? false;
      final status = res?['status'] as String? ?? 'STATUS_UNAVAILABLE';
      final fuelSupported = res?['fuelSupported'] as bool? ?? false;
      final odometerSupported = res?['odometerSupported'] as bool? ?? false;
      final fuelPct = (res?['currentFuelPercent'] as num?)?.toDouble();
      final odoMeters = (res?['currentOdometerMeters'] as num?)?.toInt();

      if (!isAttached) {
        return HeadUnitProbeResult.unattached();
      }

      if (status == 'STATUS_SUCCESS' && fuelSupported && odometerSupported) {
        return HeadUnitProbeResult(
          isAttached: true,
          status: status,
          fuelSupported: true,
          odometerSupported: true,
          currentFuelPercent: fuelPct,
          currentOdometerMeters: odoMeters,
          advisoryMessage:
              'Your vehicle supports direct telemetry via Android Auto / CarPlay. You do not need an external OBD-II Bluetooth dongle.',
          isNativeSupported: true,
          isLegacyRestricted: false,
        );
      } else {
        return HeadUnitProbeResult(
          isAttached: true,
          status: status,
          fuelSupported: fuelSupported,
          odometerSupported: odometerSupported,
          currentFuelPercent: null,
          currentOdometerMeters: null,
          advisoryMessage:
              "Your vehicle's head-unit does not expose fuel and odometer sensors (common on older or restricted OEM models). We recommend connecting a Bluetooth OBD-II sensor for automatic fuel logging.",
          isNativeSupported: false,
          isLegacyRestricted: true,
        );
      }
    } catch (_) {
      return HeadUnitProbeResult(
        isAttached: true,
        status: 'TIMEOUT',
        fuelSupported: false,
        odometerSupported: false,
        advisoryMessage:
            "Your vehicle's head-unit does not expose fuel and odometer sensors (common on older or restricted OEM models). We recommend connecting a Bluetooth OBD-II sensor for automatic fuel logging.",
        isNativeSupported: false,
        isLegacyRestricted: true,
      );
    }
  }

  /// Updates vehicle capability mask based on probe outcome
  static Vehicle applyProbeOutcomeToVehicle(Vehicle vehicle, HeadUnitProbeResult probe) {
    int updatedMask = vehicle.telemetryCapabilityMask;
    if (probe.isNativeSupported) {
      updatedMask |= TelemetryCapabilityMask.headUnitNativeFuel;
      updatedMask |= TelemetryCapabilityMask.headUnitNativeOdometer;
      updatedMask &= ~TelemetryCapabilityMask.headUnitRestrictedLegacy;
    } else if (probe.isLegacyRestricted) {
      updatedMask |= TelemetryCapabilityMask.headUnitRestrictedLegacy;
      updatedMask &= ~(TelemetryCapabilityMask.headUnitNativeFuel | TelemetryCapabilityMask.headUnitNativeOdometer);
    }
    return vehicle.copyWith(telemetryCapabilityMask: updatedMask);
  }

  /// Simulates hardware attachment state via platform channel (for testing & simulator)
  Future<void> simulateAttachment({
    required bool isAttached,
    String status = 'STATUS_SUCCESS',
    double fuelPercent = 80.0,
    int odometerMeters = 25000000,
  }) async {
    try {
      await _probeChannel.invokeMethod('simulateAttachment', {
        'isAttached': isAttached,
        'status': status,
        'fuelPercent': fuelPercent,
        'odometerMeters': odometerMeters,
      });
    } catch (_) {}
  }
}

