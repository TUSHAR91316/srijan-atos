import '../services/database_service.dart';

class HistoryRepository {
  HistoryRepository({required DatabaseService databaseService}) : _databaseService = databaseService;

  final DatabaseService _databaseService;

  Future<List<Map<String, dynamic>>> getCallLogs() => _databaseService.getCallLogs();

  Future<void> updateScamStatus(int id, bool isScam) => _databaseService.updateScamStatus(id, isScam);

  Future<void> blockNumber(String number, String reason) => _databaseService.blockNumber(number, reason);

  Future<void> addTrustedNumber(String number) => _databaseService.addTrustedNumber(number);
}
