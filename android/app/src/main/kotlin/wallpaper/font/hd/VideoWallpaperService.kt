package wallpaper.font.hd

import android.media.MediaPlayer
import android.os.Handler
import android.os.Looper
import android.service.wallpaper.WallpaperService
import android.util.Log
import android.view.SurfaceHolder
import java.io.File

/** Fondo de pantalla en video: reproduce en loop mudo el mp4 más reciente
 * guardado por [MainActivity] (Pixabay Video / Giphy siempre entregan .mp4). */
class VideoWallpaperService : WallpaperService() {
  override fun onCreateEngine(): Engine = VideoEngine()

  inner class VideoEngine : Engine() {
    private var player: MediaPlayer? = null
    private var currentHolder: SurfaceHolder? = null
    private val mainHandler = Handler(Looper.getMainLooper())
    private var retryCount = 0

    // prepareAsync() es asíncrono: Android dispara onVisibilityChanged(true)
    // casi siempre inmediatamente después de onSurfaceCreated, es decir antes
    // de que onPrepared llegue. Llamar start()/pause() en ese punto lanza
    // IllegalStateException (MediaPlayer sigue en estado Initialized), lo que
    // mata el Engine en silencio y deja el wallpaper "aplicado" pero en
    // blanco. isPrepared + wantsToPlay evitan tocar el player antes de tiempo
    // y retoman el estado correcto apenas termina de prepararse.
    private var isPrepared = false
    // Un engine recién creado casi siempre está visible; arrancar en true evita
    // quedarse pausado si el sistema no llega a disparar onVisibilityChanged
    // antes de que termine prepareAsync().
    private var wantsToPlay = true
    // pause() antes de haber llamado nunca start() es un estado inválido: en
    // algunos dispositivos (visto en un Redmi Note 11 / MIUI) no lanza
    // excepción sino que corrompe el MediaPlayer en silencio (error -38) y
    // termina matando el proceso de medios (error 100, MEDIA_ERROR_SERVER_DIED),
    // dejando el engine "aplicado" pero congelado hasta reiniciar el celular.
    // hasStarted evita pausar antes del primer start().
    private var hasStarted = false
    // Cuando la app ya es el fondo activo y el usuario aplica uno nuevo,
    // Android a veces reutiliza este mismo Engine en la pantalla de inicio en
    // vez de crear uno nuevo (onSurfaceCreated no vuelve a llamarse). Sin este
    // chequeo, el MediaPlayer se queda reproduciendo en loop el video viejo
    // que ya tenía cargado en memoria aunque MainActivity haya sobrescrito el
    // archivo en disco con el nuevo. Comparar lastModified() en cada
    // onVisibilityChanged(true) detecta el cambio y recarga.
    private var loadedFileTimestamp = -1L

    override fun onSurfaceCreated(holder: SurfaceHolder) {
      super.onSurfaceCreated(holder)
      currentHolder = holder
      retryCount = 0
      startPlayer(holder)
    }

    override fun onSurfaceChanged(holder: SurfaceHolder, format: Int, width: Int, height: Int) {
      super.onSurfaceChanged(holder, format, width, height)
      Log.d(TAG, "onSurfaceChanged: ${width}x$height isPrepared=$isPrepared sameHolder=${holder === currentHolder}")
      currentHolder = holder
      // El sistema reemplaza la Surface real al pasar de la vista previa a
      // fijar el fondo definitivo (visto en un Redmi Note 11 / MIUI: el video
      // quedaba "reproduciendo" según los logs pero congelado en el primer
      // frame en la pantalla de inicio real). Sin re-enlazar acá, el
      // MediaPlayer sigue decodificando hacia una Surface vieja que ya nadie
      // muestra en pantalla.
      val current = player
      if (current == null || !isPrepared) return
      try {
        current.setSurface(holder.surface)
        Log.d(TAG, "Surface re-enlazada en onSurfaceChanged")
      } catch (error: Exception) {
        Log.e(TAG, "No se pudo re-enlazar la superficie, recreando el player", error)
        startPlayer(holder)
      }
    }

    override fun onVisibilityChanged(visible: Boolean) {
      wantsToPlay = visible
      if (visible && hasFileChangedSinceLoad()) {
        val holder = currentHolder
        if (holder != null) {
          Log.d(TAG, "Archivo de video cambió desde la última carga, recargando")
          startPlayer(holder)
          return
        }
      }
      if (!isPrepared) {
        Log.d(TAG, "onVisibilityChanged($visible) ignorado: player aún no preparado")
        return
      }
      Log.d(TAG, "onVisibilityChanged($visible) aplicando")
      applyPlaybackState()
    }

    private fun hasFileChangedSinceLoad(): Boolean {
      val file = File(filesDir, VIDEO_FILE_NAME)
      return file.exists() && file.lastModified() != loadedFileTimestamp
    }

    override fun onSurfaceDestroyed(holder: SurfaceHolder) {
      super.onSurfaceDestroyed(holder)
      currentHolder = null
      mainHandler.removeCallbacksAndMessages(null)
      releasePlayer()
    }

    override fun onDestroy() {
      super.onDestroy()
      mainHandler.removeCallbacksAndMessages(null)
      releasePlayer()
    }

    private fun applyPlaybackState() {
      val current = player ?: return
      try {
        if (wantsToPlay) {
          current.start()
          hasStarted = true
        } else if (hasStarted) {
          current.pause()
        }
      } catch (error: IllegalStateException) {
        Log.e(TAG, "Error al cambiar estado de reproducción", error)
      }
    }

    private fun releasePlayer() {
      isPrepared = false
      hasStarted = false
      try {
        player?.release()
      } catch (error: IllegalStateException) {
        Log.e(TAG, "Error al liberar MediaPlayer", error)
      }
      player = null
    }

    private fun startPlayer(holder: SurfaceHolder) {
      val file = File(filesDir, VIDEO_FILE_NAME)
      if (!file.exists()) {
        Log.e(TAG, "No existe $VIDEO_FILE_NAME en $filesDir; no se puede aplicar el fondo animado")
        return
      }

      releasePlayer()
      loadedFileTimestamp = file.lastModified()
      try {
        player = MediaPlayer().apply {
          setDataSource(file.path)
          setSurface(holder.surface)
          isLooping = true
          setVolume(0f, 0f)
          // El contenido de Pixabay/Giphy casi siempre es horizontal o
          // cuadrado; esto lo recorta al centro para llenar la pantalla
          // vertical en vez de estirarlo o dejarlo con bandas negras.
          setVideoScalingMode(MediaPlayer.VIDEO_SCALING_MODE_SCALE_TO_FIT_WITH_CROPPING)
          setOnPreparedListener {
            retryCount = 0
            isPrepared = true
            Log.d(TAG, "MediaPlayer preparado, aplicando estado (wantsToPlay=$wantsToPlay)")
            applyPlaybackState()
          }
          setOnErrorListener { _, what, extra ->
            Log.e(TAG, "MediaPlayer error what=$what extra=$extra archivo=${file.path}")
            isPrepared = false
            scheduleRetry()
            true
          }
          prepareAsync()
        }
      } catch (error: Exception) {
        Log.e(TAG, "No se pudo preparar el video ${file.path}", error)
        scheduleRetry()
      }
    }

    // Si el reproductor entra en error (p.ej. el mediaserver murió), reintenta
    // recrearlo en vez de dejar el wallpaper congelado hasta que el usuario
    // reinicie el teléfono. Acotado para no reintentar en loop infinito si el
    // archivo de video está realmente corrupto.
    private fun scheduleRetry() {
      val holder = currentHolder ?: return
      if (retryCount >= MAX_RETRIES) {
        Log.e(TAG, "Se alcanzó el máximo de reintentos ($MAX_RETRIES), abandonando")
        return
      }
      retryCount++
      Log.d(TAG, "Reintentando preparar el video (intento $retryCount/$MAX_RETRIES)")
      mainHandler.postDelayed({ startPlayer(holder) }, RETRY_DELAY_MS)
    }
  }

  companion object {
    const val VIDEO_FILE_NAME = "video_wallpaper.mp4"
    private const val TAG = "VideoWallpaperService"
    private const val MAX_RETRIES = 3
    private const val RETRY_DELAY_MS = 500L
  }
}
