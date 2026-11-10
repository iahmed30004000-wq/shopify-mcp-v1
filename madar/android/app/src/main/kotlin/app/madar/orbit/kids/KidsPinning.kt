package app.madar.orbit.kids

import android.app.Activity
import android.app.ActivityManager
import android.content.Context
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * Android app pinning (screen pinning) for «مدار الصغار»
 * (`app.madar.orbit/kids_pinning`, lib/features/kids/shell/data/kids_store.dart).
 *
 * Three methods, nothing else, all standard APIs:
 *
 * * `isPinned` – [ActivityManager.getLockTaskModeState] is not NONE (below
 *   Android 6: [ActivityManager.isInLockTaskMode]).
 * * `start`    – [Activity.startLockTask]. Android shows its own confirmation;
 *   without the user's "App pinning" switched on it does nothing.
 * * `stop`     – [Activity.stopLockTask], called only after the parent has been
 *   through the PIN or the fingerprint.
 *
 * Unpinning by the system gesture stays the parent's. No activity attached
 * (the engine outlives the activity): the methods answer false.
 */
object KidsPinning {
    private const val CHANNEL = "app.madar.orbit/kids_pinning"

    /** Binds the channel; [activity] returns the attached activity or null. */
    fun register(flutterEngine: FlutterEngine, activity: () -> Activity?) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            val host = activity()
            try {
                when (call.method) {
                    "isPinned" -> result.success(host != null && isPinned(host))
                    "start" -> {
                        host?.startLockTask()
                        result.success(host != null)
                    }
                    "stop" -> {
                        if (host != null && isPinned(host)) host.stopLockTask()
                        result.success(host != null)
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("kids_pinning", e.message, null)
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun isPinned(activity: Activity): Boolean {
        val manager = activity.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            manager.lockTaskModeState != ActivityManager.LOCK_TASK_MODE_NONE
        } else {
            manager.isInLockTaskMode
        }
    }
}
