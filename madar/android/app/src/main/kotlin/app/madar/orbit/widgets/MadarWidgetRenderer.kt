package app.madar.orbit.widgets

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Paint
import android.os.Build
import android.os.SystemClock
import android.util.Log
import android.util.SizeF
import android.view.Gravity
import android.view.View
import android.widget.RemoteViews
import app.madar.orbit.MainActivity
import app.madar.orbit.R
import org.json.JSONArray
import org.json.JSONObject

/**
 * Turns a widget's snapshot into RemoteViews.
 *
 * **Timeline.** The snapshot's pages start at prayer times, midnight, …: the
 * page shown is the last one that has started; the kind's alarm is armed for
 * the next one ([MadarWidgetAlarms]). After the snapshot's `until` the widget
 * shows its "Open Madar" text.
 *
 * **Language and direction.** Every text comes from the snapshot in the
 * app's language and digits (not the phone's). The app declares no
 * `supportsRtl`, and a widget must follow the app's language anyway, so
 * layouts are fixed left-to-right (`layoutDirection="ltr"`) and mirrored
 * here: text gravity is set to the reading side, a direction mark starts
 * every text (so a line opening with a Latin name or a number still reads
 * right to left in Arabic), and side-by-side pieces (the astrolabe, a
 * dose's time, the progress bar) have a left and a right slot.
 *
 * **Sizes.** Android 12+: one RemoteViews per size class, the launcher picks
 * ([sizesFor]). Before: the layout for the size in the widget's options.
 *
 * **Light / dark.** Colours, backgrounds and the astrolabe variant come from
 * resources with `-night` alternatives (styles toggle the day / night image
 * views), so the launcher re-resolves them when the phone switches; nothing
 * colour-related is set from code.
 *
 * Everything a layout may show is set on every draw (text or GONE, gravity,
 * paint flags): a launcher re-applies an update onto the views it has.
 */
object MadarWidgetRenderer {
    private const val TAG = "MadarWidgets"
    private const val RLM = "‏"
    private const val LRM = "‎"

    /** Row slots in the list layout. */
    private const val ROW_SLOTS = 6

    enum class Variant { SMALL, WIDE, TALL }

    /** Where a text sits: the reading side's start or end, or centred. */
    private enum class Align { START, END, CENTER }

    private class Row(val container: Int, val open: Int, val done: Int, val time: Int)

    private val ROWS = arrayOf(
        Row(R.id.widget_row_0, R.id.widget_row_0_open, R.id.widget_row_0_done, R.id.widget_row_0_time),
        Row(R.id.widget_row_1, R.id.widget_row_1_open, R.id.widget_row_1_done, R.id.widget_row_1_time),
        Row(R.id.widget_row_2, R.id.widget_row_2_open, R.id.widget_row_2_done, R.id.widget_row_2_time),
        Row(R.id.widget_row_3, R.id.widget_row_3_open, R.id.widget_row_3_done, R.id.widget_row_3_time),
        Row(R.id.widget_row_4, R.id.widget_row_4_open, R.id.widget_row_4_done, R.id.widget_row_4_time),
        Row(R.id.widget_row_5, R.id.widget_row_5_open, R.id.widget_row_5_done, R.id.widget_row_5_time),
    )

    /** A parsed snapshot. */
    class Doc(private val json: JSONObject) {
        val rtl: Boolean = json.optBoolean("rtl", false)
        val countsOnly: Boolean = json.optBoolean("private", true)
        val title: String = json.optString("title", "")
        val stale: String = json.optString("stale", "")
        val until: Long = json.optLong("until", 0L)
        val link: String? = optText(json, "link")
        val pages: List<JSONObject>

        init {
            val list = ArrayList<JSONObject>()
            val array = json.optJSONArray("pages") ?: JSONArray()
            for (i in 0 until array.length()) {
                array.optJSONObject(i)?.let { list.add(it) }
            }
            pages = list
        }

        /** The page shown at [now], or null once the data has run out. */
        fun pageAt(now: Long): JSONObject? {
            if (now >= until || pages.isEmpty()) return null
            var current = pages[0]
            for (p in pages) {
                if (!p.has("from") || p.optLong("from") <= now) current = p
            }
            return current
        }

        /** When the widget changes next after [now]. */
        fun nextChangeAfter(now: Long): Long {
            for (p in pages) {
                if (p.has("from") && p.optLong("from") > now) return p.optLong("from")
            }
            return until
        }

        companion object {
            const val VERSION = 1

            fun parse(text: String): Doc? = try {
                val json = JSONObject(text)
                if (json.optInt("v", 0) == VERSION) Doc(json) else null
            } catch (e: Exception) {
                Log.w(TAG, "unreadable widget snapshot", e)
                null
            }
        }
    }

    private class Images(val day: Bitmap, val night: Bitmap)

    fun updateAll(context: Context, kind: MadarWidgetKind) {
        val manager = AppWidgetManager.getInstance(context)
        update(context, manager, kind, kind.ids(context))
    }

    fun update(context: Context, manager: AppWidgetManager, kind: MadarWidgetKind, ids: IntArray) {
        if (ids.isEmpty()) {
            MadarWidgetAlarms.cancel(context, kind)
            return
        }
        val now = System.currentTimeMillis()
        val doc = MadarWidgetStore.readSnapshot(context, kind)?.let { Doc.parse(it) }
        val page = doc?.pageAt(now)
        val images = page?.let { loadImages(context, kind, optText(it, "img")) }
        for (id in ids) {
            val views = try {
                if (doc == null || page == null) {
                    placeholder(context, kind, doc)
                } else {
                    build(context, manager, id, kind, doc, page, images)
                }
            } catch (e: Exception) {
                Log.w(TAG, "could not draw the ${kind.wire} widget", e)
                placeholder(context, kind, null)
            }
            try {
                manager.updateAppWidget(id, views)
            } catch (e: Exception) {
                Log.w(TAG, "could not update the ${kind.wire} widget", e)
            }
        }
        if (doc != null && page != null) {
            MadarWidgetAlarms.schedule(context, kind, doc.nextChangeAfter(now))
        } else {
            MadarWidgetAlarms.cancel(context, kind)
        }
    }

    private fun build(
        context: Context,
        manager: AppWidgetManager,
        id: Int,
        kind: MadarWidgetKind,
        doc: Doc,
        page: JSONObject,
        images: Images?,
    ): RemoteViews {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val bySize = HashMap<SizeF, RemoteViews>()
            for ((size, variant) in sizesFor(kind)) {
                bySize[size] = views(context, kind, doc, page, images, variant)
            }
            return RemoteViews(bySize)
        }
        val options = manager.getAppWidgetOptions(id)
        val width = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0) ?: 0
        val height = options?.getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT, 0) ?: 0
        return views(context, kind, doc, page, images, variantFor(kind, width, height))
    }

    /** Android 12+: the size classes the launcher chooses from (dp). */
    private fun sizesFor(kind: MadarWidgetKind): List<Pair<SizeF, Variant>> = when (kind) {
        MadarWidgetKind.PRAYER, MadarWidgetKind.BUDGET -> listOf(
            Pair(SizeF(100f, 80f), Variant.SMALL),
            Pair(SizeF(200f, 80f), Variant.WIDE),
        )
        MadarWidgetKind.MEDS, MadarWidgetKind.TASKS -> listOf(
            Pair(SizeF(100f, 80f), Variant.SMALL),
            Pair(SizeF(200f, 80f), Variant.WIDE),
            Pair(SizeF(200f, 190f), Variant.TALL),
        )
    }

    /** Before Android 12: the size class of a widget [width] × [height] dp. */
    private fun variantFor(kind: MadarWidgetKind, width: Int, height: Int): Variant {
        if (width <= 0) {
            return if (kind == MadarWidgetKind.MEDS || kind == MadarWidgetKind.TASKS) Variant.WIDE else Variant.SMALL
        }
        if (width < 180) return Variant.SMALL
        return if (height >= 190) Variant.TALL else Variant.WIDE
    }

    private fun views(
        context: Context,
        kind: MadarWidgetKind,
        doc: Doc,
        page: JSONObject,
        images: Images?,
        variant: Variant,
    ): RemoteViews = when (kind) {
        MadarWidgetKind.PRAYER -> prayer(context, doc, page, images, variant)
        MadarWidgetKind.MEDS, MadarWidgetKind.TASKS ->
            if (doc.countsOnly || variant == Variant.SMALL || page.has("empty")) {
                counts(context, kind, doc, page)
            } else {
                list(context, kind, doc, page, if (variant == Variant.TALL) ROW_SLOTS else 3)
            }
        MadarWidgetKind.BUDGET -> budget(context, kind, doc, page, variant)
    }

    // ------------------------------------------------------------ layouts ----

    private fun prayer(context: Context, doc: Doc, page: JSONObject, images: Images?, variant: Variant): RemoteViews =
        if (variant == Variant.SMALL) prayerSmall(context, doc, page, images) else prayerWide(context, doc, page, images)

    /** 2×2: centred, so it reads the same in both directions. */
    private fun prayerSmall(context: Context, doc: Doc, page: JSONObject, images: Images?): RemoteViews {
        val rtl = doc.rtl
        val v = RemoteViews(context.packageName, R.layout.widget_prayer_small)
        text(v, R.id.widget_headline, optText(page, "big"), rtl, Align.CENTER)
        text(v, R.id.widget_detail, optText(page, "sub"), rtl, Align.CENTER)
        countdown(v, page, rtl, Align.CENTER)
        image(v, R.id.widget_astro_day, R.id.widget_astro_night, images)
        v.setOnClickPendingIntent(
            android.R.id.background,
            openIntent(context, MadarWidgetKind.PRAYER, 0, link(page, doc)),
        )
        return v
    }

    /** 4×2: the astrolabe on the reading side's start, the texts beside it. */
    private fun prayerWide(context: Context, doc: Doc, page: JSONObject, images: Images?): RemoteViews {
        val rtl = doc.rtl
        val v = RemoteViews(context.packageName, R.layout.widget_prayer_wide)
        text(v, R.id.widget_title, doc.title, rtl)
        text(v, R.id.widget_headline, optText(page, "big"), rtl)
        text(v, R.id.widget_detail, optText(page, "sub"), rtl)
        countdown(v, page, rtl, Align.START)
        text(v, R.id.widget_note, optText(page, "note"), rtl)
        val hasImage = images != null
        v.setViewVisibility(R.id.widget_slot_left, if (hasImage && !rtl) View.VISIBLE else View.GONE)
        v.setViewVisibility(R.id.widget_slot_right, if (hasImage && rtl) View.VISIBLE else View.GONE)
        image(v, R.id.widget_astro_day_left, R.id.widget_astro_night_left, images)
        image(v, R.id.widget_astro_day_right, R.id.widget_astro_night_right, images)
        v.setOnClickPendingIntent(
            android.R.id.background,
            openIntent(context, MadarWidgetKind.PRAYER, 0, link(page, doc)),
        )
        return v
    }

    /** Counts only (and small sizes, and empty states): title, big count, line, dots. */
    private fun counts(context: Context, kind: MadarWidgetKind, doc: Doc, page: JSONObject): RemoteViews {
        val rtl = doc.rtl
        val v = RemoteViews(context.packageName, R.layout.widget_count)
        text(v, R.id.widget_title, doc.title, rtl)
        val empty = optText(page, "empty")
        text(v, R.id.widget_headline, if (empty == null) optText(page, "big") else null, rtl)
        text(v, R.id.widget_detail, if (empty == null) optText(page, "sub") else null, rtl)
        text(v, R.id.widget_note, optText(page, "note"), rtl)
        text(v, R.id.widget_empty, empty, rtl)
        v.setOnClickPendingIntent(android.R.id.background, openIntent(context, kind, 0, link(page, doc)))
        return v
    }

    /** Details: header, next line and a row per item (each opening its link). */
    private fun list(context: Context, kind: MadarWidgetKind, doc: Doc, page: JSONObject, capacity: Int): RemoteViews {
        val rtl = doc.rtl
        val v = RemoteViews(context.packageName, R.layout.widget_list)
        val density = context.resources.displayMetrics.density
        val headerGap = (56 * density).toInt()
        text(v, R.id.widget_title, doc.title, rtl)
        v.setViewPadding(R.id.widget_title, if (rtl) headerGap else 0, 0, if (rtl) 0 else headerGap, 0)
        text(v, R.id.widget_headline, optText(page, "big"), rtl, Align.END)
        text(v, R.id.widget_detail, optText(page, "sub"), rtl)

        val rows = page.optJSONArray("rows") ?: JSONArray()
        val more = page.optJSONArray("more") ?: JSONArray()
        val total = if (more.length() > 0) more.length() + 1 else rows.length()
        val shown = minOf(rows.length(), capacity, ROW_SLOTS)
        val timeGap = (68 * density).toInt()
        for (i in 0 until ROW_SLOTS) {
            val slot = ROWS[i]
            val row = if (i < shown) rows.optJSONObject(i) else null
            if (row == null) {
                v.setViewVisibility(slot.container, View.GONE)
                continue
            }
            v.setViewVisibility(slot.container, View.VISIBLE)
            val state = row.optString("st", "o")
            val glyph = when (state) {
                "d" -> "✓"
                "s" -> "–"
                else -> "○"
            }
            val label = "$glyph  ${row.optString("text", "")}"
            val time = optText(row, "time")
            val done = state != "o"
            text(v, slot.open, if (done) null else label, rtl)
            text(v, slot.done, if (done) label else null, rtl)
            val strike = state == "s" || (state == "d" && kind == MadarWidgetKind.TASKS)
            v.setInt(
                slot.done,
                "setPaintFlags",
                if (strike) Paint.STRIKE_THRU_TEXT_FLAG or Paint.ANTI_ALIAS_FLAG else Paint.ANTI_ALIAS_FLAG,
            )
            val gap = if (time == null) 0 else timeGap
            val left = if (rtl) gap else 0
            val right = if (rtl) 0 else gap
            v.setViewPadding(slot.open, left, 0, right, 0)
            v.setViewPadding(slot.done, left, 0, right, 0)
            text(v, slot.time, time, rtl, Align.END)
            v.setOnClickPendingIntent(
                slot.container,
                openIntent(context, kind, i + 1, optText(row, "link") ?: link(page, doc)),
            )
        }
        val hidden = total - shown
        text(v, R.id.widget_more, if (hidden > 0) optArrayText(more, hidden - 1) else null, rtl)
        text(v, R.id.widget_empty, optText(page, "empty"), rtl)
        v.setOnClickPendingIntent(android.R.id.background, openIntent(context, kind, 0, link(page, doc)))
        return v
    }

    private fun budget(context: Context, kind: MadarWidgetKind, doc: Doc, page: JSONObject, variant: Variant): RemoteViews {
        val rtl = doc.rtl
        val v = RemoteViews(context.packageName, R.layout.widget_budget)
        text(v, R.id.widget_title, doc.title, rtl)
        val empty = optText(page, "empty")
        val warn = page.optBoolean("warn", false)
        val headline = if (empty == null) optText(page, "big") else null
        text(v, R.id.widget_headline, if (warn) null else headline, rtl)
        text(v, R.id.widget_headline_warn, if (warn) headline else null, rtl)
        text(v, R.id.widget_detail, if (empty == null) optText(page, "sub") else null, rtl)
        text(v, R.id.widget_note, if (empty == null && variant != Variant.SMALL) optText(page, "note") else null, rtl)
        text(v, R.id.widget_empty, empty, rtl)
        val bar = if (empty == null && page.has("bar")) page.optInt("bar", 0).coerceIn(0, 1000) else -1
        val shownBar = when {
            bar < 0 -> 0
            warn && rtl -> R.id.widget_bar_warn_rtl
            warn -> R.id.widget_bar_warn_ltr
            rtl -> R.id.widget_bar_rtl
            else -> R.id.widget_bar_ltr
        }
        v.setViewVisibility(R.id.widget_bars, if (bar < 0) View.GONE else View.VISIBLE)
        for (id in intArrayOf(R.id.widget_bar_ltr, R.id.widget_bar_rtl, R.id.widget_bar_warn_ltr, R.id.widget_bar_warn_rtl)) {
            if (id == shownBar) {
                v.setViewVisibility(id, View.VISIBLE)
                v.setProgressBar(id, 1000, bar, false)
            } else {
                v.setViewVisibility(id, View.GONE)
            }
        }
        v.setOnClickPendingIntent(android.R.id.background, openIntent(context, kind, 0, link(page, doc)))
        return v
    }

    /** No data yet, or it ran out: "Open Madar". */
    fun placeholder(context: Context, kind: MadarWidgetKind, doc: Doc?): RemoteViews {
        val v = RemoteViews(context.packageName, R.layout.widget_placeholder)
        val rtl = doc?.rtl ?: (context.resources.configuration.layoutDirection == View.LAYOUT_DIRECTION_RTL)
        val title = doc?.title?.takeIf { it.isNotEmpty() } ?: context.getString(kind.titleRes)
        val message = doc?.stale?.takeIf { it.isNotEmpty() } ?: context.getString(R.string.widget_placeholder)
        text(v, R.id.widget_title, title, rtl, Align.CENTER)
        text(v, R.id.widget_message, message, rtl, Align.CENTER)
        v.setOnClickPendingIntent(android.R.id.background, openIntent(context, kind, 0, doc?.link))
        return v
    }

    // ------------------------------------------------------------ helpers ----

    /**
     * Shows [value] (reading in the app's direction, [rtl]) at [align], or
     * hides the view when there is nothing to show.
     */
    private fun text(v: RemoteViews, id: Int, value: String?, rtl: Boolean, align: Align = Align.START) {
        if (value.isNullOrEmpty()) {
            v.setViewVisibility(id, View.GONE)
            return
        }
        v.setViewVisibility(id, View.VISIBLE)
        v.setTextViewText(id, mark(value, rtl))
        v.setInt(id, "setGravity", gravity(rtl, align))
    }

    private fun gravity(rtl: Boolean, align: Align): Int = when (align) {
        Align.CENTER -> Gravity.CENTER
        Align.START -> (if (rtl) Gravity.RIGHT else Gravity.LEFT) or Gravity.CENTER_VERTICAL
        Align.END -> (if (rtl) Gravity.LEFT else Gravity.RIGHT) or Gravity.CENTER_VERTICAL
    }

    /** A direction mark first: the paragraph reads in the app's direction. */
    private fun mark(value: String, rtl: Boolean): String = (if (rtl) RLM else LRM) + value

    /** The ticking countdown ([android.widget.Chronometer], counting down). */
    private fun countdown(v: RemoteViews, page: JSONObject, rtl: Boolean, align: Align) {
        val target = page.optLong("cd", 0L)
        if (target <= 0L) {
            v.setChronometer(R.id.widget_countdown, SystemClock.elapsedRealtime(), null, false)
            v.setViewVisibility(R.id.widget_countdown, View.GONE)
            return
        }
        val base = SystemClock.elapsedRealtime() + (target - System.currentTimeMillis())
        val format = mark(chronometerFormat(optText(page, "cdFmt")), rtl)
        v.setViewVisibility(R.id.widget_countdown, View.VISIBLE)
        v.setChronometer(R.id.widget_countdown, base, format, true)
        v.setChronometerCountDown(R.id.widget_countdown, true)
        v.setInt(R.id.widget_countdown, "setGravity", gravity(rtl, align))
    }

    /** [format] with exactly one `%s` and every other `%` escaped. */
    private fun chronometerFormat(format: String?): String {
        if (format == null) return "%s"
        val at = format.indexOf("%s")
        if (at < 0) return "%s"
        val before = format.substring(0, at).replace("%", "%%")
        val after = format.substring(at + 2).replace("%", "%%")
        return "$before%s$after"
    }

    private fun image(v: RemoteViews, dayId: Int, nightId: Int, images: Images?) {
        if (images == null) return
        v.setImageViewBitmap(dayId, images.day)
        v.setImageViewBitmap(nightId, images.night)
    }

    private fun loadImages(context: Context, kind: MadarWidgetKind, key: String?): Images? {
        if (key == null) return null
        val day = decode(MadarWidgetStore.image(context, kind, "${key}_light")) ?: return null
        val night = decode(MadarWidgetStore.image(context, kind, "${key}_dark")) ?: day
        return Images(day, night)
    }

    private fun decode(file: java.io.File?): Bitmap? {
        if (file == null) return null
        return try {
            BitmapFactory.decodeFile(file.absolutePath)
        } catch (e: Exception) {
            Log.w(TAG, "could not decode ${file.name}", e)
            null
        }
    }

    private fun link(page: JSONObject, doc: Doc): String? = optText(page, "link") ?: doc.link

    /**
     * Opens Madar (at [route] when given): `MainActivity` with the action
     * [MadarWidgetsChannel.ACTION_OPEN] – Dart takes the route through the
     * channel ([MadarWidgetsChannel]) and routes under the app lock. No
     * intent data: Flutter would treat it as a deep link.
     */
    private fun openIntent(context: Context, kind: MadarWidgetKind, slot: Int, route: String?): android.app.PendingIntent {
        val intent = Intent(context, MainActivity::class.java)
            .setAction(MadarWidgetsChannel.ACTION_OPEN)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        if (route != null) intent.putExtra(MadarWidgetsChannel.EXTRA_ROUTE, route)
        return android.app.PendingIntent.getActivity(
            context,
            kind.requestBase + 10 + slot,
            intent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE,
        )
    }
}

/** A non-empty string field of [json], or null. */
internal fun optText(json: JSONObject, name: String): String? {
    if (!json.has(name) || json.isNull(name)) return null
    val value = json.optString(name, "")
    return if (value.isEmpty()) null else value
}

private fun optArrayText(array: JSONArray, index: Int): String? {
    if (index < 0 || index >= array.length()) return null
    val value = array.optString(index, "")
    return if (value.isEmpty()) null else value
}
