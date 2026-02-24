package com.doyakmin.hangookji.namgu

import android.Manifest
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorManager
import android.os.Build
import androidx.core.content.ContextCompat

/**
 * Starts StepsForegroundService automatically after:
 *  - Device boot (ACTION_BOOT_COMPLETED)
 *  - Quick boot on some devices (QUICKBOOT_POWERON)
 *  - My package replacement (PACKAGE_REPLACED, for app updates)
 *
 * Prerequisites: ACTIVITY_RECOGNITION permission must already be granted.
 * If not granted, the service will refuse to start on its own.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action ?: return
        if (action !in BOOT_ACTIONS) return

        if (!canStartService(context)) return

        val serviceIntent = Intent(context, StepsForegroundService::class.java)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            context.startForegroundService(serviceIntent)
        } else {
            context.startService(serviceIntent)
        }
    }

    private fun canStartService(context: Context): Boolean {
        // Step counter sensor must exist
        val sm = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
        if (sm.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) == null) return false

        // ACTIVITY_RECOGNITION permission required on Android 10+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val granted = ContextCompat.checkSelfPermission(
                context,
                Manifest.permission.ACTIVITY_RECOGNITION,
            ) == PackageManager.PERMISSION_GRANTED
            if (!granted) return false
        }

        return true
    }

    companion object {
        private val BOOT_ACTIONS = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            "android.intent.action.QUICKBOOT_POWERON",       // HTC
            "com.htc.intent.action.QUICKBOOT_POWERON",       // HTC (older)
        )
    }
}
