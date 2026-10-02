package app.madar.orbit.widgets

import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import java.security.GeneralSecurityException
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

/**
 * Encrypts the widgets' snapshots at rest: AES-256-GCM with a key that lives
 * in the Android Keystore (never in the app's files), like the database key's
 * wrapping key. The providers must read the snapshots while Madar is closed
 * and locked, so the key needs no user authentication; what it protects
 * against is a copy of the app's files.
 *
 * Blob: `[1][iv length][iv][ciphertext + tag]`.
 */
object MadarWidgetCrypto {
    private const val KEYSTORE = "AndroidKeyStore"
    private const val ALIAS = "madar_widgets_v1"
    private const val TRANSFORMATION = "AES/GCM/NoPadding"
    private const val TAG_BITS = 128
    private const val FORMAT: Byte = 1

    @Synchronized
    private fun key(create: Boolean): SecretKey? {
        val store = KeyStore.getInstance(KEYSTORE)
        store.load(null)
        val existing = store.getKey(ALIAS, null)
        if (existing is SecretKey) return existing
        if (!create) return null
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEYSTORE)
        val spec = KeyGenParameterSpec.Builder(
            ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .build()
        generator.init(spec)
        return generator.generateKey()
    }

    fun encrypt(plain: ByteArray): ByteArray {
        val secret = key(true) ?: throw GeneralSecurityException("no widget key")
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.ENCRYPT_MODE, secret)
        val iv = cipher.iv
        val sealed = cipher.doFinal(plain)
        val out = ByteArray(2 + iv.size + sealed.size)
        out[0] = FORMAT
        out[1] = iv.size.toByte()
        System.arraycopy(iv, 0, out, 2, iv.size)
        System.arraycopy(sealed, 0, out, 2 + iv.size, sealed.size)
        return out
    }

    fun decrypt(blob: ByteArray): ByteArray {
        if (blob.size < 3 || blob[0] != FORMAT) throw GeneralSecurityException("not a widget blob")
        val ivLength = blob[1].toInt() and 0xFF
        if (ivLength < 12 || ivLength > 16 || blob.size <= 2 + ivLength) {
            throw GeneralSecurityException("bad widget blob")
        }
        val secret = key(false) ?: throw GeneralSecurityException("no widget key")
        val cipher = Cipher.getInstance(TRANSFORMATION)
        cipher.init(Cipher.DECRYPT_MODE, secret, GCMParameterSpec(TAG_BITS, blob, 2, ivLength))
        return cipher.doFinal(blob, 2 + ivLength, blob.size - 2 - ivLength)
    }

    /** Forgets the key ("delete all data"): old blobs can never be read again. */
    @Synchronized
    fun deleteKey() {
        try {
            val store = KeyStore.getInstance(KEYSTORE)
            store.load(null)
            if (store.containsAlias(ALIAS)) store.deleteEntry(ALIAS)
        } catch (_: Exception) {
            // Nothing to forget, or the Keystore is unavailable: the blobs
            // are deleted anyway.
        }
    }
}
