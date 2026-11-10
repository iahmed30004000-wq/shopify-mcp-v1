package app.madar.orbit

import android.content.ContentResolver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.provider.OpenableColumns
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.InputStream

/**
 * An answer another app hands to Madar (`app.madar.orbit/share`).
 *
 * Part 3's AI bridge is a round trip over files and the clipboard: Madar
 * writes one JSON for an AI app and takes a «خطة مدار» back. This channel is
 * the third way back in, beside the paste box and the file picker — the
 * share sheet of Gemini, ChatGPT or a file manager:
 *
 * * `ACTION_SEND` of `text/plain` or `application/json` — the answer as text
 *   (`EXTRA_TEXT`) or as a file (`EXTRA_STREAM`);
 * * `ACTION_VIEW` of a `.json` file — "open with Madar".
 *
 * Nothing is fetched and nothing is kept: the text is read once and handed
 * to Dart, which only opens «استيراد خطة» with it. Not a row of the owner's
 * data is touched until he approves one suggestion by hand.
 *
 * Two ways in, like the notification launch in [MainActivity]:
 *
 * * the share **launched** the app: the intent is on the activity before
 *   Dart runs, so it is held until Dart asks ([TAKE]) — once, so coming
 *   back from recents never re-imports the same answer;
 * * the share reached a **running** app: `onNewIntent` pushes it straight to
 *   Dart ([SHARED]).
 *
 * A payload larger than [MAX_BYTES] (the contract's own 2 MiB ceiling,
 * which the validator enforces again in Dart) is dropped here rather than
 * read into memory: a plan is a short list of suggestions, and a 50 MB file
 * shared by mistake must not be able to hurt the app.
 */
object ShareIntakeChannel {
    private const val CHANNEL = "app.madar.orbit/share"
    private const val TAKE = "takeLaunchShare"
    private const val SHARED = "shared"

    /** `PlanLimits.maxPayloadBytes` – the same ceiling the validator uses. */
    private const val MAX_BYTES = 2 * 1024 * 1024

    private var channel: MethodChannel? = null

    /** The share that launched the app, until Dart takes it. */
    private var pending: Map<String, Any?>? = null

    /**
     * Binds the channel to [flutterEngine]. The channel lives on the
     * engine, which outlives the activity (audio_service caches it), so it
     * is bound again by every new activity and never torn down.
     *
     * [deliverPending] is for exactly that case: the engine is **warm**, so
     * Dart has long since made its one `takeLaunchShare` call, and a share
     * that arrived while no activity was attached would otherwise sit
     * unread. It is pushed as a new share instead.
     */
    fun register(flutterEngine: FlutterEngine, deliverPending: Boolean = false) {
        val created = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        created.setMethodCallHandler { call, result ->
            when (call.method) {
                TAKE -> {
                    val payload = pending
                    pending = null
                    result.success(payload)
                }
                else -> result.notImplemented()
            }
        }
        channel = created
        val waiting = pending
        if (deliverPending && waiting != null) {
            pending = null
            created.invokeMethod(SHARED, waiting)
        }
    }

    /**
     * Reads [intent] as a shared answer and either hands it to a running
     * Dart side or holds it for the first `takeLaunchShare`. Returns true
     * when the intent really was a share Madar understands.
     */
    fun offer(context: Context, intent: Intent?, running: Boolean): Boolean {
        val payload = payloadOf(context, intent) ?: return false
        val live = channel
        if (running && live != null) live.invokeMethod(SHARED, payload) else pending = payload
        return true
    }

    /** The text of a share intent, with the file's name when it had one. */
    private fun payloadOf(context: Context, intent: Intent?): Map<String, Any?>? {
        if (intent == null) return null
        // Re-launched from recents with the old intent: not a new share.
        if ((intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0) return null
        return when (intent.action) {
            Intent.ACTION_SEND -> {
                val text = intent.getStringExtra(Intent.EXTRA_TEXT)
                if (!text.isNullOrBlank()) {
                    mapOf("text" to text, "name" to null)
                } else {
                    @Suppress("DEPRECATION")
                    val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                    uri?.let { fileOf(context, it) }
                }
            }
            Intent.ACTION_VIEW -> intent.data?.let { fileOf(context, it) }
            else -> null
        }
    }

    /** [uri]'s text, when it is small enough and readable. */
    private fun fileOf(context: Context, uri: Uri): Map<String, Any?>? {
        val resolver = context.contentResolver
        return try {
            val size = sizeOf(resolver, uri)
            if (size > MAX_BYTES) return null
            val text = resolver.openInputStream(uri)?.use { stream -> readUpTo(stream, MAX_BYTES) } ?: return null
            if (text.isBlank()) null else mapOf("text" to text, "name" to nameOf(resolver, uri))
        } catch (_: Exception) {
            // An unreadable or revoked URI is simply not a share.
            null
        }
    }

    /** [stream] decoded as UTF-8, or null when it holds more than [limit]. */
    private fun readUpTo(stream: InputStream, limit: Int): String? {
        val out = ByteArrayOutputStream()
        val buffer = ByteArray(16 * 1024)
        while (out.size() <= limit) {
            val read = stream.read(buffer)
            if (read <= 0) break
            out.write(buffer, 0, read)
        }
        return if (out.size() > limit) null else String(out.toByteArray(), Charsets.UTF_8)
    }

    /** -1 when the provider does not say (then the read itself is bounded). */
    private fun sizeOf(resolver: ContentResolver, uri: Uri): Long = try {
        resolver.query(uri, arrayOf(OpenableColumns.SIZE), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst() && !cursor.isNull(0)) cursor.getLong(0) else -1L
        } ?: -1L
    } catch (_: Exception) {
        -1L
    }

    private fun nameOf(resolver: ContentResolver, uri: Uri): String? = try {
        resolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { cursor ->
            if (cursor.moveToFirst() && !cursor.isNull(0)) cursor.getString(0) else null
        } ?: uri.lastPathSegment
    } catch (_: Exception) {
        null
    }
}
