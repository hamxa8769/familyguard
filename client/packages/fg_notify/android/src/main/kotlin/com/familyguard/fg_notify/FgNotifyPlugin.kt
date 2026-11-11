package com.familyguard.fg_notify

import android.Manifest
import android.app.Activity
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodChannel

/**
 * Minimal system notifications for the parent app ("familyguard/notify").
 * Works in the app and in the background-check engine. Two channels:
 * "sos" (high importance, heads-up) and "alerts" (normal).
 */
class FgNotifyPlugin : FlutterPlugin, ActivityAware {
    private lateinit var context: Context
    private var activity: Activity? = null
    private var channel: MethodChannel? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        createChannels()
        channel = MethodChannel(binding.binaryMessenger, "familyguard/notify").also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "isAllowed" -> result.success(isAllowed())
                    "requestPermission" -> {
                        val a = activity
                        if (Build.VERSION.SDK_INT >= 33 && a != null && !isAllowed()) {
                            ActivityCompat.requestPermissions(
                                a, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 2001
                            )
                        }
                        result.success(isAllowed())
                    }
                    "show" -> {
                        show(
                            call.argument<Int>("id") ?: 0,
                            call.argument<String>("title") ?: "",
                            call.argument<String>("body") ?: "",
                            call.argument<Boolean>("urgent") ?: false,
                        )
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    private fun isAllowed(): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) !=
            PackageManager.PERMISSION_GRANTED
        ) return false
        return NotificationManagerCompat.from(context).areNotificationsEnabled()
    }

    private fun createChannels() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = context.getSystemService(NotificationManager::class.java)
        nm.createNotificationChannel(
            NotificationChannel(SOS, "SOS alerts", NotificationManager.IMPORTANCE_HIGH).apply {
                description = "Emergency alerts from your children"
                enableVibration(true)
            }
        )
        nm.createNotificationChannel(
            NotificationChannel(ALERTS, "Family alerts", NotificationManager.IMPORTANCE_DEFAULT).apply {
                description = "Requests and safe-zone arrivals"
            }
        )
    }

    private fun show(id: Int, title: String, body: String, urgent: Boolean) {
        if (!isAllowed()) return
        val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            ?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        val tap = launch?.let {
            PendingIntent.getActivity(
                context, id, it,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
        }
        val n = NotificationCompat.Builder(context, if (urgent) SOS else ALERTS)
            .setSmallIcon(context.applicationInfo.icon)
            .setContentTitle(title)
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(if (urgent) NotificationCompat.PRIORITY_HIGH else NotificationCompat.PRIORITY_DEFAULT)
            .setCategory(if (urgent) NotificationCompat.CATEGORY_ALARM else NotificationCompat.CATEGORY_STATUS)
            .setAutoCancel(true)
            .setContentIntent(tap)
            .build()
        try {
            NotificationManagerCompat.from(context).notify(id, n)
        } catch (_: SecurityException) {
            // Permission revoked between the check and the call.
        }
    }

    companion object {
        private const val SOS = "sos"
        private const val ALERTS = "alerts"
    }
}
