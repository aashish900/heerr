package com.aashish.heerr

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.content.res.ColorStateList
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.BitmapShader
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Shader
import android.os.Build
import android.view.View
import android.widget.RemoteViews
import java.io.File
import kotlin.math.min
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/**
 * Chubby "pill" Now Playing widget (2x1).
 *
 * Shares the home_widget data contract with [NowPlayingWidgetProvider]: the
 * Dart-side [NowPlayingWidgetUpdater] writes title / artist / tint / cover-art
 * path. This provider renders a circular cover thumbnail (rounded natively —
 * RemoteViews can't clip an ImageView to a circle), stacked title/artist, and
 * an animated waveform (a ViewFlipper of vector frames — no bitmaps). The tile
 * background is fully rounded so the ends are semicircles. No transport
 * controls by design; tapping the body opens the app.
 */
class PillWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        for (appWidgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.pill_widget)

            val hasTrack = widgetData.getBoolean("np_has_track", false)
            val title = widgetData.getString("np_title", null)
            val artist = widgetData.getString("np_artist", null)
            val playing = widgetData.getBoolean("np_playing", false)
            val tintArgb = widgetData.getString("np_tint_argb", "")?.toIntOrNull()
            val artPath = widgetData.getString("np_art_path", null)

            views.setTextViewText(
                R.id.widget_title,
                if (hasTrack && !title.isNullOrEmpty()) title else "heerr",
            )
            views.setTextViewText(
                R.id.widget_artist,
                if (hasTrack && !artist.isNullOrEmpty()) artist else "Nothing playing",
            )

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

            // Rounded cover thumbnail (90%-of-max corner radius — a soft
            // rounded square, not a full circle). Decoded heavily downsampled
            // so the bitmap stays tiny (well under the Binder limit). Hidden
            // when there's no cover.
            val bitmap = if (!artPath.isNullOrEmpty() && File(artPath).exists()) {
                runCatching { roundedBitmap(artPath, MAX_ART_PX) }.getOrNull()
            } else {
                null
            }
            if (bitmap != null) {
                views.setImageViewBitmap(R.id.widget_art, bitmap)
                views.setViewVisibility(R.id.widget_art, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_art, View.GONE)
            }

            // Waveform "sync": animate only while playing, freeze otherwise.
            // A widget has no live-amplitude API; play/pause is the only state
            // the bars can honestly reflect.
            views.setViewVisibility(
                R.id.widget_wave,
                if (playing) View.VISIBLE else View.GONE,
            )
            views.setViewVisibility(
                R.id.widget_wave_static,
                if (playing) View.GONE else View.VISIBLE,
            )

            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )

            appWidgetManager.updateAppWidget(appWidgetId, views)
        }
    }

    /**
     * Decodes [path] downsampled to at most [maxPx], centre-crops to a square,
     * and masks it into a rounded square whose corner radius is
     * [CORNER_RADIUS_FRACTION] of the maximum (half the side). At 0.9 this is a
     * soft rounded square, just short of a full circle. Returns null if the
     * file can't be decoded.
     */
    private fun roundedBitmap(path: String, maxPx: Int): Bitmap? {
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
        val src = BitmapFactory.decodeFile(path, opts) ?: return null

        val size = min(src.width, src.height)
        val left = (src.width - size) / 2
        val top = (src.height - size) / 2
        val output = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(output)
        val shader = BitmapShader(src, Shader.TileMode.CLAMP, Shader.TileMode.CLAMP)
        // Shift the shader so the centre-cropped square maps to the output.
        shader.setLocalMatrix(android.graphics.Matrix().apply {
            setTranslate(-left.toFloat(), -top.toFloat())
        })
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply { this.shader = shader }
        val radius = (size / 2f) * CORNER_RADIUS_FRACTION
        canvas.drawRoundRect(0f, 0f, size.toFloat(), size.toFloat(), radius, radius, paint)
        return output
    }

    private companion object {
        // Max thumbnail edge (px). The pill cover is small, so a tight cap keeps
        // the RemoteViews bitmap payload well under the Binder limit.
        const val MAX_ART_PX = 192

        // Cover corner radius as a fraction of the max (half the side). 1.0 =
        // a full circle; the visible gap to the pill's rounded end comes from
        // the ImageView's uniform margin in the layout, not from this inset.
        const val CORNER_RADIUS_FRACTION = 1.0f
    }
}
