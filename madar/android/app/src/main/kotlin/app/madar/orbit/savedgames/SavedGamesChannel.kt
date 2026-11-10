package app.madar.orbit.savedgames

import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.View
import android.view.ViewGroup
import android.webkit.WebView
import io.flutter.embedding.android.FlutterView
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugins.webviewflutter.WebViewFlutterAndroidExternalApi
import java.lang.ref.WeakReference
import java.util.Collections
import java.util.WeakHashMap

/**
 * The Android host of Saved Games: `app.madar.orbit/saved_games`
 * (lib/features/saved_games/data/game_platform.dart).
 *
 * Registered once per engine from `MainActivity.configureFlutterEngine`
 * ([register]); a plugin of the engine rather than a bare channel so that it
 * follows the activity (the FlutterView) and is torn down with the engine.
 *
 * Dart → Android:
 * * `keepScreenOn {on}` → `FlutterView.keepScreenOn` – never the window's
 *   FLAG_KEEP_SCREEN_ON, which the adhan's lock-screen mode owns (and
 *   clears). Remembered, and applied again to the FlutterView of an activity
 *   that attaches later (the engine outlives the activity). True when a
 *   FlutterView got it.
 * * `pauseWebView {id}` → `onPause()` + `pauseTimers()`;
 *   `resumeWebView {id}` → `onResume()` + `resumeTimers()`. True when done.
 * * `hardenWebView {id}` → no popup windows
 *   (`setSupportMultipleWindows(false)`,
 *   `setJavaScriptCanOpenWindowsAutomatically(false)` – the plugin turns
 *   both on), and the view's WebViewClient wrapped ([GameWebViewClient]) so
 *   a dead renderer is reported instead of killing the app. True when done.
 *   Dart calls it after setting its navigation delegate (the plugin's
 *   client): setting another delegate later replaces the wrapper, and needs
 *   another `hardenWebView`.
 *
 * Android → Dart: `rendererGone {id}`.
 *
 * `id` is the webview_flutter_android plugin's identifier of the WebView
 * (`AndroidWebViewController.webViewIdentifier`), resolved with
 * [WebViewFlutterAndroidExternalApi.getWebView]. An unknown id, a malformed
 * call or a failing WebView answers false: nothing throws into the channel.
 * Everything runs on the main thread (WebView's thread); a call arriving on
 * another thread is posted there.
 */
object SavedGamesChannel {
    const val CHANNEL = "app.madar.orbit/saved_games"

    /** Adds the Saved Games host to [engine] (once per engine). */
    fun register(engine: FlutterEngine) {
        if (engine.plugins.has(SavedGamesPlugin::class.java)) return
        engine.plugins.add(SavedGamesPlugin())
    }
}

class SavedGamesPlugin :
    FlutterPlugin,
    ActivityAware,
    MethodChannel.MethodCallHandler {

    companion object {
        private const val TAG = "MadarSavedGames"
    }

    private val main = Handler(Looper.getMainLooper())
    private var engine: FlutterPlugin.FlutterPluginBinding? = null
    private var channel: MethodChannel? = null
    private var activity: ActivityPluginBinding? = null

    /** What Dart last asked for with `keepScreenOn`. */
    private var keepScreenOn = false

    /**
     * The views this host paused, by id – weakly: the plugin's table decides
     * how long a WebView lives. See [settleTimers].
     */
    private val paused = HashMap<Long, WeakReference<WebView>>()

    /** Whether this host left WebView's (process-wide) timers paused. */
    private var timersPaused = false

    /** Views whose renderer is gone: unusable, never touched again. */
    private val gone: MutableSet<WebView> = Collections.newSetFromMap(WeakHashMap())

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        val c = MethodChannel(binding.binaryMessenger, SavedGamesChannel.CHANNEL)
        c.setMethodCallHandler(this)
        channel = c
        engine = binding
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel?.setMethodCallHandler(null)
        channel = null
        main.removeCallbacksAndMessages(null)
        // The engine's WebViews go with it; the process's next one must not
        // start with its timers paused.
        if (timersPaused) {
            val live = paused.values.firstNotNullOfOrNull { ref -> ref.get()?.takeUnless { it in gone } }
            if (live != null) quietly("resumeTimers") { live.resumeTimers() }
            timersPaused = false
        }
        paused.clear()
        gone.clear()
        activity = null
        engine = null
    }

    // ------------------------------------------------------------ activity ----

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        attach(binding)
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
        activity = binding
        if (!keepScreenOn) return
        // A game still playing in a warm engine: the new activity's FlutterView
        // does not exist yet when the engine attaches – apply it once the
        // window is up (a view's queued post runs when it is attached).
        binding.activity.window?.decorView?.post {
            if (activity === binding) applyKeepScreenOn()
        }
    }

    private fun detach() {
        if (keepScreenOn) flutterView()?.keepScreenOn = false
        activity = null
    }

    /**
     * The attached activity's FlutterView (MainActivity's FlutterFragment
     * view), found in its window whatever the host's layout.
     */
    private fun flutterView(): FlutterView? {
        val decor = activity?.activity?.window?.peekDecorView() ?: return null
        return findFlutterView(decor)
    }

    private fun findFlutterView(view: View): FlutterView? {
        if (view is FlutterView) return view
        if (view !is ViewGroup) return null
        for (i in 0 until view.childCount) {
            findFlutterView(view.getChildAt(i))?.let { return it }
        }
        return null
    }

    /** Puts [keepScreenOn] on the FlutterView; false when there is none now. */
    private fun applyKeepScreenOn(): Boolean {
        val view = flutterView() ?: return false
        view.keepScreenOn = keepScreenOn
        return true
    }

    // ------------------------------------------------------------- methods ----

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (!Looper.getMainLooper().isCurrentThread) {
            main.post { onMethodCall(call, result) }
            return
        }
        val args = call.arguments as? Map<*, *>
        val answer = try {
            when (call.method) {
                "keepScreenOn" -> {
                    keepScreenOn = args?.get("on") == true
                    applyKeepScreenOn()
                }
                "pauseWebView" -> idOf(args)?.let { pause(it) } ?: false
                "resumeWebView" -> idOf(args)?.let { resume(it) } ?: false
                "hardenWebView" -> idOf(args)?.let { harden(it) } ?: false
                else -> {
                    result.notImplemented()
                    return
                }
            }
        } catch (e: Exception) {
            Log.w(TAG, "${call.method} failed", e)
            false
        }
        result.success(answer)
    }

    /** A call's `id` (a Dart int arrives as Int or Long). */
    private fun idOf(args: Map<*, *>?): Long? = when (val id = args?.get("id")) {
        is Int -> id.toLong()
        is Long -> id
        else -> null
    }

    /** WebView [id] of this engine's webview plugin, unless unknown or its renderer is gone. */
    private fun webView(id: Long): WebView? {
        val binding = engine ?: return null
        val view = try {
            WebViewFlutterAndroidExternalApi.getWebView(binding, id)
        } catch (e: RuntimeException) {
            // The webview plugin is detached (its table is gone) or absent.
            Log.w(TAG, "no WebView table", e)
            null
        }
        return view?.takeUnless { it in gone }
    }

    private fun pause(id: Long): Boolean {
        val view = webView(id) ?: return false
        view.onPause()
        view.pauseTimers()
        paused[id] = WeakReference(view)
        timersPaused = true
        return true
    }

    private fun resume(id: Long): Boolean {
        val view = webView(id)
        paused.remove(id)
        view?.onResume()
        settleTimers(view)
        return view != null
    }

    private fun harden(id: Long): Boolean {
        val view = webView(id) ?: return false
        val settings = view.settings
        settings.setSupportMultipleWindows(false)
        settings.javaScriptCanOpenWindowsAutomatically = false
        val client = view.webViewClient
        if (client !is GameWebViewClient) view.webViewClient = GameWebViewClient(client, id, this)
        settleTimers(view)
        return true
    }

    /**
     * WebView's timers are process-wide: they stay paused while any view
     * this host paused is still paused. Views that went away paused (disposed,
     * renderer gone) are forgotten, and [live] – a usable WebView – resumes
     * the timers once none is left.
     */
    private fun settleTimers(live: WebView?) {
        paused.entries.removeAll { (id, ref) ->
            val view = ref.get()
            view == null || view in gone || webView(id) !== view
        }
        if (timersPaused && paused.isEmpty() && live != null) {
            live.resumeTimers()
            timersPaused = false
        }
    }

    /** From [GameWebViewClient]: WebView [id]'s renderer is gone. */
    internal fun onRendererGone(id: Long, view: WebView?) {
        if (!Looper.getMainLooper().isCurrentThread) {
            main.post { onRendererGone(id, view) }
            return
        }
        if (view != null) gone.add(view)
        paused.remove(id)
        try {
            channel?.invokeMethod("rendererGone", mapOf("id" to id))
        } catch (e: Exception) {
            Log.w(TAG, "could not reach Dart (rendererGone)", e)
        }
    }

    private inline fun quietly(what: String, block: () -> Unit) {
        try {
            block()
        } catch (e: Exception) {
            Log.w(TAG, "$what failed", e)
        }
    }
}
