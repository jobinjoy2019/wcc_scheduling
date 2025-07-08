# Flutter and Dart keep rules
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# Firebase (Firestore/Auth/Analytics safe defaults)
-keep class com.google.firebase.** { *; }
-dontwarn com.google.firebase.**

# Keep your Firestore model classes (update with your package)
-keep class com.wcc.croissant.** { *; }

# Preserve annotated fields for Firestore
-keepclassmembers class * {
  @com.google.firebase.firestore.PropertyName <methods>;
}

# (Optional) If you use Gson or Retrofit
# -keep class com.google.gson.** { *; }

# Prevent R8 from removing your MainActivity
-keep class com.wcc.croissant { *; }

-dontwarn com.google.android.play.core.splitcompat.SplitCompatApplication
-dontwarn com.google.android.play.core.splitinstall.SplitInstallException
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManager
-dontwarn com.google.android.play.core.splitinstall.SplitInstallManagerFactory
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest$Builder
-dontwarn com.google.android.play.core.splitinstall.SplitInstallRequest
-dontwarn com.google.android.play.core.splitinstall.SplitInstallSessionState
-dontwarn com.google.android.play.core.splitinstall.SplitInstallStateUpdatedListener
-dontwarn com.google.android.play.core.tasks.OnFailureListener
-dontwarn com.google.android.play.core.tasks.OnSuccessListener
-dontwarn com.google.android.play.core.tasks.Task