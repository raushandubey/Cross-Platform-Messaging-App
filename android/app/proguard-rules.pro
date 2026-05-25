# Flutter wrapper
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }

# Firebase Messaging
-keep class com.google.firebase.messaging.** { *; }

# Kotlin
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }

# Prevent stripping of annotations used by Firebase and Flutter plugins
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes EnclosingMethod

# Suppress notes about duplicate class definitions from Firebase/Google Play Services
-dontnote com.google.**
-dontnote io.flutter.**

# Play Core Split Install (R8 warning workaround)
-dontwarn com.google.android.play.core.**
