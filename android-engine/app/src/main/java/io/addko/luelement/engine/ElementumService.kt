package io.addko.luelement.engine

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.IBinder
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class ElementumService : Service() {
    private var worker: Thread? = null

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action ?: ACTION_START) {
            ACTION_STOP -> requestStop()
            else -> startEngine()
        }
        return START_NOT_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        requestShutdown()
        super.onDestroy()
    }

    override fun onTimeout(startId: Int, fgsType: Int) {
        // Android 15 limits background dataSync foreground services to six
        // hours per 24-hour window. Shut Elementum down cleanly instead of
        // letting the system raise RemoteServiceException after the timeout.
        requestShutdown(connectTimeoutMs = 500, readTimeoutMs = 1_000)
        stopSelf(startId)
    }

    private fun startEngine() {
        if (worker?.isAlive == true) return

        startAsForeground(buildNotification("Iniciando motor Elementum…"))
        val runtime = EngineConfig.prepare(this)

        worker = thread(
            start = true,
            isDaemon = false,
            name = "Luelement-Elementum",
        ) {
            val code = try {
                EngineBridge.start(runtime.log.absolutePath, runtime.args())
            } catch (error: Throwable) {
                error.printStackTrace()
                -999L
            }

            val manager = getSystemService(NotificationManager::class.java)
            manager.notify(
                NOTIFICATION_ID,
                buildNotification("Motor encerrado (código $code)"),
            )
            stopSelf()
        }

        val manager = getSystemService(NotificationManager::class.java)
        manager.notify(
            NOTIFICATION_ID,
            buildNotification("Elementum ativo em 127.0.0.1:65220"),
        )
    }

    private fun requestStop() {
        thread(name = "Luelement-Stop") {
            requestShutdown()
            try {
                worker?.join(5_000)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
            }
            stopSelf()
        }
    }

    private fun requestShutdown(
        connectTimeoutMs: Int = 1_000,
        readTimeoutMs: Int = 1_500,
    ) {
        try {
            val connection = URL("http://127.0.0.1:65220/shutdown")
                .openConnection() as HttpURLConnection
            connection.requestMethod = "GET"
            connection.connectTimeout = connectTimeoutMs
            connection.readTimeout = readTimeoutMs
            connection.instanceFollowRedirects = false
            connection.inputStream.use { it.readBytes() }
            connection.disconnect()
        } catch (_: Throwable) {
            // If the daemon never completed startup there may be nothing to
            // shut down. The service can still finish normally.
        }
    }

    private fun startAsForeground(notification: Notification) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(NOTIFICATION_ID, notification)
        }
    }

    private fun buildNotification(text: String): Notification {
        val stopIntent = Intent(this, ElementumService::class.java).apply {
            action = ACTION_STOP
        }
        val stopPendingIntent = PendingIntent.getService(
            this,
            1,
            stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val openIntent = packageManager.getLaunchIntentForPackage(packageName)
        val openPendingIntent = openIntent?.let {
            PendingIntent.getActivity(
                this,
                2,
                it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
        }

        return Notification.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.stat_sys_download)
            .setContentTitle("Luelement Engine")
            .setContentText(text)
            .setOngoing(true)
            .setContentIntent(openPendingIntent)
            .addAction(
                Notification.Action.Builder(
                    null,
                    "Parar",
                    stopPendingIntent,
                ).build(),
            )
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = getSystemService(NotificationManager::class.java)
        manager.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID,
                "Luelement Engine",
                NotificationManager.IMPORTANCE_LOW,
            ).apply {
                description = "Motor local usado pelo plugin Luelement"
            },
        )
    }

    companion object {
        const val ACTION_START = "io.addko.luelement.engine.START"
        const val ACTION_STOP = "io.addko.luelement.engine.STOP"

        private const val CHANNEL_ID = "luelement_engine"
        private const val NOTIFICATION_ID = 65220
    }
}
