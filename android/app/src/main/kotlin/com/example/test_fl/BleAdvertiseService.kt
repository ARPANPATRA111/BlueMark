package com.example.test_fl

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.bluetooth.BluetoothAdapter
import android.bluetooth.BluetoothManager
import android.bluetooth.le.AdvertiseCallback
import android.bluetooth.le.AdvertiseData
import android.bluetooth.le.AdvertiseSettings
import android.bluetooth.le.BluetoothLeAdvertiser
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.os.ParcelUuid
import androidx.core.app.NotificationCompat
import java.util.UUID

class BleAdvertiseService : Service() {
    companion object {
        const val EXTRA_ROLL_NUMBER = "rollNumber"
        const val EXTRA_SERVICE_UUID = "serviceUuid"
        const val EXTRA_MANUFACTURER_ID = "manufacturerId"
        const val EXTRA_PAYLOAD = "payload"

        private const val CHANNEL_ID = "ble_attendance_channel"
        private const val CHANNEL_NAME = "Attendance BLE Broadcast"
        private const val NOTIFICATION_ID = 7742

        @Volatile
        var isAdvertising: Boolean = false

        @Volatile
        var advertiseState: String = "stopped"

        @Volatile
        var lastError: String? = null
    }

    private var advertiser: BluetoothLeAdvertiser? = null
    private var advertiseCallback: AdvertiseCallback? = null

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        val rollNumber = intent?.getStringExtra(EXTRA_ROLL_NUMBER)?.trim()?.uppercase()
        val serviceUuid = intent?.getStringExtra(EXTRA_SERVICE_UUID)?.trim()
        val manufacturerId = intent?.getIntExtra(EXTRA_MANUFACTURER_ID, 0x0A77) ?: 0x0A77
        val payloadInts = intent?.getIntegerArrayListExtra(EXTRA_PAYLOAD)

        advertiseState = "starting"
        isAdvertising = false
        lastError = null

        if (rollNumber.isNullOrEmpty() || serviceUuid.isNullOrEmpty()) {
            advertiseState = "error"
            lastError = "Invalid advertise request"
            stopSelf()
            return START_NOT_STICKY
        }

        startForeground(NOTIFICATION_ID, createNotification(rollNumber))

        val payload = if (!payloadInts.isNullOrEmpty()) {
            payloadInts.map { it.toByte() }.toByteArray()
        } else {
            "BAT:$rollNumber".toByteArray(Charsets.UTF_8)
        }

        runCatching {
            startAdvertising(
                payload = payload,
                serviceUuid = serviceUuid,
                manufacturerId = manufacturerId,
            )
        }.onFailure {
            advertiseState = "error"
            lastError = it.message ?: "Failed to start advertising"
            stopSelf()
            return START_NOT_STICKY
        }

        return START_STICKY
    }

    override fun onDestroy() {
        stopAdvertising()
        isAdvertising = false
        if (advertiseState != "error") {
            advertiseState = "stopped"
        }
        super.onDestroy()
    }

    private fun startAdvertising(
        payload: ByteArray,
        serviceUuid: String,
        manufacturerId: Int,
    ) {
        val bluetoothManager = getSystemService(Context.BLUETOOTH_SERVICE) as BluetoothManager
        val adapter: BluetoothAdapter = bluetoothManager.adapter
            ?: throw IllegalStateException("Bluetooth adapter unavailable")
        if (!adapter.isEnabled) {
            throw IllegalStateException("Bluetooth is disabled")
        }

        advertiser = adapter.bluetoothLeAdvertiser
            ?: throw IllegalStateException("BLE advertiser unavailable on this device")

        val settings = AdvertiseSettings.Builder()
            .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_LOW_LATENCY)
            .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_HIGH)
            .setConnectable(false)
            .build()

        fun buildData(includeServiceUuid: Boolean): AdvertiseData {
            val builder = AdvertiseData.Builder()
            .setIncludeDeviceName(false)
            .addManufacturerData(manufacturerId, payload)
            if (includeServiceUuid) {
                builder.addServiceUuid(ParcelUuid(UUID.fromString(serviceUuid)))
            }
            return builder.build()
        }

        fun startWithData(includeServiceUuid: Boolean) {
            val data = buildData(includeServiceUuid)

            advertiseCallback = object : AdvertiseCallback() {
                override fun onStartSuccess(settingsInEffect: AdvertiseSettings?) {
                    advertiseState = "active"
                    isAdvertising = true
                    lastError = null
                }

                override fun onStartFailure(errorCode: Int) {
                    isAdvertising = false
                    if (includeServiceUuid && errorCode == ADVERTISE_FAILED_DATA_TOO_LARGE) {
                        startWithData(false)
                        return
                    }

                    advertiseState = "error"
                    lastError = "Advertise start failed (code=$errorCode)"
                    stopSelf()
                }
            }

            advertiser?.startAdvertising(settings, data, advertiseCallback)
        }

        startWithData(true)
    }

    private fun stopAdvertising() {
        val callback = advertiseCallback
        if (callback != null) {
            runCatching {
                advertiser?.stopAdvertising(callback)
            }
        }
        advertiseCallback = null
        isAdvertising = false
    }

    private fun createNotification(rollNumber: String): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_LOW)
            manager.createNotificationChannel(channel)
        }

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Attendance broadcast active")
            .setContentText("Student $rollNumber is discoverable for attendance")
            .setSmallIcon(R.mipmap.ic_launcher)
            .setOngoing(true)
            .setSilent(true)
            .build()
    }
}
