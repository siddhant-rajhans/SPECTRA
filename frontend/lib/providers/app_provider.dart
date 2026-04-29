import 'package:flutter/material.dart';
import '../models/user.dart';
import '../models/device_status.dart';
import '../models/sound_alert.dart';
import '../models/context_rule.dart';
import '../models/hearing_program.dart';
import '../models/iml_feedback.dart';
import '../models/transcription.dart';
import '../services/mock_data.dart';

/// Central state management for HearClear using ChangeNotifier + Provider.
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

  void login(User user) {
    _currentUser = user;
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    _activeTab = 0;
    notifyListeners();
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
  void setDeviceStatus(DeviceStatus status) {
    _deviceStatus = status;
    notifyListeners();
  }

  // ─── Alerts ──────────────────────────────────────────────────
  final List<SoundAlert> _alerts = List.from(MockData.alerts);
  List<SoundAlert> get alerts => _alerts;

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
  final List<ContextRule> _contextRules = List.from(MockData.contextRules);
  List<ContextRule> get contextRules => _contextRules;

  void toggleContextRule(String id) {
    for (final r in _contextRules) {
      if (r.id == id) {
        r.isActive = !r.isActive;
        break;
      }
    }
    notifyListeners();
  }

  // ─── Hearing Programs ────────────────────────────────────────
  final List<HearingProgram> _programs = List.from(MockData.hearingPrograms);
  List<HearingProgram> get programs => _programs;

  HearingProgram? get activeProgram => _programs.where((p) => p.isActive).firstOrNull;

  void selectProgram(String id) {
    for (final p in _programs) {
      p.isActive = p.id == id;
    }
    notifyListeners();
  }

  void updateProgramSettings(String id, ProgramSettings settings) {
    for (final p in _programs) {
      if (p.id == id) {
        p.settings.speechEnhancement = settings.speechEnhancement;
        p.settings.noiseReduction = settings.noiseReduction;
        p.settings.forwardFocus = settings.forwardFocus;
        break;
      }
    }
    notifyListeners();
  }

  // ─── Environment ─────────────────────────────────────────────
  final EnvironmentReading _environment = MockData.defaultEnvironment;
  EnvironmentReading get environment => _environment;

  // ─── IML ─────────────────────────────────────────────────────
  IMLStats _imlStats = MockData.imlStats;
  IMLStats get imlStats => _imlStats;

  final List<IMLFeedbackItem> _pendingReviews = List.from(MockData.pendingReviews);
  List<IMLFeedbackItem> get pendingReviews => _pendingReviews;

  final List<IMLFeedbackItem> _reviewedItems = List.from(MockData.reviewedItems);
  List<IMLFeedbackItem> get reviewedItems => _reviewedItems;

  void submitFeedback(String alertId, bool isCorrect, {String? correctedType}) {
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

    // Update stats
    final newConfirmed = isCorrect ? _imlStats.confirmed + 1 : _imlStats.confirmed;
    final newCorrected = !isCorrect ? _imlStats.corrected + 1 : _imlStats.corrected;
    final total = newConfirmed + newCorrected;
    _imlStats = IMLStats(
      confirmed: newConfirmed,
      corrected: newCorrected,
      accuracy: total > 0 ? newConfirmed / total : 0,
    );
    notifyListeners();
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

  void startTranscription() {
    _isTranscribing = true;
    _transcriptLines = [];
    notifyListeners();
    // Simulate incoming transcription lines
    _simulateTranscription();
  }

  void stopTranscription() {
    _isTranscribing = false;
    notifyListeners();
  }

  void _simulateTranscription() async {
    final lines = MockData.sampleTranscriptLines;
    for (int i = 0; i < lines.length; i++) {
      await Future.delayed(const Duration(seconds: 2));
      if (!_isTranscribing) return;
      _transcriptLines.add(lines[i]);
      notifyListeners();
    }
  }

  // ─── Implants ────────────────────────────────────────────────
  final List<ConnectedImplant> _connectedImplants = List.from(MockData.connectedImplants);
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
}
