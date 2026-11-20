package com.familyguard.familyguard_child

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/**
 * Restarts the block watcher after reboot — but only if enforcement is
 * actually configured (blocked apps or bedtime). The watcher checks the
 * stored config itself and stops again immediately if there is nothing
 * to enforce, so a device with no rules set does not keep a service alive.
 */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED) return
        if (!EnforcementPrefs.hasAnyRule(context)) return
        BlockWatcherService.start(context)
    }
}
