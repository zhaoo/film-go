package com.zhaoo.filmgo.film_go.widget

import android.content.Context
import android.content.SharedPreferences
import android.preference.PreferenceManager

/**
 * SharedPreferences 强类型读写 wrapper。
 *
 * 与 Flutter `shared_preferences` 插件 2.4.7（legacy sync API）保持一致：
 *   - file:   PreferenceManager.getDefaultSharedPreferences()
 *             → `{packageName}_preferences.xml`
 *   - prefix: "flutter."
 *   - int    → Long
 *   - double → String，前缀 DOUBLE_PREFIX + value.toString()
 *
 * 详见 Task 1.1 实测确认。
 */
class WidgetPrefs(private val prefs: SharedPreferences) {

    companion object {
        private const val P = "flutter."

        /** shared_preferences_android 2.x 用此前缀把 String 标记为 Dart double。 */
        const val DOUBLE_PREFIX = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu"

        const val KEY_ISO            = "${P}widget.iso"
        const val KEY_CAL_OFFSET     = "${P}widget.calOffset"
        const val KEY_LAST_EV        = "${P}widget.lastEv"
        const val KEY_LAST_APERTURE  = "${P}widget.lastAperture"
        const val KEY_LAST_SHUTTER   = "${P}widget.lastShutter"
        const val KEY_LAST_TAKEN_AT  = "${P}widget.lastTakenAt"
        const val KEY_LAST_ERROR     = "${P}widget.lastError"
        const val KEY_LOADING_AT     = "${P}widget.loadingAt"

        @Suppress("DEPRECATION")
        fun from(context: Context): WidgetPrefs =
            WidgetPrefs(PreferenceManager.getDefaultSharedPreferences(context))
    }

    val iso: Int get() = prefs.getLong(KEY_ISO, 400L).toInt()
    val calibrationOffset: Double get() = readDouble(KEY_CAL_OFFSET) ?: 0.0
    val lastEv: Double? get() = readDouble(KEY_LAST_EV)
    val lastApertureFNumber: Double? get() = readDouble(KEY_LAST_APERTURE)
    val lastShutterSeconds: Double? get() = readDouble(KEY_LAST_SHUTTER)

    val lastTakenAt: Long get() = prefs.getLong(KEY_LAST_TAKEN_AT, 0L)
    val lastError: String? get() = prefs.getString(KEY_LAST_ERROR, null)
    val loadingAt: Long get() = prefs.getLong(KEY_LOADING_AT, 0L)

    /**
     * 按 Dart shared_preferences 的 double 编码读：String，去 prefix 后 toDouble()。
     *
     * 防御性读：真实 Android `getString` 若 value 不是 String 会抛 ClassCastException
     * （例如旧版本曾以 Long 写入同一 key、或其他写入者污染了文件），此时返回 null
     * 让上层走默认值，避免 widget onUpdate 直接挂掉。
     */
    private fun readDouble(key: String): Double? {
        val raw = runCatching { prefs.getString(key, null) }.getOrNull() ?: return null
        val body = if (raw.startsWith(DOUBLE_PREFIX)) raw.substring(DOUBLE_PREFIX.length) else raw
        return body.toDoubleOrNull()
    }

    fun markLoading(now: Long = System.currentTimeMillis()) {
        prefs.edit().putLong(KEY_LOADING_AT, now).apply()
    }

    /** 写时复刻 Dart 端编码：double → String(DOUBLE_PREFIX + value)。 */
    fun writeResult(
        ev: Double,
        apertureFNumber: Double,
        shutterSeconds: Double,
        takenAtMillis: Long,
    ) {
        prefs.edit()
            .putString(KEY_LAST_EV, DOUBLE_PREFIX + ev)
            .putString(KEY_LAST_APERTURE, DOUBLE_PREFIX + apertureFNumber)
            .putString(KEY_LAST_SHUTTER, DOUBLE_PREFIX + shutterSeconds)
            .putLong(KEY_LAST_TAKEN_AT, takenAtMillis)
            .remove(KEY_LAST_ERROR)
            .putLong(KEY_LOADING_AT, 0L)
            .apply()
    }

    fun writeError(code: String) {
        prefs.edit()
            .putString(KEY_LAST_ERROR, code)
            .putLong(KEY_LOADING_AT, 0L)
            .apply()
    }
}
