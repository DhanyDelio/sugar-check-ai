# Keep MLKit text recognizer optional language classes
-dontwarn com.google.mlkit.vision.text.chinese.**
-dontwarn com.google.mlkit.vision.text.devanagari.**
-dontwarn com.google.mlkit.vision.text.japanese.**
-dontwarn com.google.mlkit.vision.text.korean.**

# Keep TFLite
-keep class org.tensorflow.** { *; }
-dontwarn org.tensorflow.**

# Keep Flutter
-keep class io.flutter.** { *; }
-dontwarn io.flutter.**
