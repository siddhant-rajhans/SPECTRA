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
