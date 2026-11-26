package com.example.alerta_sismica

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.app.NotificationManager

class MotionActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        when (intent?.action) {
            MotionProtectionService.ACTION_CONFIRM -> {
                context.getSharedPreferences(MotionProtectionService.PREFS, Context.MODE_PRIVATE)
                    .edit().putBoolean(MotionProtectionService.KEY_ALERT_PENDING, false).apply()
                context.getSystemService(NotificationManager::class.java)
                    .cancel(MotionProtectionService.ALERT_NOTIFICATION_ID)
            }
            MotionProtectionService.ACTION_SOS -> {
                context.getSharedPreferences(MotionProtectionService.PREFS, Context.MODE_PRIVATE)
                    .edit().putBoolean(MotionProtectionService.KEY_ALERT_PENDING, false)
                    .putBoolean("pending_sos", true).apply()
                context.getSystemService(NotificationManager::class.java)
                    .cancel(MotionProtectionService.ALERT_NOTIFICATION_ID)
                val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
                    ?: Intent(context, MainActivity::class.java)
                launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP)
                launch.putExtra("protection_sos_requested", true)
                context.startActivity(launch)
            }
            MotionProtectionService.ACTION_STOP -> {
                context.stopService(Intent(context, MotionProtectionService::class.java))
                context.getSharedPreferences(MotionProtectionService.PREFS, Context.MODE_PRIVATE)
                    .edit().putBoolean(MotionProtectionService.KEY_ACTIVE, false)
                    .putBoolean(MotionProtectionService.KEY_ALERT_PENDING, false).apply()
                context.getSystemService(NotificationManager::class.java)
                    .cancel(MotionProtectionService.ALERT_NOTIFICATION_ID)
            }
        }
    }
}
