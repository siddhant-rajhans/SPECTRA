/// User profile model for HearClear.
class User {
  final String id;
  final String name;
  final String email;
  final String avatarInitial;
  final String? hearingLossLevel;
  final String? deviceBrand;
  final String? deviceModel;

  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.avatarInitial,
    this.hearingLossLevel,
    this.deviceBrand,
    this.deviceModel,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      avatarInitial: json['avatar_initial']?.toString() ?? json['name']?.toString().substring(0, 1) ?? '?',
      hearingLossLevel: json['hearing_loss_level']?.toString(),
      deviceBrand: json['device_brand']?.toString(),
      deviceModel: json['device_model']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'avatar_initial': avatarInitial,
    'hearing_loss_level': hearingLossLevel,
    'device_brand': deviceBrand,
    'device_model': deviceModel,
  };
}
