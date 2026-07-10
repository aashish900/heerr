# R8/ProGuard keep rules for release builds.
#
# WorkManager (Phase Q / v2.0.0 background offline sync) uses a Room database
# whose generated `WorkDatabase_Impl` is instantiated reflectively. R8 strips
# the generated no-arg constructor in release builds, crashing at startup with
# `NoSuchMethodException: androidx.work.impl.WorkDatabase_Impl.<init> []`
# (the androidx.startup InitializationProvider can't bring WorkManager up).
# Keep WorkManager + its Room database constructors.
-keep class androidx.work.** { *; }
-keep class * extends androidx.work.Worker { *; }
-keep class * extends androidx.work.ListenableWorker { *; }

# Room: keep RoomDatabase subclasses and their reflectively-invoked
# no-arg constructors (covers WorkDatabase_Impl and any future Room DB).
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keepclassmembers class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.room.** { *; }

# audio_service (J1 / media notification + lock-screen controls). The
# AudioService + MediaButtonReceiver classes are auto-kept by AGP because
# they are declared in AndroidManifest.xml, but the plugin's internal
# MediaSession / notification-builder helper classes are not — R8 strips or
# obfuscates them, so the foreground service still starts (playback works)
# while the media notification and lock-screen controls silently stop
# rendering. Keep the whole plugin package.
-keep class com.ryanheise.audioservice.** { *; }

# just_audio: the ExoPlayer-backed playback engine behind audio_service.
# Its platform classes are referenced by the generated plugin registrant;
# keep them so R8 doesn't break playback/loading in release builds.
-keep class com.ryanheise.just_audio.** { *; }

# home_widget (#20 / Now Playing home-screen widget). HeroWidgetProvider is
# auto-kept by AGP (manifest-declared <receiver>), but it extends the
# plugin's HomeWidgetProvider and calls HomeWidgetLaunchIntent — keep the
# plugin package so R8 doesn't strip those superclass/helpers in release.
-keep class es.antonborri.home_widget.** { *; }
