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
