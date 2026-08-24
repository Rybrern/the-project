package wallpaper.font.hd

import android.app.WallpaperManager
import android.content.ComponentName
import android.content.Intent
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
  override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PANORAMA_CHANNEL)
      .setMethodCallHandler { call, result ->
        if (call.method != "setPannableWallpaper") {
          result.notImplemented()
          return@setMethodCallHandler
        }

        val sourcePath = call.argument<String>("path")
        val source = sourcePath?.let(::File)
        if (source == null || !source.exists()) {
          result.error("invalid_file", "No se encontró la imagen para el fondo.", null)
          return@setMethodCallHandler
        }

        try {
          source.copyTo(File(filesDir, ImagePannableWallpaperService.IMAGE_FILE_NAME), overwrite = true)
          val intent = Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER).apply {
            putExtra(
              WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT,
              ComponentName(this@MainActivity, ImagePannableWallpaperService::class.java),
            )
          }
          startActivity(intent)
          result.success(true)
        } catch (error: Exception) {
          result.error("set_wallpaper_failed", error.message, null)
        }
      }
    MethodChannel(flutterEngine.dartExecutor.binaryMessenger, VIDEO_CHANNEL)
      .setMethodCallHandler { call, result ->
        if (call.method == "isActiveHomeWallpaper") {
          // Compara el componente del live wallpaper activo en el sistema
          // (si hay uno) contra el nuestro. No distingue QUÉ video está
          // cargado adentro (Android no lo sabe, solo el componente), así
          // que del lado de Flutter esto se combina con el id del último
          // fondo aplicado con éxito para saber si es "este mismo" fondo.
          val activeInfo = WallpaperManager.getInstance(this).wallpaperInfo
          val isOurs = activeInfo?.component == ComponentName(this, VideoWallpaperService::class.java)
          result.success(isOurs)
          return@setMethodCallHandler
        }

        if (call.method != "setVideoWallpaper") {
          result.notImplemented()
          return@setMethodCallHandler
        }

        val sourcePath = call.argument<String>("path")
        val source = sourcePath?.let(::File)
        if (source == null || !source.exists()) {
          Log.e(TAG, "setVideoWallpaper: archivo inexistente en $sourcePath")
          result.error("invalid_file", "No se encontró el video para el fondo.", null)
          return@setMethodCallHandler
        }

        try {
          val bytesCopied = source.copyTo(
            File(filesDir, VideoWallpaperService.VIDEO_FILE_NAME),
            overwrite = true,
          ).length()
          Log.d(TAG, "setVideoWallpaper: copiados $bytesCopied bytes, lanzando picker de live wallpaper")
          val intent = Intent(WallpaperManager.ACTION_CHANGE_LIVE_WALLPAPER).apply {
            putExtra(
              WallpaperManager.EXTRA_LIVE_WALLPAPER_COMPONENT,
              ComponentName(this@MainActivity, VideoWallpaperService::class.java),
            )
          }
          startActivity(intent)
          result.success(true)
        } catch (error: Exception) {
          Log.e(TAG, "setVideoWallpaper: fallo al aplicar", error)
          result.error("set_wallpaper_failed", error.message, null)
        }
      }
  }

  private companion object {
    const val PANORAMA_CHANNEL = "wallpaper.font.hd/panorama"
    const val VIDEO_CHANNEL = "wallpaper.font.hd/video_wallpaper"
    const val TAG = "MainActivity"
  }
}
