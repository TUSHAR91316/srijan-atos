import 'package:fake_call_detector/models/call_event.dart';
import 'package:fake_call_detector/services/threat_scoring_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final scorer = ThreatScoringService();
  final trustedScorer = ThreatScoringService(
    trustedNumbers: <String>['9876543210', '+919123456789'],
  );

  test('scores unknown caller as warning or higher', () async {
    final event = CallEvent.fromMap({
      'event': 'incoming_call',
      'phoneNumber': 'Unknown',
    });

    final risk = await scorer.scoreIncomingCall(event);

    expect(risk.score, greaterThanOrEqualTo(30));
    expect(risk.reasons, contains('Unknown caller identity'));
  });

  test('scores malformed number with risk reasons', () async {
    final event = CallEvent.fromMap({
      'event': 'incoming_call',
      'phoneNumber': '12345',
    });

    final risk = await scorer.scoreIncomingCall(event);

    expect(risk.score, greaterThan(0));
    expect(risk.reasons, contains('Short or malformed caller number'));
  });

  test('scores standard local number as low risk', () async {
    final event = CallEvent.fromMap({
      'event': 'incoming_call',
      'phoneNumber': '9876543210',
    });

    final risk = await scorer.scoreIncomingCall(event);

    expect(risk.score, 0);
    expect(risk.reasons, contains('No immediate risk indicators'));
  });

  test('reduces risk when number exactly matches trusted contact', () async {
    final event = CallEvent.fromMap({
      'event': 'incoming_call',
      'phoneNumber': '9876543210',
    });

    final risk = await trustedScorer.scoreIncomingCall(event);

    expect(risk.score, 0);
    expect(risk.reasons, contains('Matches a trusted contact number'));
  });

  test('flags near-match to trusted contact as possible spoof', () async {
    final event = CallEvent.fromMap({
      'event': 'incoming_call',
      'phoneNumber': '9876543211',
    });

    final risk = await trustedScorer.scoreIncomingCall(event);

    expect(risk.score, greaterThanOrEqualTo(30));
    expect(
      risk.reasons,
      contains('Near-match to trusted contact (High spoof risk)'),
    );
  });
}
