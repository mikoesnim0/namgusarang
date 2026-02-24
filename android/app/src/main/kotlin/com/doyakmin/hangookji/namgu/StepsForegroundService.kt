package com.doyakmin.hangookji.namgu

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.text.NumberFormat
import java.util.Calendar
import java.util.Locale

class StepsForegroundService : Service(), SensorEventListener {
  private val sensorManager by lazy {
    getSystemService(Context.SENSOR_SERVICE) as SensorManager
  }
  private val stepCounterSensor: Sensor? by lazy {
    sensorManager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
  }

  private val prefs: SharedPreferences by lazy {
    getSharedPreferences(PREFS, Context.MODE_PRIVATE)
  }

  private var lastTodaySteps: Int? = null
  private var lastNotifySteps: Int? = null

  override fun onCreate() {
    super.onCreate()
    ensureNotificationChannel()
    setRunning(true)
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    if (stepCounterSensor == null) {
      stopSelf()
      return START_NOT_STICKY
    }

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
      val granted = ContextCompat.checkSelfPermission(
        this,
        Manifest.permission.ACTIVITY_RECOGNITION,
      ) == PackageManager.PERMISSION_GRANTED
      if (!granted) {
        stopSelf()
        return START_NOT_STICKY
      }
    }

    startForeground(NOTIF_ID, buildNotification(todaySteps = readCachedTodaySteps()))
    sensorManager.registerListener(
      this,
      stepCounterSensor,
      SensorManager.SENSOR_DELAY_NORMAL,
    )
    return START_STICKY
  }

  override fun onDestroy() {
    sensorManager.unregisterListener(this)
    setRunning(false)
    super.onDestroy()
  }

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onSensorChanged(event: SensorEvent) {
    val total = event.values.firstOrNull() ?: return
    val today = calcTodaySteps(total)
    if (lastTodaySteps == today) return
    lastTodaySteps = today

    saveCachedTodaySteps(today)

    // Update notification every step (1-step threshold for real-time feel).
    // setOnlyAlertOnce(true) prevents sound/vibration churn.
    val last = lastNotifySteps
    if (last == null || today != last) {
      lastNotifySteps = today
      updateNotification(today)
    }
  }

  override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
    // no-op
  }

  private fun updateNotification(todaySteps: Int) {
    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    nm.notify(NOTIF_ID, buildNotification(todaySteps))
  }

  private fun buildNotification(todaySteps: Int): Notification {
    val openIntent = Intent(this, MainActivity::class.java).apply {
      flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
    }
    val openPending = PendingIntent.getActivity(
      this,
      0,
      openIntent,
      PendingIntent.FLAG_UPDATE_CURRENT or pendingIntentImmutableFlag(),
    )

    val stepsText =
      "오늘 걸음수: ${NumberFormat.getNumberInstance(Locale.KOREA).format(todaySteps)}보"

    return NotificationCompat.Builder(this, CHANNEL_ID)
      .setSmallIcon(R.mipmap.ic_launcher)
      .setContentTitle("Walker홀릭")
      .setContentText(stepsText)
      .setContentIntent(openPending)
      .setOngoing(true)
      .setOnlyAlertOnce(true)
      .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
      // Show full step count on lock screen (not "Contents hidden")
      .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
      .build()
  }

  private fun ensureNotificationChannel() {
    if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
    val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    val channel = NotificationChannel(
      CHANNEL_ID,
      "걸음수 측정",
      NotificationManager.IMPORTANCE_LOW,
    ).apply {
      description = "백그라운드 걸음수 측정 알림"
      setShowBadge(false)
      // Show full step count on lock screen (not hidden/redacted)
      lockscreenVisibility = Notification.VISIBILITY_PUBLIC
    }
    nm.createNotificationChannel(channel)
  }

  private fun pendingIntentImmutableFlag(): Int {
    return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
      PendingIntent.FLAG_IMMUTABLE
    } else {
      0
    }
  }

  private fun hasBaselineForToday(): Boolean {
    val baselineDate = prefs.getString(KEY_BASELINE_DATE, null)
    return baselineDate == todayKey()
  }

  private fun readCachedTodaySteps(): Int {
    // IMPORTANT: Only trust cache if baseline is set for today.
    // This prevents showing stale values after reboot.
    if (!hasBaselineForToday()) return 0

    val today = todayKey()
    val cacheDate = prefs.getString(KEY_LAST_TODAY_DATE, null)

    // If cache is not for today, return 0
    if (cacheDate != today) return 0

    return prefs.getInt(KEY_LAST_TODAY_STEPS, 0).coerceAtLeast(0)
  }

  private fun saveCachedTodaySteps(today: Int) {
    prefs.edit()
      .putString(KEY_LAST_TODAY_DATE, todayKey())
      .putInt(KEY_LAST_TODAY_STEPS, today.coerceAtLeast(0))
      .apply()
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

    if (baselineDate != today) {
      saveBaseline(today, totalCounter)
      return totalCounter
    }

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

  private fun setRunning(running: Boolean) {
    prefs.edit().putBoolean(KEY_BG_RUNNING, running).apply()
  }

  companion object {
    private const val PREFS = "steps_prefs"

    // v2: added lockscreenVisibility = VISIBILITY_PUBLIC
    private const val CHANNEL_ID = "steps_tracking_v2"
    private const val NOTIF_ID = 7104

    private const val KEY_BASELINE_DATE = "baseline_date"
    private const val KEY_BASELINE_TOTAL = "baseline_total"

    private const val KEY_LAST_TODAY_DATE = "last_today_date"
    private const val KEY_LAST_TODAY_STEPS = "last_today_steps"
    private const val KEY_BG_RUNNING = "bg_steps_running"
  }
}
