import 'dart:convert';

/// Device/implant connection status.
class DeviceStatus {
  final String name;
  final bool connected;
  final int battery;
  final String? currentProgram;
  final String? lastLocation;

  const DeviceStatus({
    required this.name,
    required this.connected,
    required this.battery,
    this.currentProgram,
    this.lastLocation,
  });

  factory DeviceStatus.fromJson(Map<String, dynamic> json) {
    return DeviceStatus(
      name: json['device_name']?.toString() ?? json['name']?.toString() ?? 'Unknown Device',
      connected: json['is_connected'] == 1 || json['is_connected'] == true,
      battery: (json['battery_level'] ?? json['battery'] ?? 0) as int,
      currentProgram: json['current_program']?.toString(),
      lastLocation: json['last_seen_location']?.toString() ?? json['lastLocation']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'device_name': name,
    'is_connected': connected ? 1 : 0,
    'battery_level': battery,
    'current_program': currentProgram,
    'last_seen_location': lastLocation,
  };
}

/// Connected implant device with provider info.
class ConnectedImplant {
  final String id;
  final String providerId;
  final String providerName;
  final String displayName;
  final String? deviceModel;
  final int battery;
  final String? firmwareVersion;
  final DateTime? lastSynced;
  final List<String> features;

  const ConnectedImplant({
    required this.id,
    required this.providerId,
    required this.providerName,
    required this.displayName,
    this.deviceModel,
    required this.battery,
    this.firmwareVersion,
    this.lastSynced,
    this.features = const [],
  });

  factory ConnectedImplant.fromJson(Map<String, dynamic> json) {
    List<String> parseFeatures(dynamic f) {
      if (f is List) return f.cast<String>();
      if (f is String && f.isNotEmpty) {
        try {
          final decoded = jsonDecode(f);
          if (decoded is List) return List<String>.from(decoded.map((e) => e.toString()));
          return [f];
        } catch (_) {
          return [f];
        }
      }
      return const [];
    }

    return ConnectedImplant(
      id: json['id']?.toString() ?? '',
      providerId: json['provider']?.toString() ?? '',
      providerName: json['provider']?.toString() ?? '',
      displayName: json['display_name']?.toString() ?? '',
      deviceModel: json['device_model']?.toString(),
      battery: (json['battery_level'] ?? 0) as int,
      firmwareVersion: json['firmware_version']?.toString(),
      lastSynced: json['last_synced_at'] != null ? DateTime.tryParse(json['last_synced_at'].toString()) : null,
      features: parseFeatures(json['features']),
    );
  }
}

/// Implant provider (Cochlear, Phonak, etc.)
class ImplantProvider {
  final String id;
  final String name;
  final List<String> features;
  final List<String> models;

  const ImplantProvider({
    required this.id,
    required this.name,
    this.features = const [],
    this.models = const [],
  });
}
