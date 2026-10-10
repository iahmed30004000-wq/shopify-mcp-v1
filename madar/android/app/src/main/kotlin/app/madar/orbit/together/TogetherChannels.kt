package app.madar.orbit.together

import android.app.Activity
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.WindowManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

/**
 * Together Mode's Android side (lib/features/together).
 *
 * `madar/together_privacy` → `setSecure(bool)`: keeps the window out of the
 * recents thumbnail and screenshots (FLAG_SECURE) while a private turn (a
 * hand of cards, hidden answers) is on screen. Dart reference-counts its
 * private surfaces and sends `true` when the first one mounts and `false`
 * when the last one goes; this side counts again, so an unbalanced call can
 * neither leave the flag stuck on nor drop it while another surface still
 * holds it. The count outlives the activity (the engine does): an activity
 * that attaches later gets the flag at once. Answers the number of holds.
 *
 * `madar/together_nearby` → `sdkInt`: Android's API level, which decides the
 * runtime permissions Google Nearby Connections needs (nearby devices on
 * Android 12+, location up to Android 12L).
 *
 * Registered once per engine from `MainActivity.configureFlutterEngine`
 * ([register]). Calls arrive on the main thread (window flags must be set
 * there); one arriving elsewhere is posted to it.
 */
object TogetherChannels {
    const val PRIVACY_CHANNEL = "madar/together_privacy"
    const val NEARBY_CHANNEL = "madar/together_nearby"

    /** Adds the Together plugin to [engine] (once per engine). */
    fun register(engine: FlutterEngine) {
        if (engine.plugins.has(TogetherPlugin::class.java)) return
        engine.plugins.add(TogetherPlugin())
    }
}

class TogetherPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "MadarTogether"
    }

    private val main = Handler(Looper.getMainLooper())
    private var privacy: MethodChannel? = null
    private var nearby: MethodChannel? = null
    private var activity: Activity? = null

    /** Private surfaces currently asking for FLAG_SECURE. */
    private var holds = 0

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        privacy = MethodChannel(binding.binaryMessenger, TogetherChannels.PRIVACY_CHANNEL).also {
            it.setMethodCallHandler(this)
        }
        nearby = MethodChannel(binding.binaryMessenger, TogetherChannels.NEARBY_CHANNEL).also {
            it.setMethodCallHandler(this)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        privacy?.setMethodCallHandler(null)
        nearby?.setMethodCallHandler(null)
        privacy = null
        nearby = null
        main.removeCallbacksAndMessages(null)
        // The engine (and every Dart surface holding the flag) is gone.
        holds = 0
        apply()
        activity = null
    }

    // ------------------------------------------------------------ activity ----

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        apply()
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        activity = binding.activity
        apply()
    }

    override fun onDetachedFromActivityForConfigChanges() {
        activity = null
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    /** Puts the window's FLAG_SECURE in line with [holds]. */
    private fun apply() {
        val window = activity?.window ?: return
        try {
            if (holds > 0) {
                window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
            } else {
                window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
            }
        } catch (e: RuntimeException) {
            Log.w(TAG, "FLAG_SECURE could not be changed", e)
        }
    }

    // ------------------------------------------------------------- methods ----

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (!Looper.getMainLooper().isCurrentThread) {
            main.post { onMethodCall(call, result) }
            return
        }
        when (call.method) {
            "setSecure" -> {
                val secure = call.arguments as? Boolean
                if (secure == null) {
                    result.error("bad_arguments", "setSecure expects a bool", null)
                    return
                }
                holds = if (secure) holds + 1 else maxOf(0, holds - 1)
                apply()
                result.success(holds)
            }
            "sdkInt" -> result.success(Build.VERSION.SDK_INT)
            else -> result.notImplemented()
        }
    }
}
