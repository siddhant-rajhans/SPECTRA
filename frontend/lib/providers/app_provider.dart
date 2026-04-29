import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/user.dart';
import '../models/device_status.dart';
import '../models/sound_alert.dart';
import '../models/context_rule.dart';
import '../models/hearing_program.dart';
import '../models/iml_feedback.dart';
import '../models/transcription.dart';
import '../services/alert_fx.dart';
import '../services/api_client.dart';
import '../services/audio_listener.dart';
import '../services/mock_data.dart';
import '../services/sound_classifier.dart';
import '../services/speech_service.dart';

/// Central state management for HearClear using ChangeNotifier + Provider.
/// Now wired to the real backend API with fallback to mock data.
class AppProvider extends ChangeNotifier {
  // ─── Navigation ──────────────────────────────────────────────
  int _activeTab = 0;
  int get activeTab => _activeTab;
  void setActiveTab(int index) {
    _activeTab = index;
    notifyListeners();
  }

  // ─── Auth State ──────────────────────────────────────────────
  User? _currentUser;
  User? get currentUser => _currentUser;
  bool get isAuthenticated => _currentUser != null;

  Future<bool> loginWithCredentials(String email, String password) async {
    try {
      final response = await ApiClient.post('/auth/login', {
        'email': email,
        'password': password,
      });
      if (response['success'] == true && response['user'] != null) {
        final userJson = response['user'] as Map<String, dynamic>;
        _currentUser = User.fromJson(userJson);
        ApiClient.setUserId(_currentUser!.id);
        await ApiClient.saveSession(userJson);
        notifyListeners();
        // Load all data after login
        await _loadAllData();
        // Connect WebSocket
        _connectWebSocket();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Login error: $e');
      return false;
    }
  }

  Future<bool> signupWithCredentials(
    String name,
    String email,
    String password,
  ) async {
    try {
      final response = await ApiClient.post('/auth/signup', {
        'name': name,
        'email': email,
        'password': password,
      });
      if (response['success'] == true && response['user'] != null) {
        final userJson = response['user'] as Map<String, dynamic>;
        _currentUser = User.fromJson(userJson);
        ApiClient.setUserId(_currentUser!.id);
        await ApiClient.saveSession(userJson);
        notifyListeners();
        await _loadAllData();
        _connectWebSocket();
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Signup error: $e');
      return false;
    }
  }

  void login(User user) {
    _currentUser = user;
    ApiClient.setUserId(user.id);
    // Fire-and-forget persistence; the user can sign back in if it fails.
    ApiClient.saveSession(user.toJson());
    notifyListeners();
    _loadAllData();
    _connectWebSocket();
  }

  /// Demo mode: skip auth and use a test user
  void demoLogin() {
    const demoUser = User(
      id: 'demo-user-001',
      name: 'Demo Tester',
      email: 'demo@example.com',
      avatarInitial: 'D',
      hearingLossLevel: 'moderate',
      deviceBrand: 'Other',
      deviceModel: 'Test Device',
    );
    login(demoUser);
  }

  void logout() {
    _currentUser = null;
    _activeTab = 0;
    _wsChannel?.sink.close();
    _wsChannel = null;
    notifyListeners();
    // Forget the saved session so the next launch goes back to the auth screen.
    ApiClient.clearSession();
  }

  /// Try to restore a previously persisted session. Called once at app start
  /// after `ApiClient.initialize()`. Returns true if a session was restored.
  Future<bool> restoreSession() async {
    try {
      final saved = await ApiClient.loadSession();
      if (saved == null) return false;
      _currentUser = User.fromJson(saved);
      ApiClient.setUserId(_currentUser!.id);
      notifyListeners();
      // Best-effort background refresh; errors fall back to mock data.
      unawaited(_loadAllData());
      _connectWebSocket();
      return true;
    } catch (e) {
      debugPrint('Failed to restore session: $e');
      return false;
    }
  }

  // ─── Initial Data Load ───────────────────────────────────────
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _error;
  String? get error => _error;

  Future<void> _loadAllData() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      await Future.wait([
        _loadDeviceStatus(),
        _loadAlerts(),
        _loadContextRules(),
        _loadPrograms(),
        _loadEnvironment(),
        _loadIMLData(),
      ]);
    } catch (e) {
      _error = 'Failed to load data: $e';
      debugPrint(_error);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Notification ────────────────────────────────────────────
  Map<String, String>? _notification;
  Map<String, String>? get notification => _notification;

  /// Monotonically increasing counter — each new alert bumps it. The
  /// screen-flash overlay watches this to know when to fire a burst.
  int _alertCounter = 0;
  int get alertCounter => _alertCounter;

  String? _lastAlertSoundType;
  String? get lastAlertSoundType => _lastAlertSoundType;

  void showNotification({
    required String type,
    required String title,
    required String description,
    String? contextReasoning,
  }) {
    _notification = {
      'type': type,
      'title': title,
      'description': description,
      if (contextReasoning != null) 'contextReasoning': contextReasoning,
    };
    _lastAlertSoundType = type;
    _alertCounter += 1;
    notifyListeners();

    // Fire-and-forget; haptics shouldn't block the UI.
    AlertFx.instance.trigger(priorityForSoundType(type));
  }

  void hideNotification() {
    _notification = null;
    notifyListeners();
  }

  // ─── Device Status ───────────────────────────────────────────
  DeviceStatus _deviceStatus = MockData.defaultDevice;
  DeviceStatus get deviceStatus => _deviceStatus;

  Future<void> _loadDeviceStatus() async {
    try {
      final response = await ApiClient.get('/profile/device');
      if (response['data'] != null) {
        _deviceStatus = DeviceStatus.fromJson(
          response['data'] as Map<String, dynamic>,
        );
      }
    } catch (e) {
      debugPrint('Failed to load device status: $e');
    }
  }

  void setDeviceStatus(DeviceStatus status) {
    _deviceStatus = status;
    notifyListeners();
  }

  // ─── Alerts ──────────────────────────────────────────────────
  List<SoundAlert> _alerts = [];
  List<SoundAlert> get alerts => _alerts;

  Future<void> _loadAlerts() async {
    try {
      final response = await ApiClient.get('/alerts');
      if (response['data'] != null) {
        _alerts =
            (response['data'] as List)
                .map(
                  (json) => SoundAlert.fromJson(json as Map<String, dynamic>),
                )
                .toList();
      }
    } catch (e) {
      debugPrint('Failed to load alerts: $e');
      _alerts = List.from(MockData.alerts);
    }
  }

  Future<void> simulateAlert() async {
    try {
      final response = await ApiClient.post('/alerts/simulate');
      if (response['data'] != null) {
        final alert = SoundAlert.fromJson(
          response['data'] as Map<String, dynamic>,
        );
        _alerts.insert(0, alert);
        showNotification(
          type: alert.type,
          title:
              '${SoundTypeInfo.fromType(alert.type).icon} ${SoundTypeInfo.fromType(alert.type).label} Detected',
          description: alert.contextReasoning ?? 'Sound detected',
          contextReasoning: alert.contextReasoning,
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to simulate alert: $e');
    }
  }

  void addAlert(SoundAlert alert) {
    _alerts.insert(0, alert);
    notifyListeners();
  }

  // ─── Monitored Sounds ────────────────────────────────────────
  final List<MonitoredSound> _monitoredSounds = List.from(
    MockData.monitoredSounds,
  );
  List<MonitoredSound> get monitoredSounds => _monitoredSounds;

  void toggleMonitoredSound(String type) {
    for (final s in _monitoredSounds) {
      if (s.type == type && !s.isLocked) {
        s.isEnabled = !s.isEnabled;
        break;
      }
    }
    notifyListeners();
  }

  // ─── Context Rules ───────────────────────────────────────────
  List<ContextRule> _contextRules = [];
  List<ContextRule> get contextRules => _contextRules;

  Future<void> _loadContextRules() async {
    try {
      final response = await ApiClient.get('/alerts/context-rules');
      if (response['data'] != null) {
        _contextRules =
            (response['data'] as List)
                .map(
                  (json) => ContextRule.fromJson(json as Map<String, dynamic>),
                )
                .toList();
      }
    } catch (e) {
      debugPrint('Failed to load context rules: $e');
      _contextRules = List.from(MockData.contextRules);
    }
  }

  Future<void> toggleContextRule(String id) async {
    for (final r in _contextRules) {
      if (r.id == id) {
        r.isActive = !r.isActive;
        break;
      }
    }
    notifyListeners();
    try {
      await ApiClient.put('/alerts/context-rules/$id');
    } catch (e) {
      debugPrint('Failed to toggle context rule: $e');
    }
  }

  // ─── Hearing Programs ────────────────────────────────────────
  List<HearingProgram> _programs = [];
  List<HearingProgram> get programs => _programs;

  HearingProgram? get activeProgram =>
      _programs.where((p) => p.isActive).firstOrNull;

  Future<void> _loadPrograms() async {
    try {
      final response = await ApiClient.get('/environment/programs');
      if (response['data'] != null) {
        _programs =
            (response['data'] as List)
                .map(
                  (json) =>
                      HearingProgram.fromJson(json as Map<String, dynamic>),
                )
                .toList();
      }
    } catch (e) {
      debugPrint('Failed to load programs: $e');
      _programs = List.from(MockData.hearingPrograms);
    }
  }

  Future<void> selectProgram(String id) async {
    for (final p in _programs) {
      p.isActive = p.id == id;
    }
    notifyListeners();
    try {
      await ApiClient.put('/environment/programs/$id');
    } catch (e) {
      debugPrint('Failed to select program: $e');
    }
  }

  Future<void> updateProgramSettings(
    String id,
    ProgramSettings settings,
  ) async {
    for (final p in _programs) {
      if (p.id == id) {
        p.settings.speechEnhancement = settings.speechEnhancement;
        p.settings.noiseReduction = settings.noiseReduction;
        p.settings.forwardFocus = settings.forwardFocus;
        break;
      }
    }
    notifyListeners();
    try {
      await ApiClient.put('/environment/programs/$id', settings.toJson());
    } catch (e) {
      debugPrint('Failed to update program settings: $e');
    }
  }

  // ─── ANC mode (Home screen quick presets) ────────────────────
  String _ancMode = 'focus';
  String get ancMode => _ancMode;

  /// Apply a quick preset to the active hearing program. Three modes shown
  /// on the Home screen map to common scenarios.
  Future<void> setAncMode(String mode) async {
    _ancMode = mode;
    final active = activeProgram;
    if (active != null) {
      switch (mode) {
        case 'focus':
          active.settings.speechEnhancement = 50;
          active.settings.noiseReduction = 80;
          active.settings.forwardFocus = 80;
          break;
        case 'conversation':
          active.settings.speechEnhancement = 90;
          active.settings.noiseReduction = 60;
          active.settings.forwardFocus = 80;
          break;
        case 'outdoor':
          active.settings.speechEnhancement = 60;
          active.settings.noiseReduction = 30;
          active.settings.forwardFocus = 50;
          break;
      }
      notifyListeners();
      try {
        await ApiClient.put(
          '/environment/programs/${active.id}',
          active.settings.toJson(),
        );
      } catch (e) {
        debugPrint('Failed to apply ANC preset: $e');
      }
    } else {
      notifyListeners();
    }
  }

  // ─── Environment ─────────────────────────────────────────────
  EnvironmentReading _environment = MockData.defaultEnvironment;
  EnvironmentReading get environment => _environment;

  Future<void> _loadEnvironment() async {
    try {
      final response = await ApiClient.get('/environment/current');
      if (response['data'] != null) {
        _environment = EnvironmentReading.fromJson(
          response['data'] as Map<String, dynamic>,
        );
      }
    } catch (e) {
      debugPrint('Failed to load environment: $e');
    }
  }

  // ─── IML ─────────────────────────────────────────────────────
  IMLStats _imlStats = MockData.imlStats;
  IMLStats get imlStats => _imlStats;

  List<IMLFeedbackItem> _pendingReviews = [];
  List<IMLFeedbackItem> get pendingReviews => _pendingReviews;

  List<IMLFeedbackItem> _reviewedItems = [];
  List<IMLFeedbackItem> get reviewedItems => _reviewedItems;

  Future<void> _loadIMLData() async {
    try {
      final results = await Future.wait([
        ApiClient.get('/iml/pending'),
        ApiClient.get('/iml/reviewed'),
        ApiClient.get('/iml/stats'),
      ]);

      if (results[0]['data'] != null) {
        _pendingReviews =
            (results[0]['data'] as List)
                .map(
                  (json) =>
                      IMLFeedbackItem.fromJson(json as Map<String, dynamic>),
                )
                .toList();
      }
      if (results[1]['data'] != null) {
        _reviewedItems =
            (results[1]['data'] as List)
                .map(
                  (json) =>
                      IMLFeedbackItem.fromJson(json as Map<String, dynamic>),
                )
                .toList();
      }
      if (results[2]['data'] != null) {
        _imlStats = IMLStats.fromJson(
          results[2]['data'] as Map<String, dynamic>,
        );
      }
    } catch (e) {
      debugPrint('Failed to load IML data: $e');
      _pendingReviews = List.from(MockData.pendingReviews);
      _reviewedItems = List.from(MockData.reviewedItems);
    }
  }

  Future<void> submitFeedback(
    String alertId,
    bool isCorrect, {
    String? correctedType,
  }) async {
    // Optimistic update
    final pending = _pendingReviews.firstWhere((p) => p.id == alertId);
    _pendingReviews.removeWhere((p) => p.id == alertId);

    _reviewedItems.insert(
      0,
      IMLFeedbackItem(
        id: pending.id,
        type: pending.type,
        confidence: pending.confidence,
        location: pending.location,
        timeOfDay: pending.timeOfDay,
        isCorrect: isCorrect,
        correctedType: correctedType,
        timestamp: DateTime.now(),
      ),
    );

    // Update stats locally
    final newConfirmed =
        isCorrect ? _imlStats.confirmed + 1 : _imlStats.confirmed;
    final newCorrected =
        !isCorrect ? _imlStats.corrected + 1 : _imlStats.corrected;
    final total = newConfirmed + newCorrected;
    _imlStats = IMLStats(
      confirmed: newConfirmed,
      corrected: newCorrected,
      accuracy: total > 0 ? newConfirmed / total : 0,
    );
    notifyListeners();

    // Send to backend
    try {
      await ApiClient.post('/iml/feedback', {
        'alertId': alertId,
        'isCorrect': isCorrect,
        if (correctedType != null) 'correctedClassification': correctedType,
      });
    } catch (e) {
      debugPrint('Failed to submit feedback: $e');
    }
  }

  void skipReview(String alertId) {
    _pendingReviews.removeWhere((p) => p.id == alertId);
    notifyListeners();
  }

  // ─── Transcription ───────────────────────────────────────────
  bool _isTranscribing = false;
  bool get isTranscribing => _isTranscribing;

  List<TranscriptionLine> _transcriptLines = [];
  List<TranscriptionLine> get transcriptLines => _transcriptLines;

  String _partialTranscript = '';
  String get partialTranscript => _partialTranscript;

  String? _transcriptionError;
  String? get transcriptionError => _transcriptionError;

  String? _currentSessionId;

  final SpeechService _speech = SpeechService();
  StreamSubscription<TranscriptLine>? _speechLinesSub;
  StreamSubscription<String>? _speechPartialSub;
  StreamSubscription<SpeechStatus>? _speechStatusSub;
  bool _speechWired = false;

  void _wireSpeechStreams() {
    if (_speechWired) return;
    _speechWired = true;

    _speechLinesSub = _speech.lines.listen((line) {
      _partialTranscript = '';
      addTranscriptionLine(
        TranscriptionLine(
          speaker: 'You',
          text: line.text,
          timestamp: DateTime.now(),
        ),
      );
    });
    _speechPartialSub = _speech.partial.listen((text) {
      _partialTranscript = text;
      notifyListeners();
    });
    _speechStatusSub = _speech.status.listen((status) {
      if (status == SpeechStatus.permissionDenied) {
        _transcriptionError =
            'Microphone permission was denied. Enable it in Settings to transcribe.';
        _isTranscribing = false;
        notifyListeners();
      } else if (status == SpeechStatus.error) {
        _transcriptionError =
            'Speech recognition hit an error. Tap Start to try again.';
        notifyListeners();
      }
    });
  }

  Future<void> startTranscription() async {
    _wireSpeechStreams();
    _transcriptionError = null;

    final ready = await _speech.initialize();
    if (!ready) {
      _transcriptionError =
          'On-device speech recognition is unavailable on this device.';
      notifyListeners();
      return;
    }

    _isTranscribing = true;
    _transcriptLines = [];
    _partialTranscript = '';
    notifyListeners();

    try {
      final response = await ApiClient.post('/transcribe/sessions');
      if (response['data'] != null) {
        _currentSessionId = response['data']['id']?.toString();
      }
    } catch (e) {
      debugPrint('Failed to start transcription session: $e');
    }

    final started = await _speech.start();
    if (!started) {
      _transcriptionError =
          'Could not start the microphone. Check permissions.';
      _isTranscribing = false;
      notifyListeners();
    }
  }

  Future<void> stopTranscription() async {
    _isTranscribing = false;
    _partialTranscript = '';
    notifyListeners();

    await _speech.stop();

    if (_currentSessionId != null) {
      try {
        await ApiClient.put('/transcribe/sessions/$_currentSessionId');
      } catch (e) {
        debugPrint('Failed to end transcription session: $e');
      }
    }
    _currentSessionId = null;
  }

  void addTranscriptionLine(TranscriptionLine line) {
    _transcriptLines.add(line);
    notifyListeners();

    // Also send to backend if we have a session
    if (_currentSessionId != null) {
      ApiClient.post('/transcribe/sessions/$_currentSessionId/lines', {
        'speaker_label': line.speaker,
        'text': line.text,
      }).then(
        (_) {},
        onError: (e) {
          debugPrint('Failed to save transcription line: $e');
        },
      );
    }
  }

  // ─── Ambient Listening (sound classification) ────────────────
  late final SoundClassifier _classifier = SoundClassifier();
  late final AudioListener _audioListener = AudioListener(
    classifier: _classifier,
  );

  bool _isListening = false;
  bool get isListening => _isListening;

  String? _listenerError;
  String? get listenerError => _listenerError;

  double _ambientAmplitude = 0.0;
  double get ambientAmplitude => _ambientAmplitude;

  /// Approximate dB SPL from the live mic. Phone mics aren't calibrated, so
  /// this is good for relative loudness / context but not for medical use.
  /// Calibration constant chosen so that a typical conversation reads ~60 dB
  /// and ambient quiet reads ~30-40 dB on a Pixel 9 Pro.
  ///
  /// Returns null when the listener is not currently capturing — the gauge
  /// should show a hint instead of a stale number.
  double? get ambientDbSpl {
    if (!_isListening || _ambientAmplitude <= 0) return null;
    final dbfs = 20 * math.log(_ambientAmplitude.clamp(1e-6, 1.0)) / math.ln10;
    final dbSpl = dbfs + 94.0; // uncalibrated phone-mic offset
    return dbSpl.clamp(20.0, 110.0);
  }

  StreamSubscription<SoundClassification>? _classificationSub;
  StreamSubscription<ClassificationSnapshot>? _snapshotSub;
  StreamSubscription<double>? _amplitudeSub;
  StreamSubscription<AudioListenerStatus>? _listenerStatusSub;
  bool _audioWired = false;

  /// Most recent top-K predictions from YAMNet — used by the UI to show what
  /// the classifier is currently "hearing" even when nothing crosses threshold.
  ClassificationSnapshot? _lastSnapshot;
  ClassificationSnapshot? get lastSnapshot => _lastSnapshot;
  int _snapshotTick = 0;
  int get snapshotTick => _snapshotTick;

  // Throttle: don't fire the same alert more than once every N seconds.
  final Map<String, DateTime> _lastAlertAt = {};
  static const _alertCooldown = Duration(seconds: 8);

  // Last time we emitted an amplitude-driven notifyListeners().
  DateTime? _lastAmpNotify;

  void _wireAudioStreams() {
    if (_audioWired) return;
    _audioWired = true;

    _classificationSub = _audioListener.classifications.listen((c) {
      if (!_isMonitored(c.internalType)) return;
      final last = _lastAlertAt[c.internalType];
      final now = DateTime.now();
      if (last != null && now.difference(last) < _alertCooldown) return;
      _lastAlertAt[c.internalType] = now;
      _reportClassifiedSound(c);
    });

    _snapshotSub = _audioListener.snapshots.listen((snap) {
      _lastSnapshot = snap;
      _snapshotTick = (_snapshotTick + 1) & 0x7FFFFFFF;
      // Notify so the diagnostic widget on the Home screen can repaint —
      // throttled to one per ~0.5s by the inference cadence already.
      notifyListeners();
    });

    _amplitudeSub = _audioListener.amplitude.listen((a) {
      _ambientAmplitude = a;
      // Throttle UI repaints to ~5 Hz so the gauge / amp bar update smoothly
      // without repainting the whole tree on every audio chunk (~50 Hz).
      final now = DateTime.now();
      if (_lastAmpNotify == null ||
          now.difference(_lastAmpNotify!) > const Duration(milliseconds: 200)) {
        _lastAmpNotify = now;
        notifyListeners();
      }
    });

    _listenerStatusSub = _audioListener.status.listen((status) {
      switch (status) {
        case AudioListenerStatus.permissionDenied:
          _listenerError =
              'Microphone permission was denied. Enable it in Settings to detect sounds.';
          _isListening = false;
          notifyListeners();
          break;
        case AudioListenerStatus.modelMissing:
          _listenerError =
              'Sound classifier model not found. Run scripts/setup_yamnet.sh and rebuild.';
          _isListening = false;
          notifyListeners();
          break;
        case AudioListenerStatus.error:
          _listenerError = 'Audio capture failed. Tap Listen to try again.';
          notifyListeners();
          break;
        case AudioListenerStatus.stopped:
          // Routine stop — don't surface as error.
          break;
        case AudioListenerStatus.listening:
          _listenerError = null;
          notifyListeners();
          break;
      }
    });
  }

  bool _isMonitored(String soundType) {
    for (final s in _monitoredSounds) {
      if (s.type == soundType) return s.isEnabled;
    }
    // Unknown type — default to monitoring it.
    return true;
  }

  Future<void> startListening() async {
    _wireAudioStreams();
    _listenerError = null;

    // Ensure classifier loaded — emit a clear error if not.
    if (!_classifier.isReady) {
      final ok = await _classifier.initialize();
      if (!ok) {
        _listenerError =
            _classifier.initializationError ??
            'Sound classifier model failed to load. Run scripts/setup_yamnet.sh.';
        notifyListeners();
        return;
      }
    }

    final started = await _audioListener.start();
    if (started) {
      _isListening = true;
      notifyListeners();
    }
  }

  Future<void> stopListening() async {
    await _audioListener.stop();
    _isListening = false;
    _ambientAmplitude = 0;
    notifyListeners();
  }

  Future<void> _reportClassifiedSound(SoundClassification c) async {
    debugPrint('Detected ${c.toString()}');
    try {
      final response = await ApiClient.post('/alerts', {
        'soundType': c.internalType,
        'confidence': c.confidence,
      });
      // The WebSocket will deliver the alert back to us if `decision.deliver`
      // was true on the backend; we don't optimistically insert here to avoid
      // duplicates. If WS is down, fall back to inserting locally.
      if (_wsChannel == null && response['data'] != null) {
        final alert = SoundAlert.fromJson(
          response['data'] as Map<String, dynamic>,
        );
        addAlert(alert);
        final info = SoundTypeInfo.fromType(alert.type);
        showNotification(
          type: alert.type,
          title: '${info.icon} ${info.label} detected',
          description:
              alert.contextReasoning ??
              'Heard nearby (${(c.confidence * 100).round()}%)',
        );
      }
    } catch (e) {
      debugPrint('Failed to report classified sound: $e');
      // Offline / no backend — surface a local-only alert so the user still sees feedback.
      final info = SoundTypeInfo.fromType(c.internalType);
      addAlert(
        SoundAlert(
          id: 'local-${DateTime.now().microsecondsSinceEpoch}',
          type: c.internalType,
          confidence: c.confidence,
          delivered: true,
          timestamp: DateTime.now(),
          contextReasoning: 'Detected on-device (${c.yamnetClassName})',
        ),
      );
      showNotification(
        type: c.internalType,
        title: '${info.icon} ${info.label} detected',
        description: 'Heard nearby (${(c.confidence * 100).round()}%)',
      );
    }
  }

  // ─── Implants ────────────────────────────────────────────────
  List<ConnectedImplant> _connectedImplants = [];
  List<ConnectedImplant> get connectedImplants => _connectedImplants;

  List<ImplantProvider> get implantProviders => MockData.implantProviders;
  List<ImplantProvider> get availableProviders =>
      implantProviders
          .where((p) => !_connectedImplants.any((c) => c.providerId == p.id))
          .toList();

  void connectImplant(ConnectedImplant implant) {
    _connectedImplants.add(implant);
    notifyListeners();
  }

  void disconnectImplant(String id) {
    _connectedImplants.removeWhere((c) => c.id == id);
    notifyListeners();
  }

  // ─── WebSocket ───────────────────────────────────────────────
  WebSocketChannel? _wsChannel;

  void _connectWebSocket() {
    try {
      _wsChannel?.sink.close();
      _wsChannel = ApiClient.connectWebSocket();

      // Subscribe to alerts
      _wsChannel!.sink.add(
        jsonEncode({'type': 'subscribe', 'channel': 'alerts'}),
      );

      _wsChannel!.stream.listen(
        (data) {
          try {
            final message = jsonDecode(data.toString()) as Map<String, dynamic>;
            if (message['type'] == 'alert' && message['data'] != null) {
              final alert = SoundAlert.fromJson(
                message['data'] as Map<String, dynamic>,
              );
              _alerts.insert(0, alert);
              final info = SoundTypeInfo.fromType(alert.type);
              showNotification(
                type: alert.type,
                title: '${info.icon} ${info.label} Detected',
                description: alert.contextReasoning ?? 'Sound detected nearby',
                contextReasoning: alert.contextReasoning,
              );
            } else if (message['type'] == 'device_status' &&
                message['data'] != null) {
              _deviceStatus = DeviceStatus.fromJson(
                message['data'] as Map<String, dynamic>,
              );
              notifyListeners();
            }
          } catch (e) {
            debugPrint('WebSocket parse error: $e');
          }
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          // Reconnect after 3 seconds
          Future.delayed(const Duration(seconds: 3), () {
            if (_currentUser != null) _connectWebSocket();
          });
        },
        onDone: () {
          debugPrint('WebSocket closed. Reconnecting...');
          Future.delayed(const Duration(seconds: 3), () {
            if (_currentUser != null) _connectWebSocket();
          });
        },
      );
    } catch (e) {
      debugPrint('WebSocket connection error: $e');
    }
  }

  @override
  void dispose() {
    _wsChannel?.sink.close();
    _speechLinesSub?.cancel();
    _speechPartialSub?.cancel();
    _speechStatusSub?.cancel();
    _speech.dispose();
    _classificationSub?.cancel();
    _snapshotSub?.cancel();
    _amplitudeSub?.cancel();
    _listenerStatusSub?.cancel();
    _audioListener.dispose();
    _classifier.dispose();
    super.dispose();
  }
}
