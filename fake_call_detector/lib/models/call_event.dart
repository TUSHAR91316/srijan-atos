class CallEvent {
  const CallEvent({
    required this.eventName,
    required this.phoneNumber,
    required this.timestamp,
  });

  final String eventName;
  final String phoneNumber;
  final DateTime timestamp;

  bool get isUnknownNumber =>
      phoneNumber.trim().isEmpty || phoneNumber.toLowerCase() == 'unknown';

  factory CallEvent.fromMap(Map<dynamic, dynamic> map) {
    final rawEvent = map['event']?.toString();
    final rawPhone = map['phoneNumber']?.toString();

    return CallEvent(
      eventName: (rawEvent == null || rawEvent.isEmpty)
          ? 'incoming_call'
          : rawEvent,
      phoneNumber: (rawPhone == null || rawPhone.trim().isEmpty)
          ? 'Unknown'
          : rawPhone,
      timestamp: DateTime.now(),
    );
  }
}
