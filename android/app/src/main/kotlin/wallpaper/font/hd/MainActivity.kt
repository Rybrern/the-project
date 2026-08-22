package wallpaper.font.hd

import android.app.WallpaperManager
import android.content.ComponentName
import android.content.Intent
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
  }

  private companion object {
    const val PANORAMA_CHANNEL = "wallpaper.font.hd/panorama"
  }
}
