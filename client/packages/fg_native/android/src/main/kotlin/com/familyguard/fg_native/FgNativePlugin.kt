package com.familyguard.fg_native

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import androidx.core.app.ActivityCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

/**
 * Registers the child app's native channels in EVERY Flutter engine — the
 * app's and the background-sync engine's.
 *
 *  - Queries need only a Context, so they work in the background.
 *  - Permission dialogs need an Activity; without one (background) they
 *    report false instead of prompting.
 *  - Queries run off the main thread so large SMS/contact lists never
 *    freeze the UI.
 */
class FgNativePlugin : FlutterPlugin, ActivityAware {
    private lateinit var context: Context
    private var activity: Activity? = null
    private val channels = mutableListOf<MethodChannel>()
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        val m = binding.binaryMessenger
        channel(m, "familyguard/usage") { call, result -> onUsage(call, result) }
        channel(m, "familyguard/comms") { call, result -> onComms(call, result) }
        channel(m, "familyguard/location") { call, result -> onLocation(call, result) }
        channel(m, "familyguard/files") { call, result -> onFiles(call, result) }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channels.forEach { it.setMethodCallHandler(null) }
        channels.clear()
        io.shutdown()
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

    // ---- helpers ----

    private fun channel(
        messenger: io.flutter.plugin.common.BinaryMessenger,
        name: String,
        handler: (MethodCall, MethodChannel.Result) -> Unit,
    ) {
        val ch = MethodChannel(messenger, name)
        ch.setMethodCallHandler { call, result -> handler(call, result) }
        channels.add(ch)
    }

    /** Runs [work] on the IO thread and replies on the main thread. */
    private fun async(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            try {
                val value = work()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("native_error", e.message, null) }
            }
        }
    }

    /** Shows the system permission dialog when an Activity is available. */
    private fun ask(result: MethodChannel.Result, perms: Array<String>, code: Int) {
        val a = activity
        if (a == null) {
            result.success(false)
            return
        }
        ActivityCompat.requestPermissions(a, perms, code)
        // Dart re-checks hasPermission when the user returns.
        result.success(true)
    }

    // ---- channels ----

    private fun onUsage(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasUsageAccess" -> result.success(Collectors.hasUsageAccess(context))
            "openUsageSettings" -> {
                val i = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                (activity ?: context).startActivity(i)
                result.success(true)
            }
            "getUsage" -> async(result) { Collectors.usageToday(context) }
            else -> result.notImplemented()
        }
    }

    private fun onComms(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> result.success(Collectors.hasCommsPermission(context))
            "requestPermission" -> ask(
                result,
                arrayOf(
                    Manifest.permission.READ_CONTACTS,
                    Manifest.permission.READ_SMS,
                    Manifest.permission.READ_CALL_LOG,
                ),
                REQ_COMMS,
            )
            "getContacts" -> async(result) { Collectors.contacts(context) }
            "getSms" -> async(result) { Collectors.sms(context) }
            "getCallLog" -> async(result) { Collectors.callLog(context) }
            else -> result.notImplemented()
        }
    }

    private fun onLocation(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> result.success(Collectors.hasLocationPermission(context))
            "requestPermission" -> ask(
                result,
                arrayOf(
                    Manifest.permission.ACCESS_FINE_LOCATION,
                    Manifest.permission.ACCESS_COARSE_LOCATION,
                ),
                REQ_LOCATION,
            )
            "getLocation" -> async(result) { Collectors.lastKnownLocation(context) }
            else -> result.notImplemented()
        }
    }

    private fun onFiles(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "hasPermission" -> result.success(Collectors.hasGalleryPermission(context))
            "requestPermission" -> ask(result, arrayOf(Collectors.galleryPermission()), REQ_GALLERY)
            "getImages" -> async(result) { Collectors.images(context) }
            else -> result.notImplemented()
        }
    }

    companion object {
        private const val REQ_COMMS = 1001
        private const val REQ_LOCATION = 1002
        private const val REQ_GALLERY = 1003
    }
}
