package com.familyguard.familyguard_child

import android.Manifest
import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Process
import android.provider.CallLog
import android.provider.ContactsContract
import android.provider.Settings
import android.provider.Telephony
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.Calendar

/**
 * Native Android host for the CHILD app.
 *
 * Two MethodChannels:
 *  - "familyguard/usage": real app-usage via UsageStatsManager.
 *  - "familyguard/comms": contacts + SMS via ContentResolver (runtime permissions).
 *
 * Everything here is disclosed to the child in the app's transparency screen;
 * the app runs visibly and never hides what it reads.
 */
class MainActivity : FlutterActivity() {
    private val usageChannel = "familyguard/usage"
    private val commsChannel = "familyguard/comms"

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

    companion object {
        private const val REQ_COMMS = 1001
    }
}
