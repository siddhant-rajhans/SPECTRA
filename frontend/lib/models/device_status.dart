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
