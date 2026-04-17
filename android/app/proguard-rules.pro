# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Play Core (referenced by Flutter deferred components, not used)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# Drift / SQLite
-keep class org.sqlite.** { *; }

# USB Serial
-keep class com.hoho.android.usbserial.** { *; }

# just_audio
-keep class com.google.android.exoplayer2.** { *; }

# GraphHopper offline routing — reflection-heavy, keep everything
-keep class com.graphhopper.** { *; }
-keep class com.carrotsearch.** { *; }
-dontwarn com.graphhopper.**
-dontwarn javax.xml.bind.**
-dontwarn org.slf4j.**
