package com.aashish.heerr

import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.support.v4.media.MediaBrowserCompat
import android.support.v4.media.session.MediaControllerCompat

/**
 * Handles hero-widget progress-bar taps. Each tap zone broadcasts
 * [ACTION_WIDGET_SEEK] with a 0..1 fraction of the track (see
 * HeroWidgetProvider.seekIntent); this scales it by `np_duration_ms` (the
 * same [HOME_WIDGET_PREFS] the provider reads) and forwards a seekTo to
 * audio_service's live MediaSession.
 *
 * audio_service's AudioService exposes no static session hook, so the only
 * route in is a short-lived MediaBrowserCompat connection to fetch the
 * session token, then MediaControllerCompat.transportControls.seekTo.
 */
class WidgetSeekReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != ACTION_WIDGET_SEEK) return
        val fraction = intent.getFloatExtra(EXTRA_SEEK_FRACTION, -1f)
        if (fraction < 0f || fraction > 1f) return
        val durationMs = context
            .getSharedPreferences(HOME_WIDGET_PREFS, Context.MODE_PRIVATE)
            .getString("np_duration_ms", "")?.toLongOrNull() ?: return
        if (durationMs <= 0L) return
        val targetMs = (durationMs * fraction).toLong()

        val result = goAsync()
        var browser: MediaBrowserCompat? = null
        browser = MediaBrowserCompat(
            context,
            ComponentName(context.packageName, AUDIO_SERVICE_CLASS),
            object : MediaBrowserCompat.ConnectionCallback() {
                override fun onConnected() {
                    try {
                        MediaControllerCompat(context, browser!!.sessionToken)
                            .transportControls.seekTo(targetMs)
                    } finally {
                        browser?.disconnect()
                        result.finish()
                    }
                }

                override fun onConnectionFailed() {
                    result.finish()
                }

                override fun onConnectionSuspended() {
                    result.finish()
                }
            },
            null,
        )
        browser.connect()
    }

    companion object {
        const val ACTION_WIDGET_SEEK = "com.aashish.heerr.WIDGET_SEEK"
        const val EXTRA_SEEK_FRACTION = "seek_fraction"

        /** Base requestCode offset so seek PendingIntents never collide with
         *  mediaButtonIntent's raw-keycode requestCodes (< 100). */
        const val REQUEST_BASE = 100

        private const val AUDIO_SERVICE_CLASS = "com.ryanheise.audioservice.AudioService"
    }
}
