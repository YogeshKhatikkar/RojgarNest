# ============================================================
# Flutter Engine — Keep everything
# ============================================================
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# ============================================================
# ✅ PLAY CORE — THE MAIN FIX for R8 "Missing class" errors
# ============================================================
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

-keep class com.google.android.play.core.** { *; }
-keep interface com.google.android.play.core.** { *; }
-keep enum com.google.android.play.core.** { *; }

-keep class io.flutter.embedding.android.FlutterPlayStoreSplitApplication { *; }
-keep class io.flutter.embedding.engine.deferredcomponents.** { *; }
-keep class io.flutter.embedding.engine.FlutterJNI { *; }
-keep class io.flutter.embedding.engine.loader.** { *; }

# ============================================================
# Razorpay (used in your payment module)
# ============================================================
-keep class com.razorpay.** { *; }
-dontwarn com.razorpay.**
-keepattributes *Annotation*

# ============================================================
# Google Play Billing (used by Razorpay SDK)
# ============================================================
-keep class com.android.vending.billing.** { *; }
-dontwarn com.android.vending.billing.**

# ============================================================
# Flutter Secure Storage / KeyStore
# ============================================================
-keep class androidx.security.crypto.** { *; }
-dontwarn androidx.security.crypto.**

# ============================================================
# Geolocator / Location plugins
# ============================================================
-keep class com.baseflow.geolocator.** { *; }
-dontwarn com.baseflow.geolocator.**

# ============================================================
# Local Auth (biometric)
# ============================================================
-keep class androidx.biometric.** { *; }
-dontwarn androidx.biometric.**

# ============================================================
# WebView Flutter
# ============================================================
-keep class io.flutter.plugins.webviewflutter.** { *; }
-dontwarn io.flutter.plugins.webviewflutter.**

# ============================================================
# PDF View / Printing
# ============================================================
-keep class com.shockwave.** { *; }
-dontwarn com.shockwave.**

# ============================================================
# General — preserve annotations, generics, native methods
# ============================================================
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod
-keepattributes Exceptions

-keepclasseswithmembernames class * {
    native <methods>;
}

# Preserve Parcelable
-keepclassmembers class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# Preserve Serializable
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}