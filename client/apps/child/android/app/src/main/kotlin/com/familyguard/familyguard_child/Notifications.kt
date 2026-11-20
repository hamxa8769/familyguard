package com.familyguard.familyguard_child

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.app.NotificationCompat
import org.json.JSONArray
import org.json.JSONObject

/**
 * Small helpers for the persistent, visible notifications FamilyGuard shows
 * while anything is being monitored or captured. These are part of the
 * transparency promise: the child always sees a "Monitoring: ON" indicator
 * and a notification whenever a screenshot or audio clip is being taken.
 */
object Notifications {
    const val CHANNEL_ID = "familyguard_monitoring"
    const val CHANNEL_NAME = "FamilyGuard monitoring"
    const val WATCHER_NOTIFICATION_ID = 1001
    const val CAPTURE_NOTIFICATION_ID = 1002

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Shows when FamilyGuard monitoring, screenshots or audio recording are active."
            }
        )
    }

    fun watcherNotification(context: Context): Notification {
        ensureChannel(context)
        val openApp = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_lock)
            .setContentTitle("FamilyGuard monitoring is ON")
            .setContentText("Screen-time rules are being enforced on this device.")
            .setContentIntent(openApp)
            .setOngoing(true)
            .build()
    }

    fun captureNotification(context: Context, title: String, text: String): Notification {
        ensureChannel(context)
        return NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_camera)
            .setContentTitle(title)
            .setContentText(text)
            .setOngoing(true)
            .build()
    }
}

/**
 * Reads the enforcement config the Dart side writes with SharedPreferences
 * (the shared_preferences plugin stores it in "FlutterSharedPreferences"
 * with keys prefixed "flutter.").
 *
 * - fg_blocked_apps: JSON array of package names.
 * - fg_bedtime: JSON object {"enabled": bool, "start": "22:00", "end": "07:00"}.
 */
object EnforcementPrefs {
    private const val PREFS = "FlutterSharedPreferences"
    private const val KEY_BLOCKED = "flutter.fg_blocked_apps"
    private const val KEY_BEDTIME = "flutter.fg_bedtime"

    fun blockedApps(context: Context): List<String> {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_BLOCKED, null) ?: return emptyList()
        return try {
            val arr = JSONArray(raw)
            (0 until arr.length()).map { arr.getString(it) }
        } catch (_: Exception) {
            emptyList()
        }
    }

    /** Returns Pair(startMinutes, endMinutes) when bedtime is enabled, else null. */
    fun bedtime(context: Context): Pair<Int, Int>? {
        val raw = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_BEDTIME, null) ?: return null
        return try {
            val obj = JSONObject(raw)
            if (!obj.optBoolean("enabled", false)) return null
            val start = parseHhMm(obj.optString("start", "22:00")) ?: return null
            val end = parseHhMm(obj.optString("end", "07:00")) ?: return null
            Pair(start, end)
        } catch (_: Exception) {
            null
        }
    }

    fun hasAnyRule(context: Context): Boolean =
        blockedApps(context).isNotEmpty() || bedtime(context) != null

    /** True when [nowMinutes] (minutes since midnight) is inside start..end. */
    fun isBedtimeActive(nowMinutes: Int, range: Pair<Int, Int>): Boolean {
        val (start, end) = range
        return if (start <= end) nowMinutes in start until end
        else nowMinutes >= start || nowMinutes < end // overnight, e.g. 22:00–07:00
    }

    private fun parseHhMm(s: String): Int? {
        val parts = s.split(":")
        if (parts.size != 2) return null
        val h = parts[0].toIntOrNull() ?: return null
        val m = parts[1].toIntOrNull() ?: return null
        if (h !in 0..23 || m !in 0..59) return null
        return h * 60 + m
    }
}
