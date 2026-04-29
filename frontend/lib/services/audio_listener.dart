import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'sound_classifier.dart';

/// Streams 16 kHz mono PCM from the mic, buffers 0.975 s windows with 50%
/// overlap (so we get a fresh classification every ~0.49 s), and pushes each
/// match through [SoundClassifier]. Results land on [classifications].
///
/// The listener is intentionally app-foreground-only for the first cochlear
/// implant test — Android 14 background mic capture requires a typed
/// FOREGROUND_SERVICE_MICROPHONE service which we will add in a follow-up.
class AudioListener {
  final SoundClassifier classifier;
  final AudioRecorder _recorder = AudioRecorder();

  final _classificationController =
      StreamController<SoundClassification>.broadcast();
  final _amplitudeController = StreamController<double>.broadcast();
  final _statusController = StreamController<AudioListenerStatus>.broadcast();

  StreamSubscription<Uint8List>? _audioSub;
  Float32List _ringBuffer = Float32List(0);
  int _ringFill = 0;
  bool _running = false;

  Stream<SoundClassification> get classifications =>
      _classificationController.stream;
  Stream<double> get amplitude => _amplitudeController.stream;
  Stream<AudioListenerStatus> get status => _statusController.stream;

  bool get isRunning => _running;

  AudioListener({required this.classifier}) {
    _ringBuffer = Float32List(SoundClassifier.windowSamples * 2);
  }

  Future<bool> start() async {
    if (_running) return true;

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      _statusController.add(AudioListenerStatus.permissionDenied);
      return false;
    }

    if (!await _recorder.hasPermission()) {
      _statusController.add(AudioListenerStatus.permissionDenied);
      return false;
    }

    if (!classifier.isReady) {
      final ok = await classifier.initialize();
      if (!ok) {
        _statusController.add(AudioListenerStatus.modelMissing);
        return false;
      }
    }

    try {
      final stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: SoundClassifier.sampleRate,
          numChannels: 1,
          // Voice/communication mode trims background hiss, but for sound
          // classification we want raw audio. Default DSP is fine.
          autoGain: false,
          echoCancel: false,
          noiseSuppress: false,
        ),
      );

      _ringFill = 0;
      _running = true;
      _statusController.add(AudioListenerStatus.listening);

      _audioSub = stream.listen(
        _onAudio,
        onError: (e) {
          debugPrint('Mic stream error: $e');
          _statusController.add(AudioListenerStatus.error);
        },
        onDone: () {
          _statusController.add(AudioListenerStatus.stopped);
          _running = false;
        },
      );
      return true;
    } catch (e) {
      debugPrint('Failed to start audio listener: $e');
      _statusController.add(AudioListenerStatus.error);
      _running = false;
      return false;
    }
  }

  Future<void> stop() async {
    _running = false;
    await _audioSub?.cancel();
    _audioSub = null;
    try {
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
    } catch (e) {
      debugPrint('Recorder stop threw: $e');
    }
    _statusController.add(AudioListenerStatus.stopped);
  }

  void _onAudio(Uint8List chunk) {
    if (chunk.isEmpty) return;

    // PCM 16-bit little-endian → float32 in [-1, 1]
    final byteData = ByteData.sublistView(chunk);
    final sampleCount = chunk.length ~/ 2;

    var sumSq = 0.0;
    for (var i = 0; i < sampleCount; i++) {
      final s = byteData.getInt16(i * 2, Endian.little);
      final f = s / 32768.0;
      sumSq += f * f;

      // Slide ring buffer if full.
      if (_ringFill >= _ringBuffer.length) {
        // Shift left by half a window (50% overlap).
        const shift = SoundClassifier.windowSamples ~/ 2;
        _ringBuffer.setRange(
          0,
          _ringBuffer.length - shift,
          _ringBuffer.sublist(shift),
        );
        _ringFill = _ringBuffer.length - shift;
      }
      _ringBuffer[_ringFill++] = f;
    }

    if (sampleCount > 0) {
      final rms = (sumSq / sampleCount);
      _amplitudeController.add(rms);
    }

    // Once we have a full window, run inference. Use the most recent
    // window-sized slice ending at _ringFill.
    if (_ringFill >= SoundClassifier.windowSamples) {
      final start = _ringFill - SoundClassifier.windowSamples;
      final window = Float32List.sublistView(
        _ringBuffer,
        start,
        start + SoundClassifier.windowSamples,
      );
      final result = classifier.classify(window);
      if (result != null) {
        _classificationController.add(result);
      }
      // Drop the first half so the next inference starts on fresh audio.
      const consumed = SoundClassifier.windowSamples ~/ 2;
      _ringBuffer.setRange(
        0,
        _ringBuffer.length - consumed,
        _ringBuffer.sublist(consumed),
      );
      _ringFill -= consumed;
    }
  }

  Future<void> dispose() async {
    await stop();
    await _classificationController.close();
    await _amplitudeController.close();
    await _statusController.close();
  }
}

enum AudioListenerStatus { listening, stopped, permissionDenied, modelMissing, error }
