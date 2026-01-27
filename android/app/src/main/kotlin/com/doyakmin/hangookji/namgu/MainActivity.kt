package com.doyakmin.hangookji.namgu

import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
  private var stepsApi: StepsApi? = null

  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    stepsApi = StepsApi(this, flutterEngine.dartExecutor.binaryMessenger)
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
