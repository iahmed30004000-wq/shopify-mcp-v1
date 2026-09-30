package app.madar.orbit.widgets

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle

/**
 * The widgets' providers: they draw from the snapshot Dart wrote
 * ([MadarWidgetStore]) and need nothing else – no Flutter engine, no
 * database – so they work while Madar is closed and locked.
 *
 * * `onUpdate` (added, the periodic update, after a reboot) and the kind's
 *   alarm ([ACTION_TICK]: the next page) redraw; so do clock and time-zone
 *   changes.
 * * A widget without data shows "Open Madar" and asks a running app to
 *   write it ([MadarWidgetsChannel.notifyChanged]).
 * * When the last widget of a kind is removed, its data is deleted.
 */
abstract class MadarWidgetProvider : AppWidgetProvider() {
    abstract val kind: MadarWidgetKind

    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray) {
        MadarWidgetRenderer.update(context, appWidgetManager, kind, appWidgetIds)
        if (!MadarWidgetStore.hasSnapshot(context, kind)) MadarWidgetsChannel.notifyChanged()
    }

    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        MadarWidgetRenderer.update(context, appWidgetManager, kind, intArrayOf(appWidgetId))
    }

    override fun onEnabled(context: Context) {
        MadarWidgetsChannel.notifyChanged()
    }

    override fun onDisabled(context: Context) {
        MadarWidgetStore.remove(context, kind)
        MadarWidgetAlarms.cancel(context, kind)
        MadarWidgetsChannel.notifyChanged()
    }

    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            ACTION_TICK, Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED ->
                MadarWidgetRenderer.updateAll(context, kind)
            else -> super.onReceive(context, intent)
        }
    }

    companion object {
        /** The kind's alarm: its next page is due. */
        const val ACTION_TICK = "app.madar.orbit.widgets.TICK"
    }
}

class PrayerWidgetProvider : MadarWidgetProvider() {
    override val kind: MadarWidgetKind
        get() = MadarWidgetKind.PRAYER
}

class MedsWidgetProvider : MadarWidgetProvider() {
    override val kind: MadarWidgetKind
        get() = MadarWidgetKind.MEDS
}

class TasksWidgetProvider : MadarWidgetProvider() {
    override val kind: MadarWidgetKind
        get() = MadarWidgetKind.TASKS
}

class BudgetWidgetProvider : MadarWidgetProvider() {
    override val kind: MadarWidgetKind
        get() = MadarWidgetKind.BUDGET
}
