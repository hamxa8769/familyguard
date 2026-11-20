package com.familyguard.fg_native

import android.Manifest
import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.PackageManager
import android.location.Location
import android.location.LocationManager
import android.os.Build
import android.os.Process
import android.provider.CallLog
import android.provider.ContactsContract
import android.provider.MediaStore
import android.provider.Telephony
import androidx.core.content.ContextCompat
import java.util.Calendar

/**
 * Read-only collectors. They need only a Context (no Activity), so they work
 * both in the app and in background sync. Each one checks its own permission
 * and returns nothing when it isn't granted.
 *
 * Everything here is disclosed to the child in the app's consent and
 * "What my parent sees" screens.
 */
object Collectors {
    private const val MAX_ROWS = 200

    private fun granted(ctx: Context, perm: String) =
        ContextCompat.checkSelfPermission(ctx, perm) == PackageManager.PERMISSION_GRANTED

    // ---- Usage ----

    fun hasUsageAccess(ctx: Context): Boolean {
        val appOps = ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            appOps.unsafeCheckOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName
            )
        } else {
            @Suppress("DEPRECATION")
            appOps.checkOpNoThrow(
                AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName
            )
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    /** Foreground time per app since local midnight. */
    fun usageToday(ctx: Context): List<Map<String, Any>> {
        if (!hasUsageAccess(ctx)) return emptyList()
        val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val start = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, end)
            ?: return emptyList()
        // INTERVAL_DAILY can return several buckets per app; sum them.
        val byApp = HashMap<String, Long>()
        for (s in stats) {
            if (s.totalTimeInForeground <= 0) continue
            byApp[s.packageName] = (byApp[s.packageName] ?: 0L) + s.totalTimeInForeground
        }
        return byApp.entries
            .sortedByDescending { it.value }
            .map { mapOf("appName" to it.key, "durationSeconds" to (it.value / 1000).toInt()) }
    }

    // ---- Contacts, SMS, call log ----

    fun hasCommsPermission(ctx: Context) =
        granted(ctx, Manifest.permission.READ_CONTACTS) &&
            granted(ctx, Manifest.permission.READ_SMS) &&
            granted(ctx, Manifest.permission.READ_CALL_LOG)

    fun contacts(ctx: Context): List<Map<String, Any>> {
        if (!granted(ctx, Manifest.permission.READ_CONTACTS)) return emptyList()
        val out = ArrayList<Map<String, Any>>()
        ctx.contentResolver.query(
            ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
            arrayOf(
                ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME,
                ContactsContract.CommonDataKinds.Phone.NUMBER
            ),
            null, null,
            "${ContactsContract.CommonDataKinds.Phone.DISPLAY_NAME} ASC"
        )?.use { c ->
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

    fun sms(ctx: Context): List<Map<String, Any>> {
        if (!granted(ctx, Manifest.permission.READ_SMS)) return emptyList()
        val out = ArrayList<Map<String, Any>>()
        ctx.contentResolver.query(
            Telephony.Sms.CONTENT_URI,
            arrayOf(Telephony.Sms.ADDRESS, Telephony.Sms.BODY, Telephony.Sms.DATE, Telephony.Sms.TYPE),
            null, null,
            "${Telephony.Sms.DATE} DESC"
        )?.use { c ->
            val addrIdx = c.getColumnIndex(Telephony.Sms.ADDRESS)
            val bodyIdx = c.getColumnIndex(Telephony.Sms.BODY)
            val dateIdx = c.getColumnIndex(Telephony.Sms.DATE)
            val typeIdx = c.getColumnIndex(Telephony.Sms.TYPE)
            while (c.moveToNext() && out.size < MAX_ROWS) {
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

    fun callLog(ctx: Context): List<Map<String, Any>> {
        if (!granted(ctx, Manifest.permission.READ_CALL_LOG)) return emptyList()
        val out = ArrayList<Map<String, Any>>()
        ctx.contentResolver.query(
            CallLog.Calls.CONTENT_URI,
            arrayOf(CallLog.Calls.NUMBER, CallLog.Calls.TYPE, CallLog.Calls.DATE, CallLog.Calls.DURATION),
            null, null,
            "${CallLog.Calls.DATE} DESC"
        )?.use { c ->
            val numIdx = c.getColumnIndex(CallLog.Calls.NUMBER)
            val typeIdx = c.getColumnIndex(CallLog.Calls.TYPE)
            val dateIdx = c.getColumnIndex(CallLog.Calls.DATE)
            val durIdx = c.getColumnIndex(CallLog.Calls.DURATION)
            while (c.moveToNext() && out.size < MAX_ROWS) {
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

    fun hasLocationPermission(ctx: Context) =
        granted(ctx, Manifest.permission.ACCESS_FINE_LOCATION) ||
            granted(ctx, Manifest.permission.ACCESS_COARSE_LOCATION)

    /** Most recent last-known fix from GPS or network (no active request). */
    fun lastKnownLocation(ctx: Context): Map<String, Any>? {
        if (!hasLocationPermission(ctx)) return null
        val lm = ctx.getSystemService(Context.LOCATION_SERVICE) as LocationManager
        var best: Location? = null
        for (p in listOf(LocationManager.GPS_PROVIDER, LocationManager.NETWORK_PROVIDER)) {
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

    // ---- Photos ----

    fun galleryPermission(): String =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) Manifest.permission.READ_MEDIA_IMAGES
        else Manifest.permission.READ_EXTERNAL_STORAGE

    fun hasGalleryPermission(ctx: Context) = granted(ctx, galleryPermission())

    /** Recent photos with album (folder) name and a stable key ("m:<media id>"). */
    fun images(ctx: Context): List<Map<String, Any>> {
        if (!hasGalleryPermission(ctx)) return emptyList()
        val out = ArrayList<Map<String, Any>>()
        // No "LIMIT" in sortOrder: MediaStore rejects it on Android 11+.
        ctx.contentResolver.query(
            MediaStore.Images.Media.EXTERNAL_CONTENT_URI,
            arrayOf(
                MediaStore.Images.Media._ID,
                MediaStore.Images.Media.DISPLAY_NAME,
                MediaStore.Images.Media.SIZE,
                MediaStore.Images.Media.DATE_MODIFIED,
                MediaStore.Images.Media.BUCKET_DISPLAY_NAME,
                // Local path: only for thumbnails on the child's own screen;
                // the sync strips it before upload.
                @Suppress("DEPRECATION") MediaStore.Images.Media.DATA
            ),
            null, null,
            "${MediaStore.Images.Media.DATE_MODIFIED} DESC"
        )?.use { c ->
            val idIdx = c.getColumnIndex(MediaStore.Images.Media._ID)
            val nameIdx = c.getColumnIndex(MediaStore.Images.Media.DISPLAY_NAME)
            val sizeIdx = c.getColumnIndex(MediaStore.Images.Media.SIZE)
            val dateIdx = c.getColumnIndex(MediaStore.Images.Media.DATE_MODIFIED)
            val albumIdx = c.getColumnIndex(MediaStore.Images.Media.BUCKET_DISPLAY_NAME)
            @Suppress("DEPRECATION")
            val dataIdx = c.getColumnIndex(MediaStore.Images.Media.DATA)
            while (c.moveToNext() && out.size < MAX_ROWS) {
                out.add(
                    mapOf(
                        "key" to "m:${c.getLong(idIdx)}",
                        "album" to (if (albumIdx >= 0) c.getString(albumIdx) ?: "" else ""),
                        "name" to (c.getString(nameIdx) ?: ""),
                        "path" to (if (dataIdx >= 0) c.getString(dataIdx) ?: "" else ""),
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

    /**
     * Small JPEG preview (longest side ~[size] px) of the photo with [key]
     * ("m:<media id>"), or null. Uses the system thumbnail cache, so the
     * full photo is never read or uploaded.
     */
    fun thumbnail(ctx: Context, key: String, size: Int = 256): ByteArray? {
        if (!hasGalleryPermission(ctx) || !key.startsWith("m:")) return null
        val id = key.removePrefix("m:").toLongOrNull() ?: return null
        val bitmap = try {
            if (Build.VERSION.SDK_INT >= 29) {
                val uri = android.content.ContentUris.withAppendedId(
                    MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id
                )
                ctx.contentResolver.loadThumbnail(uri, android.util.Size(size, size), null)
            } else {
                @Suppress("DEPRECATION")
                MediaStore.Images.Thumbnails.getThumbnail(
                    ctx.contentResolver, id, MediaStore.Images.Thumbnails.MINI_KIND, null
                )
            }
        } catch (_: Exception) {
            null
        } ?: return null
        return try {
            val scaled = scaleDown(bitmap, size)
            val out = java.io.ByteArrayOutputStream()
            scaled.compress(android.graphics.Bitmap.CompressFormat.JPEG, 70, out)
            if (scaled !== bitmap) scaled.recycle()
            bitmap.recycle()
            out.toByteArray()
        } catch (_: Exception) {
            null
        }
    }

    private fun scaleDown(b: android.graphics.Bitmap, max: Int): android.graphics.Bitmap {
        val longest = maxOf(b.width, b.height)
        if (longest <= max) return b
        val f = max.toFloat() / longest
        return android.graphics.Bitmap.createScaledBitmap(
            b, (b.width * f).toInt().coerceAtLeast(1), (b.height * f).toInt().coerceAtLeast(1), true
        )
    }
}
