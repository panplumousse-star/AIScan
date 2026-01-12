# Flutter specific rules
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ML Kit Document Scanner
-keep class com.google.mlkit.** { *; }
-dontwarn com.google.mlkit.**

# Tesseract OCR
-keep class com.googlecode.tesseract.android.** { *; }
-keep class org.bytedeco.** { *; }

# Flutter Secure Storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# Encryption libraries
-keep class javax.crypto.** { *; }
-keep class java.security.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep annotations
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
