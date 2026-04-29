import '../models/user.dart';
import '../models/device_status.dart';
import '../models/sound_alert.dart';
import '../models/context_rule.dart';
import '../models/hearing_program.dart';
import '../models/iml_feedback.dart';
import '../models/transcription.dart';

/// Centralized mock data for all services.
/// Mirrors the seed data from the Node.js backend.
class MockData {
  // ─── Default User ────────────────────────────────────────────
  static const User defaultUser = User(
    id: 'default-user',
    name: 'Maruthi',
    email: 'maruthi@stevens.edu',
    avatarInitial: 'M',
    hearingLossLevel: 'Profound',
    deviceBrand: 'Cochlear',
    deviceModel: 'Nucleus 7',
  );

  // ─── Device Status ───────────────────────────────────────────
  static const DeviceStatus defaultDevice = DeviceStatus(
    name: 'Cochlear Nucleus 7',
    connected: true,
    battery: 72,
    currentProgram: 'home',
    lastLocation: 'Home',
  );

  // ─── Environment ─────────────────────────────────────────────
  static const EnvironmentReading defaultEnvironment = EnvironmentReading(
    location: 'Home',
    noiseLevel: 42,
    calendarStatus: 'Free',
    timeOfDay: 'Evening',
  );

  // ─── Sound Alerts ────────────────────────────────────────────
  static List<SoundAlert> alerts = [
    SoundAlert(
      id: 'alert-1',
      type: 'doorbell',
      confidence: 0.92,
      delivered: true,
      contextReasoning: 'Home location, no active meeting, within waking hours — delivering alert.',
      location: 'Home',
      timeOfDay: 'Afternoon',
      timestamp: DateTime.now().subtract(const Duration(minutes: 15)),
    ),
    SoundAlert(
      id: 'alert-2',
      type: 'fire_alarm',
      confidence: 0.98,
      delivered: true,
      contextReasoning: 'Critical safety alert — always delivered regardless of context.',
      location: 'Home',
      timeOfDay: 'Afternoon',
      timestamp: DateTime.now().subtract(const Duration(hours: 1)),
    ),
    SoundAlert(
      id: 'alert-3',
      type: 'phone_ring',
      confidence: 0.85,
      delivered: false,
      contextReasoning: 'Meeting mode active — suppressing non-critical phone notifications.',
      location: 'Office',
      timeOfDay: 'Morning',
      timestamp: DateTime.now().subtract(const Duration(hours: 3)),
    ),
    SoundAlert(
      id: 'alert-4',
      type: 'knock',
      confidence: 0.78,
      delivered: true,
      contextReasoning: 'Home location, evening hours — delivering knock alert.',
      location: 'Home',
      timeOfDay: 'Evening',
      timestamp: DateTime.now().subtract(const Duration(hours: 5)),
    ),
    SoundAlert(
      id: 'alert-5',
      type: 'car_horn',
      confidence: 0.88,
      delivered: true,
      contextReasoning: 'Outdoors context — prioritizing environmental hazard sounds.',
      location: 'Outdoors',
      timeOfDay: 'Morning',
      timestamp: DateTime.now().subtract(const Duration(hours: 8)),
    ),
  ];

  // ─── Monitored Sounds ────────────────────────────────────────
  static List<MonitoredSound> monitoredSounds = [
    MonitoredSound(type: 'doorbell', label: 'Doorbell', icon: '🔔', isEnabled: true),
    MonitoredSound(type: 'fire_alarm', label: 'Fire Alarm', icon: '🚨', isEnabled: true, isLocked: true),
    MonitoredSound(type: 'car_horn', label: 'Car Horn', icon: '🚗', isEnabled: true),
    MonitoredSound(type: 'name_called', label: 'Name Called', icon: '👤', isEnabled: true),
    MonitoredSound(type: 'alarm_timer', label: 'Timer/Alarm', icon: '⏱️', isEnabled: true),
    MonitoredSound(type: 'baby_crying', label: 'Baby Crying', icon: '👶', isEnabled: false),
  ];

  // ─── Context Rules ───────────────────────────────────────────
  static List<ContextRule> contextRules = [
    ContextRule(
      id: 'meeting',
      title: 'Meeting Mode',
      description: 'Suppress non-critical sounds during meetings',
      icon: '📞',
      isActive: false,
    ),
    ContextRule(
      id: 'sleep',
      title: 'Sleep Mode',
      description: 'Only critical alerts from 10 PM — 7 AM',
      icon: '😴',
      isActive: true,
    ),
    ContextRule(
      id: 'outdoors',
      title: 'Outdoors Mode',
      description: 'Prioritize environmental safety sounds',
      icon: '🌳',
      isActive: false,
    ),
    ContextRule(
      id: 'restaurant',
      title: 'Restaurant Mode',
      description: 'Boost speech detection, reduce ambient noise',
      icon: '🍽️',
      isActive: false,
    ),
  ];

  // ─── Hearing Programs ────────────────────────────────────────
  static List<HearingProgram> hearingPrograms = [
    HearingProgram(
      id: 'home',
      name: 'Home / Quiet',
      icon: '🏠',
      isActive: true,
      settings: ProgramSettings(speechEnhancement: 40, noiseReduction: 30, forwardFocus: 20),
    ),
    HearingProgram(
      id: 'restaurant',
      name: 'Restaurant',
      icon: '🍽️',
      isActive: false,
      settings: ProgramSettings(speechEnhancement: 80, noiseReduction: 70, forwardFocus: 65),
    ),
    HearingProgram(
      id: 'music',
      name: 'Music / Media',
      icon: '🎵',
      isActive: false,
      settings: ProgramSettings(speechEnhancement: 20, noiseReduction: 15, forwardFocus: 10),
    ),
    HearingProgram(
      id: 'outdoors',
      name: 'Outdoors',
      icon: '🌳',
      isActive: false,
      settings: ProgramSettings(speechEnhancement: 55, noiseReduction: 45, forwardFocus: 50),
    ),
    HearingProgram(
      id: 'sleep',
      name: 'Sleep Mode',
      icon: '😴',
      isActive: false,
      settings: ProgramSettings(speechEnhancement: 10, noiseReduction: 90, forwardFocus: 5),
    ),
  ];

  // ─── IML Data ────────────────────────────────────────────────
  static const IMLStats imlStats = IMLStats(
    confirmed: 12,
    corrected: 3,
    accuracy: 0.80,
  );

  static List<IMLFeedbackItem> pendingReviews = [
    IMLFeedbackItem(
      id: 'pending-1',
      type: 'doorbell',
      confidence: 0.87,
      location: 'Home',
      timeOfDay: 'Evening',
      timestamp: DateTime(2026, 4, 28, 19, 30),
    ),
    IMLFeedbackItem(
      id: 'pending-2',
      type: 'knock',
      confidence: 0.72,
      location: 'Office',
      timeOfDay: 'Afternoon',
      timestamp: DateTime(2026, 4, 28, 14, 15),
    ),
    IMLFeedbackItem(
      id: 'pending-3',
      type: 'car_horn',
      confidence: 0.91,
      location: 'Outdoors',
      timeOfDay: 'Morning',
      timestamp: DateTime(2026, 4, 28, 9, 45),
    ),
  ];

  static List<IMLFeedbackItem> reviewedItems = [
    IMLFeedbackItem(
      id: 'reviewed-1',
      type: 'fire_alarm',
      confidence: 0.96,
      isCorrect: true,
      timestamp: DateTime(2026, 4, 27, 11, 0),
    ),
    IMLFeedbackItem(
      id: 'reviewed-2',
      type: 'doorbell',
      confidence: 0.65,
      isCorrect: false,
      correctedType: 'knock',
      timestamp: DateTime(2026, 4, 27, 10, 0),
    ),
    IMLFeedbackItem(
      id: 'reviewed-3',
      type: 'phone_ring',
      confidence: 0.88,
      isCorrect: true,
      timestamp: DateTime(2026, 4, 26, 15, 30),
    ),
  ];

  // ─── Transcription Lines ─────────────────────────────────────
  static List<TranscriptionLine> sampleTranscriptLines = [
    TranscriptionLine(
      speaker: 'Speaker 1',
      text: 'Hi, can you hear me clearly?',
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    TranscriptionLine(
      speaker: 'Speaker 2',
      text: 'Yes, the transcription is working well.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 4)),
    ),
    TranscriptionLine(
      speaker: 'Speaker 1',
      text: 'Great. Let me know if you need me to speak louder.',
      timestamp: DateTime.now().subtract(const Duration(minutes: 3)),
    ),
  ];

  // ─── Implant Providers ───────────────────────────────────────
  static const List<ImplantProvider> implantProviders = [
    ImplantProvider(
      id: 'cochlear',
      name: 'Cochlear',
      features: ['Battery sync', 'Program control', 'Find my device', 'Hearing health'],
      models: ['Nucleus 7', 'Nucleus 8', 'Nucleus 8 Sound Processor'],
    ),
    ImplantProvider(
      id: 'phonak',
      name: 'Phonak',
      features: ['Battery sync', 'Program control', 'Remote tuning'],
      models: ['Phonak Marvel', 'Phonak Lumity', 'Phonak Paradise'],
    ),
    ImplantProvider(
      id: 'oticon',
      name: 'Oticon',
      features: ['Battery sync', 'Remote control', 'Sound booster'],
      models: ['Oticon More', 'Oticon Intent', 'Oticon Real'],
    ),
    ImplantProvider(
      id: 'resound',
      name: 'ReSound',
      features: ['Battery sync', 'Program control'],
      models: ['ReSound Omnia', 'ReSound Prona'],
    ),
    ImplantProvider(
      id: 'starkey',
      name: 'Starkey',
      features: ['Battery sync', 'Health tracking', 'Fall detection'],
      models: ['Starkey Evolv AI', 'Starkey Genesis'],
    ),
    ImplantProvider(
      id: 'widex',
      name: 'Widex',
      features: ['Battery sync', 'Sound sense'],
      models: ['Widex Moment', 'Widex Magnolia'],
    ),
  ];

  static List<ConnectedImplant> connectedImplants = [
    ConnectedImplant(
      id: 'conn-1',
      providerId: 'cochlear',
      providerName: 'Cochlear',
      displayName: 'My Cochlear',
      deviceModel: 'Nucleus 7',
      battery: 72,
      firmwareVersion: '4.2.1',
      lastSynced: DateTime.now().subtract(const Duration(hours: 1)),
      features: ['Battery sync', 'Program control', 'Find my device'],
    ),
  ];

  // ─── Provider Logo Map ───────────────────────────────────────
  static const Map<String, String> providerLogos = {
    'Cochlear': '🎧',
    'Phonak': '👂',
    'Oticon': '🔊',
    'ReSound': '📡',
    'Starkey': '🌟',
    'Widex': '💫',
    'Other': '🔌',
  };
}
