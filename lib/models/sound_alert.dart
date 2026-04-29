import 'package:flutter/material.dart';

/// Sound alert detected by the classifier with context information.
class SoundAlert {
  final String id;
  final String type;
  final double confidence;
  final bool delivered;
  final String? contextReasoning;
  final String? location;
  final String? timeOfDay;
  final DateTime timestamp;

  const SoundAlert({
    required this.id,
    required this.type,
    required this.confidence,
    required this.delivered,
    this.contextReasoning,
    this.location,
    this.timeOfDay,
    required this.timestamp,
  });
}

/// Maps sound types to their display metadata.
class SoundTypeInfo {
  final String icon;
  final String label;
  final Color color;

  const SoundTypeInfo({
    required this.icon,
    required this.label,
    required this.color,
  });

  static SoundTypeInfo fromType(String type) {
    return _soundTypeMap[type] ??
        SoundTypeInfo(icon: '📢', label: type.isEmpty ? 'Unknown' : type, color: const Color(0xFFB8B8D4));
  }

  static const Map<String, SoundTypeInfo> _soundTypeMap = {
    'doorbell': SoundTypeInfo(icon: '🔔', label: 'Doorbell', color: Color(0xFFFDCB6E)),
    'fire_alarm': SoundTypeInfo(icon: '🚨', label: 'Fire Alarm', color: Color(0xFFFF6B6B)),
    'car_horn': SoundTypeInfo(icon: '🚗', label: 'Car Horn', color: Color(0xFF74B9FF)),
    'name_called': SoundTypeInfo(icon: '👤', label: 'Name Called', color: Color(0xFFA29BFE)),
    'alarm_timer': SoundTypeInfo(icon: '⏱️', label: 'Timer/Alarm', color: Color(0xFF00CEC9)),
    'baby_crying': SoundTypeInfo(icon: '👶', label: 'Baby Crying', color: Color(0xFFFD79A8)),
    'phone_ring': SoundTypeInfo(icon: '📱', label: 'Phone Ring', color: Color(0xFF00B894)),
    'knock': SoundTypeInfo(icon: '🚪', label: 'Knock', color: Color(0xFFE17055)),
    'siren': SoundTypeInfo(icon: '🚑', label: 'Siren', color: Color(0xFFD63031)),
    'dog_bark': SoundTypeInfo(icon: '🐕', label: 'Dog Bark', color: Color(0xFFFFEAA7)),
    'microwave': SoundTypeInfo(icon: '📻', label: 'Microwave', color: Color(0xFF81ECEC)),
    'smoke_detector': SoundTypeInfo(icon: '🔥', label: 'Smoke Detector', color: Color(0xFFFF7675)),
  };

  static List<SoundTypeInfo> get allTypes => _soundTypeMap.entries
      .map((e) => SoundTypeInfo(icon: e.value.icon, label: e.value.label, color: e.value.color))
      .toList();

  static List<MapEntry<String, SoundTypeInfo>> get allEntries => _soundTypeMap.entries.toList();
}
