# OkHttp (usado indirectamente por Firebase/http) referencia estos proveedores
# TLS opcionales en tiempo de compilación, pero nunca se cargan en Android.
-dontwarn org.conscrypt.Conscrypt
-dontwarn org.conscrypt.OpenSSLProvider
