import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Wraps the `speech_to_text` plugin with the lifecycle the Transcribe screen
/// needs: continuous dictation, auto-restart when the platform recognizer
/// times out, and a stream of finalized lines for the provider to append.
class SpeechService {
  final SpeechToText _speech = SpeechToText();
  bool _initialized = false;
  bool _running = false;
  bool _stoppedByUser = false;
  String _localeId = 'en_US';

  final _linesController = StreamController<TranscriptLine>.broadcast();
  final _partialController = StreamController<String>.broadcast();
  final _statusController = StreamController<SpeechStatus>.broadcast();

  Stream<TranscriptLine> get lines => _linesController.stream;
  Stream<String> get partial => _partialController.stream;
  Stream<SpeechStatus> get status => _statusController.stream;

  bool get isRunning => _running;
  bool get isAvailable => _initialized && _speech.isAvailable;

  Future<bool> initialize() async {
    if (_initialized) return _speech.isAvailable;

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      _statusController.add(SpeechStatus.permissionDenied);
      return false;
    }

    try {
      _initialized = await _speech.initialize(
        onError: (err) {
          debugPrint('Speech error: ${err.errorMsg} (permanent=${err.permanent})');
          _statusController.add(SpeechStatus.error);
          if (_running && !_stoppedByUser) {
            // The platform engine often errors out on long silences; restart.
            Future.delayed(const Duration(milliseconds: 400), _safeRestart);
          }
        },
        onStatus: (s) {
          debugPrint('Speech status: $s');
          if (s == 'done' || s == 'notListening') {
            if (_running && !_stoppedByUser) {
              Future.delayed(const Duration(milliseconds: 200), _safeRestart);
            }
          }
        },
      );

      if (_initialized) {
        final systemLocale = await _speech.systemLocale();
        if (systemLocale != null) {
          _localeId = systemLocale.localeId;
        }
      }
      return _initialized;
    } catch (e) {
      debugPrint('Speech initialize threw: $e');
      _initialized = false;
      return false;
    }
  }

  Future<bool> start() async {
    if (!_initialized && !await initialize()) return false;
    if (_running) return true;

    _running = true;
    _stoppedByUser = false;
    _statusController.add(SpeechStatus.listening);
    return _safeRestart();
  }

  Future<void> stop() async {
    _stoppedByUser = true;
    _running = false;
    try {
      await _speech.stop();
    } catch (e) {
      debugPrint('Speech stop threw: $e');
    }
    _statusController.add(SpeechStatus.stopped);
  }

  Future<bool> _safeRestart() async {
    if (!_running || _stoppedByUser) return false;
    try {
      await _speech.listen(
        onResult: _onResult,
        listenOptions: SpeechListenOptions(
          partialResults: true,
          listenMode: ListenMode.dictation,
          cancelOnError: false,
          autoPunctuation: true,
        ),
        // Long durations work around the recognizer's tendency to short-circuit
        // on silence. We restart on completion anyway via onStatus.
        listenFor: const Duration(minutes: 5),
        pauseFor: const Duration(seconds: 5),
        localeId: _localeId,
      );
      return true;
    } catch (e) {
      debugPrint('Speech listen threw: $e');
      _statusController.add(SpeechStatus.error);
      return false;
    }
  }

  void _onResult(SpeechRecognitionResult result) {
    final text = result.recognizedWords.trim();
    if (text.isEmpty) return;
    if (result.finalResult) {
      _linesController.add(TranscriptLine(
        text: text,
        confidence: result.confidence == 0 ? null : result.confidence,
      ));
    } else {
      _partialController.add(text);
    }
  }

  Future<void> dispose() async {
    await stop();
    await _linesController.close();
    await _partialController.close();
    await _statusController.close();
  }
}

enum SpeechStatus { listening, stopped, permissionDenied, error }

class TranscriptLine {
  final String text;
  final double? confidence;
  const TranscriptLine({required this.text, this.confidence});
}
