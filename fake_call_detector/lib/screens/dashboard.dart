import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/dashboard_provider.dart';
import 'history_screen.dart';

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // ── Theme colours ───────────────────────────────────────────────────────────
  static const _bgColor = Color(0xFF0D0D1A);
  static const _cardColor = Color(0xFF1A1A2E);
  static const _accentPurple = Color(0xFF6C3BF5);
  static const _safeGreen = Color(0xFF00E676);
  static const _warnAmber = Color(0xFFFFAB00);
  static const _dangerRed = Color(0xFFFF1744);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.9, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Color _threatColor(ThreatLevel threatLevel) => switch (threatLevel) {
    ThreatLevel.safe => _safeGreen,
    ThreatLevel.warning => _warnAmber,
    ThreatLevel.danger => _dangerRed,
  };

  String _threatLabel(ThreatLevel threatLevel) => switch (threatLevel) {
    ThreatLevel.safe => 'SAFE',
    ThreatLevel.warning => 'SUSPICIOUS',
    ThreatLevel.danger => 'HIGH RISK',
  };

  IconData _threatIcon(ThreatLevel threatLevel) => switch (threatLevel) {
    ThreatLevel.safe => Icons.verified_user_rounded,
    ThreatLevel.warning => Icons.policy_rounded,
    ThreatLevel.danger => Icons.gpp_bad_rounded,
  };

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(dashboardProvider);
    final controller = ref.read(dashboardProvider.notifier);
    final threatColor = _threatColor(state.threatLevel);

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_rounded, color: _accentPurple, size: 22),
            const SizedBox(width: 8),
            const Text('Fake Call Detector'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'History',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HistoryScreen()),
              );
            },
            icon: const Icon(Icons.timeline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            _buildThreatCard(state, threatColor),
            const SizedBox(height: 12),
            _buildRiskMeterCard(state, threatColor),
            const SizedBox(height: 20),
            if (state.callerNumber.isNotEmpty) _buildCallerCard(state.callerNumber),
            if (state.callerNumber.isNotEmpty) const SizedBox(height: 20),
            _buildAudioStatusCard(state.isAudioCapturing),
            const SizedBox(height: 12),
            _buildTrustedContactsCard(state.trustedContactCount, controller),
            const SizedBox(height: 16),
            _buildCaptureButton(state.isAudioCapturing, controller),
            const SizedBox(height: 8),
            const Center(
              child: Text(
                'All analysis is performed on-device. No data leaves your phone.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.white38),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThreatCard(DashboardState state, Color threatColor) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: threatColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: threatColor.withValues(alpha: 0.15),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: CircleAvatar(
              radius: 42,
              backgroundColor: threatColor.withValues(alpha: 0.12),
              child: Icon(_threatIcon(state.threatLevel), color: threatColor, size: 44),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _threatLabel(state.threatLevel),
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: threatColor,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            state.latestEvent,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white60,
              height: 1.4,
            ),
          ),
          if (state.latestReason.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              state.latestReason,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.white38),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRiskMeterCard(DashboardState state, Color threatColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: threatColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.speed_rounded, color: Colors.white70, size: 20),
              const SizedBox(width: 8),
              Text(
                'Real-time Risk ${(100 * state.riskProbability).toStringAsFixed(1)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: LinearProgressIndicator(
              minHeight: 10,
              value: state.riskProbability,
              backgroundColor: Colors.white12,
              color: threatColor,
            ),
          ),
          if (state.latestReasons.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Why flagged: ${state.latestReasons.take(2).join(' • ')}',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCallerCard(String callerNumber) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _warnAmber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const CircleAvatar(
            backgroundColor: Color(0xFF2A2A3E),
            child: Icon(Icons.phone_in_talk_rounded, color: _warnAmber),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Incoming from',
                style: TextStyle(fontSize: 12, color: Colors.white38),
              ),
              Text(
                callerNumber,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAudioStatusCard(bool isAudioCapturing) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isAudioCapturing
              ? _dangerRed.withValues(alpha: 0.4)
              : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Icon(
            isAudioCapturing ? Icons.mic_rounded : Icons.mic_off_rounded,
            color: isAudioCapturing ? _dangerRed : Colors.white38,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isAudioCapturing
                      ? 'Audio Analysis Active'
                      : 'Audio Analysis Idle',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isAudioCapturing ? _dangerRed : Colors.white54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  isAudioCapturing
                      ? 'Speakerphone workaround engaged'
                      : 'Waiting for incoming call',
                  style: const TextStyle(fontSize: 12, color: Colors.white38),
                ),
              ],
            ),
          ),
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isAudioCapturing ? _dangerRed : Colors.white24,
              boxShadow: isAudioCapturing
                  ? [
                      BoxShadow(
                        color: _dangerRed.withValues(alpha: 0.6),
                        blurRadius: 6,
                      ),
                    ]
                  : [],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTrustedContactsCard(
    int trustedContactCount,
    DashboardController controller,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: Row(
        children: [
          const Icon(Icons.contacts_rounded, color: Colors.white70, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              trustedContactCount > 0
                  ? 'Trusted contacts loaded: $trustedContactCount'
                  : 'No trusted contacts loaded',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: controller.refreshTrustedNumbers,
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
  }

  Widget _buildCaptureButton(
    bool isAudioCapturing,
    DashboardController controller,
  ) {
    return ElevatedButton.icon(
      onPressed: () => controller.toggleAudioCapture(!isAudioCapturing),
      icon: Icon(
        isAudioCapturing
            ? Icons.stop_circle_rounded
            : Icons.play_circle_rounded,
      ),
      label: Text(
        isAudioCapturing ? 'Stop Manual Capture' : 'Start Manual Capture',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isAudioCapturing ? _dangerRed : _accentPurple,
        foregroundColor: Colors.white,
      ),
    );
  }
}
