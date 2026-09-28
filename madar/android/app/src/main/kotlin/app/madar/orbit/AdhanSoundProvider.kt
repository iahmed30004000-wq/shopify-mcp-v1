package app.madar.orbit

import android.content.ContentProvider
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.database.Cursor
import android.database.MatrixCursor
import android.net.Uri
import android.os.ParcelFileDescriptor
import android.provider.OpenableColumns
import java.io.File
import java.io.FileNotFoundException

/**
 * Serves the muezzin recordings the user attached (copied by the app into
 * `files/adhan_sounds/`) read-only to the system, so a notification channel
 * can play one as its sound while Madar itself is not running.
 *
 * A channel sound is played by SystemUI, which cannot read Madar's private
 * files; `file://` URIs are forbidden in notifications since Android 7. The
 * provider is not exported: access is granted per URI to the system packages
 * ([grantToSystem]) – again after every reboot / update, because URI grants
 * do not survive them (see [AdhanBootGuard]).
 *
 * Framework APIs only (no androidx dependency), one flat folder, names
 * validated so nothing outside it can ever be served.
 */
class AdhanSoundProvider : ContentProvider() {
    companion object {
        const val DIRECTORY = "adhan_sounds"

        /** Packages that play notification sounds (SystemUI's RingtonePlayer; system_server). */
        private val SYSTEM_READERS = listOf("com.android.systemui", "android")

        private val SAFE_NAME = Regex("^[a-z0-9]{4,40}\\.[a-z0-9]{2,5}$")

        fun authority(context: Context): String = "${context.packageName}.adhansounds"

        fun directory(context: Context): File = File(context.filesDir, DIRECTORY).apply { mkdirs() }

        /** content:// URI of [name] in the sound folder, or null if it does not exist. */
        fun uriFor(context: Context, name: String): Uri? {
            if (!SAFE_NAME.matches(name)) return null
            val file = File(directory(context), name)
            if (!file.isFile) return null
            return Uri.Builder().scheme("content").authority(authority(context)).appendPath(name).build()
        }

        fun grantToSystem(context: Context, uri: Uri) {
            for (pkg in SYSTEM_READERS) {
                try {
                    context.grantUriPermission(pkg, uri, Intent.FLAG_GRANT_READ_URI_PERMISSION)
                } catch (_: Exception) {
                    // Package absent / not visible on this build: the other one plays it.
                }
            }
        }

        /** Re-grants every recording (boot / app update drop URI grants). */
        fun grantAll(context: Context) {
            val files = directory(context).listFiles() ?: return
            for (f in files) {
                uriFor(context, f.name)?.let { grantToSystem(context, it) }
            }
        }

        private fun mimeOf(name: String): String = when (name.substringAfterLast('.', "")) {
            "mp3" -> "audio/mpeg"
            "wav" -> "audio/wav"
            "ogg", "oga" -> "audio/ogg"
            "opus" -> "audio/opus"
            "m4a", "mp4", "aac" -> "audio/mp4"
            "flac" -> "audio/flac"
            else -> "application/octet-stream"
        }
    }

    override fun onCreate(): Boolean = true

    private fun fileFor(uri: Uri): File {
        val ctx = context ?: throw FileNotFoundException(uri.toString())
        val segments = uri.pathSegments
        if (uri.authority != authority(ctx) || segments.size != 1 || !SAFE_NAME.matches(segments[0])) {
            throw FileNotFoundException(uri.toString())
        }
        val dir = directory(ctx).canonicalFile
        val file = File(dir, segments[0]).canonicalFile
        if (file.parentFile != dir || !file.isFile) throw FileNotFoundException(uri.toString())
        return file
    }

    override fun openFile(uri: Uri, mode: String): ParcelFileDescriptor {
        if (mode != "r") throw SecurityException("Madar's sound provider is read-only")
        return ParcelFileDescriptor.open(fileFor(uri), ParcelFileDescriptor.MODE_READ_ONLY)
    }

    override fun getType(uri: Uri): String = mimeOf(uri.lastPathSegment ?: "")

    override fun query(
        uri: Uri,
        projection: Array<out String>?,
        selection: String?,
        selectionArgs: Array<out String>?,
        sortOrder: String?,
    ): Cursor {
        val file = fileFor(uri)
        val columns = projection ?: arrayOf(OpenableColumns.DISPLAY_NAME, OpenableColumns.SIZE)
        val row = columns.map { col ->
            when (col) {
                OpenableColumns.DISPLAY_NAME -> file.name
                OpenableColumns.SIZE -> file.length()
                else -> null
            }
        }
        return MatrixCursor(columns, 1).apply { addRow(row.toTypedArray()) }
    }

    override fun insert(uri: Uri, values: ContentValues?): Uri? = throw UnsupportedOperationException()

    override fun update(uri: Uri, values: ContentValues?, selection: String?, selectionArgs: Array<out String>?): Int = 0

    override fun delete(uri: Uri, selection: String?, selectionArgs: Array<out String>?): Int = 0
}
