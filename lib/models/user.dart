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
}
