import 'dart:typed_data';

import 'package:image/image.dart' as img;

import '../state/quality_settings_controller.dart';

/// Recorta [bytes] al centro para que coincida con [targetAspectRatio]
/// (ancho / alto). Así, un fondo horizontal descargado de la API queda bien
/// encuadrado como fondo de pantalla vertical en vez de que el sistema
/// operativo lo recorte de forma arbitraria.
///
/// [maxDimension] y [jpegQuality] vienen de la preferencia de calidad del
/// usuario (ver `QualitySettingsController`/`imageQualityParams`); se pasan
/// ya resueltos porque esta función corre dentro de un isolate (`compute()`)
/// y no tiene acceso a `Provider`.
Uint8List cropToAspectRatio(
  (
    Uint8List bytes,
    double targetAspectRatio,
    double horizontalAlignment,
    int maxDimension,
    int jpegQuality,
  ) args,
) {
  final (bytes, targetAspectRatio, horizontalAlignment, maxDimension, jpegQuality) = args;
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

  var cropped = img.copyCrop(
    decoded,
    x: x,
    y: y,
    width: cropWidth,
    height: cropHeight,
  );

  // El encoder JPEG de `package:image` puede generar archivos corruptos
  // (tabla Huffman inválida) con recortes muy angostos sacados de fuentes en
  // alta resolución — pasa justo con fondos verticales recortados a la
  // relación de aspecto angosta de un celular. Bajar a un tamaño razonable
  // de pantalla antes de codificar evita ese caso límite del encoder, además
  // de ser el mecanismo real detrás de la preferencia de calidad del usuario.
  if (cropped.height > maxDimension) {
    cropped = img.copyResize(cropped, height: maxDimension);
  }

  return Uint8List.fromList(img.encodeJpg(cropped, quality: jpegQuality));
}

/// Resuelve [ImageQuality] a los parámetros concretos que usa
/// [cropToAspectRatio]. Nunca hace upscale: `copyResize` solo actúa cuando
/// el recorte ya excede `maxDimension`.
({int maxDimension, int jpegQuality}) imageQualityParams(ImageQuality quality) {
  switch (quality) {
    case ImageQuality.balanced:
      return (maxDimension: 1600, jpegQuality: 88);
    case ImageQuality.high:
      return (maxDimension: 2400, jpegQuality: 94);
    case ImageQuality.maximum:
      return (maxDimension: 3200, jpegQuality: 97);
  }
}
