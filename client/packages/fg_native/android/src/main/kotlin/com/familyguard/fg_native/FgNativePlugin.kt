package com.familyguard.fg_native

import android.Manifest
import android.app.Activity
import android.app.admin.DevicePolicyManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import android.os.PowerManager
import android.net.Uri
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
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
        channel(m, "familyguard/enforce") { call, result -> onEnforce(call, result) }
        channel(m, "familyguard/permissions") { call, result -> onPermissions(call, result) }
        // Device-admin lock, registered here (not only in MainActivity) so
        // it also works in the background WorkManager isolate, where there
        // is no Activity: lockNow/isAdminActive need only a Context.
        // MainActivity registers the same channel in the foreground engine
        // (it configures its channels after the plugins), with identical
        // behaviour — the two handlers never disagree.
        channel(m, "familyguard/lock") { call, result -> onLock(call, result) }
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
            // Per-type grants, so each of contacts / SMS / calls syncs when
            // its own permission is granted (no all-or-nothing gate).
            "hasPermissions" -> result.success(
                mapOf(
                    "contacts" to Collectors.hasContactsPermission(context),
                    "sms" to Collectors.hasSmsPermission(context),
                    "callLog" to Collectors.hasCallLogPermission(context),
                )
            )
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
            "requestPermission" -> ask(result, Collectors.galleryPermissions().toTypedArray(), REQ_GALLERY)
            "getImages" -> async(result) { Collectors.images(context) }
            "getVideos" -> async(result) { Collectors.videos(context) }
            "getOriginal" -> {
                val key = call.argument<String>("key") ?: ""
                async(result) { Collectors.originalBytes(context, key) }
            }
            "getThumbnail" -> {
                val key = call.argument<String>("key") ?: ""
                val size = call.argument<Int>("size") ?: 1024
                async(result) { Collectors.thumbnail(context, key, size) }
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Permanently-denied detection + app-Settings fallback for the
     * permissions screen. Android cannot tell "never asked" apart from
     * "don't ask again" on its own, so Dart only consults
     * [isPermanentlyDenied] for items it has already requested at least
     * once (tracked in SharedPreferences on the Dart side).
     */
    private fun onPermissions(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isPermanentlyDenied" -> {
                val perms = call.argument<List<String>>("permissions") ?: emptyList()
                val requireAll = call.argument<Boolean>("requireAll") ?: false
                result.success(isPermanentlyDenied(perms, requireAll))
            }
            "openAppSettings" -> {
                val i = Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.parse("package:${context.packageName}"),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                (activity ?: context).startActivity(i)
                result.success(true)
            }
            // Battery-optimisation exemption (Doze / App Standby): without
            // it Android may defer the background sync and enforcement
            // restarts for hours. The user approves on a system screen;
            // nothing is granted silently.
            "isIgnoringBatteryOptimizations" -> {
                val pm = context.getSystemService(Context.POWER_SERVICE) as PowerManager
                result.success(pm.isIgnoringBatteryOptimizations(context.packageName))
            }
            "requestBatteryOptimisationExemption" -> {
                val i = Intent(
                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                    Uri.parse("package:${context.packageName}"),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                (activity ?: context).startActivity(i)
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Device-admin lock ("Lock now"), usable with only a Context — so the
     * background WorkManager isolate can execute a `lock_now` command
     * without the app being open. Only force-lock is possible (the admin
     * receiver declares no other policy); activation itself is a visible
     * system screen, never silent.
     */
    private fun onLock(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "isAdminActive" -> result.success(isAdminActive())
            "requestAdmin" -> {
                val a = activity
                if (a == null) {
                    // No Activity in the background: cannot show the system
                    // admin screen. The foreground UI asks from there.
                    result.success(false)
                } else {
                    val i = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
                        putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent())
                        putExtra(
                            DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                            "FamilyGuard can lock this device when your parent sends a " +
                                "\"Lock now\" command. It cannot wipe the device, change " +
                                "passwords, or disable the camera or microphone."
                        )
                    }
                    a.startActivity(i)
                    result.success(true)
                }
            }
            "lockNow" -> {
                if (!isAdminActive()) {
                    result.error("NOT_ADMIN", "Device admin is not activated", null)
                } else {
                    devicePolicyManager().lockNow()
                    result.success(true)
                }
            }
            else -> result.notImplemented()
        }
    }

    private fun devicePolicyManager(): DevicePolicyManager =
        context.getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager

    /**
     * The admin receiver lives in the child app (fg_native cannot reference
     * the app module's class), so it is addressed by its manifest-declared
     * name — the same component MainActivity uses via
     * `GuardDeviceAdminReceiver::class.java`.
     */
    private fun adminComponent(): ComponentName = ComponentName(
        context.packageName,
        "com.familyguard.familyguard_child.GuardDeviceAdminReceiver",
    )

    private fun isAdminActive(): Boolean =
        devicePolicyManager().isAdminActive(adminComponent())

    /**
     * True when the system will no longer show the runtime dialog for the
     * given permission(s): denied AND
     * `shouldShowRequestPermissionRationale` is false. With [requireAll]
     * every listed permission must be in that state (location: either
     * permission grants the item); otherwise any one is enough (comms:
     * all three are required, so one stuck permission blocks the item).
     * The `"gallery"` alias resolves to the OS-version gallery permission.
     * POST_NOTIFICATIONS does not exist below API 33 and is never
     * permanently denied there.
     */
    private fun isPermanentlyDenied(perms: List<String>, requireAll: Boolean): Boolean {
        val a = activity ?: return false
        if (perms.isEmpty()) return false
        val states = perms.map { perm ->
            val resolved = if (perm == "gallery") Collectors.galleryPermission() else perm
            if (resolved == Manifest.permission.POST_NOTIFICATIONS &&
                android.os.Build.VERSION.SDK_INT < 33
            ) {
                return@map false
            }
            val denied = ContextCompat.checkSelfPermission(context, resolved) !=
                PackageManager.PERMISSION_GRANTED
            val noRationale = !ActivityCompat.shouldShowRequestPermissionRationale(a, resolved)
            denied && noRationale
        }
        return if (requireAll) states.all { it } else states.any { it }
    }

    /**
     * Rules from the parent → saved on the phone → applied by
     * [EnforcementService] (apps, bedtime, limit) and [DnsVpnService] (web).
     */
    private fun onEnforce(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "setRules" -> {
                try {
                    Rules.save(context, call.argument<String>("json") ?: "{}")
                    result.success(apply())
                } catch (e: Exception) {
                    result.error("bad_rules", e.message, null)
                }
            }
            "status" -> result.success(status())
            "requestOverlay" -> {
                val i = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:${context.packageName}"),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                (activity ?: context).startActivity(i)
                result.success(true)
            }
            "requestVpn" -> {
                val a = activity
                val prepare = android.net.VpnService.prepare(context)
                if (prepare == null) {
                    result.success(true) // already approved
                } else if (a == null) {
                    result.success(false)
                } else {
                    a.startActivityForResult(prepare, REQ_VPN)
                    result.success(false) // Dart re-checks status on resume
                }
            }
            "requestNotifications" -> {
                val a = activity
                if (android.os.Build.VERSION.SDK_INT >= 33 && a != null) {
                    ActivityCompat.requestPermissions(
                        a, arrayOf(Manifest.permission.POST_NOTIFICATIONS), REQ_NOTIFY
                    )
                }
                result.success(true)
            }
            "apply" -> result.success(apply())
            else -> result.notImplemented()
        }
    }

    private fun apply(): Map<String, Any> {
        EnforcementService.sync(context)
        DnsVpnService.sync(context)
        return status()
    }

    private fun status(): Map<String, Any> {
        val rules = Rules.load(context)
        return mapOf(
            "usageAccess" to Collectors.hasUsageAccess(context),
            "overlay" to Settings.canDrawOverlays(context),
            "notifications" to androidx.core.app.NotificationManagerCompat.from(context).areNotificationsEnabled(),
            "vpnApproved" to DnsVpnService.prepared(context),
            "appRulesActive" to EnforcementService.running,
            "webFilterActive" to DnsVpnService.running,
            "hasAppRules" to rules.hasAppRules,
            "hasWebRules" to rules.blockedDomains.isNotEmpty(),
            // "hostname" here bypasses the DNS-only web filter; the parent
            // is warned about it (see the status blob + alert watcher).
            "privateDnsMode" to (DnsVpnService.privateDnsMode(context) ?: "off"),
            "privateDnsHostname" to (DnsVpnService.privateDnsHostname(context) ?: ""),
        )
    }

    companion object {
        private const val REQ_VPN = 1004
        private const val REQ_NOTIFY = 1005
        private const val REQ_COMMS = 1001
        private const val REQ_LOCATION = 1002
        private const val REQ_GALLERY = 1003
    }
}
