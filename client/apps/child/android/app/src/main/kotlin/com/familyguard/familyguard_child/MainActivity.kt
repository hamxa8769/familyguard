package com.familyguard.familyguard_child

import android.Manifest
import android.app.Activity
import android.app.AppOpsManager
import android.app.admin.DevicePolicyManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.pm.ApplicationInfo
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.media.projection.MediaProjectionManager
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.os.Process
import android.provider.CallLog
import android.provider.MediaStore
import android.provider.ContactsContract
import android.provider.Settings
import android.provider.Telephony
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.Calendar
import org.json.JSONObject

/**
 * Native Android host for the CHILD app.
 *
 * MethodChannels:
 *  - "familyguard/usage": real app-usage via UsageStatsManager.
 *  - "familyguard/comms": contacts + SMS via ContentResolver (runtime permissions).
 *  - "familyguard/location": last-known location.
 *  - "familyguard/files": gallery images.
 *  - "familyguard/apps": installed-apps inventory (PackageManager).
 *  - "familyguard/browsing": browser-app sessions (UsageEvents; URL history
 *    is not accessible to third-party apps — only which browser was open,
 *    when, and for how long).
 *  - "familyguard/lock": device-admin lock-now (user-activated admin only).
 *  - "familyguard/screen": on-request screenshot (MediaProjection, system
 *    approval every time, countdown + notification first).
 *  - "familyguard/audio": SOS / parent-requested short audio, max 30 s.
 *  - "familyguard/enforcement": bedtime / app-blocking watcher service.
 *
 * Everything here is disclosed to the child in the app's transparency screen;
 * the app runs visibly and never hides what it reads.
 */
class MainActivity : FlutterActivity() {
    private val usageChannel = "familyguard/usage"
    private val commsChannel = "familyguard/comms"
    private val locationChannel = "familyguard/location"
    private val filesChannel = "familyguard/files"
    private val appsChannel = "familyguard/apps"
    private val browsingChannel = "familyguard/browsing"
    private val lockChannel = "familyguard/lock"
    private val screenChannel = "familyguard/screen"
    private val audioChannel = "familyguard/audio"
    private val enforcementChannel = "familyguard/enforcement"

    private val countdownHandler = Handler(Looper.getMainLooper())
    private var pendingScreenshotCommandId: String? = null
    private var pendingAudioCommandId: String? = null
    private var countdownRunnable: Runnable? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger

        MethodChannel(messenger, usageChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasUsageAccess" -> result.success(hasUsageAccess())
                "openUsageSettings" -> {
                    startActivity(
                        Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS)
                            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                    result.success(true)
                }
                "getUsage" -> result.success(queryUsage())
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, commsChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(hasCommsPermission())
                "requestPermission" -> {
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(
                            Manifest.permission.READ_CONTACTS,
                            Manifest.permission.READ_SMS,
                            Manifest.permission.READ_CALL_LOG
                        ),
                        REQ_COMMS
                    )
                    // Flutter re-checks hasPermission when the user returns.
                    result.success(true)
                }
                "getContacts" -> result.success(queryContacts())
                "getSms" -> result.success(querySms())
                "getCallLog" -> result.success(queryCallLog())
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, locationChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasPermission" -> result.success(hasLocationPermission())
                "requestPermission" -> {
                    ActivityCompat.requestPermissions(
                        this,
                        arrayOf(
                            Manifest.permission.ACCESS_FINE_LOCATION,
                            Manifest.permission.ACCESS_COARSE_LOCATION
                        ),
                        REQ_LOCATION
                    )
                    result.success(true)
                }
                "getLocation" -> result.success(lastKnownLocation())
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, appsChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "getInstalledApps" -> result.success(queryInstalledApps())
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, browsingChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "getBrowserSessions" -> result.success(queryBrowserSessions())
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, lockChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAdminActive" -> result.success(isAdminActive())
                "requestAdmin" -> {
                    requestDeviceAdmin()
                    result.success(true)
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

        MethodChannel(messenger, screenChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "requestScreenshot" -> {
                    val commandId = call.argument<String>("commandId") ?: ""
                    val countdown = (call.argument<Int>("countdownSeconds") ?: 5)
                        .coerceIn(3, 10)
                    startScreenshotCountdown(commandId, countdown)
                    result.success(true)
                }
                "getCaptureResult" -> result.success(readCaptureResult())
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, audioChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "hasAudioPermission" -> result.success(hasAudioPermission())
                "requestAudioPermission" -> {
                    ActivityCompat.requestPermissions(
                        this, arrayOf(Manifest.permission.RECORD_AUDIO), REQ_AUDIO
                    )
                    result.success(true)
                }
                "startSosAudio" -> {
                    val commandId = call.argument<String>("commandId") ?: ""
                    if (!hasAudioPermission()) {
                        result.error("NO_PERMISSION", "Microphone permission not granted", null)
                    } else {
                        pendingAudioCommandId = commandId
                        CaptureService.startAudio(this, commandId)
                        result.success(true)
                    }
                }
                "stopAudio" -> {
                    CaptureService.stopAudio(this)
                    result.success(true)
                }
                "getCaptureResult" -> result.success(readCaptureResult())
                else -> result.notImplemented()
            }
        }

        MethodChannel(messenger, enforcementChannel).setMethodCallHandler { call, result ->
            when (call.method) {
                "startWatcher" -> {
                    BlockWatcherService.start(this)
                    result.success(true)
                }
                "stopWatcher" -> {
                    BlockWatcherService.stop(this)
                    result.success(true)
                }
                "hasOverlayPermission" -> result.success(Settings.canDrawOverlays(this))
                "openOverlaySettings" -> {
                    startActivity(
                        Intent(
                            Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                            Uri.parse("package:$packageName")
                        ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                    )
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    // The MediaProjection permission result. Android shows its own system
    // dialog; if the child denies it, the capture is recorded as denied
    // and the parent sees the request as rejected — there is no silent path.
    @Deprecated("Use Activity Result APIs; kept for the projection intent.")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_SCREEN_CAPTURE) return
        val commandId = pendingScreenshotCommandId ?: ""
        pendingScreenshotCommandId = null
        if (resultCode == Activity.RESULT_OK && data != null) {
            CaptureService.startScreenshot(this, resultCode, data, commandId)
        } else {
            CaptureService.writeResultFile(
                this, "screenshot", commandId, null, "denied"
            )
        }
    }

    // ---- Installed apps ----

    private fun queryInstalledApps(): List<Map<String, Any>> {
        val pm = packageManager
        return pm.getInstalledApplications(PackageManager.GET_META_DATA)
            .sortedBy { it.loadLabel(pm).toString().lowercase() }
            .map { app ->
                val info = try {
                    pm.getPackageInfo(app.packageName, 0)
                } catch (_: PackageManager.NameNotFoundException) {
                    null
                }
                mapOf(
                    "packageName" to app.packageName,
                    "label" to app.loadLabel(pm).toString(),
                    "versionName" to (info?.versionName ?: ""),
                    "installedAt" to (info?.firstInstallTime ?: 0L),
                    "systemApp" to ((app.flags and ApplicationInfo.FLAG_SYSTEM) != 0)
                )
            }
    }

    // ---- Browsing sessions ----
    //
    // URL-level history is not available to third-party apps on Android
    // (Chrome does not expose it; a VPN/proxy would be needed and is out of
    // scope). What we can honestly report: which browser app was in the
    // foreground, when, and for how long — built from UsageEvents.

    private fun browserPackages(): Set<String> {
        val intent = Intent(Intent.ACTION_VIEW, Uri.parse("https://example.com"))
        return packageManager.queryIntentActivities(intent, 0)
            .map { it.activityInfo.packageName }
            .toSet()
    }

    private fun queryBrowserSessions(): List<Map<String, Any>> {
        if (!hasUsageAccess()) return emptyList()
        val browsers = browserPackages()
        if (browsers.isEmpty()) return emptyList()
        val pm = packageManager
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val start = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        val events = usm.queryEvents(start, end) ?: return emptyList()
        val sessions = ArrayList<Map<String, Any>>()
        var openPackage: String? = null
        var openSince = 0L
        fun closeSession(at: Long) {
            val pkg = openPackage ?: return
            val duration = ((at - openSince) / 1000).toInt()
            if (duration >= 5) {
                val label = try {
                    pm.getApplicationInfo(pkg, 0).loadLabel(pm).toString()
                } catch (_: Exception) {
                    pkg
                }
                sessions.add(
                    mapOf(
                        "packageName" to pkg,
                        "browserLabel" to label,
                        "startedAt" to openSince,
                        "endedAt" to at,
                        "durationSeconds" to duration
                    )
                )
            }
            openPackage = null
        }
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName
            when (event.eventType) {
                UsageEvents.Event.MOVE_TO_FOREGROUND -> {
                    if (pkg in browsers) {
                        if (openPackage != null && openPackage != pkg) closeSession(event.timeStamp)
                        if (openPackage == null) {
                            openPackage = pkg
                            openSince = event.timeStamp
                        }
                    } else if (openPackage != null) {
                        closeSession(event.timeStamp)
                    }
                }
                UsageEvents.Event.MOVE_TO_BACKGROUND -> {
                    if (openPackage == pkg) closeSession(event.timeStamp)
                }
            }
        }
        if (openPackage != null) closeSession(end)
        return sessions.sortedByDescending { it["startedAt"] as Long }
    }

    // ---- Device admin lock ----

    private fun devicePolicyManager(): DevicePolicyManager =
        getSystemService(Context.DEVICE_POLICY_SERVICE) as DevicePolicyManager

    private fun adminComponent(): ComponentName =
        ComponentName(this, GuardDeviceAdminReceiver::class.java)

    private fun isAdminActive(): Boolean =
        devicePolicyManager().isAdminActive(adminComponent())

    private fun requestDeviceAdmin() {
        val intent = Intent(DevicePolicyManager.ACTION_ADD_DEVICE_ADMIN).apply {
            putExtra(DevicePolicyManager.EXTRA_DEVICE_ADMIN, adminComponent())
            putExtra(
                DevicePolicyManager.EXTRA_ADD_EXPLANATION,
                "FamilyGuard can lock this device when your parent sends a " +
                    "\"Lock now\" command. It cannot wipe the device, change " +
                    "passwords, or disable the camera or microphone."
            )
        }
        startActivity(intent)
    }

    // ---- Screenshot countdown ----

    private fun startScreenshotCountdown(commandId: String, seconds: Int) {
        countdownRunnable?.let { countdownHandler.removeCallbacks(it) }
        pendingScreenshotCommandId = commandId
        Notifications.ensureChannel(this)
        var remaining = seconds
        val runnable = object : Runnable {
            override fun run() {
                if (remaining > 0) {
                    val nm = NotificationManagerCompat.from(this@MainActivity)
                    try {
                        nm.notify(
                            Notifications.CAPTURE_NOTIFICATION_ID,
                            Notifications.captureNotification(
                                this@MainActivity,
                                "Screenshot in $remaining seconds",
                                "Your parent requested a screenshot. It will be taken after the countdown."
                            )
                        )
                    } catch (_: SecurityException) {
                        // Notifications permission not granted; the system
                        // screen-capture dialog still asks the child.
                    }
                    remaining--
                    countdownHandler.postDelayed(this, 1000)
                } else {
                    val pm = getSystemService(Context.MEDIA_PROJECTION_SERVICE)
                        as MediaProjectionManager
                    startActivityForResult(
                        pm.createScreenCaptureIntent(), REQ_SCREEN_CAPTURE
                    )
                }
            }
        }
        countdownRunnable = runnable
        countdownHandler.post(runnable)
    }

    // ---- Audio permission + capture result ----

    private fun hasAudioPermission(): Boolean =
        ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
            PackageManager.PERMISSION_GRANTED

    private fun readCaptureResult(): Map<String, Any?>? {
        val file = File(cacheDir, CaptureService.RESULT_FILE)
        if (!file.exists()) return null
        return try {
            val obj = JSONObject(file.readText())
            file.delete()
            mapOf(
                "type" to obj.optString("type"),
                "commandId" to obj.optString("commandId"),
                "path" to if (obj.isNull("path")) null else obj.optString("path"),
                "error" to if (obj.isNull("error")) null else obj.optString("error"),
                "at" to obj.optLong("at")
            )
        } catch (_: Exception) {
            file.delete()
            null
        }
    }

    // ---- Usage ----

    private fun hasUsageAccess(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun queryUsage(): List<Map<String, Any>> {
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val start = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, end)
            ?: return emptyList()
        return stats
            .filter { it.totalTimeInForeground > 0 }
            .sortedByDescending { it.totalTimeInForeground }
            .map {
                mapOf(
                    "appName" to it.packageName,
                    "durationSeconds" to (it.totalTimeInForeground / 1000).toInt()
                )
            }
    }

    // ---- Contacts + SMS ----

    private fun hasCommsPermission(): Boolean {
        val contacts = ContextCompat.checkSelfPermission(
            this, Manifest.permission.READ_CONTACTS
        ) == PackageManager.PERMISSION_GRANTED
        val sms = ContextCompat.checkSelfPermission(
            this, Manifest.permission.READ_SMS
        ) == PackageManager.PERMISSION_GRANTED
        val calls = ContextCompat.checkSelfPermission(
            this, Manifest.permission.READ_CALL_LOG
        ) == PackageManager.PERMISSION_GRANTED
        return contacts && sms && calls
    }

    private fun queryContacts(): List<Map<String, Any>> {
        if (!hasCommsPermission()) return emptyList()
        val out = ArrayList<Map<String, Any>>()
        val cursor = contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            arrayOf(
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                ContactsContract.CommonDataKinds.Phone.NUMBER
            ),
            null, null,
            "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC"
        )
        cursor?.use { c ->
            val nameIdx = c.getColumnIndex(ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME)
            val numIdx = c.getColumnIndex(ContactsContract.CommonDataKinds.Phone.NUMBER)
            while (c.moveToNext()) {
                out.add(
                    mapOf(
                        "name" to (c.getString(nameIdx) ?: ""),
                        "number" to (c.getString(numIdx) ?: "")
                    )
                )
            }
        }
        return out
    }

    private fun querySms(): List<Map<String, Any>> {
        if (!hasCommsPermission()) return emptyList()
        val out = ArrayList<Map<String, Any>>()
        val cursor = contentResolver.query(
            Telephony.Sms.CONTENT_URI,
            arrayOf(
                Telephony.Sms.ADDRESS,
                Telephony.Sms.BODY,
                Telephony.Sms.DATE,
                Telephony.Sms.TYPE
            ),
            null, null,
            "${Telephony.Sms.DATE} DESC LIMIT 200"
        )
        cursor?.use { c ->
            val addrIdx = c.getColumnIndex(Telephony.Sms.ADDRESS)
            val bodyIdx = c.getColumnIndex(Telephony.Sms.BODY)
            val dateIdx = c.getColumnIndex(Telephony.Sms.DATE)
            val typeIdx = c.getColumnIndex(Telephony.Sms.TYPE)
            while (c.moveToNext()) {
                out.add(
                    mapOf(
                        "address" to (c.getString(addrIdx) ?: ""),
                        "body" to (c.getString(bodyIdx) ?: ""),
                        "date" to c.getLong(dateIdx),
                        "type" to c.getInt(typeIdx)
                    )
                )
            }
        }
        return out
    }

    private fun queryCallLog(): List<Map<String, Any>> {
        if (!hasCommsPermission()) return emptyList()
        val out = ArrayList<Map<String, Any>>()
        val cursor = contentResolver.query(
            CallLog.Calls.CONTENT_URI,
            arrayOf(
                CallLog.Calls.NUMBER,
                CallLog.Calls.TYPE,
                CallLog.Calls.DATE,
                CallLog.Calls.DURATION
            ),
            null, null,
            "${CallLog.Calls.DATE} DESC LIMIT 200"
        )
        cursor?.use { c ->
            val numIdx = c.getColumnIndex(CallLog.Calls.NUMBER)
            val typeIdx = c.getColumnIndex(CallLog.Calls.TYPE)
            val dateIdx = c.getColumnIndex(CallLog.Calls.DATE)
            val durIdx = c.getColumnIndex(CallLog.Calls.DURATION)
            while (c.moveToNext()) {
                out.add(
                    mapOf(
                        "number" to (c.getString(numIdx) ?: ""),
                        "type" to c.getInt(typeIdx),
                        "date" to c.getLong(dateIdx),
                        "duration" to c.getInt(durIdx)
                    )
                )
            }
        }
        return out
    }

    // ---- Location ----

    private fun hasLocationPermission(): Boolean {
        return ContextCompat.checkSelfPermission(
            this, Manifest.permission.ACCESS_FINE_LOCATION
        ) == PackageManager.PERMISSION_GRANTED ||
            ContextCompat.checkSelfPermission(
                this, Manifest.permission.ACCESS_COARSE_LOCATION
            ) == PackageManager.PERMISSION_GRANTED
    }

    private fun lastKnownLocation(): Map<String, Any>? {
        if (!hasLocationPermission()) return null
        val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
        var best: Location? = null
        val providers = listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)
        for (p in providers) {
            try {
                if (!lm.isProviderEnabled(p)) continue
                val loc = lm.getLastKnownLocation(p) ?: continue
                if (best == null || loc.time > best.time) best = loc
            } catch (_: SecurityException) {
                return null
            }
        }
        val b = best ?: return null
        return mapOf("lat" to b.latitude, "lng" to b.longitude, "time" to b.time)
    }

    // ---- Gallery (images) ----

    private fun hasGalleryPermission(): Boolean {
        val perm = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            Manifest.permission.READ_MEDIA_IMAGES
        } else {
            Manifest.permission.READ_EXTERNAL_STORAGE
        }
        return ContextCompat.checkSelfPermission(this, perm) == PackageManager.PERMISSION_GRANTED
    }

    private fun queryImages(): List<Map<String, Any>> {
        if (!hasGalleryPermission()) return emptyList()
        val out = ArrayList<Map<String, Any>>()
        val proj = arrayOf(
            MediaStore.Images.Media.DISPLAY_NAME,
            MediaStore.Images.Media.SIZE,
            MediaStore.Images.Media.DATE_MODIFIED,
            MediaStore.Images.Media.DATA
        )
        val cursor = contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            proj, null, null,
            "${MediaStore.Images.Media.DATE_MODIFIED} DESC LIMIT 200"
        )
        cursor?.use { c ->
            val nameIdx = c.getColumnIndex(MediaStore.Images.Media.DISPLAY_NAME)
            val sizeIdx = c.getColumnIndex(MediaStore.Images.Media.SIZE)
            val dateIdx = c.getColumnIndex(MediaStore.Images.Media.DATE_MODIFIED)
            val dataIdx = c.getColumnIndex(MediaStore.Images.Media.DATA)
            while (c.moveToNext()) {
                out.add(
                    mapOf(
                        "name" to (c.getString(nameIdx) ?: ""),
                        "path" to (c.getString(dataIdx) ?: ""),
                        "size" to c.getLong(sizeIdx),
                        // DATE_MODIFIED is seconds since epoch -> milliseconds.
                        "date" to c.getLong(dateIdx) * 1000,
                        "isImage" to true
                    )
                )
            }
        }
        return out
    }

    companion object {
        private const val REQ_COMMS = 1001
        private const val REQ_LOCATION = 1002
        private const val REQ_GALLERY = 1003
        private const val REQ_AUDIO = 1004
        private const val REQ_SCREEN_CAPTURE = 1005
    }
}
