/// IML (Interactive ML) feedback item.
class IMLFeedbackItem {
  final String id;
  final String type;
  final double confidence;
  final String? location;
  final String? timeOfDay;
  final bool? isCorrect;
  final String? correctedType;
  final DateTime timestamp;

  const IMLFeedbackItem({
    required this.id,
    required this.type,
    required this.confidence,
    this.location,
    this.timeOfDay,
    this.isCorrect,
    this.correctedType,
    required this.timestamp,
  });

  factory IMLFeedbackItem.fromJson(Map<String, dynamic> json) {
    return IMLFeedbackItem(
      id: json['id']?.toString() ?? json['alert_id']?.toString() ?? '',
      type: json['sound_type']?.toString() ?? json['original_classification']?.toString() ?? json['type']?.toString() ?? '',
      confidence: (json['confidence'] ?? 0.0).toDouble(),
      location: json['context_location']?.toString() ?? json['location']?.toString(),
      timeOfDay: json['context_time_of_day']?.toString() ?? json['timeOfDay']?.toString(),
      isCorrect: json['is_correct'] == 1 || json['is_correct'] == true ? true : (json['is_correct'] == 0 || json['is_correct'] == false ? false : null),
      correctedType: json['corrected_classification']?.toString(),
      timestamp: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Aggregated IML model statistics.
class IMLStats {
  final int confirmed;
  final int corrected;
  final double accuracy;

  const IMLStats({
    required this.confirmed,
    required this.corrected,
    required this.accuracy,
  });

  int get total => confirmed + corrected;

  factory IMLStats.fromJson(Map<String, dynamic> json) {
    return IMLStats(
      confirmed: (json['confirmed'] ?? 0) as int,
      corrected: (json['corrected'] ?? 0) as int,
      accuracy: (json['accuracy'] ?? 0.0).toDouble(),
    );
  }
}
