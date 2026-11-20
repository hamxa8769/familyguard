package com.familyguard.familyguard_child

import android.app.Notification
import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.PixelFormat
import android.hardware.display.DisplayManager
import android.hardware.display.VirtualDisplay
import android.media.ImageReader
import android.media.MediaRecorder
import android.media.ToneGenerator
import android.media.AudioManager
import android.media.projection.MediaProjection
import android.media.projection.MediaProjectionManager
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.DisplayMetrics
import android.view.WindowManager
import androidx.core.content.ContextCompat
import org.json.JSONObject
import java.io.File
import java.io.FileOutputStream

/**
 * Foreground service that performs the two on-request captures.
 *
 * Screenshots (MediaProjection):
 * - Runs only after the child sees a countdown notification AND approves
 *   the system screen-capture dialog. Android requires that approval every
 *   time — there is no silent screenshot, and this code does not try to
 *   work around it.
 * - Captures a single frame, saves a PNG to the app cache, writes a result
 *   file the Dart side polls, then stops itself.
 *
 * SOS / parent-requested audio (MediaRecorder):
 * - Records at most 30 seconds (MediaRecorder maxDuration), with a
 *   persistent notification, a beep at start and at stop, and a visible
 *   "Recording" state. Never starts on its own — only from an SOS press
 *   or an accepted parent request.
 *
 * Both results are written to cacheDir/capture_result.json as
 * {"type","commandId","path","error","at"} and read by MainActivity.
 */
class CaptureService : Service() {
    private var mediaProjection: MediaProjection? = null
    private var virtualDisplay: VirtualDisplay? = null
    private var imageReader: ImageReader? = null
    private var recorder: MediaRecorder? = null
    private var recordingCommandId: String? = null
    private val handler = Handler(Looper.getMainLooper())

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_SCREENSHOT -> {
                val resultCode = intent.getIntExtra(EXTRA_RESULT_CODE, 0)
                val data = intent.getParcelableExtra<Intent>(EXTRA_DATA)
                val commandId = intent.getStringExtra(EXTRA_COMMAND_ID) ?: ""
                if (data == null) {
                    writeResult("screenshot", commandId, null, "missing projection data")
                    stopSelf()
                } else {
                    startScreenshot(resultCode, data, commandId)
                }
            }
            ACTION_AUDIO -> {
                val commandId = intent.getStringExtra(EXTRA_COMMAND_ID) ?: ""
                startAudio(commandId)
            }
            ACTION_STOP_AUDIO -> stopAudio("stopped")
        }
        return START_NOT_STICKY
    }

    // ---- Screenshot ----

    private fun startForegroundTyped(notification: Notification, type: Int) {
        // The 3-arg startForeground exists only on API 29+; minSdk is 24.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(Notifications.CAPTURE_NOTIFICATION_ID, notification, type)
        } else {
            startForeground(Notifications.CAPTURE_NOTIFICATION_ID, notification)
        }
    }

    private fun startScreenshot(resultCode: Int, data: Intent, commandId: String) {
        startForegroundTyped(
            Notifications.captureNotification(
                this, "Taking screenshot", "A screenshot requested by your parent is being taken."
            ),
            // Android 14 requires the mediaProjection foreground-service type.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MEDIA_PROJECTION else 0
        )
        try {
            val pm = getSystemService(Context.MEDIA_PROJECTION_SERVICE) as MediaProjectionManager
            val projection = pm.getMediaProjection(resultCode, data)
                ?: throw IllegalStateException("MediaProjection was null")
            mediaProjection = projection
            val wm = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val metrics = DisplayMetrics()
            @Suppress("DEPRECATION")
            wm.defaultDisplay.getRealMetrics(metrics)
            val width = metrics.widthPixels
            val height = metrics.heightPixels
            val reader = ImageReader.newInstance(width, height, PixelFormat.RGBA_8888, 2)
            imageReader = reader
            virtualDisplay = projection.createVirtualDisplay(
                "FamilyGuardScreenshot", width, height, metrics.densityDpi,
                DisplayManager.VIRTUAL_DISPLAY_FLAG_AUTO_MIRROR,
                reader.surface, null, handler
            )
            // Give the compositor a moment to draw a frame, then grab it.
            handler.postDelayed({
                try {
                    val image = reader.acquireLatestImage()
                    if (image == null) {
                        writeResult("screenshot", commandId, null, "no frame captured")
                    } else {
                        val path = saveImage(image, commandId)
                        writeResult("screenshot", commandId, path, null)
                        image.close()
                    }
                } catch (e: Exception) {
                    writeResult("screenshot", commandId, null, e.message ?: "capture failed")
                } finally {
                    cleanupProjection()
                    stopSelf()
                }
            }, 700)
        } catch (e: Exception) {
            writeResult("screenshot", commandId, null, e.message ?: "capture failed")
            cleanupProjection()
            stopSelf()
        }
    }

    private fun saveImage(image: android.media.Image, commandId: String): String {
        val plane = image.planes[0]
        val buffer = plane.buffer
        val pixelStride = plane.pixelStride
        val rowStride = plane.rowStride
        val rowPadding = rowStride - pixelStride * image.width
        val bitmap = Bitmap.createBitmap(
            image.width + rowPadding / pixelStride, image.height, Bitmap.Config.ARGB_8888
        )
        bitmap.copyPixelsFromBuffer(buffer)
        val cropped = Bitmap.createBitmap(bitmap, 0, 0, image.width, image.height)
        val file = File(cacheDir, "screenshot_${commandId}_${System.currentTimeMillis()}.png")
        FileOutputStream(file).use { out ->
            cropped.compress(Bitmap.CompressFormat.PNG, 100, out)
        }
        bitmap.recycle()
        if (cropped != bitmap) cropped.recycle()
        return file.absolutePath
    }

    private fun cleanupProjection() {
        try { virtualDisplay?.release() } catch (_: Exception) {}
        try { mediaProjection?.stop() } catch (_: Exception) {}
        try { imageReader?.close() } catch (_: Exception) {}
        virtualDisplay = null
        mediaProjection = null
        imageReader = null
    }

    // ---- Audio ----

    private fun startAudio(commandId: String) {
        startForegroundTyped(
            Notifications.captureNotification(
                this, "Recording audio (SOS)", "A short audio clip (max 30 seconds) is being recorded."
            ),
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q)
                android.content.pm.ServiceInfo.FOREGROUND_SERVICE_TYPE_MICROPHONE else 0
        )
        try {
            beep()
            val rec = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                MediaRecorder(this)
            } else {
                @Suppress("DEPRECATION")
                MediaRecorder()
            }
            recorder = rec
            recordingCommandId = commandId
            val file = File(cacheDir, "audio_${commandId}_${System.currentTimeMillis()}.m4a")
            rec.setAudioSource(MediaRecorder.AudioSource.MIC)
            rec.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            rec.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            rec.setOutputFile(file.absolutePath)
            rec.setMaxDuration(MAX_AUDIO_MS)
            rec.setOnInfoListener { _, what, _ ->
                if (what == MediaRecorder.MEDIA_RECORDER_INFO_MAX_DURATION_REACHED) {
                    stopAudio(null)
                }
            }
            rec.setOnErrorListener { _, _, _ -> stopAudio("recording error") }
            rec.prepare()
            rec.start()
            // Safety net: stop at 30 s even if the callback is missed.
            handler.postDelayed({ stopAudio(null) }, MAX_AUDIO_MS.toLong() + 500)
            pendingAudioFile = file.absolutePath
        } catch (e: Exception) {
            writeResult("audio", commandId, null, e.message ?: "recording failed")
            stopSelf()
        }
    }

    private fun stopAudio(error: String?) {
        val commandId = recordingCommandId ?: return
        recordingCommandId = null
        try { recorder?.stop() } catch (_: Exception) { /* already stopped */ }
        try { recorder?.release() } catch (_: Exception) {}
        recorder = null
        beep()
        writeResult("audio", commandId, if (error == null) pendingAudioFile else null, error)
        pendingAudioFile = null
        stopSelf()
    }

    private var pendingAudioFile: String? = null

    private fun beep() {
        try {
            val tone = ToneGenerator(AudioManager.STREAM_ALARM, 80)
            tone.startTone(ToneGenerator.TONE_PROP_BEEP, 300)
            handler.postDelayed({ tone.release() }, 500)
        } catch (_: Exception) {
        }
    }

    // ---- Result file ----

    private fun writeResult(type: String, commandId: String, path: String?, error: String?) {
        writeResultFile(this, type, commandId, path, error)
    }

    override fun onDestroy() {
        handler.removeCallbacksAndMessages(null)
        try { recorder?.release() } catch (_: Exception) {}
        cleanupProjection()
        super.onDestroy()
    }

    companion object {
        const val ACTION_SCREENSHOT = "com.familyguard.SCREENSHOT"
        const val ACTION_AUDIO = "com.familyguard.AUDIO"
        const val ACTION_STOP_AUDIO = "com.familyguard.STOP_AUDIO"
        const val EXTRA_RESULT_CODE = "resultCode"
        const val EXTRA_DATA = "data"
        const val EXTRA_COMMAND_ID = "commandId"
        const val RESULT_FILE = "capture_result.json"
        const val MAX_AUDIO_MS = 30_000 // Hard cap: SOS/parent audio is at most 30 seconds.

        fun startScreenshot(context: Context, resultCode: Int, data: Intent, commandId: String) {
            val intent = Intent(context, CaptureService::class.java).apply {
                action = ACTION_SCREENSHOT
                putExtra(EXTRA_RESULT_CODE, resultCode)
                putExtra(EXTRA_DATA, data)
                putExtra(EXTRA_COMMAND_ID, commandId)
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun startAudio(context: Context, commandId: String) {
            val intent = Intent(context, CaptureService::class.java).apply {
                action = ACTION_AUDIO
                putExtra(EXTRA_COMMAND_ID, commandId)
            }
            ContextCompat.startForegroundService(context, intent)
        }

        fun stopAudio(context: Context) {
            context.startService(
                Intent(context, CaptureService::class.java).apply { action = ACTION_STOP_AUDIO }
            )
        }

        /** Writes the shared capture-result file (also used by MainActivity
         * when the user denies the system screen-capture dialog). */
        fun writeResultFile(
            context: Context, type: String, commandId: String, path: String?, error: String?
        ) {
            try {
                val obj = JSONObject().apply {
                    put("type", type)
                    put("commandId", commandId)
                    put("path", path ?: JSONObject.NULL)
                    put("error", error ?: JSONObject.NULL)
                    put("at", System.currentTimeMillis())
                }
                File(context.cacheDir, RESULT_FILE).writeText(obj.toString())
            } catch (_: Exception) {
            }
        }
    }
}
