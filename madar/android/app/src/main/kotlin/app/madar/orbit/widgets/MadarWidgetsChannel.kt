package app.madar.orbit.widgets

import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.lang.ref.WeakReference
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

/**
 * The home-screen widgets' side of `app.madar.orbit/widgets`
 * (lib/features/widgets/data/widget_platform.dart).
 *
 * Registered once per engine from `MainActivity.configureFlutterEngine`
 * ([register]); a plugin of the engine rather than a bare channel so that it
 * sees the activity's launch intent and the new intents a warm engine gets
 * (a widget tap reaching a running app).
 *
 * Dart → Android:
 * * `installed` → the kinds with a widget on a home screen;
 * * `publish {kind, json, images?}` → stores the snapshot (encrypted) and
 *   images for a kind that *is* installed (nothing is written otherwise),
 *   redraws its widgets and arms its next page;
 * * `remove {kind}`, `clearAll` → deletes data ("delete all data": the key
 *   too) and redraws the widgets as "Open Madar";
 * * `takeLaunch` → the route of the widget tap that opened the app, once.
 *
 * Android → Dart: `changed` (a widget was added / removed – publish again),
 * `launch` (a tap is waiting in `takeLaunch`).
 *
 * File and Keystore work runs on one background thread; results are posted
 * back to the main thread.
 */
object MadarWidgetsChannel {
    const val CHANNEL = "app.madar.orbit/widgets"

    /** The action of a widget tap's launch intent; the route is [EXTRA_ROUTE]. */
    const val ACTION_OPEN = "app.madar.orbit.widgets.OPEN"
    const val EXTRA_ROUTE = "app.madar.orbit.widgets.ROUTE"

    /** Adds the widgets' plugin to [engine] (once per engine). */
    fun register(engine: FlutterEngine, context: Context) {
        if (engine.plugins.has(MadarWidgetsPlugin::class.java)) return
        engine.plugins.add(MadarWidgetsPlugin(context.applicationContext))
    }

    /** Tells a running app that widgets were added or removed. */
    fun notifyChanged() {
        MadarWidgetsPlugin.current()?.send("changed")
    }
}

class MadarWidgetsPlugin(private val context: Context) :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler,
    PluginRegistry.NewIntentListener {

    companion object {
        private const val TAG = "MadarWidgets"

        private var live: WeakReference<MadarWidgetsPlugin>? = null

        private val io: ExecutorService = Executors.newSingleThreadExecutor()

        fun current(): MadarWidgetsPlugin? = live?.get()
    }

    private val main = Handler(Looper.getMainLooper())
    private var channel: MethodChannel? = null
    private var activity: ActivityPluginBinding? = null

    /** The route of the last widget tap, until Dart takes it. */
    private var pendingRoute: String? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val c = MethodChannel(binding.binaryMessenger, MadarWidgetsChannel.CHANNEL)
        c.setMethodCallHandler(this)
        channel = c
        live = WeakReference(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        if (live?.get() === this) live = null
    }

    // ------------------------------------------------------------ activity ----

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        attach(binding)
        take(binding.activity.intent)
    }

    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) {
        attach(binding)
    }

    override fun onDetachedFromActivityForConfigChanges() {
        detach()
    }

    override fun onDetachedFromActivity() {
        detach()
    }

    private fun attach(binding: ActivityPluginBinding) {
        activity?.removeOnNewIntentListener(this)
        activity = binding
        binding.addOnNewIntentListener(this)
    }

    private fun detach() {
        activity?.removeOnNewIntentListener(this)
        activity = null
    }

    override fun onNewIntent(intent: Intent): Boolean {
        if (intent.action != MadarWidgetsChannel.ACTION_OPEN) return false
        take(intent)
        return true
    }

    /**
     * Keeps the route of a widget launch for Dart and tells a running Dart
     * app. Consumed from the intent, so a re-attach never replays it; a
     * relaunch from recents carries the old intent and is ignored.
     */
    private fun take(intent: Intent?) {
        if (intent == null || intent.action != MadarWidgetsChannel.ACTION_OPEN) return
        if ((intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0) return
        val route = intent.getStringExtra(MadarWidgetsChannel.EXTRA_ROUTE)
        intent.removeExtra(MadarWidgetsChannel.EXTRA_ROUTE)
        if (route.isNullOrEmpty() || route.length > 200) return
        pendingRoute = route
        send("launch")
    }

    /** Invokes [method] on the Dart side (main thread), if it is listening. */
    fun send(method: String) {
        main.post {
            try {
                channel?.invokeMethod(method, null)
            } catch (e: Exception) {
                Log.w(TAG, "could not reach Dart ($method)", e)
            }
        }
    }

    // ------------------------------------------------------------- methods ----

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "installed" -> result.success(
                MadarWidgetKind.values().filter { it.isInstalled(context) }.map { it.wire },
            )
            "takeLaunch" -> {
                val route = pendingRoute
                pendingRoute = null
                result.success(route)
            }
            "publish" -> {
                val kind = MadarWidgetKind.fromWire(call.argument<String>("kind"))
                val json = call.argument<String>("json")
                if (kind == null || json == null) {
                    result.error("widgets", "publish needs a kind and a snapshot", null)
                    return
                }
                val images = imagesOf(call.argument<Any>("images"))
                background(result) { publish(kind, json, images) }
            }
            "remove" -> {
                val kind = MadarWidgetKind.fromWire(call.argument<String>("kind"))
                if (kind == null) {
                    result.error("widgets", "unknown widget", null)
                    return
                }
                background(result) {
                    MadarWidgetStore.remove(context, kind)
                    MadarWidgetRenderer.updateAll(context, kind)
                    null
                }
            }
            "clearAll" -> background(result) {
                MadarWidgetStore.clearAll(context)
                for (kind in MadarWidgetKind.values()) {
                    MadarWidgetAlarms.cancel(context, kind)
                    MadarWidgetRenderer.updateAll(context, kind)
                }
                null
            }
            else -> result.notImplemented()
        }
    }

    /**
     * Stores and draws [kind]'s snapshot – only while one of its widgets is
     * on a home screen. True when written.
     */
    private fun publish(kind: MadarWidgetKind, json: String, images: Map<String, ByteArray>?): Boolean {
        if (!kind.isInstalled(context)) return false
        MadarWidgetStore.writeSnapshot(context, kind, json)
        if (images != null) MadarWidgetStore.replaceImages(context, kind, images)
        MadarWidgetRenderer.updateAll(context, kind)
        return true
    }

    private fun imagesOf(raw: Any?): Map<String, ByteArray>? {
        if (raw !is Map<*, *>) return null
        val out = HashMap<String, ByteArray>()
        for ((k, v) in raw) {
            if (k is String && v is ByteArray) out[k] = v
        }
        return out
    }

    private fun background(result: MethodChannel.Result, work: () -> Any?) {
        io.execute {
            try {
                val answer = work()
                main.post { result.success(answer) }
            } catch (e: Exception) {
                Log.w(TAG, "widget work failed", e)
                main.post { result.error("widgets", e.message, null) }
            }
        }
    }
}
