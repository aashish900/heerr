package com.aashish.heerr

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Path
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.RectF
import android.graphics.Shader
import android.os.Bundle
import android.view.KeyEvent
import android.view.View
import android.widget.RemoteViews
import java.io.File
import java.util.Locale
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** home_widget plugin's SharedPreferences file (HomeWidgetPlugin.PREFERENCES); shared with WidgetSeekReceiver. */
internal const val HOME_WIDGET_PREFS = "HomeWidgetPreferences"

/**
 * 4x1 "hero" Now Playing widget — the app's only home-screen widget.
 *
 * Shares the `np_*` home_widget data contract written by the Dart
 * [NowPlayingWidgetUpdater]. Two states, toggled off `np_has_track`:
 *  - **idle**   : gradient heerr logo + "Start listening to your music" +
 *                 flat white transport.
 *  - **playing**: full-height album art flush against the left edge (left
 *                 corners rounded natively below — RemoteViews can't clip —
 *                 and its right edge alpha-faded into the tile so there's no
 *                 hard border) + title/artist + wide animated gradient
 *                 waveform + a tap-to-seek progress bar spanning to the right
 *                 edge + m:ss times + gradient play disc.
 * Each state group carries its own transport ids (no duplicate-id ambiguity);
 * all buttons broadcast ACTION_MEDIA_BUTTON to audio_service's
 * MediaButtonReceiver (drives the LIVE MediaSession); the progress bar is
 * overlaid with tap zones broadcasting to [WidgetSeekReceiver] (RemoteViews
 * can't host a drag gesture); the body tap opens the app. Layout uses only
 * RemoteViews-whitelisted views.
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

                // Full-height cover, cropped to the art view's aspect and with
                // its LEFT corners rounded so it hugs the tile's edge
                // (RemoteViews can't clip an ImageView). The view's height
                // comes from the widget options (portrait = maxHeight).
                val heightDp = appWidgetManager
                    .getAppWidgetOptions(appWidgetId)
                    .getInt(AppWidgetManager.OPTION_APPWIDGET_MAX_HEIGHT)
                    .let { if (it > 0) it else FALLBACK_HEIGHT_DP }
                val bitmap = if (!artPath.isNullOrEmpty() && File(artPath).exists()) {
                    runCatching {
                        buildArtBitmap(context, artPath, ART_WIDTH_DP, heightDp)
                    }.getOrNull()
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

                // Tap-to-seek: 10 equal-width invisible zones over the
                // progress bar. RemoteViews can't drag a slider, so each tap
                // jumps to the midpoint of its zone via WidgetSeekReceiver.
                for ((i, id) in SEEK_ZONE_IDS.withIndex()) {
                    views.setOnClickPendingIntent(id, seekIntent(context, i))
                }

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

                views.setImageViewResource(
                    R.id.widget_play_pause,
                    if (playing) R.drawable.widget_ic_pause else R.drawable.widget_ic_play,
                )
            }

            // Transport controls -> live MediaSession via MediaButtonReceiver.
            // Both state groups carry their own button ids; wire them all.
            val playPause = mediaButtonIntent(context, KeyEvent.KEYCODE_MEDIA_PLAY_PAUSE)
            val next = mediaButtonIntent(context, KeyEvent.KEYCODE_MEDIA_NEXT)
            val prev = mediaButtonIntent(context, KeyEvent.KEYCODE_MEDIA_PREVIOUS)
            views.setOnClickPendingIntent(R.id.widget_play_pause, playPause)
            views.setOnClickPendingIntent(R.id.widget_next, next)
            views.setOnClickPendingIntent(R.id.widget_prev, prev)
            views.setOnClickPendingIntent(R.id.widget_idle_play, playPause)
            views.setOnClickPendingIntent(R.id.widget_idle_next, next)
            views.setOnClickPendingIntent(R.id.widget_idle_prev, prev)

            // Tapping the body opens the app (for full seek / browsing).
            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    /** Redraw on resize so the cover crop tracks the new widget height. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle,
    ) {
        super.onAppWidgetOptionsChanged(context, appWidgetManager, appWidgetId, newOptions)
        onUpdate(
            context,
            appWidgetManager,
            intArrayOf(appWidgetId),
            context.getSharedPreferences(HOME_WIDGET_PREFS, Context.MODE_PRIVATE),
        )
    }

    private fun formatTime(ms: Long): String {
        if (ms <= 0L) return "0:00"
        val totalSec = ms / 1000
        return String.format(Locale.US, "%d:%02d", totalSec / 60, totalSec % 60)
    }

    /**
     * Decodes [path] and center-crops it into a [widthDp] x [heightDp] bitmap
     * whose LEFT corners are rounded to sit flush inside the tile's gradient
     * border, and whose right [FADE_FRACTION] alpha-fades to transparent so
     * it blends into the tile background instead of showing a hard edge.
     * Output density is capped at 2x so the RemoteViews bitmap payload stays
     * well under the Binder transaction limit (~224x212 px, ~0.19 MB).
     */
    private fun buildArtBitmap(
        context: Context,
        path: String,
        widthDp: Int,
        heightDp: Int,
    ): Bitmap? {
        val src = decodeScaledBitmap(path, MAX_ART_PX) ?: return null
        val density = context.resources.displayMetrics.density.coerceAtMost(2f)
        val outW = (widthDp * density).toInt().coerceAtLeast(1)
        val outH = (heightDp * density).toInt().coerceAtLeast(1)
        val radius = CORNER_DP * density

        val out = Bitmap.createBitmap(outW, outH, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(out)
        val clip = Path().apply {
            addRoundRect(
                RectF(0f, 0f, outW.toFloat(), outH.toFloat()),
                // Per-corner radii: top-left, top-right, bottom-right, bottom-left.
                floatArrayOf(radius, radius, 0f, 0f, 0f, 0f, radius, radius),
                Path.Direction.CW,
            )
        }
        canvas.clipPath(clip)

        // Matrix centre-crop: scale to cover, centre the overflow.
        val scale = maxOf(outW.toFloat() / src.width, outH.toFloat() / src.height)
        val dx = (outW - src.width * scale) / 2f
        val dy = (outH - src.height * scale) / 2f
        val matrix = Matrix().apply {
            setScale(scale, scale)
            postTranslate(dx, dy)
        }
        canvas.drawBitmap(src, matrix, Paint(Paint.FILTER_BITMAP_FLAG))

        // Alpha-fade the right edge into the tile so art blends into the
        // widget body instead of a hard border (DST_IN masks existing pixels
        // by the gradient's alpha, opaque white -> fully transparent).
        val fadeStart = outW * (1f - FADE_FRACTION)
        val fade = Paint().apply {
            shader = LinearGradient(
                fadeStart, 0f, outW.toFloat(), 0f,
                Color.WHITE, Color.TRANSPARENT, Shader.TileMode.CLAMP,
            )
            xfermode = PorterDuffXfermode(PorterDuff.Mode.DST_IN)
        }
        canvas.drawRect(fadeStart, 0f, outW.toFloat(), outH.toFloat(), fade)

        return out
    }

    /**
     * Decodes [path] downsampled so neither side exceeds [maxPx], keeping the
     * intermediate decode memory bounded before the crop above.
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

    /** Broadcasts a seek to the midpoint of zone [index] out of [SEEK_ZONE_IDS]. */
    private fun seekIntent(context: Context, index: Int): PendingIntent {
        val intent = Intent(context, WidgetSeekReceiver::class.java).apply {
            action = WidgetSeekReceiver.ACTION_WIDGET_SEEK
            putExtra(
                WidgetSeekReceiver.EXTRA_SEEK_FRACTION,
                (index + 0.5f) / SEEK_ZONE_IDS.size,
            )
        }
        return PendingIntent.getBroadcast(
            context,
            // Distinct requestCode per zone (extras don't participate in
            // Intent.filterEquals); offset clear of mediaButtonIntent's raw
            // keycode requestCodes.
            WidgetSeekReceiver.REQUEST_BASE + index,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
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
        const val MAX_ART_PX = 512
        const val ART_WIDTH_DP = 112
        /** Matches widget_background's corner radius (28dp) — no border inset. */
        const val CORNER_DP = 28
        const val FALLBACK_HEIGHT_DP = 110
        /** Right fraction of the art bitmap that alpha-fades to transparent. */
        const val FADE_FRACTION = 0.35f
        /** Progress-bar tap-to-seek zone ids, left to right; see hero_widget.xml. */
        val SEEK_ZONE_IDS = intArrayOf(
            R.id.widget_seek_0, R.id.widget_seek_1, R.id.widget_seek_2,
            R.id.widget_seek_3, R.id.widget_seek_4, R.id.widget_seek_5,
            R.id.widget_seek_6, R.id.widget_seek_7, R.id.widget_seek_8,
            R.id.widget_seek_9,
        )
    }
}
