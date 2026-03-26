class CallEvent {
  const CallEvent({
    required this.eventName,
    required this.phoneNumber,
    required this.timestamp,
    this.durationSeconds,
    this.voiceSimilarity,
    this.voiceEmbedding,
    this.antiSpoofScore,
    this.snrDb,
    this.voiceUsable,
  });

  final String eventName;
  final String phoneNumber;
  final DateTime timestamp;
  final int? durationSeconds;
  final double? voiceSimilarity;
  final List<double>? voiceEmbedding;
  final double? antiSpoofScore;
  final double? snrDb;
  final bool? voiceUsable;

  bool get isUnknownNumber =>
      phoneNumber.trim().isEmpty || phoneNumber.toLowerCase() == 'unknown';

  factory CallEvent.fromMap(Map<dynamic, dynamic> map) {
    final rawEvent = map['event']?.toString();
    final rawPhone = map['phoneNumber']?.toString();
    final rawDuration = map['durationSeconds'];
    final rawVoiceSimilarity = map['voiceSimilarity'];
    final rawVoiceEmbedding = map['voiceEmbedding'];
    final rawAntiSpoof = map['antiSpoofScore'];
    final rawSnrDb = map['snrDb'];
    final rawVoiceUsable = map['voiceUsable'];

    return CallEvent(
      eventName: (rawEvent == null || rawEvent.isEmpty)
          ? 'incoming_call'
          : rawEvent,
      phoneNumber: (rawPhone == null || rawPhone.trim().isEmpty)
          ? 'Unknown'
          : rawPhone,
      timestamp: DateTime.now(),
      durationSeconds: rawDuration is int
          ? rawDuration
          : int.tryParse(rawDuration?.toString() ?? ''),
      voiceSimilarity: rawVoiceSimilarity is num
          ? rawVoiceSimilarity.toDouble()
          : double.tryParse(rawVoiceSimilarity?.toString() ?? ''),
      voiceEmbedding: rawVoiceEmbedding is List
          ? rawVoiceEmbedding
              .map((e) => e is num ? e.toDouble() : double.tryParse(e.toString()) ?? 0.0)
              .toList(growable: false)
          : null,
      antiSpoofScore: rawAntiSpoof is num
          ? rawAntiSpoof.toDouble()
          : double.tryParse(rawAntiSpoof?.toString() ?? ''),
      snrDb: rawSnrDb is num ? rawSnrDb.toDouble() : double.tryParse(rawSnrDb?.toString() ?? ''),
      voiceUsable: rawVoiceUsable is bool
          ? rawVoiceUsable
          : (rawVoiceUsable?.toString().toLowerCase() == 'true'
              ? true
              : rawVoiceUsable?.toString().toLowerCase() == 'false'
                  ? false
                  : null),
    );
  }
}
