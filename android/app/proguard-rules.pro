-keepattributes *Annotation*,SourceFile,LineNumberTable,Signature,Exceptions,InnerClasses,EnclosingMethod

-keep class com.meowclash.app.models.** { *; }
-keep class com.meowclash.app.core.** { *; }
-keep class com.meowclash.app.plugins.** { *; }
-keep class com.meowclash.app.services.** { *; }
-keep class com.meowclash.app.widgets.** { *; }
-keep class com.meowclash.app.MeowClashApplication { *; }
-keep class com.meowclash.app.MainActivity { *; }
-keep class com.meowclash.app.TempActivity { *; }
-keep class com.meowclash.app.FilesProvider { *; }
-keep class com.meowclash.app.GlobalState { *; }

-dontwarn com.meowclash.app.**
-dontwarn com.google.gson.**
-dontwarn javax.xml.stream.**
-dontwarn javax.xml.bind.**
-dontwarn javax.annotation.**
-dontwarn org.apache.**
-dontwarn kotlinx.coroutines.**
