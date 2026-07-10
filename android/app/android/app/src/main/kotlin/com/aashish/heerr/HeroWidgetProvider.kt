package com.aashish.heerr

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.view.KeyEvent
import android.view.View
import android.widget.RemoteViews
import java.io.File
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * 4x2 "hero" Now Playing widget — the full-size brand tile.
 *
 * Shares the `np_*` home_widget data contract with the other widgets (written
 * by the Dart [NowPlayingWidgetUpdater]). Two states, toggled off `np_has_track`:
 *  - **idle**   : gradient heerr logo + "Start listening to your music".
 *  - **playing**: album art + title/artist + animated gradient waveform +
 *                 display-only progress bar + m:ss timestamps.
 * The transport row (prev / play-pause / next) is shared across both states, so
 * the control ids exist once; the play button gets the gradient disc background
 * only when a track is loaded. Transport buttons broadcast ACTION_MEDIA_BUTTON
 * to audio_service's MediaButtonReceiver (drives the LIVE MediaSession); the
 * body tap opens the app. Layout uses only RemoteViews-whitelisted views.
 */
class HeroWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.hero_widget)

            val hasTrack = widgetData.getBoolean("np_has_track", false)
            val title = widgetData.getString("np_title", null)
            val artist = widgetData.getString("np_artist", null)
            val playing = widgetData.getBoolean("np_playing", false)
            val positionMs = widgetData.getString("np_position_ms", "")?.toLongOrNull() ?: 0L
            val durationMs = widgetData.getString("np_duration_ms", "")?.toLongOrNull() ?: 0L
            val artPath = widgetData.getString("np_art_path", null)

            views.setViewVisibility(
                R.id.hero_idle_group,
                if (hasTrack) View.GONE else View.VISIBLE,
            )
            views.setViewVisibility(
                R.id.hero_playing_group,
                if (hasTrack) View.VISIBLE else View.GONE,
            )

            if (hasTrack) {
                views.setTextViewText(
                    R.id.widget_title,
                    if (!title.isNullOrEmpty()) title else "heerr",
                )
                views.setTextViewText(
                    R.id.widget_artist,
                    if (!artist.isNullOrEmpty()) artist else "",
                )

                // Left cover-art thumbnail, decoded heavily downsampled so the
                // bitmap stays well under the Binder transaction limit.
                val bitmap = if (!artPath.isNullOrEmpty() && File(artPath).exists()) {
                    runCatching { decodeScaledBitmap(artPath, MAX_ART_PX) }.getOrNull()
                } else {
                    null
                }
                if (bitmap != null) {
                    views.setImageViewBitmap(R.id.widget_art, bitmap)
                } else {
                    views.setImageViewResource(R.id.widget_art, R.drawable.widget_ic_album)
                }

                // Display-only progress, scaled to the ProgressBar's max (1000),
                // plus m:ss timestamps. Position ticks are pushed from Dart.
                val progress = if (durationMs > 0L) {
                    ((positionMs.toDouble() / durationMs.toDouble()) * 1000.0)
                        .toInt().coerceIn(0, 1000)
                } else {
                    0
                }
                views.setProgressBar(R.id.widget_progress, 1000, progress, false)
                views.setTextViewText(R.id.widget_time_pos, formatTime(positionMs))
                views.setTextViewText(R.id.widget_time_dur, formatTime(durationMs))

                // Waveform "sync": animate (ViewFlipper) only while playing, else
                // freeze on a static frame. No live-amplitude API on a widget.
                views.setViewVisibility(
                    R.id.widget_wave,
                    if (playing) View.VISIBLE else View.GONE,
                )
                views.setViewVisibility(
                    R.id.widget_wave_static,
                    if (playing) View.GONE else View.VISIBLE,
                )
            }

            // Play/pause glyph, and the gradient disc behind it only when a track
            // is loaded (idle keeps the flat white glyph, per the concept).
            views.setImageViewResource(
                R.id.widget_play_pause,
                if (playing) R.drawable.widget_ic_pause else R.drawable.widget_ic_play,
            )
            views.setInt(
                R.id.widget_play_pause,
                "setBackgroundResource",
                if (hasTrack) R.drawable.widget_play_circle else 0,
            )

            // Transport controls -> live MediaSession via MediaButtonReceiver.
            views.setOnClickPendingIntent(
                R.id.widget_play_pause,
                mediaButtonIntent(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE),
            )
            views.setOnClickPendingIntent(
                R.id.widget_next,
                mediaButtonIntent(context, KeyEvent.KEYCODE_MEDIA_NEXT),
            )
            views.setOnClickPendingIntent(
                R.id.widget_prev,
                mediaButtonIntent(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS),
            )

            // Tapping the body opens the app (for full seek / browsing).
            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    private fun formatTime(ms: Long): String {
        if (ms <= 0L) return "0:00"
        val totalSec = ms / 1000
        return "%d:%02d".format(totalSec / 60, totalSec % 60)
    }

    /**
     * Decodes [path] downsampled so neither side exceeds [maxPx], keeping the
     * RemoteViews bitmap payload well under the Binder transaction limit.
     */
    private fun decodeScaledBitmap(path: String, maxPx: Int): Bitmap? {
        val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
        BitmapFactory.decodeFile(path, bounds)
        val w = bounds.outWidth
        val h = bounds.outHeight
        if (w <= 0 || h <= 0) return null
        var sample = 1
        while (w / sample > maxPx || h / sample > maxPx) {
            sample *= 2
        }
        val opts = BitmapFactory.Options().apply { inSampleSize = sample }
        return BitmapFactory.decodeFile(path, opts)
    }

    private fun mediaButtonIntent(context: Context, keyCode: Int): PendingIntent {
        val intent = Intent(Intent.ACTION_MEDIA_BUTTON).apply {
            component = ComponentName(
                context.packageName,
                "com.ryanheise.audioservice.MediaButtonReceiver",
            )
            putExtra(Intent.EXTRA_KEY_EVENT, KeyEvent(KeyEvent.ACTION_DOWN, keyCode))
        }
        return PendingIntent.getBroadcast(
            context,
            keyCode,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
    }

    private companion object {
        const val MAX_ART_PX = 192
    }
}
