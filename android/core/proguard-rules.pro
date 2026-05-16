-keepattributes *Annotation*,SourceFile,LineNumberTable,Signature,Exceptions,InnerClasses,EnclosingMethod

-keep class com.follow.clashm.core.** { *; }

-keepclassmembers class * {
    native <methods>;
}

-dontwarn com.follow.clashm.**
