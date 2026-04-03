package com.example.test_fl

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
	private val channelName = "attendance_ble_advertiser"

	override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
		super.configureFlutterEngine(flutterEngine)

		MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
			when (call.method) {
				"startAdvertising" -> {
					val rollNumber = call.argument<String>("rollNumber")
					val serviceUuid = call.argument<String>("serviceUuid")
					val manufacturerId = call.argument<Int>("manufacturerId") ?: 0x0A77
					val payload = call.argument<List<Int>>("payload")

					if (rollNumber.isNullOrBlank() || serviceUuid.isNullOrBlank()) {
						result.error("invalid_args", "rollNumber and serviceUuid are required", null)
						return@setMethodCallHandler
					}

					try {
						val intent = Intent(this, BleAdvertiseService::class.java).apply {
							putExtra(BleAdvertiseService.EXTRA_ROLL_NUMBER, rollNumber)
							putExtra(BleAdvertiseService.EXTRA_SERVICE_UUID, serviceUuid)
							putExtra(BleAdvertiseService.EXTRA_MANUFACTURER_ID, manufacturerId)
							if (payload != null) {
								putIntegerArrayListExtra(BleAdvertiseService.EXTRA_PAYLOAD, ArrayList(payload))
							}
						}

						if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
							startForegroundService(intent)
						} else {
							startService(intent)
						}
						result.success(true)
					} catch (error: Throwable) {
						result.error("start_failed", error.message, null)
					}
				}

				"stopAdvertising" -> {
					try {
						val intent = Intent(this, BleAdvertiseService::class.java)
						stopService(intent)
						result.success(true)
					} catch (error: Throwable) {
						result.error("stop_failed", error.message, null)
					}
				}

				"getAdvertisingStatus" -> {
					result.success(
						mapOf(
							"isAdvertising" to BleAdvertiseService.isAdvertising,
							"state" to BleAdvertiseService.advertiseState,
							"lastError" to BleAdvertiseService.lastError,
						)
					)
				}

				else -> result.notImplemented()
			}
		}
	}
}
