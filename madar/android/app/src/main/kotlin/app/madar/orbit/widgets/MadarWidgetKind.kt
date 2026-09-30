package app.madar.orbit.widgets

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import app.madar.orbit.R

/**
 * The four home-screen widgets. [wire] is the name Dart uses for the same
 * widget (`MadarWidgetKind.wire` in lib/features/widgets) and the name of its
 * files; never rename one.
 *
 * [requestBase] spaces the request codes of the widget's PendingIntents
 * (its alarm, its taps) so no two widgets ever share one.
 */
enum class MadarWidgetKind(
    val wire: String,
    val providerClass: Class<out MadarWidgetProvider>,
    val requestBase: Int,
    val titleRes: Int,
) {
    PRAYER("prayer", PrayerWidgetProvider::class.java, 7100, R.string.widget_prayer_title),
    MEDS("meds", MedsWidgetProvider::class.java, 7200, R.string.widget_meds_title),
    TASKS("tasks", TasksWidgetProvider::class.java, 7300, R.string.widget_tasks_title),
    BUDGET("budget", BudgetWidgetProvider::class.java, 7400, R.string.widget_budget_title);

    fun component(context: Context): ComponentName = ComponentName(context, providerClass)

    /** The ids of this widget's instances on the home screen(s). */
    fun ids(context: Context): IntArray = try {
        AppWidgetManager.getInstance(context).getAppWidgetIds(component(context)) ?: IntArray(0)
    } catch (_: Exception) {
        IntArray(0)
    }

    fun isInstalled(context: Context): Boolean = ids(context).isNotEmpty()

    companion object {
        fun fromWire(wire: String?): MadarWidgetKind? = values().firstOrNull { it.wire == wire }
    }
}
