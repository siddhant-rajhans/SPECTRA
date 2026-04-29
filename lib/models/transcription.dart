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
}
