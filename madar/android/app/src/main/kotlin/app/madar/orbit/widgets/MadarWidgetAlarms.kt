package app.madar.orbit.widgets

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.os.Build
import android.util.Log

/**
 * One alarm per widget kind, at the moment its snapshot moves to its next
 * page (a prayer time, midnight) or runs out: the provider then redraws
 * ([MadarWidgetProvider.ACTION_TICK]) and arms the next one.
 *
 * `RTC`, not `RTC_WAKEUP`: a widget only matters while the screen is on, so
 * an alarm due while the phone sleeps waits until it wakes (no wake-ups, no
 * battery cost). Exact where the app may (USE_EXACT_ALARM from Android 13,
 * SCHEDULE_EXACT_ALARM on 12 – both in the manifest for the adhan), else the
 * system's inexact delivery.
 */
object MadarWidgetAlarms {
    private const val TAG = "MadarWidgets"

    fun schedule(context: Context, kind: MadarWidgetKind, atMillis: Long) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        val at = maxOf(atMillis, System.currentTimeMillis() + 1000L)
        val pending = pendingIntent(context, kind)
        try {
            if (canScheduleExact(manager)) {
                manager.setExact(AlarmManager.RTC, at, pending)
            } else {
                manager.set(AlarmManager.RTC, at, pending)
            }
        } catch (e: SecurityException) {
            Log.w(TAG, "exact alarm refused, using an inexact one", e)
            manager.set(AlarmManager.RTC, at, pending)
        }
    }

    fun cancel(context: Context, kind: MadarWidgetKind) {
        val manager = context.getSystemService(Context.ALARM_SERVICE) as? AlarmManager ?: return
        manager.cancel(pendingIntent(context, kind))
    }

    private fun canScheduleExact(manager: AlarmManager): Boolean =
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) manager.canScheduleExactAlarms() else true

    private fun pendingIntent(context: Context, kind: MadarWidgetKind): PendingIntent {
        val intent = Intent(context, kind.providerClass).setAction(MadarWidgetProvider.ACTION_TICK)
        return PendingIntent.getBroadcast(
            context,
            kind.requestBase,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }
}
