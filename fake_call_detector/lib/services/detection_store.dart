import '../models/call_event.dart';
import 'database_service.dart';

abstract class DetectionStore {
  Future<int> getRecentCallCount(String phoneNumber, Duration window);

  Future<List<Map<String, dynamic>>> getRecentCallsForNumber(String phoneNumber, int limit);

  Future<int> insertRiskLog({
    required CallEvent event,
    required int score,
    required double probability,
    required String reasons,
    required String signalBreakdown,
    required double? voiceSimilarity,
    required int? durationSeconds,
  });

  Future<void> addVoiceEmbeddingSample(
    String phoneNumber,
    List<double> embedding,
    double quality, {
    int maxSamples,
  });

  Future<List<List<double>>> getVoiceEmbeddingSamples(String phoneNumber);
}

class SqlDetectionStore implements DetectionStore {
  SqlDetectionStore(this._databaseService);

  final DatabaseService _databaseService;

  @override
  Future<int> getRecentCallCount(String phoneNumber, Duration window) {
    return _databaseService.getRecentCallCount(phoneNumber, window);
  }

  @override
  Future<List<Map<String, dynamic>>> getRecentCallsForNumber(String phoneNumber, int limit) {
    return _databaseService.getRecentCallsForNumber(phoneNumber, limit);
  }

  @override
  Future<int> insertRiskLog({
    required CallEvent event,
    required int score,
    required double probability,
    required String reasons,
    required String signalBreakdown,
    required double? voiceSimilarity,
    required int? durationSeconds,
  }) {
    return _databaseService.insertRiskLog(
      event: event,
      score: score,
      probability: probability,
      reasons: reasons,
      signalBreakdown: signalBreakdown,
      voiceSimilarity: voiceSimilarity,
      durationSeconds: durationSeconds,
    );
  }

  @override
  Future<void> addVoiceEmbeddingSample(
    String phoneNumber,
    List<double> embedding,
    double quality, {
    int maxSamples = 8,
  }) {
    return _databaseService.addVoiceEmbeddingSample(
      phoneNumber,
      embedding,
      quality,
      maxSamples: maxSamples,
    );
  }

  @override
  Future<List<List<double>>> getVoiceEmbeddingSamples(String phoneNumber) {
    return _databaseService.getVoiceEmbeddingSamples(phoneNumber);
  }
}
