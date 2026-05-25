-keepattributes *Annotation*,SourceFile,LineNumberTable,Signature,Exceptions,InnerClasses,EnclosingMethod

-keep class com.meowclash.app.core.** { *; }

-keepclassmembers class * {
    native <methods>;
}

-dontwarn com.meowclash.app.**
