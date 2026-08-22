package wallpaper.font.hd

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.service.wallpaper.WallpaperService
import android.view.MotionEvent
import android.view.SurfaceHolder
import java.io.File

/** A lightweight live wallpaper that pans one still image across home pages. */
class ImagePannableWallpaperService : WallpaperService() {
  override fun onCreateEngine(): Engine = ImagePannableEngine()

  inner class ImagePannableEngine : Engine() {
    private val paint = Paint(Paint.FILTER_BITMAP_FLAG)
    private var bitmap: Bitmap? = null
    private var visible = false
    private var xOffset = 0.5f
    private var surfaceWidth = 0
    private var surfaceHeight = 0
    private var lastTouchX: Float? = null

    init {
      // Algunos launchers de MIUI no envían offsets entre escritorios. Al
      // habilitar eventos táctiles podemos desplazar la panorámica con un
      // arrastre directo sobre la pantalla de inicio cuando el launcher los
      // reenvía al fondo animado.
      setTouchEventsEnabled(true)
    }

    override fun onSurfaceChanged(
      holder: SurfaceHolder,
      format: Int,
      width: Int,
      height: Int,
    ) {
      super.onSurfaceChanged(holder, format, width, height)
      surfaceWidth = width
      surfaceHeight = height
      loadBitmap()
      drawFrame(holder)
    }

    override fun onVisibilityChanged(isVisible: Boolean) {
      visible = isVisible
      if (visible) drawFrame(surfaceHolder)
    }

    override fun onOffsetsChanged(
      xOffset: Float,
      yOffset: Float,
      xOffsetStep: Float,
      yOffsetStep: Float,
      xPixelOffset: Int,
      yPixelOffset: Int,
    ) {
      this.xOffset = xOffset.coerceIn(0f, 1f)
      if (visible) drawFrame(surfaceHolder)
    }

    override fun onTouchEvent(event: MotionEvent) {
      when (event.actionMasked) {
        MotionEvent.ACTION_DOWN -> lastTouchX = event.x
        MotionEvent.ACTION_MOVE -> {
          val previousX = lastTouchX
          if (previousX != null && surfaceWidth > 0) {
            val distance = event.x - previousX
            xOffset = (xOffset - distance / surfaceWidth).coerceIn(0f, 1f)
            lastTouchX = event.x
            if (visible) drawFrame(surfaceHolder)
          }
        }
        MotionEvent.ACTION_UP, MotionEvent.ACTION_CANCEL -> lastTouchX = null
      }
      super.onTouchEvent(event)
    }

    override fun onSurfaceDestroyed(holder: SurfaceHolder) {
      super.onSurfaceDestroyed(holder)
      bitmap?.recycle()
      bitmap = null
    }

    private fun loadBitmap() {
      bitmap?.recycle()
      val file = File(filesDir, IMAGE_FILE_NAME)
      if (!file.exists()) return

      val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
      BitmapFactory.decodeFile(file.path, bounds)
      val targetHeight = surfaceHeight.coerceAtLeast(1920) * 2
      var sampleSize = 1
      while (bounds.outHeight / sampleSize > targetHeight) sampleSize *= 2
      bitmap = BitmapFactory.decodeFile(
        file.path,
        BitmapFactory.Options().apply { inSampleSize = sampleSize },
      )
    }

    private fun drawFrame(holder: SurfaceHolder) {
      if (!visible || surfaceWidth == 0 || surfaceHeight == 0) return
      val image = bitmap ?: return
      var canvas: Canvas? = null
      try {
        canvas = holder.lockCanvas()
        if (canvas == null) return
        canvas.drawColor(Color.BLACK)
        val scale = maxOf(
          surfaceWidth.toFloat() / image.width,
          surfaceHeight.toFloat() / image.height,
        )
        val renderedWidth = image.width * scale
        val renderedHeight = image.height * scale
        val left = if (renderedWidth > surfaceWidth) {
          -(renderedWidth - surfaceWidth) * xOffset
        } else {
          (surfaceWidth - renderedWidth) / 2
        }
        val top = (surfaceHeight - renderedHeight) / 2
        canvas.drawBitmap(image, null, android.graphics.RectF(left, top, left + renderedWidth, top + renderedHeight), paint)
      } finally {
        if (canvas != null) holder.unlockCanvasAndPost(canvas)
      }
    }
  }

  companion object {
    const val IMAGE_FILE_NAME = "pannable_wallpaper.jpg"
  }
}
