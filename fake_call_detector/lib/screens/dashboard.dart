import 'dart:async';
import 'package:flutter/material.dart';
import '../services/native_bridge.dart';

enum ThreatLevel { safe, warning, danger }

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with SingleTickerProviderStateMixin {
  String _latestEvent = 'Monitoring for incoming calls…';
  String _callerNumber = '';
  bool _isAudioCapturing = false;
  ThreatLevel _threatLevel = ThreatLevel.safe;
  StreamSubscription<dynamic>? _callEventSubscription;
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
    _listenToCallEvents();
  }

  @override
  void dispose() {
    _callEventSubscription?.cancel(); // ← fix stream subscription leak
    _pulseController.dispose();
    super.dispose();
  }

  void _listenToCallEvents() {
    _callEventSubscription = NativeBridge.callEventsStream.listen(
      (event) {
        if (event is Map) {
          final phoneNumber = event['phoneNumber'] as String? ?? 'Unknown';
          final eventName = event['event'] as String? ?? 'incoming_call';
          if (!mounted) return;
          setState(() {
            _callerNumber = phoneNumber;
            _latestEvent = 'Incoming call detected ($eventName)';
            _threatLevel = ThreatLevel.warning; // escalate after ML analysis
          });
          _toggleAudioCapture(true);
        }
      },
      onError: (dynamic error) {
        if (!mounted) return;
        setState(() {
          _latestEvent = 'Monitoring error: $error';
          _threatLevel = ThreatLevel.safe;
        });
      },
    );
  }

  Future<void> _toggleAudioCapture(bool start) async {
    final success = start
        ? await NativeBridge.startAudioCapture()
        : await NativeBridge.stopAudioCapture();
    if (!mounted) return;
    if (success) {
      setState(() {
        _isAudioCapturing = start;
        if (!start) {
          _threatLevel = ThreatLevel.safe;
          _callerNumber = '';
          _latestEvent = 'Monitoring for incoming calls…';
        }
      });
    }
  }

  // ── Helpers ─────────────────────────────────────────────────────────────────

  Color get _threatColor => switch (_threatLevel) {
    ThreatLevel.safe => _safeGreen,
    ThreatLevel.warning => _warnAmber,
    ThreatLevel.danger => _dangerRed,
  };

  String get _threatLabel => switch (_threatLevel) {
    ThreatLevel.safe => 'PROTECTED',
    ThreatLevel.warning => 'ANALYSING…',
    ThreatLevel.danger => 'THREAT DETECTED',
  };

  IconData get _threatIcon => switch (_threatLevel) {
    ThreatLevel.safe => Icons.verified_user_rounded,
    ThreatLevel.warning => Icons.policy_rounded,
    ThreatLevel.danger => Icons.gpp_bad_rounded,
  };

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
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
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildThreatCard(),
              const SizedBox(height: 20),
              if (_callerNumber.isNotEmpty) _buildCallerCard(),
              if (_callerNumber.isNotEmpty) const SizedBox(height: 20),
              _buildAudioStatusCard(),
              const Spacer(),
              _buildCaptureButton(),
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
      ),
    );
  }

  Widget _buildThreatCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _threatColor.withValues(alpha: 0.35),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: _threatColor.withValues(alpha: 0.15),
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
              backgroundColor: _threatColor.withValues(alpha: 0.12),
              child: Icon(_threatIcon, color: _threatColor, size: 44),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _threatLabel,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: _threatColor,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _latestEvent,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white60,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCallerCard() {
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
                _callerNumber,
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

  Widget _buildAudioStatusCard() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isAudioCapturing
              ? _dangerRed.withValues(alpha: 0.4)
              : Colors.white12,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _isAudioCapturing ? Icons.mic_rounded : Icons.mic_off_rounded,
            color: _isAudioCapturing ? _dangerRed : Colors.white38,
            size: 28,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _isAudioCapturing
                      ? 'Audio Analysis Active'
                      : 'Audio Analysis Idle',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _isAudioCapturing ? _dangerRed : Colors.white54,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _isAudioCapturing
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
              color: _isAudioCapturing ? _dangerRed : Colors.white24,
              boxShadow: _isAudioCapturing
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

  Widget _buildCaptureButton() {
    return ElevatedButton.icon(
      onPressed: () => _toggleAudioCapture(!_isAudioCapturing),
      icon: Icon(
        _isAudioCapturing
            ? Icons.stop_circle_rounded
            : Icons.play_circle_rounded,
      ),
      label: Text(
        _isAudioCapturing ? 'Stop Manual Capture' : 'Start Manual Capture',
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: _isAudioCapturing ? _dangerRed : _accentPurple,
        foregroundColor: Colors.white,
      ),
    );
  }
}
