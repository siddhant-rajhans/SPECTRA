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

  factory HearingProgram.fromJson(Map<String, dynamic> json) {
    // Map icon names to emoji
    const iconMap = {
      'home': '🏠',
      'utensils': '🍽️',
      'music': '🎵',
      'car': '🌳',
      'moon': '😴',
    };
    final iconKey = json['icon']?.toString() ?? 'home';
    return HearingProgram(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      icon: iconMap[iconKey] ?? '🏠',
      isActive: json['is_selected'] == 1 || json['is_selected'] == true,
      settings: ProgramSettings(
        speechEnhancement: (json['speech_enhancement'] ?? 50) as int,
        noiseReduction: (json['noise_reduction'] ?? 50) as int,
        forwardFocus: (json['forward_focus'] ?? 50) as int,
      ),
    );
  }
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

  Map<String, dynamic> toJson() => {
    'speech_enhancement': speechEnhancement,
    'noise_reduction': noiseReduction,
    'forward_focus': forwardFocus,
  };
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

  factory EnvironmentReading.fromJson(Map<String, dynamic> json) {
    return EnvironmentReading(
      location: json['location']?.toString() ?? 'Unknown',
      noiseLevel: (json['noise_level'] ?? json['noiseLevel'] ?? 40) as int,
      calendarStatus: json['calendar_status']?.toString() ?? json['calendarStatus']?.toString(),
      timeOfDay: json['time_of_day']?.toString() ?? json['timeOfDay']?.toString() ?? 'Day',
    );
  }
}
