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
}
