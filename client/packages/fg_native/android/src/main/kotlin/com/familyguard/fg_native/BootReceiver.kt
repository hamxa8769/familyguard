package com.familyguard.fg_native

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Re-applies saved rules after the phone restarts (or the app updates). */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> {
                // A background foreground-service start can be refused right
                // after boot; schedule a WorkManager retry instead of
                // waiting for the app to be opened. Only when the refusal
                // is the cause — missing usage access cannot be fixed by a
                // retry (the user must grant it), and no rules means
                // nothing to start.
                if (!EnforcementService.sync(context) &&
                    Rules.load(context).hasAppRules &&
                    Collectors.hasUsageAccess(context)
                ) {
                    EnforcementRetryWorker.schedule(context)
                }
                DnsVpnService.sync(context)
            }
        }
    }
}
