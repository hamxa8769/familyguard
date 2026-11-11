package com.familyguard.fg_native

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat

/**
 * Applies the parent's rules on the phone, visibly.
 *
 * Runs as a foreground service with a permanent "FamilyGuard is active"
 * notification (never hidden). Every ~1.5 s it reads which app is in front
 * (UsageStatsManager events) and, if that app is blocked, it's bedtime, or
 * today's limit is used up, shows [BlockActivity] on top. Calls, the home
 * screen, Settings and FamilyGuard itself are never paused.
 *
 * Needs: Usage access (to see the front app) and "Display over other apps"
 * (Android only lets a background service open a screen with it).
 */
class EnforcementService : Service() {
    private val handler = Handler(Looper.getMainLooper())
    private var rules = Rules()
    private var frontApp: String? = null
    private var lastEventsCheck = 0L
    private var usedMinutes = 0
    private var lastUsageCheck = 0L
    private var lastNotified = ""

    private val tick = object : Runnable {
        override fun run() {
            try {
                check()
            } catch (_: Exception) {
                // Never crash the service; try again next tick.
            }
            handler.postDelayed(this, TICK_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onCreate() {
        super.onCreate()
        createChannel(this)
        val n = notification("Rules from your parent are on")
        if (Build.VERSION.SDK_INT >= 34) {
            startForeground(NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(NOTIF_ID, n)
        }
        running = true
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        rules = Rules.load(this)
        lastUsageCheck = 0
        if (!rules.hasAppRules) {
            stopSelf()
            return START_NOT_STICKY
        }
        handler.removeCallbacks(tick)
        handler.post(tick)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        running = false
        super.onDestroy()
    }

    private fun check() {
        val now = System.currentTimeMillis()
        updateFrontApp(now)
        if (now - lastUsageCheck > USAGE_EVERY_MS) {
            lastUsageCheck = now
            val allowed = AlwaysAllowed.packages(this)
            usedMinutes = Collectors.usageToday(this)
                .filter { (it["appName"] as String) !in allowed }
                .sumOf { (it["durationSeconds"] as Int) } / 60
            updateNotification()
        }

        val app = frontApp ?: return
        if (app in AlwaysAllowed.packages(this)) return
        val reason = when {
            app in rules.blockedApps -> BlockActivity.REASON_APP
            rules.bedtimeNow() -> BlockActivity.REASON_BEDTIME
            rules.limitMinutes?.let { usedMinutes >= it } == true -> BlockActivity.REASON_LIMIT
            else -> return
        }
        if (BlockActivity.showing) return
        if (!Settings.canDrawOverlays(this)) return // can't open a screen from the background
        startActivity(
            Intent(this, BlockActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                .putExtra(BlockActivity.EXTRA_REASON, reason)
                .putExtra(BlockActivity.EXTRA_APP, app)
        )
    }

    /** Latest app that came to the foreground, from usage events. */
    private fun updateFrontApp(now: Long) {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val from = if (lastEventsCheck == 0L) now - 60_000 else lastEventsCheck - 2_000
        lastEventsCheck = now
        val events = usm.queryEvents(from, now)
        val e = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(e)
            @Suppress("DEPRECATION")
            val resumed = e.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND ||
                (Build.VERSION.SDK_INT >= 29 && e.eventType == UsageEvents.Event.ACTIVITY_RESUMED)
            if (resumed) frontApp = e.packageName
        }
    }

    private fun updateNotification() {
        val text = when {
            rules.bedtimeNow() -> "Bedtime — apps are paused"
            rules.limitMinutes != null -> {
                val left = (rules.limitMinutes!! - usedMinutes).coerceAtLeast(0)
                if (left == 0) "Today's screen time is used up" else "$left min of screen time left today"
            }
            else -> "Rules from your parent are on"
        }
        if (text == lastNotified) return
        lastNotified = text
        val nm = getSystemService(NotificationManager::class.java)
        nm.notify(NOTIF_ID, notification(text))
    }

    private fun notification(text: String): Notification {
        val open = packageManager.getLaunchIntentForPackage(packageName)?.let {
            PendingIntent.getActivity(this, 0, it, PendingIntent.FLAG_IMMUTABLE)
        }
        return NotificationCompat.Builder(this, CHANNEL)
            .setSmallIcon(applicationInfo.icon)
            .setContentTitle("FamilyGuard is active")
            .setContentText(text)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setContentIntent(open)
            .build()
    }

    companion object {
        private const val CHANNEL = "fg_enforcement"
        private const val NOTIF_ID = 4201
        private const val TICK_MS = 1500L
        private const val USAGE_EVERY_MS = 30_000L

        @Volatile
        var running = false
            private set

        private fun createChannel(ctx: Context) {
            if (Build.VERSION.SDK_INT < 26) return
            val nm = ctx.getSystemService(NotificationManager::class.java)
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "FamilyGuard status", NotificationManager.IMPORTANCE_LOW)
                    .apply { description = "Shows that FamilyGuard rules are active" }
            )
        }

        /** Starts (or refreshes) enforcement when there are rules; stops it when there are none. */
        fun sync(ctx: Context): Boolean {
            val rules = Rules.load(ctx)
            val intent = Intent(ctx, EnforcementService::class.java)
            if (!rules.hasAppRules) {
                ctx.stopService(intent)
                return false
            }
            if (!Collectors.hasUsageAccess(ctx)) return false
            return try {
                ContextCompat.startForegroundService(ctx, intent)
                true
            } catch (_: Exception) {
                // Android may refuse to start a foreground service from the
                // background; the app starts it next time it is opened.
                false
            }
        }
    }
}
