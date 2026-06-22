package com.aashish.heerr

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.view.KeyEvent
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * #20: home-screen "Now Playing" widget — a compact single-row tile.
 *
 * Display state is written from Dart via the `home_widget` package
 * (NowPlayingWidgetUpdater) into the [widgetData] SharedPreferences; this
 * provider renders title/artist, a play-pause icon and a position progress
 * bar. Transport controls are dispatched as `ACTION_MEDIA_BUTTON` broadcasts
 * to audio_service's already-registered MediaButtonReceiver, so they drive
 * the LIVE MediaSession — no second player, no Flutter background isolate.
 *
 * No cover art by design: decoding bitmaps from disk on every track change
 * was the source of repeated blank-widget / race bugs (see DEBT.md #20). The
 * layout uses only RemoteViews-whitelisted views (LinearLayout / TextView /
 * ProgressBar / ImageButton).
 */
class NowPlayingWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.now_playing_widget)

            val hasTrack = widgetData.getBoolean("np_has_track", false)
            val title = widgetData.getString("np_title", null)
            val artist = widgetData.getString("np_artist", null)
            val playing = widgetData.getBoolean("np_playing", false)
            // Position/duration arrive as decimal-string millis (see Dart side).
            val positionMs = widgetData.getString("np_position_ms", "0")?.toIntOrNull() ?: 0
            val durationMs = widgetData.getString("np_duration_ms", "0")?.toIntOrNull() ?: 0
            // Cover-derived background tint (signed ARGB int as a string).
            val tintArgb = widgetData.getString("np_tint_argb", "")?.toIntOrNull()

            views.setTextViewText(
                R.id.widget_title,
                if (hasTrack && !title.isNullOrEmpty()) title else "heerr",
            )
            views.setTextViewText(
                R.id.widget_artist,
                if (hasTrack && !artist.isNullOrEmpty()) artist else "Nothing playing",
            )
            views.setImageViewResource(
                R.id.widget_play_pause,
                if (playing) android.R.drawable.ic_media_pause
                else android.R.drawable.ic_media_play,
            )

            // Cover-derived background tint. setInt(..,"setBackgroundColor",..)
            // paints a flat colour (replacing the rounded drawable) only when a
            // tint is present; otherwise the default @drawable/widget_background
            // stays. No bitmaps — just an int over the wire.
            if (tintArgb != null && tintArgb != 0) {
                views.setInt(R.id.widget_root, "setBackgroundColor", tintArgb)
            }

            // Position bar (display only). Clamp the progress into [0, max].
            if (durationMs > 0) {
                views.setProgressBar(
                    R.id.widget_progress,
                    durationMs,
                    positionMs.coerceIn(0, durationMs),
                    false,
                )
            } else {
                views.setProgressBar(R.id.widget_progress, 0, 0, false)
            }

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
}
