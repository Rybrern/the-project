import 'package:image/image.dart' as img;
import 'package:flutter/foundation.dart';

/// Generador de perceptual hash (pHash) para deduplicación visual.
/// Permite detectar imágenes similares incluso con pequeñas variaciones.
class PerceptualHashGenerator {
  /// Tamaño de la imagen normalizada para cálculo de hash
  static const int hashSize = 8;

  /// Genera un pHash a partir de datos de imagen
  /// Retorna string de 64 caracteres (0s y 1s)
  Future<String> generateHash(Uint8List imageData) async {
    try {
      // Decodifica imagen
      final image = img.decodeImage(imageData);
      if (image == null) return '';

      // Redimensiona a 8x8
      final resized = img.copyResize(
        image,
        width: hashSize,
        height: hashSize,
      );

      // Convierte a escala de grises
      final grayscale = _toGrayscale(resized);

      // Calcula DCT (Discrete Cosine Transform)
      final dct = _computeDCT(grayscale);

      // Calcula promedio de los valores DCT (exceptuando el primero)
      final avg = _calculateAverage(dct);

      // Crea hash binario
      final hash = _createBinaryHash(dct, avg);

      return hash;
    } catch (e) {
      debugPrint('PerceptualHashGenerator: Error generating hash: $e');
      return '';
    }
  }

  /// Convierte imagen a escala de grises
  List<List<double>> _toGrayscale(img.Image image) {
    final grayscale = <List<double>>[];

    for (int y = 0; y < image.height; y++) {
      final row = <double>[];
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixelSafe(x, y);
        // Fórmula estándar de conversión a gris
        final gray = 0.299 * pixel.r + 0.587 * pixel.g + 0.114 * pixel.b;
        row.add(gray.toDouble());
      }
      grayscale.add(row);
    }

    return grayscale;
  }

  /// Calcula DCT (muy simplificado)
  List<List<double>> _computeDCT(List<List<double>> grayscale) {
    final result = <List<double>>[];

    for (int u = 0; u < hashSize; u++) {
      final row = <double>[];
      for (int v = 0; v < hashSize; v++) {
        double sum = 0;
        final cu = u == 0 ? 1 / 2 : 1;
        final cv = v == 0 ? 1 / 2 : 1;

        for (int x = 0; x < hashSize; x++) {
          for (int y = 0; y < hashSize; y++) {
            sum += grayscale[x][y] *
                _cos((2 * x + 1) * u * 3.14159 / (2 * hashSize)) *
                _cos((2 * y + 1) * v * 3.14159 / (2 * hashSize));
          }
        }

        final value = 0.25 * cu * cv * sum;
        row.add(value);
      }
      result.add(row);
    }

    return result;
  }

  /// Calcula promedio de valores DCT
  double _calculateAverage(List<List<double>> dct) {
    double sum = 0;
    int count = 0;

    for (int i = 0; i < dct.length; i++) {
      for (int j = 0; j < dct[i].length; j++) {
        if (i == 0 && j == 0) continue; // Salta componente DC
        sum += dct[i][j];
        count++;
      }
    }

    return count == 0 ? 0 : sum / count;
  }

  /// Crea hash binario
  String _createBinaryHash(List<List<double>> dct, double avg) {
    final hash = StringBuffer();

    for (int i = 0; i < dct.length; i++) {
      for (int j = 0; j < dct[i].length; j++) {
        if (i == 0 && j == 0) continue;
        hash.write(dct[i][j] > avg ? '1' : '0');
      }
    }

    return hash.toString();
  }

  /// Cálculo de coseno (simplificado)
  double _cos(double value) {
    // Retorna aproximación de coseno para el rango [0, 2π]
    const pi = 3.14159265359;
    value = value % (2 * pi);

    if (value < 0) value += 2 * pi;

    // Series de Taylor
    double result = 1;
    double term = 1;
    for (int n = 1; n < 10; n++) {
      term *= -value * value / (2 * n * (2 * n - 1));
      result += term;
    }

    return result;
  }
}

/// Comparador de hashes perceptuales
class PerceptualHashComparator {
  /// Calcula distancia de Hamming entre dos hashes
  /// Rango: 0 (idéntico) a 64 (completamente diferente)
  static int hammingDistance(String hash1, String hash2) {
    if (hash1.length != hash2.length) return 64;

    int distance = 0;
    for (int i = 0; i < hash1.length; i++) {
      if (hash1[i] != hash2[i]) distance++;
    }

    return distance;
  }

  /// Verifica similitud entre dos hashes
  /// threshold: máxima distancia de Hamming permitida
  /// (0-10: muy similar, 10-20: similar, 20+: diferentes)
  static bool isSimilar(
    String hash1,
    String hash2, {
    int threshold = 5,
  }) {
    return hammingDistance(hash1, hash2) <= threshold;
  }

  /// Calcula porcentaje de similitud (0-100)
  static double similarityPercentage(String hash1, String hash2) {
    final distance = hammingDistance(hash1, hash2);
    return ((64 - distance) / 64 * 100).clamp(0, 100);
  }
}
