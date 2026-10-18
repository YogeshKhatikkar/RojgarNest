// android/app/src/main/java/com/rojgarnext/app/MainActivity.kt
// ✅ COMPLETE FIXED VERSION - Extends FlutterFragmentActivity for Biometric

package com.rojgarnext.app

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.annotation.NonNull

class MainActivity: FlutterFragmentActivity() {
    private val CHANNEL = "com.rojgarnext.app/platform"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Method channel for platform-specific calls
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "getPlatformVersion" -> {
                        result.success("Android ${android.os.Build.VERSION.RELEASE}")
                    }
                    "getDeviceInfo" -> {
                        val deviceInfo = mapOf(
                            "manufacturer" to android.os.Build.MANUFACTURER,
                            "model" to android.os.Build.MODEL,
                            "version" to android.os.Build.VERSION.RELEASE,
                            "sdk" to android.os.Build.VERSION.SDK_INT.toString()
                        )
                        result.success(deviceInfo)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }
}