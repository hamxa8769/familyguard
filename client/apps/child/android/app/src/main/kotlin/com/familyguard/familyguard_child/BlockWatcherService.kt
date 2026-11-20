package com.familyguard.familyguard_child

import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import androidx.core.content.ContextCompat
import java.util.Calendar

/**
 * Foreground service that enforces bedtime locks and app blocking.
 *
 * How it works (all transparent, no stealth):
 * - Runs with a persistent "FamilyGuard monitoring is ON" notification.
 * - Every 5 seconds it asks UsageStats which app is in the foreground.
 * - If the foreground app is on the blocked list, or bedtime is active and
 *   the foreground app is not FamilyGuard itself, it covers the screen with
 *   a visible overlay explaining why, with a button to go home.
 * - The overlay is removed as soon as the user leaves the blocked app.
 *
 * OS limits (honest, not worked around):
 * - UsageStats only works after the user grants usage access in a system
 *   screen; without it nothing is enforced.
 * - The overlay needs "Draw over other apps" permission; without it the
 *   service cannot block and the Dart side tells the user to grant it.
 * - This is not Device Owner / lock-task mode: a determined user can still
 *   force-stop the app. Full kiosk-style enforcement needs a device-owner
 *   setup (e.g. via Android Enterprise), which is out of scope here.
 */
class BlockWatcherService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var overlayView: View? = null
    private var lastBlockedPackage: String? = null
    private var lastReason: String? = null

    private val tick = object : Runnable {
        override fun run() {
            enforceOnce()
            handler.postDelayed(this, POLL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        startForeground(
            Notifications.WATCHER_NOTIFICATION_ID,
            Notifications.watcherNotification(this)
        )
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        handler.removeCallbacks(tick)
        handler.post(tick)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        hideOverlay()
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun enforceOnce() {
        val blocked = EnforcementPrefs.blockedApps(this)
        val bedtime = EnforcementPrefs.bedtime(this)
        if (blocked.isEmpty() && bedtime == null) {
            hideOverlay()
            stopSelf()
            return
        }
        val foreground = currentForegroundPackage() ?: return
        if (foreground == packageName) {
            hideOverlay()
            return
        }
        val now = Calendar.getInstance()
        val nowMinutes = now.get(Calendar.HOUR_OF_DAY) * 60 + now.get(Calendar.MINUTE)
        val bedtimeActive = bedtime != null &&
            EnforcementPrefs.isBedtimeActive(nowMinutes, bedtime)
        val reason = when {
            bedtimeActive -> "It is bedtime. This device is locked until the morning."
            foreground in blocked -> "This app is blocked by a family rule."
            else -> null
        }
        if (reason != null) {
            showOverlay(foreground, reason)
        } else {
            hideOverlay()
        }
    }

    private fun currentForegroundPackage(): String? {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val events = usm.queryEvents(end - 60_000, end) ?: return null
        var lastPackage: String? = null
        var lastTime = 0L
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND &&
                event.timeStamp > lastTime
            ) {
                lastTime = event.timeStamp
                lastPackage = event.packageName
            }
        }
        return lastPackage
    }

    private fun showOverlay(packageName: String, reason: String) {
        if (lastBlockedPackage == packageName && lastReason == reason && overlayView != null) {
            return // Already showing the same block.
        }
        hideOverlay()
        if (!Settings.canDrawOverlays(this)) return // Dart side asks the user to grant it.
        val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        val layout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(0xFF1B1B1B.toInt())
            setPadding(48, 48, 48, 48)
        }
        val title = TextView(this).apply {
            text = "FamilyGuard"
            textSize = 28f
            setTextColor(0xFFFFFFFF.toInt())
            gravity = Gravity.CENTER
        }
        val body = TextView(this).apply {
            text = "$reason\n\nBlocked app: $packageName"
            textSize = 16f
            setTextColor(0xFFDDDDDD.toInt())
            gravity = Gravity.CENTER
            setPadding(0, 24, 0, 32)
        }
        val home = Button(this).apply {
            text = "Go to home screen"
            setOnClickListener {
                val homeIntent = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(homeIntent)
            }
        }
        layout.addView(title)
        layout.addView(body)
        layout.addView(home)
        val params = WindowManager.LayoutParams(
            WindowManager.LayoutParams.MATCH_PARENT,
            WindowManager.LayoutParams.MATCH_PARENT,
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            else
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_SYSTEM_ALERT,
            WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH,
            PixelFormat.TRANSLUCENT
        )
        try {
            wm.addView(layout, params)
            overlayView = layout
            lastBlockedPackage = packageName
            lastReason = reason
        } catch (_: Exception) {
            // Overlay permission revoked mid-run; Dart side re-prompts.
        }
    }

    private fun hideOverlay() {
        val view = overlayView ?: return
        overlayView = null
        lastBlockedPackage = null
        lastReason = null
        try {
            val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            wm.removeView(view)
        } catch (_: Exception) {
        }
    }

    companion object {
        private const val POLL_MS = 5_000L

        fun start(context: Context) {
            val intent = Intent(context, BlockWatcherService::class.java)
            ContextCompat.startForegroundService(context, intent)
        }

        fun stop(context: Context) {
            context.stopService(Intent(context, BlockWatcherService::class.java))
        }
    }
}
