package com.aktron.fuelmetrics

import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val PROBE_CHANNEL = "fuel_metrics/headunit_probe"
    private val TELEMETRY_CHANNEL = "fuel_metrics/headunit_telemetry"

    private var eventSink: EventChannel.EventSink? = null
    private var isSimulatedAttached = false
    private var simulatedStatus = "STATUS_SUCCESS"
    private var simulatedFuelPercent = 78.5
    private var simulatedOdometerMeters = 25420000L

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PROBE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getAttachmentStatus" -> {
                    val data = mapOf(
                        "isAttached" to isSimulatedAttached,
                        "connectionType" to if (isSimulatedAttached) "PROJECTION" else "NONE"
                    )
                    result.success(data)
                }
                "probeCapabilities" -> {
                    val timeoutMs = call.argument<Int>("timeoutMs") ?: 3000
                    val isNative = simulatedStatus == "STATUS_SUCCESS"
                    val response = mapOf(
                        "isAttached" to isSimulatedAttached,
                        "status" to simulatedStatus,
                        "fuelSupported" to isNative,
                        "odometerSupported" to isNative,
                        "currentFuelPercent" to if (isNative) simulatedFuelPercent else null,
                        "currentOdometerMeters" to if (isNative) simulatedOdometerMeters else null
                    )
                    result.success(response)
                }
                "simulateAttachment" -> {
                    isSimulatedAttached = call.argument<Boolean>("isAttached") ?: false
                    simulatedStatus = call.argument<String>("status") ?: "STATUS_SUCCESS"
                    call.argument<Double>("fuelPercent")?.let { simulatedFuelPercent = it }
                    call.argument<Long>("odometerMeters")?.let { simulatedOdometerMeters = it }
                    
                    if (isSimulatedAttached) {
                        eventSink?.success(mapOf(
                            "event" to "ATTACHED",
                            "status" to simulatedStatus,
                            "fuelPercent" to simulatedFuelPercent,
                            "odometerMeters" to simulatedOdometerMeters
                        ))
                    } else {
                        eventSink?.success(mapOf(
                            "event" to "DETACHED"
                        ))
                    }
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, TELEMETRY_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    eventSink = events
                    if (isSimulatedAttached) {
                        events?.success(mapOf(
                            "event" to "CURRENT_STATE",
                            "status" to simulatedStatus,
                            "fuelPercent" to simulatedFuelPercent,
                            "odometerMeters" to simulatedOdometerMeters
                        ))
                    }
                }

                override fun onCancel(arguments: Any?) {
                    eventSink = null
                }
            }
        )
    }
}
