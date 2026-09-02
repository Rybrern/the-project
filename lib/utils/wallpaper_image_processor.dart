import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Decodifica con las mismas guardas anti-OOM que usa [cropToAspectRatio]:
/// rechaza payloads >25MB antes de decodificar, y resultados >50MP después
/// (una imagen maliciosa/corrupta puede reportar dimensiones absurdas).
img.Image? decodeSafely(Uint8List bytes) {
  if (bytes.length > 25 * 1024 * 1024) return null;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return null;
  if (decoded.width * decoded.height > 50 * 1000 * 1000) return null;
  if (decoded.width <= 0 || decoded.height <= 0) return null;
  return decoded;
}

/// Rota [bytes] en pasos de 90° ([quarterTurns] 1..3 = 90/180/270°
/// horario). `0` es un no-op que devuelve [bytes] sin recodificar. Pensada
/// para correr en un isolate vía `compute()`.
Uint8List rotateJpeg((Uint8List bytes, int quarterTurns) args) {
  final (bytes, quarterTurns) = args;
  final turns = quarterTurns % 4;
  if (turns == 0) return bytes;
  final decoded = decodeSafely(bytes);
  if (decoded == null) return bytes;
  final rotated = img.copyRotate(decoded, angle: 90 * turns);
  return Uint8List.fromList(img.encodeJpg(rotated, quality: 92));
}

/// Recorta el rectángulo exacto [x],[y],[width],[height] (en píxeles reales
/// de la imagen decodificada) y codifica. El rectángulo ya viene calculado
/// por la UI a partir del transform de un editor interactivo — acá solo se
/// clampea a los límites reales de la imagen por seguridad. Pensada para
/// correr en un isolate vía `compute()`.
Uint8List cropJpeg((Uint8List bytes, int x, int y, int width, int height) args) {
  final (bytes, x, y, width, height) = args;
  final decoded = decodeSafely(bytes);
  if (decoded == null) return bytes;

  final clampedX = x.clamp(0, decoded.width - 1);
  final clampedY = y.clamp(0, decoded.height - 1);
  final clampedWidth = width.clamp(1, decoded.width - clampedX);
  final clampedHeight = height.clamp(1, decoded.height - clampedY);

  final cropped = img.copyCrop(
    decoded,
    x: clampedX,
    y: clampedY,
    width: clampedWidth,
    height: clampedHeight,
  );
  return Uint8List.fromList(img.encodeJpg(cropped, quality: 92));
}

/// Recorta [bytes] al centro para que coincida con [targetAspectRatio]
/// (ancho / alto). Así, un fondo horizontal descargado de la API queda bien
/// encuadrado como fondo de pantalla vertical en vez de que el sistema
/// operativo lo recorte de forma arbitraria.
Uint8List cropToAspectRatio((Uint8List bytes, double targetAspectRatio) args) {
  final (bytes, targetAspectRatio) = args;
  // Defensa OOM: rechazar imágenes >25MB o con dimensiones absurdas antes de decodificar
  if (bytes.length > 25 * 1024 * 1024) return bytes;
  // Validar que targetAspectRatio sea razonable (evitar división por cero / valores extremos)
  if (!targetAspectRatio.isFinite || targetAspectRatio <= 0.2 || targetAspectRatio > 5) {
    return bytes;
  }
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;
  // Límite de megapíxeles para evitar OOM en isolate (ej: 50 MP)
  if (decoded.width * decoded.height > 50 * 1000 * 1000) return bytes;
  if (decoded.width <= 0 || decoded.height <= 0) return bytes;

  final sourceAspectRatio = decoded.width / decoded.height;

  var cropWidth = decoded.width;
  var cropHeight = decoded.height;

  if (sourceAspectRatio > targetAspectRatio) {
    cropWidth = (decoded.height * targetAspectRatio).round();
  } else if (sourceAspectRatio < targetAspectRatio) {
    cropHeight = (decoded.width / targetAspectRatio).round();
  }

  final x = ((decoded.width - cropWidth) / 2).round();
  final y = ((decoded.height - cropHeight) / 2).round();

  final cropped = img.copyCrop(decoded, x: x, y: y, width: cropWidth, height: cropHeight);
  return Uint8List.fromList(img.encodeJpg(cropped, quality: 92));
}
