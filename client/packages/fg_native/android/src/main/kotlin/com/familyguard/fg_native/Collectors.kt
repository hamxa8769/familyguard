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
    private const val MAX_ROWS = 1000

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

    // Per-type checks: each of contacts / SMS / calls syncs on its own
    // permission (an all-or-nothing gate lost all three when one was denied).
    fun hasContactsPermission(ctx: Context) =
        granted(ctx, Manifest.permission.READ_CONTACTS)

    fun hasSmsPermission(ctx: Context) =
        granted(ctx, Manifest.permission.READ_SMS)

    fun hasCallLogPermission(ctx: Context) =
        granted(ctx, Manifest.permission.READ_CALL_LOG)

    fun hasAnyCommsPermission(ctx: Context) =
        hasContactsPermission(ctx) || hasSmsPermission(ctx) || hasCallLogPermission(ctx)

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
            arrayOf(Telephony.Sms.ADDRESS, Telephony.Sms.BODY, Telephony.Sms.DATE, Telephony.Sms.TYPE, Telephony.Sms.THREAD_ID),
            null, null,
            "${Telephony.Sms.DATE} DESC"
        )?.use { c ->
            val addrIdx = c.getColumnIndex(Telephony.Sms.ADDRESS)
            val bodyIdx = c.getColumnIndex(Telephony.Sms.BODY)
            val dateIdx = c.getColumnIndex(Telephony.Sms.DATE)
            val typeIdx = c.getColumnIndex(Telephony.Sms.TYPE)
            val threadIdx = c.getColumnIndex(Telephony.Sms.THREAD_ID)
            while (c.moveToNext() && out.size < MAX_ROWS) {
                out.add(
                    mapOf(
                        "address" to (c.getString(addrIdx) ?: ""),
                        "body" to (c.getString(bodyIdx) ?: ""),
                        "date" to c.getLong(dateIdx),
                        "type" to c.getInt(typeIdx),
                        "threadId" to (if (threadIdx >= 0) c.getLong(threadIdx) else -1L)
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

    /** All media permissions the gallery needs (images + video on Android 13+). */
    fun galleryPermissions(): List<String> =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            listOf(Manifest.permission.READ_MEDIA_IMAGES, Manifest.permission.READ_MEDIA_VIDEO)
        } else {
            listOf(Manifest.permission.READ_EXTERNAL_STORAGE)
        }

    fun hasGalleryPermission(ctx: Context) = granted(ctx, galleryPermission())

    fun hasVideoPermission(ctx: Context) =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            granted(ctx, Manifest.permission.READ_MEDIA_VIDEO)
        } else {
            granted(ctx, Manifest.permission.READ_EXTERNAL_STORAGE)
        }

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
     * Small JPEG preview (longest side ~[size] px, quality 85) of the photo
     * ("m:<media id>") or video poster ("v:<media id>") with [key], or null.
     * Uses the system thumbnail cache, so the full file is never read.
     * The 1024 px tier is what the parent grid and viewer both show.
     */
    fun thumbnail(ctx: Context, key: String, size: Int = 1024): ByteArray? {
        val isVideo = key.startsWith("v:")
        if ((!isVideo && !key.startsWith("m:")) || (!isVideo && !hasGalleryPermission(ctx)) || (isVideo && !hasVideoPermission(ctx))) return null
        val id = key.removePrefix("m:").removePrefix("v:").toLongOrNull() ?: return null
        val bitmap = try {
            if (Build.VERSION.SDK_INT >= 29) {
                val uri = android.content.ContentUris.withAppendedId(
                    if (isVideo) MediaStore.Video.Media.EXTERNAL_CONTENT_URI
                    else MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id
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
            scaled.compress(android.graphics.Bitmap.CompressFormat.JPEG, 85, out)
            if (scaled !== bitmap) scaled.recycle()
            bitmap.recycle()
            out.toByteArray()
        } catch (_: Exception) {
            null
        }
    }

    /** Recent videos, mirroring [images]: key "v:<media id>", poster via [thumbnail]. */
    fun videos(ctx: Context): List<Map<String, Any>> {
        if (!hasVideoPermission(ctx)) return emptyList()
        val out = ArrayList<Map<String, Any>>()
        // No "LIMIT" in sortOrder: MediaStore rejects it on Android 11+.
        ctx.contentResolver.query(
            MediaStore.Video.Media.EXTERNAL_CONTENT_URI,
            arrayOf(
                MediaStore.Video.Media._ID,
                MediaStore.Video.Media.DISPLAY_NAME,
                MediaStore.Video.Media.SIZE,
                MediaStore.Video.Media.DATE_MODIFIED,
                MediaStore.Video.Media.BUCKET_DISPLAY_NAME,
                MediaStore.Video.Media.DURATION,
                // Local path: only for the original-file upload on the
                // child's own device; the sync strips it before upload.
                @Suppress("DEPRECATION") MediaStore.Video.Media.DATA
            ),
            null, null,
            "${MediaStore.Video.Media.DATE_MODIFIED} DESC"
        )?.use { c ->
            val idIdx = c.getColumnIndex(MediaStore.Video.Media._ID)
            val nameIdx = c.getColumnIndex(MediaStore.Video.Media.DISPLAY_NAME)
            val sizeIdx = c.getColumnIndex(MediaStore.Video.Media.SIZE)
            val dateIdx = c.getColumnIndex(MediaStore.Video.Media.DATE_MODIFIED)
            val albumIdx = c.getColumnIndex(MediaStore.Video.Media.BUCKET_DISPLAY_NAME)
            val durIdx = c.getColumnIndex(MediaStore.Video.Media.DURATION)
            @Suppress("DEPRECATION")
            val dataIdx = c.getColumnIndex(MediaStore.Video.Media.DATA)
            while (c.moveToNext() && out.size < MAX_ROWS) {
                out.add(
                    mapOf(
                        "key" to "v:${c.getLong(idIdx)}",
                        "album" to (if (albumIdx >= 0) c.getString(albumIdx) ?: "" else ""),
                        "name" to (c.getString(nameIdx) ?: ""),
                        "path" to (if (dataIdx >= 0) c.getString(dataIdx) ?: "" else ""),
                        "size" to c.getLong(sizeIdx),
                        // DATE_MODIFIED is seconds since epoch -> milliseconds.
                        "date" to c.getLong(dateIdx) * 1000,
                        "duration" to (if (durIdx >= 0) c.getLong(durIdx) / 1000 else 0L),
                        "isImage" to false
                    )
                )
            }
        }
        return out
    }

    /**
     * Original file bytes for one photo ("m:") or video ("v:") — only used
     * when the parent requested this exact file (see files originals).
     * Capped at 8 MB, matching the server's MAX_ORIGINAL_BYTES.
     */
    fun originalBytes(ctx: Context, key: String): ByteArray? {
        val isVideo = key.startsWith("v:")
        if ((!isVideo && !key.startsWith("m:")) || (!isVideo && !hasGalleryPermission(ctx)) || (isVideo && !hasVideoPermission(ctx))) return null
        val id = key.removePrefix("m:").removePrefix("v:").toLongOrNull() ?: return null
        val uri = android.content.ContentUris.withAppendedId(
            if (isVideo) MediaStore.Video.Media.EXTERNAL_CONTENT_URI
            else MediaStore.Images.Media.EXTERNAL_CONTENT_URI, id
        )
        return try {
            ctx.contentResolver.openInputStream(uri)?.use { input ->
                val out = java.io.ByteArrayOutputStream()
                val buf = ByteArray(64 * 1024)
                var total = 0
                while (true) {
                    val n = input.read(buf)
                    if (n < 0) break
                    total += n
                    if (total > 8 * 1024 * 1024) return null
                    out.write(buf, 0, n)
                }
                out.toByteArray()
            }
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
