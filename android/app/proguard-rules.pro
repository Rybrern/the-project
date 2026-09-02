# OkHttp (usado indirectamente por Firebase/http) referencia estos proveedores
# TLS opcionales en tiempo de compilación, pero nunca se cargan en Android.
-dontwarn org.conscrypt.Conscrypt
-dontwarn org.conscrypt.OpenSSLProvider

# WorkManager (dependencia transitiva de Firebase/AdMob) instancia su
# WorkDatabase generada por Room vía reflection en el arranque de la app.
# Sin esta regla, R8 la renombra/elimina y la app crashea al iniciar con
# NoSuchMethodException: androidx.work.impl.WorkDatabase_Impl.<init>.
-keep class * extends androidx.room.RoomDatabase
-keep class androidx.work.impl.WorkDatabase_Impl { <init>(); }
-dontwarn androidx.room.**
# Flutter — mantener entry points
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.view.** { *; }
# gal / share_plus reflection
-keep class com.** { *; }
