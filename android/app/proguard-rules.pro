-keepattributes *Annotation*,SourceFile,LineNumberTable,Signature,Exceptions,InnerClasses,EnclosingMethod

-keep class com.follow.clashm.models.** { *; }
-keep class com.follow.clashm.core.** { *; }
-keep class com.follow.clashm.plugins.** { *; }
-keep class com.follow.clashm.services.** { *; }
-keep class com.follow.clashm.widgets.** { *; }
-keep class com.follow.clashm.MeowClashApplication { *; }
-keep class com.follow.clashm.MainActivity { *; }
-keep class com.follow.clashm.TempActivity { *; }
-keep class com.follow.clashm.FilesProvider { *; }
-keep class com.follow.clashm.GlobalState { *; }

-dontwarn com.follow.clashm.**
-dontwarn com.google.gson.**
-dontwarn javax.xml.stream.**
-dontwarn javax.xml.bind.**
-dontwarn javax.annotation.**
-dontwarn org.apache.**
-dontwarn kotlinx.coroutines.**
