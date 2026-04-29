import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

import 'sound_type_map.dart';

/// Loads the YAMNet TFLite model + AudioSet class map and runs inference on
/// 0.975-second windows of mono 16 kHz audio (15600 float samples). Emits a
/// [SoundClassification] when a known sound type breaches [confidenceThreshold].
///
/// Setup: download the YAMNet model + class map by running
/// `frontend/scripts/setup_yamnet.sh` (or .ps1 on Windows). The classifier
/// fails open — if the model is missing the app still runs, classification is
/// just disabled.
class SoundClassifier {
  static const int sampleRate = 16000;
  static const int windowSamples = 15600; // 0.975 s
  static const String _modelAsset = 'assets/models/yamnet.tflite';
  static const String _classMapAsset = 'assets/models/yamnet_class_map.csv';

  /// Score below which we ignore the prediction.
  double confidenceThreshold;

  Interpreter? _interpreter;
  List<String> _classNames = const [];
  Map<int, String> _indexToType = const {};
  bool _ready = false;
  String? _initError;

  SoundClassifier({this.confidenceThreshold = 0.30});

  bool get isReady => _ready;
  String? get initializationError => _initError;
  int get classCount => _classNames.length;

  Future<bool> initialize() async {
    if (_ready) return true;
    try {
      final options = InterpreterOptions()..threads = 2;
      _interpreter = await Interpreter.fromAsset(_modelAsset, options: options);
      _classNames = await _loadClassMap();
      _indexToType = SoundTypeMap.buildIndexMap(_classNames);
      _ready = true;
      _initError = null;
      debugPrint(
        'YAMNet ready: ${_classNames.length} classes, '
        '${_indexToType.length} mapped to internal types',
      );
      return true;
    } catch (e, st) {
      _initError = 'Failed to load YAMNet: $e';
      debugPrint('$_initError\n$st');
      _ready = false;
      return false;
    }
  }

  Future<List<String>> _loadClassMap() async {
    final csv = await rootBundle.loadString(_classMapAsset);
    final lines = const LineSplitter().convert(csv);
    if (lines.isEmpty) return const [];
    // Header: index,mid,display_name
    final out = <String>[];
    for (var i = 1; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;
      final parts = _splitCsvLine(line);
      if (parts.length < 3) continue;
      out.add(parts[2].replaceAll('"', ''));
    }
    return out;
  }

  /// Minimal CSV splitter that respects quoted commas (the YAMNet class map
  /// uses commas inside quoted display names like "Children playing, kids playing").
  List<String> _splitCsvLine(String line) {
    final result = <String>[];
    final buffer = StringBuffer();
    bool inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == ',' && !inQuotes) {
        result.add(buffer.toString());
        buffer.clear();
      } else {
        buffer.write(c);
      }
    }
    result.add(buffer.toString());
    return result;
  }

  /// Run inference on a window of float32 audio in `[-1, 1]`. Returns the
  /// best matching internal sound type or `null` if nothing crosses the
  /// confidence threshold.
  SoundClassification? classify(Float32List samples) {
    if (!_ready || _interpreter == null) return null;
    if (samples.length != windowSamples) {
      // Pad or truncate so the input tensor shape matches.
      samples = _resize(samples, windowSamples);
    }

    // Output buffer is [1, num_classes]. Some YAMNet variants emit per-frame
    // scores [N, 521]; we accept either by allocating with the model's actual
    // shape.
    final outputTensor = _interpreter!.getOutputTensor(0);
    final outputShape = outputTensor.shape;
    final flatSize = outputShape.fold<int>(1, (a, b) => a * b);
    final outputBuffer = List.filled(flatSize, 0.0).reshape(outputShape);

    try {
      _interpreter!.run(samples.reshape([windowSamples]), outputBuffer);
    } catch (e) {
      debugPrint('YAMNet run failed: $e');
      return null;
    }

    final scores = _flattenAndAverage(outputBuffer, _classNames.length);
    if (scores.isEmpty) return null;

    var maxIdx = -1;
    var maxScore = 0.0;
    for (var i = 0; i < scores.length; i++) {
      final s = scores[i];
      if (s > maxScore) {
        maxScore = s;
        maxIdx = i;
      }
    }

    if (maxIdx < 0) return null;
    final mapped = _indexToType[maxIdx];
    if (mapped == null) {
      // Predicted something we don't surface (e.g. "Music"); not an alert.
      return null;
    }
    if (maxScore < confidenceThreshold) return null;

    return SoundClassification(
      internalType: mapped,
      yamnetClassIndex: maxIdx,
      yamnetClassName: maxIdx < _classNames.length ? _classNames[maxIdx] : 'unknown',
      confidence: maxScore,
    );
  }

  /// Average per-frame scores down to a single 1-D vector. For the fixed-size
  /// YAMNet variant the output is already [1, 521], in which case this is a
  /// no-op flatten.
  List<double> _flattenAndAverage(dynamic output, int classCount) {
    if (classCount == 0) return const [];
    if (output is List && output.isNotEmpty) {
      // Drill until we have a List<num> of scores per frame.
      final frames = <List<double>>[];
      void walk(dynamic node) {
        if (node is List && node.isNotEmpty) {
          if (node.first is num) {
            frames.add(List<double>.from(node.map((e) => (e as num).toDouble())));
          } else {
            for (final c in node) {
              walk(c);
            }
          }
        }
      }
      walk(output);
      if (frames.isEmpty) return const [];
      final avg = List<double>.filled(classCount, 0.0);
      for (final frame in frames) {
        final n = frame.length < classCount ? frame.length : classCount;
        for (var i = 0; i < n; i++) {
          avg[i] += frame[i];
        }
      }
      for (var i = 0; i < classCount; i++) {
        avg[i] /= frames.length;
      }
      return avg;
    }
    return const [];
  }

  Float32List _resize(Float32List input, int target) {
    final out = Float32List(target);
    final n = input.length < target ? input.length : target;
    for (var i = 0; i < n; i++) {
      out[i] = input[i];
    }
    return out;
  }

  Future<void> dispose() async {
    _interpreter?.close();
    _interpreter = null;
    _ready = false;
  }
}

class SoundClassification {
  final String internalType;
  final int yamnetClassIndex;
  final String yamnetClassName;
  final double confidence;

  const SoundClassification({
    required this.internalType,
    required this.yamnetClassIndex,
    required this.yamnetClassName,
    required this.confidence,
  });

  @override
  String toString() =>
      'SoundClassification($internalType, "$yamnetClassName" @ ${(confidence * 100).toStringAsFixed(1)}%)';
}
