package aleem.flutter.defender

import android.content.Context
import android.content.SharedPreferences

private const val PREFS_NAME = "flutter_defender_prefs"
private const val KEY_LAST_BACKGROUNDED_AT_MS = "last_backgrounded_at_ms"
private const val KEY_WAS_AUTHENTICATED = "was_authenticated"
private const val KEY_ACTIVE_GUARD_KIND = "active_guard_kind"

internal class LifecycleSnapshotStore(context: Context) {
    private val prefs: SharedPreferences =
        context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

    fun save(snapshot: LifecycleSnapshot) {
        prefs.edit().apply {
            if (snapshot.lastBackgroundedAtMs != null) {
                putLong(KEY_LAST_BACKGROUNDED_AT_MS, snapshot.lastBackgroundedAtMs)
            } else {
                remove(KEY_LAST_BACKGROUNDED_AT_MS)
            }
            putBoolean(KEY_WAS_AUTHENTICATED, snapshot.wasAuthenticated == true)
            putInt(KEY_ACTIVE_GUARD_KIND, snapshot.activeGuardKind?.raw ?: DefenderGuardKind.NONE.raw)
        }.apply()
    }

    fun load(): LifecycleSnapshot {
        val hasTimestamp = prefs.contains(KEY_LAST_BACKGROUNDED_AT_MS)
        val storedKind = prefs.getInt(KEY_ACTIVE_GUARD_KIND, DefenderGuardKind.NONE.raw)
        return LifecycleSnapshot(
            lastBackgroundedAtMs = if (hasTimestamp) prefs.getLong(KEY_LAST_BACKGROUNDED_AT_MS, 0L) else null,
            wasAuthenticated = prefs.getBoolean(KEY_WAS_AUTHENTICATED, false),
            activeGuardKind = DefenderGuardKind.ofRaw(storedKind) ?: DefenderGuardKind.NONE
        )
    }

    fun clear() {
        prefs.edit()
            .remove(KEY_LAST_BACKGROUNDED_AT_MS)
            .remove(KEY_WAS_AUTHENTICATED)
            .remove(KEY_ACTIVE_GUARD_KIND)
            .apply()
    }
}
