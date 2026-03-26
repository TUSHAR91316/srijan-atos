import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/auth_repository.dart';
import '../repositories/history_repository.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';

final databaseServiceProvider = Provider<DatabaseService>(
  (ref) => DatabaseService(),
);

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(databaseService: ref.read(databaseServiceProvider)),
);

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(authService: ref.read(authServiceProvider)),
);

final historyRepositoryProvider = Provider<HistoryRepository>(
  (ref) => HistoryRepository(databaseService: ref.read(databaseServiceProvider)),
);
