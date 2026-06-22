package com.aashish.heerr

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.ColorStateList
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Thin "bar" Now Playing widget (3x1 / 4x1).
 *
 * Shares the home_widget data contract with [NowPlayingWidgetProvider]: the
 * same Dart-side [NowPlayingWidgetUpdater] writes title / artist / playing /
 * tint plus the bar-only `np_position_ms` / `np_duration_ms` keys into the
 * [widgetData] SharedPreferences. This provider renders an animated waveform
 * (a ViewFlipper of vector frames — no bitmaps), inline title/artist, and a
 * display-only progress bar. No transport controls and no cover art by design
 * (cover art lives on the pill / classic tiles). Tapping the body opens the
 * app for full controls.
 */
class BarWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.bar_widget)

            val hasTrack = widgetData.getBoolean("np_has_track", false)
            val title = widgetData.getString("np_title", null)
            val artist = widgetData.getString("np_artist", null)
            val playing = widgetData.getBoolean("np_playing", false)
            val tintArgb = widgetData.getString("np_tint_argb", "")?.toIntOrNull()
            val positionMs = widgetData.getString("np_position_ms", "")?.toLongOrNull() ?: 0L
            val durationMs = widgetData.getString("np_duration_ms", "")?.toLongOrNull() ?: 0L

            views.setTextViewText(
                R.id.widget_title,
                if (hasTrack && !title.isNullOrEmpty()) title else "heerr",
            )
            views.setTextViewText(
                R.id.widget_artist,
                if (hasTrack && !artist.isNullOrEmpty()) artist else "Nothing playing",
            )

            // Display-only progress, scaled to the ProgressBar's max (1000).
            val progress = if (durationMs > 0L) {
                ((positionMs.toDouble() / durationMs.toDouble()) * 1000.0)
                    .toInt().coerceIn(0, 1000)
            } else {
                0
            }
            views.setProgressBar(R.id.widget_progress, 1000, progress, false)

            // Waveform "sync": animate (ViewFlipper) only while playing, else
            // freeze on a static frame. A widget has no live-amplitude API, so
            // play/pause is the only state the bars can honestly reflect.
            views.setViewVisibility(
                R.id.widget_wave,
                if (playing) View.VISIBLE else View.GONE,
            )
            views.setViewVisibility(
                R.id.widget_wave_static,
                if (playing) View.GONE else View.VISIBLE,
            )

            // Cover-derived background tint on the rounded tile (API 31+ only;
            // older devices keep the default dark tile). No bitmaps — just an int.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                views.setColorStateList(
                    R.id.widget_root,
                    "setBackgroundTintList",
                    if (tintArgb != null && tintArgb != 0) {
                        ColorStateList.valueOf(tintArgb)
                    } else {
                        null
                    },
                )
            }

            // Tapping the body opens the app (for full seek / browsing).
            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }
}
