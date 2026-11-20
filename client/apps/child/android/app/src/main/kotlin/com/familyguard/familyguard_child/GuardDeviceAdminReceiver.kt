package com.familyguard.familyguard_child

import android.app.admin.DeviceAdminReceiver
import android.content.Context
import android.content.Intent

/**
 * Device admin receiver for the "Lock now" remote command.
 *
 * Only the force-lock policy is declared (see res/xml/device_admin.xml).
 * The admin is activated by the user in a visible system screen
 * (Settings > Security > Device admin apps) — never silently — and can be
 * deactivated there at any time. FamilyGuard cannot wipe the device, change
 * passwords, or disable the camera or microphone.
 */
class GuardDeviceAdminReceiver : DeviceAdminReceiver() {
    override fun onEnabled(context: Context, intent: Intent) {
        // Nothing to do: activation is the visible system flow.
    }
}
