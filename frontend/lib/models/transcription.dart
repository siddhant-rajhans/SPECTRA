/// A transcription session.
class TranscriptionSession {
  final String id;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int speakerCount;

  const TranscriptionSession({
    required this.id,
    required this.startedAt,
    this.endedAt,
    this.speakerCount = 1,
  });

  factory TranscriptionSession.fromJson(Map<String, dynamic> json) {
    return TranscriptionSession(
      id: json['id']?.toString() ?? '',
      startedAt: DateTime.tryParse(json['started_at']?.toString() ?? '') ?? DateTime.now(),
      endedAt: json['ended_at'] != null ? DateTime.tryParse(json['ended_at'].toString()) : null,
      speakerCount: (json['speaker_count'] ?? 1) as int,
    );
  }
}

/// A single transcribed line within a session.
class TranscriptionLine {
  final String speaker;
  final String text;
  final DateTime timestamp;

  const TranscriptionLine({
    required this.speaker,
    required this.text,
    required this.timestamp,
  });

  factory TranscriptionLine.fromJson(Map<String, dynamic> json) {
    return TranscriptionLine(
      speaker: json['speaker_label']?.toString() ?? json['speaker']?.toString() ?? 'Speaker',
      text: json['text']?.toString() ?? '',
      timestamp: DateTime.tryParse(json['created_at']?.toString() ?? json['timestamp']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
