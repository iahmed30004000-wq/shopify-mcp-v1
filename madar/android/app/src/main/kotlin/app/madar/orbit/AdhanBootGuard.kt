package app.madar.orbit

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

/**
 * Runs on boot / app update just before flutter_local_notifications'
 * `ScheduledNotificationBootReceiver` re-arms its alarms (higher
 * `android:priority` in the manifest; both receivers live in this process,
 * so the order is honoured):
 *
 * 1. **Drops stale alarms.** Alarms are wiped when the phone is off; the
 *    plugin re-arms every cached one on boot, and one whose time has passed
 *    fires at once – a phone switched on at 9:00 would call the Fajr adhan.
 *    Madar marks its alarms with a drop-if-late window (payload envelope
 *    keys `at` and `late`, see `lib/core/notifications/notification_envelope.dart`);
 *    entries later than that are removed from the plugin's cache first.
 * 2. **Re-grants the muezzin recordings** to the system (URI grants do not
 *    survive a reboot or an update), so custom channel sounds keep playing.
 *
 * Nothing here touches Dart; the app re-plans everything on its next start.
 */
class AdhanBootGuard : BroadcastReceiver() {
    companion object {
        private const val TAG = "MadarAdhanBootGuard"

        /** flutter_local_notifications' cache (SharedPreferences file and key). */
        private const val PLUGIN_PREFS = "scheduled_notifications"
        private const val PLUGIN_KEY = "scheduled_notifications"

        private val ACTIONS = setOf(
            Intent.ACTION_BOOT_COMPLETED,
            Intent.ACTION_MY_PACKAGE_REPLACED,
            "android.intent.action.QUICKBOOT_POWERON",
            "com.htc.intent.action.QUICKBOOT_POWERON",
        )

        /** Whether a Madar payload envelope says this alarm is too late to sound. */
        fun isStale(payload: String?, nowMs: Long): Boolean {
            if (payload.isNullOrEmpty() || !payload.startsWith("{")) return false
            return try {
                val o = JSONObject(payload)
                val at = o.optLong("at", -1L)
                val late = o.optLong("late", -1L)
                at > 0 && late >= 0 && nowMs > at + late
            } catch (_: Exception) {
                false
            }
        }

        fun pruneStale(context: Context, nowMs: Long = System.currentTimeMillis()): Int {
            val prefs = context.getSharedPreferences(PLUGIN_PREFS, Context.MODE_PRIVATE)
            val json = prefs.getString(PLUGIN_KEY, null) ?: return 0
            return try {
                val all = JSONArray(json)
                val kept = JSONArray()
                var removed = 0
                for (i in 0 until all.length()) {
                    val item = all.opt(i)
                    val payload = (item as? JSONObject)?.optString("payload", "")
                    if (isStale(payload, nowMs)) removed++ else kept.put(item)
                }
                // commit(), not apply(): the plugin's receiver reads the cache next.
                if (removed > 0) prefs.edit().putString(PLUGIN_KEY, kept.toString()).commit()
                removed
            } catch (e: Exception) {
                Log.w(TAG, "could not read the notification cache", e)
                0
            }
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in ACTIONS) return
        val removed = pruneStale(context)
        if (removed > 0) Log.i(TAG, "dropped $removed alarm(s) that passed while the phone was off")
        AdhanSoundProvider.grantAll(context)
    }
}
