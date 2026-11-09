package com.familyguard.fg_native

import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.telecom.TelecomManager
import org.json.JSONObject
import java.util.Calendar

/**
 * The parent's rules for this device, cached on the phone so they keep
 * working offline and after a reboot. Written by Dart (setRules) after each
 * sync; read by [EnforcementService] and [DnsVpnService].
 */
data class Rules(
    val blockedApps: Set<String> = emptySet(),
    /** Today's allowance in minutes (daily limit + approved extra), or null. */
    val limitMinutes: Int? = null,
    val bedtimeStart: Int? = null,
    val bedtimeEnd: Int? = null,
    val blockedDomains: List<String> = emptyList(),
) {
    val hasAppRules: Boolean
        get() = blockedApps.isNotEmpty() || limitMinutes != null || bedtimeStart != null

    fun bedtimeNow(hour: Int = Calendar.getInstance().get(Calendar.HOUR_OF_DAY)): Boolean {
        val s = bedtimeStart ?: return false
        val e = bedtimeEnd ?: return false
        if (s == e) return false
        return if (s < e) hour in s until e else hour >= s || hour < e
    }

    fun domainBlocked(name: String): Boolean {
        val d = name.trimEnd('.').lowercase()
        return blockedDomains.any { d == it || d.endsWith(".$it") }
    }

    companion object {
        private const val PREFS = "fg_enforcement"
        private const val KEY = "rules"

        fun parse(json: String): Rules {
            val o = JSONObject(json)
            fun strings(key: String): List<String> {
                val a = o.optJSONArray(key) ?: return emptyList()
                return (0 until a.length()).map { a.optString(it) }.filter { it.isNotBlank() }
            }
            fun intOrNull(key: String): Int? =
                if (o.has(key) && !o.isNull(key)) o.optInt(key) else null
            return Rules(
                blockedApps = strings("blockedApps").toSet(),
                limitMinutes = intOrNull("limitMinutes"),
                bedtimeStart = intOrNull("bedtimeStart"),
                bedtimeEnd = intOrNull("bedtimeEnd"),
                blockedDomains = strings("blockedDomains").map { it.trim().lowercase().trimEnd('.') },
            )
        }

        fun save(ctx: Context, json: String) {
            parse(json) // validate before storing
            ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY, json).apply()
        }

        fun load(ctx: Context): Rules {
            val json = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY, null)
                ?: return Rules()
            return try {
                parse(json)
            } catch (_: Exception) {
                Rules()
            }
        }
    }
}

/**
 * Apps that are never paused: FamilyGuard itself, the home screen, the phone
 * dialer (calls must always work), system UI, Settings and emergency apps.
 */
object AlwaysAllowed {
    private var cache: Set<String>? = null

    fun packages(ctx: Context): Set<String> {
        cache?.let { return it }
        val out = mutableSetOf(
            ctx.packageName,
            "com.android.systemui",
            "com.android.settings",
            "com.android.emergency",
            "com.google.android.dialer",
            "com.android.dialer",
            "com.android.phone",
            "com.android.server.telecom",
        )
        val home = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
        val launchers = if (Build.VERSION.SDK_INT >= 33) {
            ctx.packageManager.queryIntentActivities(home, PackageManager.ResolveInfoFlags.of(0))
        } else {
            @Suppress("DEPRECATION")
            ctx.packageManager.queryIntentActivities(home, 0)
        }
        launchers.forEach { out.add(it.activityInfo.packageName) }
        try {
            val tm = ctx.getSystemService(Context.TELECOM_SERVICE) as TelecomManager
            tm.defaultDialerPackage?.let { out.add(it) }
        } catch (_: Exception) {
        }
        cache = out
        return out
    }
}
