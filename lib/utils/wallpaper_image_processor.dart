import 'dart:typed_data';

import 'package:image/image.dart' as img;

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
