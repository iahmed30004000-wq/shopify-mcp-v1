package app.madar.orbit.widgets

import android.content.Context
import android.util.Log
import java.io.File
import java.io.FileOutputStream

/**
 * The widgets' data in app-private storage (`no_backup/madar_widgets/`,
 * never backed up, never shared):
 *
 * * `<kind>.bin` – the snapshot JSON Dart built, encrypted
 *   ([MadarWidgetCrypto]);
 * * `<kind>-<image>.png` – its images (the prayer widget's astrolabes: no
 *   personal data), `<image>` being `<key>_light` / `<key>_dark`.
 *
 * Written only for widgets that are on a home screen ([writeIfInstalled]),
 * deleted when the last one of a kind is removed and on "delete all data".
 * Writes are atomic (temp file + rename), so a provider drawing at the same
 * moment reads the old file or the new one. Writing and deleting hold this
 * object's lock: the app's write (on the channel's thread) and the
 * provider's `onDisabled` (main thread) never interleave, so a widget
 * removed while the app was writing never keeps its data.
 */
object MadarWidgetStore {
    private const val TAG = "MadarWidgets"
    private const val DIRECTORY = "madar_widgets"

    private val SAFE_IMAGE = Regex("^[a-z0-9_]{1,48}$")

    fun directory(context: Context): File = File(context.noBackupFilesDir, DIRECTORY).apply { mkdirs() }

    private fun snapshotFile(context: Context, kind: MadarWidgetKind): File =
        File(directory(context), "${kind.wire}.bin")

    /**
     * Writes [kind]'s snapshot [json] (encrypted) and, when given, replaces
     * its [images] – only if [installed] (asked under the lock) still says a
     * widget of it is on a home screen. True when written.
     */
    fun writeIfInstalled(
        context: Context,
        kind: MadarWidgetKind,
        json: String,
        images: Map<String, ByteArray>?,
        installed: () -> Boolean,
    ): Boolean = synchronized(this) {
        if (installed()) {
            writeSnapshot(context, kind, json)
            if (images != null) replaceImages(context, kind, images)
            true
        } else {
            false
        }
    }

    private fun writeSnapshot(context: Context, kind: MadarWidgetKind, json: String) {
        val blob = MadarWidgetCrypto.encrypt(json.toByteArray(Charsets.UTF_8))
        writeAtomically(snapshotFile(context, kind), blob)
    }

    /** The snapshot JSON of [kind], or null (none, or unreadable). */
    fun readSnapshot(context: Context, kind: MadarWidgetKind): String? {
        val file = snapshotFile(context, kind)
        if (!file.isFile) return null
        return try {
            String(MadarWidgetCrypto.decrypt(file.readBytes()), Charsets.UTF_8)
        } catch (e: Exception) {
            Log.w(TAG, "could not read the ${kind.wire} widget's data", e)
            null
        }
    }

    fun hasSnapshot(context: Context, kind: MadarWidgetKind): Boolean = snapshotFile(context, kind).isFile

    /** Replaces every image of [kind] with [images] (name → PNG bytes). */
    private fun replaceImages(context: Context, kind: MadarWidgetKind, images: Map<String, ByteArray>) {
        deleteImages(context, kind)
        for ((name, bytes) in images) {
            if (!SAFE_IMAGE.matches(name)) continue
            writeAtomically(File(directory(context), "${kind.wire}-$name.png"), bytes)
        }
    }

    /** The PNG file of [kind]'s image [name], or null. */
    fun image(context: Context, kind: MadarWidgetKind, name: String): File? {
        if (!SAFE_IMAGE.matches(name)) return null
        val file = File(directory(context), "${kind.wire}-$name.png")
        return if (file.isFile) file else null
    }

    private fun deleteImages(context: Context, kind: MadarWidgetKind) {
        val prefix = "${kind.wire}-"
        directory(context).listFiles()?.forEach { f ->
            if (f.name.startsWith(prefix) && f.name.endsWith(".png")) f.delete()
        }
    }

    /** Deletes [kind]'s snapshot and images. */
    fun remove(context: Context, kind: MadarWidgetKind) {
        synchronized(this) {
            snapshotFile(context, kind).delete()
            deleteImages(context, kind)
        }
    }

    /** Deletes every widget's data and the widgets' key. */
    fun clearAll(context: Context) {
        synchronized(this) {
            File(context.noBackupFilesDir, DIRECTORY).deleteRecursively()
            MadarWidgetCrypto.deleteKey()
        }
    }

    private fun writeAtomically(target: File, bytes: ByteArray) {
        val temp = File(target.parentFile, "${target.name}.tmp")
        FileOutputStream(temp).use { out ->
            out.write(bytes)
            out.fd.sync()
        }
        if (!temp.renameTo(target)) {
            target.delete()
            if (!temp.renameTo(target)) {
                temp.delete()
                throw java.io.IOException("could not write ${target.name}")
            }
        }
    }
}
