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
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import org.json.JSONObject

/**
 * FlutterFragmentActivity is required by local_auth (BiometricPrompt needs a
 * FragmentActivity host).
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
 */
class MainActivity : FlutterFragmentActivity() {
    companion object {
        private const val CHANNEL = "app.madar.orbit/adhan"
        private const val ALARMS_CHANNEL = "app.madar.orbit/alarms"

        /** flutter_local_notifications' alarm receiver (its PendingIntents' target). */
        private const val PLUGIN_ALARM_RECEIVER =
            "com.dexterous.flutterlocalnotifications.ScheduledNotificationReceiver"

        /** flutter_local_notifications' launch intent (action + extras). */
        private const val SELECT_NOTIFICATION = "SELECT_NOTIFICATION"
        private const val EXTRA_PAYLOAD = "payload"
        private const val EXTRA_NOTIFICATION_ID = "notificationId"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        // A restored activity (process death, then back from recents) still
        // carries the intent that first launched it: never a lock-screen
        // launch then.
        if (savedInstanceState == null && isOwnAdhanLaunch(intent)) setLockScreenMode(true)
        super.onCreate(savedInstanceState)
    }

    override fun onNewIntent(intent: Intent) {
        if (isOwnAdhanLaunch(intent)) setLockScreenMode(true)
        super.onNewIntent(intent)
    }

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            try {
                result.success(handle(call))
            } catch (e: Exception) {
                result.error("adhan_system", e.message, null)
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARMS_CHANNEL).setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "armed" -> {
                        val ids = (call.argument<List<*>>("ids") ?: emptyList<Any>())
                            .mapNotNull { (it as? Number)?.toInt() }
                        result.success(armedAlarmIds(ids))
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("alarms", e.message, null)
            }
        }
    }

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
    private fun armedAlarmIds(ids: List<Int>): List<Int> {
        val component = ComponentName(this, PLUGIN_ALARM_RECEIVER)
        val flags = PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
        return ids.filter { id ->
            PendingIntent.getBroadcast(this, id, Intent().setComponent(component), flags) != null
        }
    }

    private fun handle(call: MethodCall): Any? = when (call.method) {
        "lockScreen" -> {
            setLockScreenMode(call.argument<Boolean>("enabled") == true)
            null
        }
        "isKeyguardLocked" -> (getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager).isKeyguardLocked
        "canUseFullScreenIntent" -> if (Build.VERSION.SDK_INT >= 34) {
            (getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).canUseFullScreenIntent()
        } else {
            true
        }
        "alarmVolume" -> {
            val audio = getSystemService(Context.AUDIO_SERVICE) as AudioManager
            mapOf(
                "current" to audio.getStreamVolume(AudioManager.STREAM_ALARM),
                "max" to audio.getStreamMaxVolume(AudioManager.STREAM_ALARM),
            )
        }
        "soundsDirectory" -> AdhanSoundProvider.directory(this).absolutePath
        "soundUri" -> {
            val name = call.argument<String>("name") ?: ""
            AdhanSoundProvider.uriFor(this, name)?.let { uri ->
                AdhanSoundProvider.grantToSystem(this, uri)
                uri.toString()
            }
        }
        "openSoundSettings" -> open(Intent(Settings.ACTION_SOUND_SETTINGS))
        "openNotificationSettings" -> {
            val channel = call.argument<String>("channelId")
            val intent = if (channel != null) {
                Intent(Settings.ACTION_CHANNEL_NOTIFICATION_SETTINGS)
                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                    .putExtra(Settings.EXTRA_CHANNEL_ID, channel)
            } else {
                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
            }
            open(intent)
        }
        "openFullScreenIntentSettings" -> if (Build.VERSION.SDK_INT >= 34) {
            open(Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT, Uri.parse("package:$packageName")))
        } else {
            open(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
        }
        "openBatterySettings" -> open(Intent(Settings.ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS)) ||
            open(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
        else -> throw IllegalArgumentException("unknown method ${call.method}")
    }

    private fun open(intent: Intent): Boolean = try {
        startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        true
    } catch (_: ActivityNotFoundException) {
        false
    } catch (_: SecurityException) {
        false
    }
}
