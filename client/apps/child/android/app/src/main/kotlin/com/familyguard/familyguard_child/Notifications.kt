package com.familyguard.familyguard_child

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.core.app.NotificationCompat

/**
 * Small helpers for the visible notifications FamilyGuard shows while a
 * screenshot or audio clip is being captured. These are part of the
 * transparency promise: the child always sees a notification whenever a
 * screenshot or audio clip is being taken.
 *
 * The channel id is `familyguard_monitoring_v2` (not the v0.9.0
 * `familyguard_monitoring`): Android ignores importance changes to an
 * existing channel, so the old one is deleted here and recreated at
 * IMPORTANCE_LOW — otherwise phones that already installed v0.9.0 would
 * keep the old IMPORTANCE_DEFAULT channel forever.
 */
object Notifications {
    const val CHANNEL_ID = "familyguard_monitoring_v2"
    private const val LEGACY_CHANNEL_ID = "familyguard_monitoring"
    const val CHANNEL_NAME = "FamilyGuard monitoring"
    const val CAPTURE_NOTIFICATION_ID = 1002

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        // Drop the v0.9.0 channel (IMPORTANCE_DEFAULT) so it cannot linger.
        nm.deleteNotificationChannel(LEGACY_CHANNEL_ID)
        if (nm.getNotificationChannel(CHANNEL_ID) != null) return
        nm.createNotificationChannel(
            NotificationChannel(
                CHANNEL_ID, CHANNEL_NAME, NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Shows when FamilyGuard takes a screenshot or records audio."
            }
        )
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
