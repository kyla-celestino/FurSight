import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

class DetectionResult {
  final String animalType;
  final double confidence;
  final List<double> boundingBox;
  final img.Image croppedImage;

  DetectionResult({
    required this.animalType,
    required this.confidence,
    required this.boundingBox,
    required this.croppedImage,
  });
}

class AIService {
  static const double SIMILARITY_THRESHOLD = 0.65;
  static const int DETECT_INPUT_SIZE = 416;
  static const int REID_INPUT_SIZE = 224;
  static const int EMBEDDING_DIM = 128;

  Interpreter? _detectInterpreter;
  Interpreter? _reidInterpreter;
  List<String> _labels = [];
  bool _isLoaded = false;

  Future<void> loadModels() async {
    if (_isLoaded) return;
    try {
      _detectInterpreter = await Interpreter.fromAsset(
        'assets/models/detect.tflite',
        options: InterpreterOptions()..threads = 4,
      );
      _reidInterpreter = await Interpreter.fromAsset(
        'assets/models/reid.tflite',
        options: InterpreterOptions()..threads = 4,
      );
      final labelsData = await rootBundle.loadString(
        'assets/models/detect_labels.txt',
      );
      _labels = labelsData
          .split('\n')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
      _isLoaded = true;
    } catch (e) {
      throw Exception('Failed to load AI models: $e');
    }
  }

  Future<DetectionResult?> detectAnimal(File imageFile) async {
    await loadModels();

    final rawImage = img.decodeImage(await imageFile.readAsBytes());
    if (rawImage == null) return null;

    final resized = img.copyResize(
      rawImage,
      width: DETECT_INPUT_SIZE,
      height: DETECT_INPUT_SIZE,
    );

    final input = _imageToFloat32Detection(resized, DETECT_INPUT_SIZE);

    final outputShape = _detectInterpreter!.getOutputTensor(0).shape;
    final output = List.generate(
      outputShape[0],
      (_) => List.generate(
        outputShape[1],
        (_) => List.filled(outputShape[2], 0.0),
      ),
    );

    _detectInterpreter!.run(input, output);
    return _parseDetectionOutput(output[0], rawImage);
  }

  DetectionResult? _parseDetectionOutput(
    List<List<double>> output,
    img.Image originalImage,
  ) {
    double bestConf = 0.15;
    int bestIdx = -1;
    int bestClass = -1;

    final numDetections = output[0].length;

    for (int i = 0; i < numDetections; i++) {
      final catConf = output[4][i];
      final dogConf = output[5][i];
      final maxConf = max(catConf, dogConf);
      final classIdx = catConf > dogConf ? 0 : 1;

      if (maxConf > bestConf) {
        bestConf = maxConf;
        bestIdx = i;
        bestClass = classIdx;
      }
    }

    if (bestIdx == -1) return null;

    final cx = output[0][bestIdx];
    final cy = output[1][bestIdx];
    final bw = output[2][bestIdx];
    final bh = output[3][bestIdx];

    final x = (cx - bw / 2).clamp(0.0, 1.0);
    final y = (cy - bh / 2).clamp(0.0, 1.0);
    final w = bw.clamp(0.0, 1.0 - x);
    final h = bh.clamp(0.0, 1.0 - y);

    final cropX = (x * originalImage.width).toInt();
    final cropY = (y * originalImage.height).toInt();
    final cropW = (w * originalImage.width)
        .toInt()
        .clamp(1, originalImage.width - cropX);
    final cropH = (h * originalImage.height)
        .toInt()
        .clamp(1, originalImage.height - cropY);

    final cropped = img.copyCrop(
      originalImage,
      x: cropX,
      y: cropY,
      width: cropW,
      height: cropH,
    );

    return DetectionResult(
      animalType: bestClass == 0 ? 'cat' : 'dog',
      confidence: bestConf,
      boundingBox: [x, y, w, h],
      croppedImage: cropped,
    );
  }

  Future<List<double>> getEmbedding(img.Image animalImage) async {
    await loadModels();

    final resized = img.copyResize(
      animalImage,
      width: REID_INPUT_SIZE,
      height: REID_INPUT_SIZE,
    );

    final input = _imageToFloat32Reid(resized, REID_INPUT_SIZE);
    final output = List.generate(1, (_) => List.filled(EMBEDDING_DIM, 0.0));

    _reidInterpreter!.run(input, output);

    final embedding = output[0];
    final norm = sqrt(embedding.fold(0.0, (sum, v) => sum + v * v));
    
    // ── DEBUG ──────────────────────────────────────────
    print('=== EMBEDDING DEBUG ===');
    print('Raw norm before normalize: $norm');
    print('First 5 values: ${embedding.sublist(0, 5)}');
    // ───────────────────────────────────────────────────

    if (norm > 0) {
      return embedding.map((v) => v / norm).toList();
    }
    return embedding;
  }

  double cosineSimilarity(List<double> a, List<double> b) {
    if (a.length != b.length) return 0.0;
    double dot = 0.0;
    double normA = 0.0;
    double normB = 0.0;
    for (int i = 0; i < a.length; i++) {
      dot += a[i] * b[i];
      normA += a[i] * a[i];
      normB += b[i] * b[i];
    }
    final denom = sqrt(normA) * sqrt(normB);
    return denom == 0 ? 0.0 : dot / denom;
  }

  Map<String, dynamic> findBestMatch(
    List<double> queryEmbedding,
    Map<String, List<double>> knownEmbeddings,
  ) {
    String? bestId;
    double bestSim = 0.0;

    // ── DEBUG ──────────────────────────────────────────
    print('=== FINDBESTMATCH DEBUG ===');
    print('Known embeddings count: ${knownEmbeddings.length}');
    print('Query embedding first 5: ${queryEmbedding.sublist(0, 5)}');
    // ───────────────────────────────────────────────────

    for (final entry in knownEmbeddings.entries) {
      final sim = cosineSimilarity(queryEmbedding, entry.value);
      print('  ${entry.key} → sim: $sim'); // DEBUG
      if (sim > bestSim) {
        bestSim = sim;
        bestId = entry.key;
      }
    }

    print('Best match: $bestId at $bestSim vs threshold $SIMILARITY_THRESHOLD'); // DEBUG

    if (bestSim >= SIMILARITY_THRESHOLD) {
      return {'individualId': bestId, 'similarity': bestSim};
    }
    return {'individualId': null, 'similarity': bestSim};
  }

  // For detection (unchanged — no normalization needed for YOLO)
List<List<List<List<double>>>> _imageToFloat32Detection(
  img.Image image,
  int size,
  ) {
    return List.generate(
      1,
      (_) => List.generate(
        size,
        (y) => List.generate(
          size,
          (x) {
            final pixel = image.getPixel(x, y);
            return [
              pixel.r / 255.0,
              pixel.g / 255.0,
              pixel.b / 255.0,
            ];
          },
        ),
      ),
    );
  }

// For reid — applies ImageNet mean/std normalization
List<List<List<List<double>>>> _imageToFloat32Reid(
  img.Image image,
  int size,
  ) {
    const mean = [0.485, 0.456, 0.406];
    const std  = [0.229, 0.224, 0.225];
    return List.generate(
      1,
      (_) => List.generate(
        size,
        (y) => List.generate(
          size,
          (x) {
            final pixel = image.getPixel(x, y);
            return [
              (pixel.r / 255.0 - mean[0]) / std[0],
              (pixel.g / 255.0 - mean[1]) / std[1],
              (pixel.b / 255.0 - mean[2]) / std[2],
            ];
          },
        ),
      ),
    );
  }

  void dispose() {
    _detectInterpreter?.close();
    _reidInterpreter?.close();
  }
}