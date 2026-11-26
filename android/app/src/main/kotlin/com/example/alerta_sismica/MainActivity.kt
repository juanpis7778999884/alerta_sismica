package com.example.alerta_sismica

import android.content.Intent
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startProtection" -> {
                    val prefs = getSharedPreferences(MotionProtectionService.PREFS, MODE_PRIVATE)
                    prefs.edit().putBoolean(MotionProtectionService.KEY_ACTIVE, true).apply()
                    val intent = Intent(this, MotionProtectionService::class.java)
                    try {
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(intent)
                        else startService(intent)
                        result.success(true)
                    } catch (e: Exception) {
                        prefs.edit().putBoolean(MotionProtectionService.KEY_ACTIVE, false).apply()
                        result.error("START_FAILED", e.message, null)
                    }
                }
                "stopProtection" -> {
                    getSharedPreferences(MotionProtectionService.PREFS, MODE_PRIVATE).edit()
                        .putBoolean(MotionProtectionService.KEY_ACTIVE, false)
                        .putBoolean(MotionProtectionService.KEY_ALERT_PENDING, false).apply()
                    stopService(Intent(this, MotionProtectionService::class.java))
                    result.success(true)
                }
                "consumePendingAlert" -> {
                    val prefs = getSharedPreferences(MotionProtectionService.PREFS, MODE_PRIVATE)
                    val pending = prefs.getBoolean("pending_alert_open", false)
                    prefs.edit().putBoolean("pending_alert_open", false).apply()
                    result.success(pending)
                }
                "confirmMovement" -> {
                    getSharedPreferences(MotionProtectionService.PREFS, MODE_PRIVATE).edit()
                        .putBoolean(MotionProtectionService.KEY_ALERT_PENDING, false).apply()
                    getSystemService(android.app.NotificationManager::class.java)
                        .cancel(MotionProtectionService.ALERT_NOTIFICATION_ID)
                    result.success(true)
                }
                "consumePendingSos" -> {
                    val prefs = getSharedPreferences(MotionProtectionService.PREFS, MODE_PRIVATE)
                    val pending = prefs.getBoolean("pending_sos", false)
                    prefs.edit().putBoolean("pending_sos", false).apply()
                    result.success(pending)
                }
                "isProtectionActive" -> result.success(
                    getSharedPreferences(MotionProtectionService.PREFS, MODE_PRIVATE)
                        .getBoolean(MotionProtectionService.KEY_ACTIVE, false)
                )
                else -> result.notImplemented()
            }
        }
        if (intent?.getBooleanExtra(MotionProtectionService.EXTRA_MOVEMENT_ALERT, false) == true) {
            getSharedPreferences(MotionProtectionService.PREFS, MODE_PRIVATE).edit().putBoolean("pending_alert_open", true).apply()
            intent.removeExtra(MotionProtectionService.EXTRA_MOVEMENT_ALERT)
            channel?.invokeMethod("onMovementAlertOpened", null)
        }
        if (intent?.getBooleanExtra("protection_sos_requested", false) == true) {
            intent.removeExtra("protection_sos_requested")
            channel?.invokeMethod("onProtectionSosRequested", null)
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.getBooleanExtra(MotionProtectionService.EXTRA_MOVEMENT_ALERT, false)) {
            getSharedPreferences(MotionProtectionService.PREFS, MODE_PRIVATE).edit().putBoolean("pending_alert_open", true).apply()
            intent.removeExtra(MotionProtectionService.EXTRA_MOVEMENT_ALERT)
            channel?.invokeMethod("onMovementAlertOpened", null)
        }
        if (intent.getBooleanExtra("protection_sos_requested", false)) {
            intent.removeExtra("protection_sos_requested")
            channel?.invokeMethod("onProtectionSosRequested", null)
        }
    }

    companion object {
        private const val CHANNEL = "com.example.alerta_sismica/motion_protection"
    }
}
