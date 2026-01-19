-keepattributes Signature
-keepattributes *Annotation*

-keep class com.google.gson.reflect.TypeToken { *; }
-keep class com.google.gson.** { *; }
-dontwarn com.google.gson.**

-keep class com.dexterous.flutterlocalnotifications.models.** { *; }
