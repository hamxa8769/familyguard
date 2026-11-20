package com.familyguard.fg_native

import android.content.Context
import androidx.work.ExistingWorkPolicy
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.OutOfQuotaPolicy
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

/**
 * Retries enforcement after Android refused a background foreground-service
 * start — at boot, after an app update, or from a background sync's
 * setRules call. Android may refuse `startForegroundService` from the
 * background (background-start restrictions); this worker runs a minute
 * later, when the restriction has usually lifted, instead of waiting for
 * the child to open the app.
 *
 * No exact alarm is used (deliberately — see the audit): WorkManager
 * decides the exact moment, subject to Doze.
 */
class EnforcementRetryWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {
    override fun doWork(): Result {
        val rules = Rules.load(applicationContext)
        if (!rules.hasAppRules && rules.blockedDomains.isEmpty()) return Result.success()
        EnforcementService.sync(applicationContext)
        DnsVpnService.sync(applicationContext)
        // If the start was refused again, EnforcementService.sync() already
        // scheduled the next retry, so this attempt is done either way.
        return Result.success()
    }

    companion object {
        private const val UNIQUE_NAME = "familyguard.enforcement-retry"

        /** One-time expedited retry in ~1 minute; keeps an already-pending one. */
        fun schedule(ctx: Context) {
            try {
                val work = OneTimeWorkRequestBuilder<EnforcementRetryWorker>()
                    .setInitialDelay(1, TimeUnit.MINUTES)
                    .setExpedited(OutOfQuotaPolicy.RUN_AS_NON_EXPEDITED_WORK_REQUEST)
                    .build()
                WorkManager.getInstance(ctx).enqueueUniqueWork(
                    UNIQUE_NAME, ExistingWorkPolicy.KEEP, work
                )
            } catch (_: Exception) {
                // WorkManager unavailable (e.g. not initialised yet at boot):
                // the next app open / sync starts enforcement instead.
            }
        }
    }
}
