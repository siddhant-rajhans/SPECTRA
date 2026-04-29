/// Context-aware filtering rule.
class ContextRule {
  final String id;
  final String title;
  final String description;
  final String icon;
  bool isActive;

  ContextRule({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.isActive,
  });

  factory ContextRule.fromJson(Map<String, dynamic> json) {
    // Map condition_type to icon
    const iconMap = {
      'calendar_event': '📞',
      'time_range': '😴',
      'location': '🌳',
    };
    final condType = json['condition_type']?.toString() ?? '';
    return ContextRule(
      id: json['id']?.toString() ?? '',
      title: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      icon: iconMap[condType] ?? '⚙️',
      isActive: json['is_active'] == 1 || json['is_active'] == true,
    );
  }
}

/// A monitored sound type with toggle state.
class MonitoredSound {
  final String type;
  final String label;
  final String icon;
  bool isEnabled;
  final bool isLocked; // e.g. fire alarm is always on

  MonitoredSound({
    required this.type,
    required this.label,
    required this.icon,
    required this.isEnabled,
    this.isLocked = false,
  });
}
