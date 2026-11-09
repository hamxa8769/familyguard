package com.familyguard.familyguard_child

import io.flutter.embedding.android.FlutterActivity

/**
 * The child app's Android host. All native collectors (usage, contacts/SMS/
 * calls, location, photos) live in the local `fg_native` plugin
 * (client/packages/fg_native) so the background sync engine can use them too.
 */
class MainActivity : FlutterActivity()
