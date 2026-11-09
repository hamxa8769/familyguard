package com.familyguard.fg_native

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

/** Re-applies saved rules after the phone restarts (or the app updates). */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED -> {
                EnforcementService.sync(context)
                DnsVpnService.sync(context)
            }
        }
    }
}
