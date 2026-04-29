import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/user.dart';
import '../models/device_status.dart';
import '../models/sound_alert.dart';
import '../models/context_rule.dart';
import '../models/hearing_program.dart';
import '../models/iml_feedback.dart';
import '../models/transcription.dart';
import '../services/api_client.dart';
import '../services/mock_data.dart';

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
        _currentUser = User.fromJson(response['user'] as Map<String, dynamic>);
        ApiClient.setUserId(_currentUser!.id);
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

  Future<bool> signupWithCredentials(String name, String email, String password) async {
    try {
      final response = await ApiClient.post('/auth/signup', {
        'name': name,
        'email': email,
        'password': password,
      });
      if (response['success'] == true && response['user'] != null) {
        _currentUser = User.fromJson(response['user'] as Map<String, dynamic>);
        ApiClient.setUserId(_currentUser!.id);
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
    notifyListeners();
    _loadAllData();
    _connectWebSocket();
  }

  void logout() {
    _currentUser = null;
    _activeTab = 0;
    _wsChannel?.sink.close();
    _wsChannel = null;
    notifyListeners();
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
    notifyListeners();
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
        _deviceStatus = DeviceStatus.fromJson(response['data'] as Map<String, dynamic>);
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
        _alerts = (response['data'] as List)
            .map((json) => SoundAlert.fromJson(json as Map<String, dynamic>))
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
        final alert = SoundAlert.fromJson(response['data'] as Map<String, dynamic>);
        _alerts.insert(0, alert);
        showNotification(
          type: alert.type,
          title: '${SoundTypeInfo.fromType(alert.type).icon} ${SoundTypeInfo.fromType(alert.type).label} Detected',
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
  final List<MonitoredSound> _monitoredSounds = List.from(MockData.monitoredSounds);
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
        _contextRules = (response['data'] as List)
            .map((json) => ContextRule.fromJson(json as Map<String, dynamic>))
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

  HearingProgram? get activeProgram => _programs.where((p) => p.isActive).firstOrNull;

  Future<void> _loadPrograms() async {
    try {
      final response = await ApiClient.get('/environment/programs');
      if (response['data'] != null) {
        _programs = (response['data'] as List)
            .map((json) => HearingProgram.fromJson(json as Map<String, dynamic>))
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

  Future<void> updateProgramSettings(String id, ProgramSettings settings) async {
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

  // ─── Environment ─────────────────────────────────────────────
  EnvironmentReading _environment = MockData.defaultEnvironment;
  EnvironmentReading get environment => _environment;

  Future<void> _loadEnvironment() async {
    try {
      final response = await ApiClient.get('/environment/current');
      if (response['data'] != null) {
        _environment = EnvironmentReading.fromJson(response['data'] as Map<String, dynamic>);
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
        _pendingReviews = (results[0]['data'] as List)
            .map((json) => IMLFeedbackItem.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      if (results[1]['data'] != null) {
        _reviewedItems = (results[1]['data'] as List)
            .map((json) => IMLFeedbackItem.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      if (results[2]['data'] != null) {
        _imlStats = IMLStats.fromJson(results[2]['data'] as Map<String, dynamic>);
      }
    } catch (e) {
      debugPrint('Failed to load IML data: $e');
      _pendingReviews = List.from(MockData.pendingReviews);
      _reviewedItems = List.from(MockData.reviewedItems);
    }
  }

  Future<void> submitFeedback(String alertId, bool isCorrect, {String? correctedType}) async {
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
    final newConfirmed = isCorrect ? _imlStats.confirmed + 1 : _imlStats.confirmed;
    final newCorrected = !isCorrect ? _imlStats.corrected + 1 : _imlStats.corrected;
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

  String? _currentSessionId;

  Future<void> startTranscription() async {
    _isTranscribing = true;
    _transcriptLines = [];
    notifyListeners();

    try {
      final response = await ApiClient.post('/transcribe/sessions');
      if (response['data'] != null) {
        _currentSessionId = response['data']['id']?.toString();
      }
    } catch (e) {
      debugPrint('Failed to start transcription session: $e');
    }

    // Simulate incoming transcription lines (will be replaced with speech_to_text)
    _simulateTranscription();
  }

  Future<void> stopTranscription() async {
    _isTranscribing = false;
    notifyListeners();

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
      }).catchError((e) => debugPrint('Failed to save transcription line: $e'));
    }
  }

  void _simulateTranscription() async {
    final lines = MockData.sampleTranscriptLines;
    for (int i = 0; i < lines.length; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (!_isTranscribing) return;
      addTranscriptionLine(lines[i]);
    }
  }

  // ─── Implants ────────────────────────────────────────────────
  List<ConnectedImplant> _connectedImplants = [];
  List<ConnectedImplant> get connectedImplants => _connectedImplants;

  List<ImplantProvider> get implantProviders => MockData.implantProviders;
  List<ImplantProvider> get availableProviders =>
      implantProviders.where((p) => !_connectedImplants.any((c) => c.providerId == p.id)).toList();

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
      _wsChannel!.sink.add(jsonEncode({
        'type': 'subscribe',
        'channel': 'alerts',
      }));

      _wsChannel!.stream.listen(
        (data) {
          try {
            final message = jsonDecode(data.toString()) as Map<String, dynamic>;
            if (message['type'] == 'alert' && message['data'] != null) {
              final alert = SoundAlert.fromJson(message['data'] as Map<String, dynamic>);
              _alerts.insert(0, alert);
              final info = SoundTypeInfo.fromType(alert.type);
              showNotification(
                type: alert.type,
                title: '${info.icon} ${info.label} Detected',
                description: alert.contextReasoning ?? 'Sound detected nearby',
                contextReasoning: alert.contextReasoning,
              );
            } else if (message['type'] == 'device_status' && message['data'] != null) {
              _deviceStatus = DeviceStatus.fromJson(message['data'] as Map<String, dynamic>);
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
    super.dispose();
  }
}
