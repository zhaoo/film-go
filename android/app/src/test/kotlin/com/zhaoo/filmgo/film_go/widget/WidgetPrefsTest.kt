package com.zhaoo.filmgo.film_go.widget

import org.junit.Test
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull

class WidgetPrefsTest {

    /** 内存版 SharedPreferences，避免起 Android 上下文。 */
    private class FakePrefs : android.content.SharedPreferences {
        val data = HashMap<String, Any?>()
        override fun getAll(): MutableMap<String, *> = data
        override fun getString(key: String, defValue: String?) = data[key] as String? ?: defValue
        override fun getStringSet(key: String, defValues: MutableSet<String>?) = defValues
        override fun getInt(key: String, defValue: Int) = (data[key] as? Long)?.toInt() ?: (data[key] as? Int) ?: defValue
        override fun getLong(key: String, defValue: Long) = (data[key] as? Long) ?: defValue
        override fun getFloat(key: String, defValue: Float) = (data[key] as? Float) ?: defValue
        override fun getBoolean(key: String, defValue: Boolean) = (data[key] as? Boolean) ?: defValue
        override fun contains(key: String) = data.containsKey(key)
        override fun edit(): android.content.SharedPreferences.Editor = FakeEditor(this)
        override fun registerOnSharedPreferenceChangeListener(l: android.content.SharedPreferences.OnSharedPreferenceChangeListener?) {}
        override fun unregisterOnSharedPreferenceChangeListener(l: android.content.SharedPreferences.OnSharedPreferenceChangeListener?) {}
    }

    private class FakeEditor(val prefs: FakePrefs) : android.content.SharedPreferences.Editor {
        override fun putString(key: String, value: String?) = apply { prefs.data[key] = value }
        override fun putStringSet(key: String, values: MutableSet<String>?) = this
        override fun putInt(key: String, value: Int) = apply { prefs.data[key] = value }
        override fun putLong(key: String, value: Long) = apply { prefs.data[key] = value }
        override fun putFloat(key: String, value: Float) = apply { prefs.data[key] = value }
        override fun putBoolean(key: String, value: Boolean) = apply { prefs.data[key] = value }
        override fun remove(key: String) = apply { prefs.data.remove(key) }
        override fun clear() = apply { prefs.data.clear() }
        override fun commit() = true
        override fun apply() {}
    }

    @Test fun `default iso is 400 when missing`() {
        val p = WidgetPrefs(FakePrefs())
        assertEquals(400, p.iso)
    }

    @Test fun `default calibration offset is 0`() {
        val p = WidgetPrefs(FakePrefs())
        assertEquals(0.0, p.calibrationOffset, 1e-9)
    }

    @Test fun `lastError defaults to null`() {
        val p = WidgetPrefs(FakePrefs())
        assertNull(p.lastError)
    }

    @Test fun `lastTakenAt defaults to 0`() {
        val p = WidgetPrefs(FakePrefs())
        assertEquals(0L, p.lastTakenAt)
    }

    @Test fun `writeResult round-trips ev aperture shutter taken`() {
        val raw = FakePrefs()
        val p = WidgetPrefs(raw)
        p.writeResult(ev = 12.3, apertureFNumber = 8.0, shutterSeconds = 1.0 / 250.0, takenAtMillis = 1234567890L)
        assertEquals(12.3, p.lastEv!!, 1e-9)
        assertEquals(8.0, p.lastApertureFNumber!!, 1e-9)
        assertEquals(1.0 / 250.0, p.lastShutterSeconds!!, 1e-9)
        assertEquals(1234567890L, p.lastTakenAt)
        assertNull(p.lastError)
    }

    @Test fun `reads Dart-encoded double (DOUBLE_PREFIX + value as String)`() {
        val raw = FakePrefs()
        // 模拟 Dart shared_preferences 写入的真实格式
        raw.data[WidgetPrefs.KEY_CAL_OFFSET] = "VGhpcyBpcyB0aGUgcHJlZml4IGZvciBEb3VibGUu" + "0.42"
        val p = WidgetPrefs(raw)
        assertEquals(0.42, p.calibrationOffset, 1e-9)
    }

    @Test fun `reads Dart-encoded int (Long)`() {
        val raw = FakePrefs()
        raw.data[WidgetPrefs.KEY_ISO] = 800L
        val p = WidgetPrefs(raw)
        assertEquals(800, p.iso)
    }

    @Test fun `writeError sets error code and clears loading`() {
        val p = WidgetPrefs(FakePrefs())
        p.markLoading()
        assert(p.loadingAt > 0)
        p.writeError("TIMEOUT")
        assertEquals("TIMEOUT", p.lastError)
        assertEquals(0L, p.loadingAt)
    }
}
