import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final DatabaseService _dbService = DatabaseService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        title: const Text('Call History & Flags'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _dbService.getCallLogs(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(
              child: Text(
                'No call logs found.',
                style: TextStyle(color: Colors.white38),
              ),
            );
          }

          final logs = snapshot.data!;
          return ListView.builder(
            itemCount: logs.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final log = logs[index];
              final score = log['threat_score'] as int;
              final isScam = log['is_scam'] == 1;
              final color = isScam ? const Color(0xFFFF1744) : _getScoreColor(score);
              final DateTime timestamp = DateTime.parse(log['timestamp']);
              final String phoneNumber = log['phone_number'];

              return Card(
                color: const Color(0xFF1A1A2E),
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: color.withValues(alpha: 0.3)),
                ),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.1),
                    child: Icon(
                      isScam || score >= 60 ? Icons.gpp_bad_rounded : Icons.verified_user_rounded,
                      color: color,
                    ),
                  ),
                  title: Text(
                    phoneNumber,
                    style: TextStyle(
                      color: isScam ? const Color(0xFFFF1744) : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(
                    DateFormat('MMM dd, hh:mm a').format(timestamp),
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  trailing: Text(
                    isScam ? 'SCAM' : '$score%',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      fontSize: 16,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Reasons for Score:', style: TextStyle(color: Colors.white54, fontSize: 12)),
                          Text(log['reasons'], style: const TextStyle(color: Colors.white70)),
                          const Divider(color: Colors.white12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton.icon(
                                icon: Icon(isScam ? Icons.undo : Icons.report_problem, size: 18),
                                label: Text(isScam ? 'Unflag' : 'Flag as Scam'),
                                style: TextButton.styleFrom(foregroundColor: isScam ? Colors.white70 : const Color(0xFFFF1744)),
                                onPressed: () async {
                                  await _dbService.updateScamStatus(log['id'], !isScam);
                                  if (!isScam) {
                                    await _dbService.blockNumber(phoneNumber, 'User flagged as scam');
                                  }
                                  if (!mounted) return;
                                  setState(() {});
                                },
                              ),
                              TextButton.icon(
                                icon: const Icon(Icons.verified_rounded, size: 18, color: Color(0xFF00E676)),
                                label: const Text('Trust Number'),
                                style: TextButton.styleFrom(foregroundColor: const Color(0xFF00E676)),
                                onPressed: () async {
                                  await _dbService.addTrustedNumber(phoneNumber);
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Added to trusted list')),
                                  );
                                },
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  Color _getScoreColor(int score) {
    if (score >= 60) return const Color(0xFFFF1744);
    if (score >= 30) return const Color(0xFFFFAB00);
    return const Color(0xFF00E676);
  }
}
