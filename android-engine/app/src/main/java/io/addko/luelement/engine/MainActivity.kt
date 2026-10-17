package io.addko.luelement.engine

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Typeface
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.annotation.RequiresApi
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class MainActivity : Activity() {
    private lateinit var status: TextView

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        if (handleDeepLink(intent)) {
            finish()
            return
        }

        setContentView(buildUi())
        requestNotificationPermissionIfNeeded()
        refreshStatus()
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (handleDeepLink(intent)) {
            finish()
            return
        }
        if (::status.isInitialized) {
            refreshStatus()
        }
    }

    private fun buildUi(): LinearLayout {
        val density = resources.displayMetrics.density
        val padding = (24 * density).toInt()

        status = TextView(this).apply {
            text = "Verificando motor…"
            textSize = 16f
        }

        val title = TextView(this).apply {
            text = "Luelement Engine"
            textSize = 26f
            setTypeface(typeface, Typeface.BOLD)
        }

        val description = TextView(this).apply {
            text = "Companion nativo do plugin Luelement. O motor escuta apenas no dispositivo local."
            textSize = 15f
        }

        val start = Button(this).apply {
            text = "Iniciar motor"
            setOnClickListener {
                startEngine()
                status.text = "Iniciando…"
                delayedRefresh()
            }
        }

        val stop = Button(this).apply {
            text = "Parar motor"
            setOnClickListener {
                stopEngine()
                status.text = "Encerrando…"
                delayedRefresh()
            }
        }

        return LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(padding, padding, padding, padding)
            addView(title, matchWrap())
            addView(description, matchWrap(top = 12))
            addView(status, matchWrap(top = 24))
            addView(start, matchWrap(top = 24))
            addView(stop, matchWrap(top = 8))
        }
    }

    private fun matchWrap(top: Int = 0): LinearLayout.LayoutParams {
        val density = resources.displayMetrics.density
        return LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.WRAP_CONTENT,
        ).apply {
            topMargin = (top * density).toInt()
        }
    }

    private fun handleDeepLink(intent: Intent?): Boolean {
        if (intent?.action != Intent.ACTION_VIEW) return false

        return when (intent.data?.host?.lowercase()) {
            "start" -> {
                startEngine()
                true
            }
            "stop" -> {
                stopEngine()
                true
            }
            else -> false
        }
    }

    private fun startEngine() {
        val service = Intent(this, ElementumService::class.java).apply {
            action = ElementumService.ACTION_START
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(service)
        } else {
            startService(service)
        }
    }

    private fun stopEngine() {
        val service = Intent(this, ElementumService::class.java).apply {
            action = ElementumService.ACTION_STOP
        }
        startService(service)
    }

    private fun refreshStatus() {
        thread(name = "Luelement-Status") {
            val running = try {
                val connection = URL("http://127.0.0.1:65220/torrents/list")
                    .openConnection() as HttpURLConnection
                connection.connectTimeout = 500
                connection.readTimeout = 750
                connection.requestMethod = "GET"
                val ok = connection.responseCode in 200..299
                connection.disconnect()
                ok
            } catch (_: Throwable) {
                false
            }

            runOnUiThread {
                if (!isFinishing && ::status.isInitialized) {
                    status.text = if (running) {
                        "Motor ativo • 127.0.0.1:65220"
                    } else {
                        "Motor parado"
                    }
                }
            }
        }
    }

    private fun delayedRefresh() {
        thread(name = "Luelement-DelayedStatus") {
            try {
                Thread.sleep(1_500)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
            }
            if (!isFinishing) {
                refreshStatus()
            }
        }
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestNotifications()
        }
    }

    @RequiresApi(33)
    private fun requestNotifications() {
        requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 65220)
    }
}
