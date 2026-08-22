import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Recorta [bytes] al centro para que coincida con [targetAspectRatio]
/// (ancho / alto). Así, un fondo horizontal descargado de la API queda bien
/// encuadrado como fondo de pantalla vertical en vez de que el sistema
/// operativo lo recorte de forma arbitraria.
Uint8List cropToAspectRatio(
  (Uint8List bytes, double targetAspectRatio, double horizontalAlignment) args,
) {
  final (bytes, targetAspectRatio, horizontalAlignment) = args;
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return bytes;

  final sourceAspectRatio = decoded.width / decoded.height;

  var cropWidth = decoded.width;
  var cropHeight = decoded.height;

  if (sourceAspectRatio > targetAspectRatio) {
    cropWidth = (decoded.height * targetAspectRatio).round();
  } else if (sourceAspectRatio < targetAspectRatio) {
    cropHeight = (decoded.width / targetAspectRatio).round();
  }

  final x = ((decoded.width - cropWidth) * horizontalAlignment.clamp(0, 1))
      .round();
  final y = ((decoded.height - cropHeight) / 2).round();

  final cropped = img.copyCrop(
    decoded,
    x: x,
    y: y,
    width: cropWidth,
    height: cropHeight,
  );
  return Uint8List.fromList(img.encodeJpg(cropped, quality: 92));
}
