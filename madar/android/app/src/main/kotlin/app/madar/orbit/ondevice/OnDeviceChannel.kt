package app.madar.orbit.ondevice

import android.app.ActivityManager
import android.content.Context
import android.os.Build
import android.os.PowerManager
import android.os.StatFs
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/**
 * The phone's own answer to «what can you run?» (`app.madar.orbit/ondevice`,
 * lib/features/ondevice_ai/data/ondevice_probe_client.dart). Part 15, step A.
 *
 * ONE method, `probe`, that returns a map:
 *
 * * `aicore`  = `"unsupported"` and `engine` = `"unsupported"` – on purpose.
 *   No on-device engine is wired in yet (the ML Kit Prompt API on AICore and
 *   Google AI Edge are developer-preview APIs that must be measured on the
 *   owner's phone first), so nothing here claims a capability it has not
 *   proved. Step B replaces these two strings with real feature probes.
 * * `sdkInt`           – [Build.VERSION.SDK_INT].
 * * `totalRamBytes`    – [ActivityManager.MemoryInfo.totalMem].
 * * `availableRamBytes`– [ActivityManager.MemoryInfo.availMem].
 * * `freeStorageBytes` – [StatFs.getAvailableBytes] of the app's private files
 *   directory (where the optional weights would be stored).
 * * `thermalStatus`    – [PowerManager.getCurrentThermalStatus] (0 none … 6
 *   shutdown), or -1 below Android 10, where the platform has no such call.
 * * `batterySaver`     – [PowerManager.isPowerSaveMode].
 *
 * Every value comes from a standard Android API. Nothing is fetched, nothing
 * is stored, nothing leaves the phone. A value that cannot be read is simply
 * left out of the map (Dart reads a missing number as unknown, not as zero).
 */
object OnDeviceChannel {
    private const val CHANNEL = "app.madar.orbit/ondevice"

    /** Binds the channel to [flutterEngine]; answers from the application context. */
    fun register(flutterEngine: FlutterEngine, context: Context) {
        val app = context.applicationContext
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "probe" -> try {
                    result.success(probe(app))
                } catch (e: Exception) {
                    result.error("ondevice_probe", e.message, null)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun probe(context: Context): Map<String, Any> {
        val out = HashMap<String, Any>()
        out["aicore"] = "unsupported"
        out["engine"] = "unsupported"
        out["sdkInt"] = Build.VERSION.SDK_INT

        try {
            val am = context.getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            val info = ActivityManager.MemoryInfo()
            am.getMemoryInfo(info)
            out["totalRamBytes"] = info.totalMem
            out["availableRamBytes"] = info.availMem
        } catch (_: Exception) {
            // Left out: unknown, not zero.
        }

        try {
            val stat = StatFs(context.filesDir.path)
            out["freeStorageBytes"] = stat.availableBytes
        } catch (_: Exception) {
        }

        val power = context.getSystemService(Context.POWER_SERVICE) as? PowerManager
        if (power != null) {
            out["thermalStatus"] = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                power.currentThermalStatus
            } else {
                -1
            }
            out["batterySaver"] = power.isPowerSaveMode
        }
        return out
    }
}
