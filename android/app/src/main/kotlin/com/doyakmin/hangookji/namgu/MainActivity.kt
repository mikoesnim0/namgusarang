package com.doyakmin.hangookji.namgu

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterFragmentActivity

class MainActivity : FlutterFragmentActivity() {
  private var stepsApi: StepsApi? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    stepsApi = StepsApi(this, flutterEngine.dartExecutor.binaryMessenger)
  }

  override fun onResume() {
    super.onResume()
    // Ensure step tracking notification is always running when app is open.
    // No-op if permission is not yet granted.
    stepsApi?.ensureBackgroundStepsRunning()
  }

  override fun onRequestPermissionsResult(
    requestCode: Int,
    permissions: Array<out String>,
    grantResults: IntArray,
  ) {
    super.onRequestPermissionsResult(requestCode, permissions, grantResults)
    stepsApi?.onRequestPermissionsResult(requestCode, grantResults)
  }
}
