# SPECTRA / HearClear ProGuard / R8 rules.
#
# TFLite ships optional GPU and NNAPI delegate classes that R8 can't find at
# build time (they live in separate artifacts). Tell R8 not to fail on them.
-dontwarn org.tensorflow.lite.gpu.**
-keep class org.tensorflow.lite.gpu.** { *; }

-dontwarn org.tensorflow.lite.nnapi.**
-keep class org.tensorflow.lite.nnapi.** { *; }

-keep class org.tensorflow.lite.** { *; }

# speech_to_text plugin reflects on these.
-keep class com.csdcorp.speech_to_text.** { *; }

# record / record_android plugin uses MediaCodec; keep its native bridges.
-keep class com.llfbandit.record.** { *; }

# permission_handler reflects over permission constants.
-keep class com.baseflow.permissionhandler.** { *; }
