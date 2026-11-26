package com.example.alerta_sismica

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import androidx.core.app.NotificationCompat
import kotlin.math.sqrt

class MotionProtectionService : Service(), SensorEventListener {
    private lateinit var sensorManager: SensorManager
    private val handler = Handler(Looper.getMainLooper())
    private val samples = ArrayDeque<Double>()
    private var gravity = doubleArrayOf(0.0, 0.0, 0.0)
    private var gyroMagnitude = 0.0
    private var gravityInitialized = false
    private var lastAlertAt = 0L
    private var lastNotificationAt = 0L

    private val repeatAlert = object : Runnable {
        override fun run() {
            val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
            if (!prefs.getBoolean(KEY_ALERT_PENDING, false)) return
            showMovementAlert()
            handler.postDelayed(this, ALERT_REPEAT_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        createChannels()
        sensorManager = getSystemService(SENSOR_SERVICE) as SensorManager
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            stopProtection()
            return START_NOT_STICKY
        }

        val prefs = getSharedPreferences(PREFS, MODE_PRIVATE)
        if (!prefs.getBoolean(KEY_ACTIVE, false) && intent == null) {
            stopSelf()
            return START_NOT_STICKY
        }

        prefs.edit().putBoolean(KEY_ACTIVE, true).apply()
        val notification = ongoingNotification()
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIFICATION_ID, notification, android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
        registerSensors()
        if (prefs.getBoolean(KEY_ALERT_PENDING, false)) {
            handler.removeCallbacks(repeatAlert)
            handler.postDelayed(repeatAlert, ALERT_REPEAT_MS)
        }
        return START_STICKY
    }

    private fun registerSensors() {
        sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
        }
        sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
        }
    }

    override fun onSensorChanged(event: SensorEvent) {
        when (event.sensor.type) {
            Sensor.TYPE_ACCELEROMETER -> {
                if (!gravityInitialized) {
                    for (i in 0..2) gravity[i] = event.values[i].toDouble()
                    gravityInitialized = true
                    return
                }
                val alpha = 0.88
                for (i in 0..2) {
                    gravity[i] = alpha * gravity[i] + (1.0 - alpha) * event.values[i]
                }
                val x = event.values[0] - gravity[0]
                val y = event.values[1] - gravity[1]
                val z = event.values[2] - gravity[2]
                val magnitude = sqrt(x * x + y * y + z * z)
                val now = System.currentTimeMillis()
                samples.addLast(magnitude * magnitude)
                while (samples.size > 45) samples.removeFirst()
                if (samples.size >= 12) {
                    val rms = sqrt(samples.average())
                    val unusualRotationWithVibration = rms >= 0.8 && gyroMagnitude >= 2.0
                    if ((rms >= RMS_THRESHOLD || unusualRotationWithVibration) &&
                        now - lastAlertAt >= ALERT_COOLDOWN_MS) {
                        lastAlertAt = now
                        beginMovementAlert()
                    }
                }
            }
            Sensor.TYPE_GYROSCOPE -> {
                val x = event.values[0].toDouble()
                val y = event.values[1].toDouble()
                val z = event.values[2].toDouble()
                gyroMagnitude = sqrt(x * x + y * y + z * z)
                // El giroscopio complementa la lectura inercial y evita tratar
                // una lectura incompleta como una medición válida.
                if (gyroMagnitude.isNaN()) gyroMagnitude = 0.0
            }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit

    private fun beginMovementAlert() {
        getSharedPreferences(PREFS, MODE_PRIVATE).edit()
            .putBoolean(KEY_ALERT_PENDING, true).apply()
        showMovementAlert()
        handler.removeCallbacks(repeatAlert)
        handler.postDelayed(repeatAlert, ALERT_REPEAT_MS)
    }

    private fun showMovementAlert() {
        lastNotificationAt = System.currentTimeMillis()
        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(EXTRA_MOVEMENT_ALERT, true)
        }
        val openPending = PendingIntent.getActivity(
            this, 7102, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val okIntent = Intent(this, MotionActionReceiver::class.java).setAction(ACTION_CONFIRM)
        val okPending = PendingIntent.getBroadcast(
            this, 7103, okIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val sosIntent = Intent(this, MotionActionReceiver::class.java).setAction(ACTION_SOS)
        val sosPending = PendingIntent.getBroadcast(
            this, 7104, sosIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val notification = NotificationCompat.Builder(this, ALERT_CHANNEL)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("¿Estás bien?")
            .setContentText("Alerta Sísmica detectó movimiento inusual. Confirma tu estado.")
            .setStyle(NotificationCompat.BigTextStyle().bigText("Se detectó movimiento inusual. Si necesitas ayuda, activa SOS. Si no respondes, volveremos a avisarte en 30 segundos."))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(false)
            .setContentIntent(openPending)
            .addAction(android.R.drawable.ic_menu_close_clear_cancel, "Estoy bien", okPending)
            .addAction(android.R.drawable.ic_dialog_alert, "Activar SOS", sosPending)
            .build()
        manager().notify(ALERT_NOTIFICATION_ID, notification)
    }

    private fun ongoingNotification(): Notification {
        val stopIntent = Intent(this, MotionActionReceiver::class.java).setAction(ACTION_STOP)
        val stopPending = PendingIntent.getBroadcast(
            this, 7105, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(this, SERVICE_CHANNEL)
            .setSmallIcon(android.R.drawable.ic_menu_compass)
            .setContentTitle("Protección sísmica activa")
            .setContentText("Acelerómetro y giroscopio monitoreando el movimiento")
            .setOngoing(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .addAction(android.R.drawable.ic_media_pause, "Detener", stopPending)
            .build()
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val serviceChannel = NotificationChannel(
            SERVICE_CHANNEL, "Protección sísmica", NotificationManager.IMPORTANCE_LOW
        ).apply { description = "Indica que el monitoreo de movimiento está activo." }
        val alertChannel = NotificationChannel(
            ALERT_CHANNEL, "Confirmación de movimiento", NotificationManager.IMPORTANCE_HIGH
        ).apply {
            description = "Confirma si estás bien o activa SOS ante movimiento inusual."
            enableVibration(true)
        }
        manager().createNotificationChannel(serviceChannel)
        manager().createNotificationChannel(alertChannel)
    }

    private fun manager() = getSystemService(NotificationManager::class.java)

    private fun stopProtection() {
        handler.removeCallbacksAndMessages(null)
        sensorManager.unregisterListener(this)
        getSharedPreferences(PREFS, MODE_PRIVATE).edit()
            .putBoolean(KEY_ACTIVE, false)
            .putBoolean(KEY_ALERT_PENDING, false)
            .apply()
        manager().cancel(ALERT_NOTIFICATION_ID)
        manager().cancel(NOTIFICATION_ID)
        stopForeground(STOP_FOREGROUND_REMOVE)
        stopSelf()
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        sensorManager.unregisterListener(this)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    companion object {
        const val PREFS = "motion_protection"
        const val KEY_ACTIVE = "active"
        const val KEY_ALERT_PENDING = "alert_pending"
        const val EXTRA_MOVEMENT_ALERT = "movement_alert"
        const val ACTION_STOP = "com.example.alerta_sismica.STOP"
        const val ACTION_CONFIRM = "com.example.alerta_sismica.CONFIRM"
        const val ACTION_SOS = "com.example.alerta_sismica.SOS"
        const val SERVICE_CHANNEL = "motion_protection_service"
        const val ALERT_CHANNEL = "motion_protection_alerts"
        const val NOTIFICATION_ID = 7101
        const val ALERT_NOTIFICATION_ID = 7102
        private const val RMS_THRESHOLD = 1.5
        private const val ALERT_COOLDOWN_MS = 60_000L
        private const val ALERT_REPEAT_MS = 30_000L
    }
}
