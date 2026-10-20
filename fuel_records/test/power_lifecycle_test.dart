import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:fuel_records/models/fuel_record.dart';
import 'package:fuel_records/services/telemetry_orchestrator.dart';
import 'package:fuel_records/services/obd_ble_session_manager.dart';
import 'package:fuel_records/services/station_and_price_resolver.dart';

void main() {
  group('Hardware-Gated Power Lifecycle & Battery Optimization Tests', () {
    test('Test 1: Cruise Backoff Verification - Polling duty cycle scales exponentially (15s -> 30s -> 60s)', () {
      fakeAsync((async) {
        final obdManager = ObdBleSessionManager();
        obdManager.updateSimulatedState(rpm: 2200.0, fuelPercent: 65.0, odometer: 30000.0);
        obdManager.connectAndHandshake('AA:BB:CC:11:22:33', autoConnect: true);

        // Advance to complete connection and handshake (100ms connection + 7x40ms AT commands = 380ms)
        async.elapse(const Duration(milliseconds: 500));
        expect(obdManager.isConnected, isTrue);
        expect(obdManager.autoConnect, isTrue);

        // Immediate first poll executed on verification
        expect(obdManager.pollCount, 1);
        expect(obdManager.currentBackoffSeconds, 30); // Stepped to 30s for next interval

        // Elapse 14 seconds: Poll count remains 1 (strictly verifies NOT polling at 1Hz)
        async.elapse(const Duration(seconds: 14));
        expect(obdManager.pollCount, 1);

        // Elapse 1 more second (15s total): 2nd poll triggers
        async.elapse(const Duration(seconds: 1));
        expect(obdManager.pollCount, 2);
        expect(obdManager.currentBackoffSeconds, 60); // Stepped to 60s for next interval

        // Elapse 29 seconds: Poll count remains 2
        async.elapse(const Duration(seconds: 29));
        expect(obdManager.pollCount, 2);

        // Elapse 1 more second (30s total): 3rd poll triggers
        async.elapse(const Duration(seconds: 1));
        expect(obdManager.pollCount, 3);
        expect(obdManager.currentBackoffSeconds, 60); // Capped at 60s

        // Elapse 59 seconds: Poll count remains 3
        async.elapse(const Duration(seconds: 59));
        expect(obdManager.pollCount, 3);

        // Elapse 1 more second (60s total): 4th poll triggers
        async.elapse(const Duration(seconds: 1));
        expect(obdManager.pollCount, 4);
        expect(obdManager.currentBackoffSeconds, 60); // Stays capped at 60s

        obdManager.dispose();
      });
    });

    test('Test 2: Hard-Bounded 180s Refuel Watch Cutoff - Stops polling and scrubs RAM after 180s idle', () {
      fakeAsync((async) {
        final obdManager = ObdBleSessionManager();
        final orchestrator = TelemetryOrchestrator(obdManager: obdManager);

        // 1. Vehicle cruising on highway
        orchestrator.transitionPowerState(PowerLifecycleState.activeCruiseTelemetry);
        orchestrator.onTelemetryFrameReceived(fuelPercent: 40.0, odometer: 45000.0, rpm: 2200.0);
        expect(orchestrator.powerState, PowerLifecycleState.activeCruiseTelemetry);

        // 2. RPM drops to 0 (engine off at pump) -> Transitions to REFUEL_WATCH_WINDOW
        orchestrator.onTelemetryFrameReceived(fuelPercent: 40.0, odometer: 45000.0, rpm: 0.0);
        expect(orchestrator.powerState, PowerLifecycleState.refuelWatchWindow);
        expect(obdManager.is1HzForced, isTrue);
        expect(orchestrator.refuelWatchSecondsRemaining, 180);

        // 3. Elapse 100 seconds without refuel jump
        async.elapse(const Duration(seconds: 100));
        expect(orchestrator.refuelWatchSecondsRemaining, 80);
        expect(orchestrator.powerState, PowerLifecycleState.refuelWatchWindow);

        // 4. Elapse remaining 80 seconds (180s total)
        async.elapse(const Duration(seconds: 80));

        // Assert 180s timeout cleanly scrubs memory and returns to DORMANT_SUSPENDED
        expect(orchestrator.powerState, PowerLifecycleState.dormantSuspended);
        expect(orchestrator.refuelWatchSecondsRemaining, 0);

        // Assert RAM scrubbing
        expect(orchestrator.ephemeralState.initialFuelPercent, isNull);
        expect(orchestrator.ephemeralState.latestFuelPercent, isNull);
        expect(orchestrator.ephemeralState.lastKnownOdometer, isNull);
        expect(orchestrator.ephemeralState.ephemeralLat, isNull);
        expect(orchestrator.ephemeralState.ephemeralLon, isNull);

        orchestrator.dispose();
      });
    });

    test('Test 3: Traffic Light Recovery - Driver resumes motion, cancels 180s timer, reverts to cruise backoff', () {
      fakeAsync((async) {
        final obdManager = ObdBleSessionManager();
        final orchestrator = TelemetryOrchestrator(obdManager: obdManager);

        orchestrator.transitionPowerState(PowerLifecycleState.activeCruiseTelemetry);

        // Vehicle stops at red traffic light (RPM == 0)
        orchestrator.onTelemetryFrameReceived(fuelPercent: 55.0, odometer: 12000.0, rpm: 0.0);
        expect(orchestrator.powerState, PowerLifecycleState.refuelWatchWindow);
        expect(obdManager.is1HzForced, isTrue);

        // Stopped at light for 20 seconds
        async.elapse(const Duration(seconds: 20));
        expect(orchestrator.refuelWatchSecondsRemaining, 160);

        // Light turns green! Driver resumes driving (RPM == 1800)
        orchestrator.onTelemetryFrameReceived(fuelPercent: 55.0, odometer: 12000.0, rpm: 1800.0);

        // Assert 180s countdown was cancelled and orchestrator reverted to ACTIVE_CRUISE_TELEMETRY
        expect(orchestrator.powerState, PowerLifecycleState.activeCruiseTelemetry);
        expect(obdManager.is1HzForced, isFalse);

        // Elapse another 160 seconds: No cutoff timeout should trigger
        async.elapse(const Duration(seconds: 160));
        expect(orchestrator.powerState, PowerLifecycleState.activeCruiseTelemetry);

        orchestrator.dispose();
      });
    });

    test('Test 4: Single-Shot GPS Gating - 0 invocations in cruise, exactly 1 invocation bounded by 5s on refuel guard', () {
      fakeAsync((async) {
        int gpsInvocations = 0;
        Duration? recordedTimeLimit;
        bool refuelConfirmedCalled = false;

        final orchestrator = TelemetryOrchestrator(
          singleShotGpsResolver: ({Duration timeLimit = const Duration(seconds: 5)}) async {
            gpsInvocations++;
            recordedTimeLimit = timeLimit;
            return {'latitude': 37.7749, 'longitude': -122.4194};
          },
          onRefuelConfirmed: (fuel, odo, {lat, lon}) async {
            refuelConfirmedCalled = true;
          },
        );

        // 1. Cruise telemetry stream (RPM = 2200, constant fuel)
        orchestrator.onTelemetryFrameReceived(fuelPercent: 30.0, odometer: 80000.0, rpm: 2200.0);
        async.elapse(const Duration(seconds: 60));
        expect(gpsInvocations, 0); // ZERO continuous location polling during cruise

        // 2. Stop at gas station pump (RPM == 0) -> REFUEL_WATCH_WINDOW
        orchestrator.onTelemetryFrameReceived(fuelPercent: 30.0, odometer: 80000.0, rpm: 0.0);
        async.elapse(const Duration(seconds: 10));
        expect(gpsInvocations, 0); // ZERO GPS while awaiting fuel volume increase

        // 3. Small slosh (+5%) under +15% threshold
        orchestrator.onTelemetryFrameReceived(fuelPercent: 35.0, odometer: 80000.0, rpm: 0.0);
        async.elapse(const Duration(seconds: 5));
        expect(gpsInvocations, 0);

        // 4. Refuel completed: Fuel level jumps from 30% to 75% (+45% >= 15%) while RPM == 0
        orchestrator.onTelemetryFrameReceived(fuelPercent: 75.0, odometer: 80000.0, rpm: 0.0);
        async.elapse(const Duration(milliseconds: 100));

        // Assert single-shot GPS was called exactly once with 5-second boundary
        expect(gpsInvocations, 1);
        expect(recordedTimeLimit, const Duration(seconds: 5));
        expect(refuelConfirmedCalled, isTrue);

        // Assert immediate transition into TEARDOWN_AND_SCRUB -> DORMANT_SUSPENDED
        expect(orchestrator.powerState, PowerLifecycleState.dormantSuspended);

        // Subsequent idle time triggers zero additional location calls
        async.elapse(const Duration(seconds: 60));
        expect(gpsInvocations, 1);

        orchestrator.dispose();
      });
    });

    test('Test 5: Guarded Single-Shot GPS helper respects 5-second timeout and consent', () async {
      StationAndPriceResolver.singleShotGpsInvocationCount = 0;

      // When consent is false, immediately returns null without invoking GPS
      final noConsentResult = await StationAndPriceResolver.acquireGuardedSingleShotLocation(
        countryName: 'United States',
        historyRecords: [],
        hasLocationConsent: false,
      );
      expect(noConsentResult.stationName, isNull);
      expect(StationAndPriceResolver.singleShotGpsInvocationCount, 1);

      // When provider succeeds within 5s boundary
      final successResult = await StationAndPriceResolver.acquireGuardedSingleShotLocation(
        countryName: 'United States',
        historyRecords: [
          FuelRecord(
            id: 'r_hist',
            vehicleId: 'v1',
            dateTime: DateTime.now(),
            odometer: 10000,
            fuelAmount: 30,
            totalPrice: 45,
            gasStation: 'Chevron Station',
          ),
        ],
        customGpsProvider: () async => {'latitude': 37.7749, 'longitude': -122.4194},
      );
      expect(successResult.isTimeout, isFalse);
      expect(successResult.latitude, 37.7749);
      expect(successResult.stationName, 'Chevron Station');

      // When provider times out beyond 5 seconds
      final timeoutResult = await StationAndPriceResolver.acquireGuardedSingleShotLocation(
        timeLimit: const Duration(milliseconds: 100),
        countryName: 'United States',
        historyRecords: [],
        customGpsProvider: () async {
          await Future.delayed(const Duration(milliseconds: 500));
          return {'latitude': 37.7749, 'longitude': -122.4194};
        },
      );
      expect(timeoutResult.isTimeout, isTrue);
      expect(timeoutResult.stationName, isNull);
    });
  });
}
