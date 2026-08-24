/// Fondo animado (video en loop) traído de Pixabay Video. Se maneja aparte
/// de [Wallpaper] porque su flujo de vista previa y de aplicado es distinto:
/// no hay recorte de imagen, sino un video que se reproduce en bucle mudo
/// tanto en la previsualización como en el fondo de pantalla real.
class AnimatedWallpaper {
  const AnimatedWallpaper({
    required this.id,
    required this.previewImageUrl,
    required this.videoUrl,
    required this.width,
    required this.height,
  });

  final String id;
  final String previewImageUrl;
  final String videoUrl;
  final int width;
  final int height;

  double get aspectRatio => width / height;
}
