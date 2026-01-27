package com.doyakmin.hangookji.namgu

import android.Manifest
import android.content.Context
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.Looper
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar
import java.util.Locale

class StepsApi(
  private val activity: FlutterActivity,
  messenger: BinaryMessenger,
) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler, SensorEventListener {
  private val methodChannel = MethodChannel(messenger, "com.doyakmin.hangookji.namgu/steps")
  private val eventChannel = EventChannel(messenger, "com.doyakmin.hangookji.namgu/steps_stream")

  private val sensorManager =
    activity.getSystemService(Context.SENSOR_SERVICE) as SensorManager
  private val stepCounterSensor: Sensor? = sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
  private val prefs: SharedPreferences =
    activity.getSharedPreferences("steps_prefs", Context.MODE_PRIVATE)
  private val mainHandler = Handler(Looper.getMainLooper())

  private var eventSink: EventChannel.EventSink? = null
  private var pendingPermissionResult: MethodChannel.Result? = null
  private var pendingGetStepsResult: MethodChannel.Result? = null
  private var lastTodaySteps: Int? = null

  init {
    methodChannel.setMethodCallHandler(this)
    eventChannel.setStreamHandler(this)
  }

  override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
    eventSink = events
    startSensorIfPossible()
  }

  override fun onCancel(arguments: Any?) {
    eventSink = null
    if (pendingGetStepsResult == null) {
      stopSensor()
    }
  }

  override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
    when (call.method) {
      "isAvailable" -> result.success(stepCounterSensor != null)
      "getPermissionStatus" -> result.success(permissionStatus())
      "requestPermission" -> requestPermission(result)
      "getTodaySteps" -> getTodaySteps(result)
      else -> result.notImplemented()
    }
  }

  private fun permissionStatus(): String {
    if (stepCounterSensor == null) return "notSupported"
    if (hasActivityPermission()) return "granted"
    return "denied"
  }

  private fun requestPermission(result: MethodChannel.Result) {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
      result.success(true)
      startSensorIfPossible()
      return
    }

    if (hasActivityPermission()) {
      result.success(true)
      startSensorIfPossible()
      return
    }

    if (pendingPermissionResult != null) {
      result.success(false)
      return
    }

    pendingPermissionResult = result
    ActivityCompat.requestPermissions(
      activity,
      arrayOf(Manifest.permission.ACTIVITY_RECOGNITION),
      REQUEST_CODE_ACTIVITY,
    )
  }

  fun onRequestPermissionsResult(
    requestCode: Int,
    grantResults: IntArray,
  ) {
    if (requestCode != REQUEST_CODE_ACTIVITY) return

    val granted =
      grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
    pendingPermissionResult?.success(granted)
    pendingPermissionResult = null

    if (granted) startSensorIfPossible() else stopSensor()

    // If a Dart call is waiting for steps, release it with null on denial.
    if (!granted && pendingGetStepsResult != null) {
      pendingGetStepsResult?.success(null)
      pendingGetStepsResult = null
    }
  }

  private fun getTodaySteps(result: MethodChannel.Result) {
    if (stepCounterSensor == null) {
      result.success(null)
      return
    }
    if (!hasActivityPermission()) {
      result.success(null)
      return
    }

    val cached = lastTodaySteps
    if (cached != null) {
      result.success(cached)
      return
    }

    pendingGetStepsResult = result
    startSensorIfPossible()

    // Timeout: if we don't get a sensor event quickly, return 0 to unblock UI.
    mainHandler.postDelayed({
      if (pendingGetStepsResult != null) {
        pendingGetStepsResult?.success(0)
        pendingGetStepsResult = null
      }
    }, 1500)
  }

  private fun hasActivityPermission(): Boolean {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) return true
    return ContextCompat.checkSelfPermission(
      activity,
      Manifest.permission.ACTIVITY_RECOGNITION,
    ) == PackageManager.PERMISSION_GRANTED
  }

  private fun startSensorIfPossible() {
    if (stepCounterSensor == null) return
    if (!hasActivityPermission()) return
    sensorManager.registerListener(
      this,
      stepCounterSensor,
      SensorManager.SENSOR_DELAY_NORMAL,
    )
  }

  private fun stopSensor() {
    sensorManager.unregisterListener(this)
  }

  override fun onSensorChanged(event: SensorEvent) {
    val total = event.values.firstOrNull() ?: return
    val today = calcTodaySteps(total)

    if (lastTodaySteps == today) return
    lastTodaySteps = today

    eventSink?.success(today)

    val pending = pendingGetStepsResult
    if (pending != null) {
      pending.success(today)
      pendingGetStepsResult = null
    }
  }

  override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
    // no-op
  }

  private fun calcTodaySteps(totalCounter: Float): Int {
    val baseline = ensureBaseline(totalCounter)
    val raw = (totalCounter - baseline).toInt()
    return if (raw < 0) 0 else raw
  }

  private fun ensureBaseline(totalCounter: Float): Float {
    val today = todayKey()
    val baselineDate = prefs.getString(KEY_BASELINE_DATE, null)
    val storedBaseline = prefs.getFloat(KEY_BASELINE_TOTAL, totalCounter)

    // New day → reset baseline.
    if (baselineDate != today) {
      saveBaseline(today, totalCounter)
      return totalCounter
    }

    // Sensor reset (e.g., reboot) → reset baseline.
    if (totalCounter + 1 < storedBaseline) {
      saveBaseline(today, totalCounter)
      return totalCounter
    }

    return storedBaseline
  }

  private fun saveBaseline(date: String, totalCounter: Float) {
    prefs.edit()
      .putString(KEY_BASELINE_DATE, date)
      .putFloat(KEY_BASELINE_TOTAL, totalCounter)
      .apply()
  }

  private fun todayKey(): String {
    val c = Calendar.getInstance()
    val y = c.get(Calendar.YEAR)
    val m = c.get(Calendar.MONTH) + 1
    val d = c.get(Calendar.DAY_OF_MONTH)
    return String.format(Locale.US, "%04d%02d%02d", y, m, d)
  }

  companion object {
    private const val REQUEST_CODE_ACTIVITY = 9103
    private const val KEY_BASELINE_DATE = "baseline_date"
    private const val KEY_BASELINE_TOTAL = "baseline_total"
  }
}

