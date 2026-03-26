import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/service_providers.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  _HistoryFilter _filter = _HistoryFilter.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D0D1A),
      appBar: AppBar(
        title: const Text('Call History & Flags'),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ref.read(historyRepositoryProvider).getCallLogs(),
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

          final logs = _applyFilter(snapshot.data!);
          if (logs.isEmpty) {
            return const Center(
              child: Text(
                'No entries for selected filter.',
                style: TextStyle(color: Colors.white38),
              ),
            );
          }

          return ListView.builder(
            itemCount: logs.length,
            padding: const EdgeInsets.all(16),
            itemBuilder: (context, index) {
              final log = logs[index];
              final score = log['threat_score'] as int;
              final isScam = log['is_scam'] == 1;
              final color = isScam ? const Color(0xFFFF1744) : _getScoreColor(score);
              final DateTime timestamp = DateTime.parse(log['timestamp']);
              final String phoneNumber = (log['phone_number'] ?? 'Unknown').toString();
              final probability = (log['risk_probability'] as num?)?.toDouble();
              final reasons = _parseReasons(log['risk_reasons_json'], log['reasons']);
              final signals = _parseSignals(log['signal_breakdown_json']);

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
                    'Timeline: ${DateFormat('MMM dd, hh:mm a').format(timestamp)}',
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
                          Text(reasons.join('\n• ').replaceFirst('', '• '), style: const TextStyle(color: Colors.white70)),
                          if (probability != null) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Model probability: ${(probability * 100).toStringAsFixed(1)}%',
                              style: const TextStyle(color: Colors.white54, fontSize: 12),
                            ),
                          ],
                          if (signals.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: signals.entries
                                  .where((entry) => entry.value >= 0.4)
                                  .map(
                                    (entry) => Chip(
                                      backgroundColor: color.withValues(alpha: 0.15),
                                      labelStyle: const TextStyle(color: Colors.white70, fontSize: 11),
                                      label: Text('${entry.key}: ${(entry.value * 100).toStringAsFixed(0)}%'),
                                    ),
                                  )
                                  .toList(growable: false),
                            ),
                          ],
                          const Divider(color: Colors.white12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              TextButton.icon(
                                icon: Icon(isScam ? Icons.undo : Icons.report_problem, size: 18),
                                label: Text(isScam ? 'Unflag' : 'Flag as Scam'),
                                style: TextButton.styleFrom(foregroundColor: isScam ? Colors.white70 : const Color(0xFFFF1744)),
                                onPressed: () async {
                                  await ref.read(historyRepositoryProvider).updateScamStatus(log['id'], !isScam);
                                  if (!isScam) {
                                    await ref.read(historyRepositoryProvider).blockNumber(phoneNumber, 'User flagged as scam');
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
                                  final messenger = ScaffoldMessenger.of(context);
                                  await ref.read(historyRepositoryProvider).addTrustedNumber(phoneNumber);
                                  if (!mounted) return;
                                  messenger.showSnackBar(
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
      bottomNavigationBar: _buildFilterBar(),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      color: const Color(0xFF121223),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        children: _HistoryFilter.values
            .map(
              (filter) => ChoiceChip(
                selectedColor: const Color(0xFF6C3BF5),
                labelStyle: TextStyle(
                  color: _filter == filter ? Colors.white : Colors.white70,
                ),
                label: Text(filter.label),
                selected: _filter == filter,
                onSelected: (_) => setState(() => _filter = filter),
              ),
            )
            .toList(growable: false),
      ),
    );
  }

  List<Map<String, dynamic>> _applyFilter(List<Map<String, dynamic>> logs) {
    return logs.where((log) {
      final score = (log['threat_score'] as int?) ?? 0;
      final isScam = log['is_scam'] == 1;
      final number = (log['phone_number'] ?? '').toString();

      switch (_filter) {
        case _HistoryFilter.all:
          return true;
        case _HistoryFilter.flagged:
          return isScam || score >= 60;
        case _HistoryFilter.trusted:
          return score <= 20;
        case _HistoryFilter.unknown:
          return number.trim().isEmpty || number.toLowerCase() == 'unknown';
      }
    }).toList(growable: false);
  }

  List<String> _parseReasons(dynamic riskReasonsJson, dynamic fallbackReasons) {
    if (riskReasonsJson is String && riskReasonsJson.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(riskReasonsJson);
        if (decoded is List) {
          return decoded.map((e) => e.toString()).toList(growable: false);
        }
      } catch (_) {
        return <String>[riskReasonsJson];
      }
    }

    final fallback = fallbackReasons?.toString() ?? 'No details available';
    return fallback.split(', ').where((e) => e.trim().isNotEmpty).toList(growable: false);
  }

  Map<String, double> _parseSignals(dynamic signalJson) {
    if (signalJson is! String || signalJson.trim().isEmpty) {
      return const <String, double>{};
    }

    try {
      final decoded = jsonDecode(signalJson);
      if (decoded is! Map) return const <String, double>{};
      return decoded.map((key, value) {
        final parsed = value is num ? value.toDouble() : double.tryParse(value.toString()) ?? 0;
        return MapEntry(key.toString(), parsed);
      });
    } catch (_) {
      return const <String, double>{};
    }
  }

  Color _getScoreColor(int score) {
    if (score >= 60) return const Color(0xFFFF1744);
    if (score >= 30) return const Color(0xFFFFAB00);
    return const Color(0xFF00E676);
  }
}

enum _HistoryFilter { all, flagged, trusted, unknown }

extension on _HistoryFilter {
  String get label => switch (this) {
        _HistoryFilter.all => 'All',
        _HistoryFilter.flagged => 'Flagged',
        _HistoryFilter.trusted => 'Trusted',
        _HistoryFilter.unknown => 'Unknown',
      };
}
