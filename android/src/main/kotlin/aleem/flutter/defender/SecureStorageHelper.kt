package aleem.flutter.defender

import android.content.Context
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey

internal class SecureStorageHelper(context: Context) {
    private val encryptedPrefs by lazy {
        val key = MasterKey.Builder(context)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            context,
            PREFS_NAME,
            key,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    fun write(key: String, value: String) {
        encryptedPrefs.edit().putString(key, value).apply()
    }

    fun read(key: String): String? = encryptedPrefs.getString(key, null)

    fun delete(key: String) {
        encryptedPrefs.edit().remove(key).apply()
    }

    fun clearAll() {
        encryptedPrefs.edit().clear().apply()
    }

    private companion object {
        const val PREFS_NAME = "flutter_defender_secure_store"
    }
}
