# Add project specific ProGuard rules here.

# Keep media_kit classes
-keep class media.kit.** { *; }
-keep class com.alexmercerind.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep OpenGL ES related classes
-keep class android.opengl.** { *; }
-keep class javax.microedition.khronos.** { *; }

# Keep video player related classes
-keep class io.flutter.plugins.videoplayer.** { *; }
