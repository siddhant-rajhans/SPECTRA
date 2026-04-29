/// Hearing program with tunable settings.
class HearingProgram {
  final String id;
  final String name;
  final String icon;
  bool isActive;
  final ProgramSettings settings;

  HearingProgram({
    required this.id,
    required this.name,
    required this.icon,
    required this.isActive,
    required this.settings,
  });
}

/// Fine-tuning settings for a hearing program.
class ProgramSettings {
  int speechEnhancement;
  int noiseReduction;
  int forwardFocus;

  ProgramSettings({
    this.speechEnhancement = 50,
    this.noiseReduction = 50,
    this.forwardFocus = 50,
  });
}

/// Current environment reading.
class EnvironmentReading {
  final String location;
  final int noiseLevel;
  final String? calendarStatus;
  final String timeOfDay;

  const EnvironmentReading({
    required this.location,
    required this.noiseLevel,
    this.calendarStatus,
    required this.timeOfDay,
  });
}
