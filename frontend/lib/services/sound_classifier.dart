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

  /// Score below which we ignore the prediction. YAMNet's softmax tends to
  /// spread probability mass across related sounds, so 0.15 is more realistic
  /// than the textbook 0.30 for catching baby cry / dog bark / etc. in the wild.
  double confidenceThreshold;

  /// How many top predictions to scan when deciding whether *anything* in the
  /// window matches one of our 12 internal types. The top class is often
  /// "Speech" or "Music" while the actual alert sits a few ranks down.
  final int topK;

  Interpreter? _interpreter;
  List<String> _classNames = const [];
  Map<int, String> _indexToType = const {};
  bool _ready = false;
  String? _initError;

  /// Most recent classification snapshot — set on every classify() call,
  /// regardless of whether it crossed the threshold or mapped to one of our
  /// types. The UI surfaces this so users (and the dev) can see what the
  /// classifier is actually predicting in real time.
  ClassificationSnapshot? lastSnapshot;

  SoundClassifier({this.confidenceThreshold = 0.15, this.topK = 10});

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

    // Build a (index, score) list, sort descending by score.
    final indexed = <_RankedScore>[];
    for (var i = 0; i < scores.length; i++) {
      indexed.add(_RankedScore(i, scores[i]));
    }
    indexed.sort((a, b) => b.score.compareTo(a.score));

    final topPicks = indexed.take(topK).toList();

    // Capture a snapshot for the UI. Always populate so users can see what
    // the model is "hearing" even when nothing crosses the threshold.
    final topNamed = topPicks
        .map((r) => RankedClass(
              yamnetClassIndex: r.index,
              yamnetClassName: r.index < _classNames.length
                  ? _classNames[r.index]
                  : 'idx ${r.index}',
              confidence: r.score,
              mappedType: _indexToType[r.index],
            ))
        .toList();
    lastSnapshot = ClassificationSnapshot(
      timestamp: DateTime.now(),
      topPredictions: topNamed,
    );

    // Walk the top predictions in order; pick the highest-ranked one that
    // (a) maps to an internal type and (b) crosses the threshold.
    for (final r in topPicks) {
      final mapped = _indexToType[r.index];
      if (mapped == null) continue;
      if (r.score < confidenceThreshold) continue;
      return SoundClassification(
        internalType: mapped,
        yamnetClassIndex: r.index,
        yamnetClassName: r.index < _classNames.length ? _classNames[r.index] : 'unknown',
        confidence: r.score,
      );
    }
    return null;
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

/// One ranked prediction from a single inference window.
class RankedClass {
  final int yamnetClassIndex;
  final String yamnetClassName;
  final double confidence;
  /// Internal sound type if this YAMNet class maps to one (e.g. "Bark" → "dog_bark").
  final String? mappedType;

  const RankedClass({
    required this.yamnetClassIndex,
    required this.yamnetClassName,
    required this.confidence,
    required this.mappedType,
  });
}

/// All top-K predictions from the most recent inference. Useful for the UI
/// to show the user what the classifier is currently "hearing" even when no
/// alert fires.
class ClassificationSnapshot {
  final DateTime timestamp;
  final List<RankedClass> topPredictions;

  const ClassificationSnapshot({
    required this.timestamp,
    required this.topPredictions,
  });

  RankedClass? get topPrediction =>
      topPredictions.isEmpty ? null : topPredictions.first;
}

class _RankedScore {
  final int index;
  final double score;
  _RankedScore(this.index, this.score);
}
