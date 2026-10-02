package app.madar.orbit

import android.app.KeyguardManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.ActivityNotFoundException
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import android.view.WindowManager
import app.madar.orbit.savedgames.SavedGamesChannel
import app.madar.orbit.together.TogetherChannels
import app.madar.orbit.widgets.MadarWidgetsChannel
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import com.ryanheise.audioservice.AudioServicePlugin
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.engine.FlutterEngineCache
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject
import java.lang.ref.WeakReference

/**
 * AudioServiceFragmentActivity: a FlutterFragmentActivity (local_auth's
 * BiometricPrompt needs a FragmentActivity host) whose FlutterEngine is the
 * one audio_service caches and shares with its background media service.
 * audio_service's plugin looks that engine up every time it attaches to an
 * activity and *creates and runs a second one* (a second `main()`: another
 * database connection, scheduler and audio engine in the same process) when
 * the activity did not provide it – so the base class is not optional.
 *
 * The engine now outlives the activity (the user backs out, the process
 * stays): a later launch of a new activity attaches to the running Dart app,
 * where flutter_local_notifications neither re-reads the launch intent nor
 * reports it (it only does for `onNewIntent`). A notification launch into a
 * warm engine is therefore forwarded as a new intent ([warmLaunch]).
 *
 * Adhan: when one of Madar's own adhan notifications launches the activity
 * through its full-screen intent, the window is allowed over the lock screen
 * and turns the screen on – only for that launch. The manifest deliberately
 * does not set `showWhenLocked` / `turnScreenOn` for the whole activity:
 * otherwise Madar, left open when the phone locks, would be readable over the
 * keyguard. Dart clears the mode when the adhan screen closes
 * (`app.madar.orbit/adhan` → `lockScreen(false)`) and whenever the app
 * started without an adhan to show.
 *
 * Alarms: `app.madar.orbit/alarms` → `armed(ids)` tells Dart which of the
 * notification plugin's alarms still exist (see [armedAlarmIds]).
 *
 * Both channels answer from the application context, so they keep working
 * while the engine runs without an activity; only `lockScreen` needs the
 * attached one ([channelHost]).
 */
class MainActivity : AudioServiceFragmentActivity() {
    companion object {
        private const val CHANNEL = "app.madar.orbit/adhan"
        private const val ALARMS_CHANNEL = "app.madar.orbit/alarms"

        /** The activity the channels above currently call into. */
        private var channelHost: WeakReference<MainActivity>? = null

        /**
         * The display mode flutter_displaymode chose (90 / 120 Hz) for the
         * previous window; a warm engine never asks again for the next one.
         */
        private var displayModeId = 0

        /** flutter_local_notifications' alarm receiver (its PendingIntents' target). */
        private const val PLUGIN_ALARM_RECEIVER =
            "com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"

        /** flutter_local_notifications' launch intent (action + extras). */
        private const val SELECT_NOTIFICATION = "SELECT_NOTIFICATION"
        private const val SELECT_FOREGROUND_NOTIFICATION = "SELECT_FOREGROUND_NOTIFICATION"
        private const val EXTRA_PAYLOAD = "payload"
        private const val EXTRA_NOTIFICATION_ID = "notificationId"

        /** [handleAdhan]'s answer for a method this side does not know. */
        private object NotImplemented

        /**
         * The ids among [ids] whose alarm still exists. flutter_local_notifications
         * arms every scheduled notification as
         * `PendingIntent.getBroadcast(context, id, Intent(context, ScheduledNotificationReceiver), FLAG_UPDATE_CURRENT or FLAG_IMMUTABLE)`;
         * a force stop (the user, an OEM battery manager) cancels the app's alarms
         * *and* its pending intents, while the plugin's own list of scheduled
         * notifications survives. `FLAG_NO_CREATE` with the same request code,
         * intent (explicit component, no action / data) and mutability flag finds
         * the pending intent only while it exists.
         */
        private fun armedAlarmIds(context: Context, ids: List<Int>): List<Int> {
            val component = ComponentName(context, PLUGIN_ALARM_RECEIVER)
            val flags = PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
            return ids.filter { id ->
                PendingIntent.getBroadcast(context, id, Intent().setComponent(component), flags) != null
            }
        }

        private fun handleAdhan(context: Context, call: MethodCall): Any? = when (call.method) {
            "lockScreen" -> {
                // No activity attached: nothing is over the lock screen to clear,
                // and nothing to put there.
                channelHost?.get()?.setLockScreenMode(call.argument<Boolean>("enabled") == true)
                null
            }
            "isKeyguardLocked" -> (context.getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager).isKeyguardLocked
            "canUseFullScreenIntent" -> if (Build.VERSION.SDK_INT >= 34) {
                (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).canUseFullScreenIntent()
            } else {
                true
            }
            "alarmVolume" -> {
                val audio = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
                mapOf(
                    "current" to audio.getStreamVolume(AudioManager.STREAM_ALARM),
                    "max" to audio.getStreamMaxVolume(AudioManager.STREAM_ALARM),
                )
            }
            "soundsDirectory" -> AdhanSoundProvider.directory(context).absolutePath
            "soundUri" -> {
                val name = call.argument<String>("name") ?: ""
                AdhanSoundProvider.uriFor(context, name)?.let { uri ->
                    AdhanSoundProvider.grantToSystem(context, uri)
                    uri.toString()
                }
            }
            "openSoundSettings" -> open(context, Intent(Settings.ACTION_SOUND_SETTINGS))
            "openNotificationSettings" -> {
                val channel = call.argument<String>("channelId")
                val intent = if (channel != null) {
                    Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                        .putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                        .putExtra(Settings.EXTRA_CHANNEL_ID, channel)
                } else {
                    Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName)
                }
                open(context, intent)
            }
            "openFullScreenIntentSettings" -> if (Build.VERSION.SDK_INT >= 34) {
                open(context, Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:${context.packageName}")))
            } else {
                open(
                    context,
                    Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.packageName),
                )
            }
            "openBatterySettings" -> open(context, Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)) ||
                open(context, Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}")))
            else -> NotImplemented
        }

        /** Opens a system screen – from the attached activity when there is one. */
        private fun open(context: Context, intent: Intent): Boolean = try {
            (channelHost?.get() ?: context).startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            true
        } catch (_: ActivityNotFoundException) {
            false
        } catch (_: SecurityException) {
            false
        }
    }

    /** A notification launch to hand to an already running Dart app. */
    private var warmLaunch: Intent? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Before super.onCreate, which creates the shared engine if needed.
        val warm = FlutterEngineCache.getInstance().contains(AudioServicePlugin.getFlutterEngineId())
        // A restored activity (process death, then back from recents) still
        // carries the intent that first launched it: never a lock-screen
        // launch then.
        if (savedInstanceState == null) {
            if (isOwnAdhanLaunch(intent)) setLockScreenMode(true)
            if (warm && isNotificationLaunch(intent)) warmLaunch = intent
        }
        if (warm && displayModeId != 0) {
            window.attributes = window.attributes.apply { preferredDisplayModeId = displayModeId }
        }
        super.onCreate(savedInstanceState)
    }

    override fun onDestroy() {
        displayModeId = window.attributes.preferredDisplayModeId
        super.onDestroy()
    }

    override fun onNewIntent(intent: Intent) {
        if (isOwnAdhanLaunch(intent)) setLockScreenMode(true)
        super.onNewIntent(intent)
    }

    /** One of flutter_local_notifications' own launches (tap / full-screen), not a re-launch from recents. */
    private fun isNotificationLaunch(intent: Intent?): Boolean =
        intent != null &&
            (intent.action == SELECT_NOTIFICATION || intent.action == SELECT_FOREGROUND_NOTIFICATION) &&
            (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) == 0

    /**
     * A full-screen launch of an adhan notification Madar itself posted and
     * that is still showing (so another app cannot forge the intent to put
     * Madar over the lock screen).
     */
    private fun isOwnAdhanLaunch(intent: Intent?): Boolean {
        if (intent == null || intent.action != SELECT_NOTIFICATION) return false
        // Re-launched from recents with the old intent: not a new adhan (the
        // notification plugin ignores such launches too, so Dart would never
        // show the adhan screen nor clear the mode).
        if ((intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0) return false
        val payload = intent.getStringExtra(EXTRA_PAYLOAD) ?: return false
        val lockScreen = try {
            val o = JSONObject(payload)
            o.optString("ns") == "adhan" && o.optInt("ls", 0) == 1
        } catch (_: Exception) {
            false
        }
        if (!lockScreen) return false
        val id = intent.getIntExtra(EXTRA_NOTIFICATION_ID, Int.MIN_VALUE)
        if (id == Int.MIN_VALUE) return false
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return try {
            manager.activeNotifications.any { it.id == id }
        } catch (_: Exception) {
            false
        }
    }

    private fun setLockScreenMode(enabled: Boolean) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(enabled)
            setTurnScreenOn(enabled)
        } else {
            @Suppress("DEPRECATION")
            val flags = WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            if (enabled) window.addFlags(flags) else window.clearFlags(flags)
        }
        if (enabled) {
            window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        channelHost = WeakReference(this)
        // The handlers hold the application context only: the engine (and
        // Dart's adhan scheduler) outlives this activity, and must still get
        // the sound URIs / armed alarms when no activity is attached.
        val app = applicationContext
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                val answer = handleAdhan(app, call)
                if (answer === NotImplemented) result.notImplemented() else result.success(answer)
            } catch (e: Exception) {
                result.error("adhan_system", e.message, null)
            }
        }
        MethodChannel(messenger, ALARMS_CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "armed" -> {
                        val ids = (call.argument<List<*>>("ids") ?: emptyList<Any>())
                            .mapNotNull { (it as? Number)?.toInt() }
                        result.success(armedAlarmIds(app, ids))
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("alarms", e.message, null)
            }
        }
        MadarWidgetsChannel.register(flutterEngine, app)
        SavedGamesChannel.register(flutterEngine)
        TogetherChannels.register(flutterEngine)
        // The plugins are attached to this activity by now (the engine attaches
        // them before it calls configureFlutterEngine): deliver the launch the
        // way flutter_local_notifications reports a tap to a running app.
        warmLaunch?.let {
            warmLaunch = null
            flutterEngine.activityControlSurface.onNewIntent(it)
        }
    }

    /** The engine outlives this activity: window calls (lock-screen mode) no longer reach it. */
    override fun cleanUpFlutterEngine(flutterEngine: FlutterEngine) {
        if (channelHost?.get() === this) channelHost = null
        super.cleanUpFlutterEngine(flutterEngine)
    }
}
