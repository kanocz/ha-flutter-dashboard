# Keep ImageIO classes for qr_code_tools
-keep class javax.imageio.** { *; }
-keep class com.github.jaiimageio.** { *; }
-dontwarn javax.imageio.**
-dontwarn com.github.jaiimageio.**

# Keep QR code tools classes
-keep class com.google.zxing.** { *; }
-dontwarn com.google.zxing.**

# Keep reflection classes
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}