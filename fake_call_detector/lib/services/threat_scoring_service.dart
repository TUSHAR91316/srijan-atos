import '../models/call_event.dart';
import 'database_service.dart';

class ThreatScore {
  const ThreatScore({required this.score, required this.reasons});

  final int score;
  final List<String> reasons;
}

class ThreatScoringService {
  ThreatScoringService({this.trustedNumbers = const <String>[]});

  final List<String> trustedNumbers;
  final DatabaseService _dbService = DatabaseService();

  Future<ThreatScore> scoreIncomingCall(CallEvent event) async {
    var score = 0;
    final reasons = <String>[];
    final normalized = _normalizePhone(event.phoneNumber);
    final digitsOnly = _digitsOnly(normalized);

    // 1. Check if the number is manually blocked (Local Sync)
    final isBlocked = await _dbService.isNumberBlocked(digitsOnly);
    if (isBlocked) {
      return const ThreatScore(
        score: 100,
        reasons: ['Number manually flagged as scam in your history'],
      );
    }

    if (event.isUnknownNumber) {
      score += 40;
      reasons.add('Unknown caller identity');
    }

    if (normalized.startsWith('+')) {
      score += 20;
      reasons.add('International formatted number');
    }

    if (digitsOnly.length < 10) {
      score += 20;
      reasons.add('Short or malformed caller number');
    }

    if (trustedNumbers.isNotEmpty && digitsOnly.isNotEmpty) {
      final trustedDigits = trustedNumbers
          .map(_digitsOnly)
          .where((n) => n.isNotEmpty);

      final exactTrustedMatch = trustedDigits.contains(digitsOnly);
      if (exactTrustedMatch) {
        score = (score - 20).clamp(0, 100);
        reasons.add('Matches a trusted contact number');
      } else {
        final nearMatch = trustedDigits.any(
          (trusted) => _isNearDigitMatch(digitsOnly, trusted),
        );
        if (nearMatch) {
          score += 45;
          reasons.add('Near-match to trusted contact (High spoof risk)');
        }
      }
    }

    if (event.eventName != 'incoming_call') {
      score += 10;
      reasons.add('Unexpected call event type');
    }

    return ThreatScore(
      score: score.clamp(0, 100),
      reasons: reasons.isEmpty
          ? const ['No immediate risk indicators']
          : reasons,
    );
  }

  String _normalizePhone(String value) =>
      value.replaceAll(RegExp(r'[\s\-()]'), '');

  String _digitsOnly(String value) => value.replaceAll(RegExp(r'[^0-9]'), '');

  bool _isNearDigitMatch(String incoming, String trusted) {
    if (incoming == trusted) return false;

    if (incoming.length == trusted.length) {
      var diff = 0;
      for (var i = 0; i < incoming.length; i++) {
        if (incoming[i] != trusted[i]) diff++;
        if (diff > 1) return false;
      }
      return diff == 1;
    }

    if ((incoming.length - trusted.length).abs() <= 3) {
      return incoming.endsWith(trusted) || trusted.endsWith(incoming);
    }

    return false;
  }
}
