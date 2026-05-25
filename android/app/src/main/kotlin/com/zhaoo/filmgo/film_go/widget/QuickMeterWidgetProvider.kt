package com.zhaoo.filmgo.film_go.widget

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.view.View
import android.widget.RemoteViews
import com.zhaoo.filmgo.film_go.MainActivity
import com.zhaoo.filmgo.film_go.R
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import java.util.concurrent.atomic.AtomicBoolean

class QuickMeterWidgetProvider : AppWidgetProvider() {

    companion object {
        private const val ACTION_MEASURE = "com.zhaoo.filmgo.film_go.widget.ACTION_MEASURE"
        private const val ACTION_OPEN_APP = "com.zhaoo.filmgo.film_go.widget.ACTION_OPEN_APP"
        private val inFlight = AtomicBoolean(false)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            renderAndUpdate(context, appWidgetManager, id)
        }
    }

    override fun onReceive(context: Context, intent: Intent) {
        super.onReceive(context, intent)
        when (intent.action) {
            ACTION_MEASURE -> handleMeasure(context)
            ACTION_OPEN_APP -> openMainActivity(context)
        }
    }

    private fun handleMeasure(context: Context) {
        if (!inFlight.compareAndSet(false, true)) return  // 二次点击直接退出

        val prefs = WidgetPrefs.from(context)
        prefs.markLoading()
        pushAllWidgets(context)

        val pending = goAsync()
        val appCtx = context.applicationContext  // receiver context 可能短命，用 application
        CoroutineScope(Dispatchers.Default).launch {
            try {
                val result = AlsMeter.measure(appCtx)
                when (result) {
                    is MeterResult.NoSensor -> prefs.writeError("NO_SENSOR")
                    is MeterResult.Timeout -> prefs.writeError("TIMEOUT")
                    is MeterResult.Lux -> {
                        val ev = ExposureMath.fromLux(
                            lux = result.value.toDouble(),
                            iso = prefs.iso,
                            calibrationOffset = prefs.calibrationOffset,
                        )
                        val pair = ExposureMath.medianOrNull(
                            ExposureMath.suggestPairs(ev, prefs.iso),
                        )
                        if (pair == null) {
                            // 不写入假的 aperture/shutter，避免后续误展示为真实读数
                            prefs.writeError("OUT_OF_RANGE")
                        } else {
                            prefs.writeResult(
                                ev = ev,
                                apertureFNumber = pair.apertureFNumber,
                                shutterSeconds = pair.shutterSeconds,
                                takenAtMillis = System.currentTimeMillis(),
                            )
                        }
                    }
                }
            } catch (t: Throwable) {
                android.util.Log.w("QuickMeterWidget", "measure failed", t)
                prefs.writeError("TIMEOUT")  // 任何意外异常按超时处理
            } finally {
                pushAllWidgets(appCtx)
                inFlight.set(false)
                runCatching { pending.finish() }
            }
        }
    }

    private fun openMainActivity(context: Context) {
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        context.startActivity(intent)
    }

    private fun pushAllWidgets(context: Context) {
        val mgr = AppWidgetManager.getInstance(context)
        val ids = mgr.getAppWidgetIds(ComponentName(context, QuickMeterWidgetProvider::class.java))
        for (id in ids) renderAndUpdate(context, mgr, id)
    }

    private fun renderAndUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        widgetId: Int,
    ) {
        val views = RemoteViews(context.packageName, R.layout.widget_quick_meter)
        val prefs = WidgetPrefs.from(context)

        val now = System.currentTimeMillis()
        val loadingAt = prefs.loadingAt
        val loading = loadingAt > 0 && (now - loadingAt) < 2000
        val error = prefs.lastError
        val taken = prefs.lastTakenAt

        when {
            loading -> renderLoading(views, context)
            error == "NO_SENSOR" -> renderPermanentError(views, context)
            error == "TIMEOUT" && taken == 0L ->
                renderEmptyWithMessage(views, context.getString(R.string.widget_err_timeout_first))
            error == "TIMEOUT" && taken > 0L ->
                renderResult(views, context, prefs,
                    footnote = context.getString(R.string.widget_err_timeout_again))
            error == "OUT_OF_RANGE" -> {
                if (taken > 0L && prefs.lastEv != null) {
                    renderResult(views, context, prefs,
                        secondaryOverride = context.getString(R.string.widget_err_out_of_range))
                } else {
                    renderEmptyWithMessage(views,
                        context.getString(R.string.widget_err_out_of_range))
                }
            }
            taken > 0L -> renderResult(views, context, prefs)
            else -> renderEmpty(views, context)
        }

        // 默认整卡片可点击 → 按测光
        views.setOnClickPendingIntent(R.id.widget_button, measureIntent(context))

        appWidgetManager.updateAppWidget(widgetId, views)
    }

    private fun renderEmpty(views: RemoteViews, context: Context) {
        views.setTextViewText(R.id.widget_primary_line, context.getString(R.string.widget_empty_hint))
        views.setViewVisibility(R.id.widget_secondary_line, View.GONE)
        views.setViewVisibility(R.id.widget_footnote_line, View.GONE)
        views.setTextViewText(R.id.widget_button, context.getString(R.string.widget_btn_measure))
    }

    private fun renderEmptyWithMessage(views: RemoteViews, msg: String) {
        views.setTextViewText(R.id.widget_primary_line, msg)
        views.setViewVisibility(R.id.widget_secondary_line, View.GONE)
        views.setViewVisibility(R.id.widget_footnote_line, View.GONE)
    }

    private fun renderLoading(views: RemoteViews, context: Context) {
        views.setTextViewText(R.id.widget_primary_line,
            context.getString(R.string.widget_loading))
        views.setViewVisibility(R.id.widget_secondary_line, View.GONE)
        views.setViewVisibility(R.id.widget_footnote_line, View.GONE)
    }

    private fun renderPermanentError(views: RemoteViews, context: Context) {
        views.setTextViewText(R.id.widget_primary_line,
            context.getString(R.string.widget_err_no_sensor))
        views.setViewVisibility(R.id.widget_secondary_line, View.GONE)
        views.setViewVisibility(R.id.widget_footnote_line, View.GONE)
        views.setTextViewText(R.id.widget_button, context.getString(R.string.widget_btn_open_app))
        views.setOnClickPendingIntent(R.id.widget_button, openAppIntent(context))
    }

    private fun renderResult(
        views: RemoteViews,
        context: Context,
        prefs: WidgetPrefs,
        secondaryOverride: String? = null,
        footnote: String? = null,
    ) {
        val ev = prefs.lastEv ?: return renderEmpty(views, context)
        views.setTextViewText(R.id.widget_primary_line, "EV " + formatEv(ev))
        val secondary = secondaryOverride ?: buildString {
            append("f/").append(formatF(prefs.lastApertureFNumber ?: 8.0))
            append(" · ").append(formatShutter(prefs.lastShutterSeconds ?: (1.0 / 125.0)))
            append(" · ISO ").append(prefs.iso)
        }
        views.setTextViewText(R.id.widget_secondary_line, secondary)
        views.setViewVisibility(R.id.widget_secondary_line, View.VISIBLE)
        if (footnote != null) {
            views.setTextViewText(R.id.widget_footnote_line, footnote)
            views.setViewVisibility(R.id.widget_footnote_line, View.VISIBLE)
        } else {
            views.setViewVisibility(R.id.widget_footnote_line, View.GONE)
        }
        views.setTextViewText(R.id.widget_button, context.getString(R.string.widget_btn_remeasure))
    }

    private fun measureIntent(context: Context): PendingIntent {
        val intent = Intent(context, QuickMeterWidgetProvider::class.java).apply {
            action = ACTION_MEASURE
        }
        return PendingIntent.getBroadcast(
            context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun openAppIntent(context: Context): PendingIntent {
        val intent = Intent(context, QuickMeterWidgetProvider::class.java).apply {
            action = ACTION_OPEN_APP
        }
        return PendingIntent.getBroadcast(
            context, 1, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private fun formatEv(ev: Double): String =
        String.format("%.1f", ev)

    private fun formatF(n: Double): String {
        // 整数显示无小数（"f/8"），其他保留 1 位（"f/2.8"），与 Dart Aperture.display 一致
        return if (kotlin.math.abs(n - kotlin.math.round(n)) < 0.05)
            String.format("%.0f", n)
        else
            String.format("%.1f", n)
    }

    private fun formatShutter(sec: Double): String {
        return if (sec >= 1.0) {
            if (kotlin.math.abs(sec - kotlin.math.round(sec)) < 0.01)
                String.format("%.0fs", sec)
            else
                String.format("%.1fs", sec)
        } else {
            val denom = kotlin.math.round(1.0 / sec).toInt()
            "1/$denom"
        }
    }
}
