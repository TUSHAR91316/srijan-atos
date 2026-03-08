import 'package:flutter/material.dart';
import '../services/native_bridge.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _latestEvent = "No active call";
  bool _isAudioCapturing = false;

  @override
  void initState() {
    super.initState();
    _listenToCallEvents();
  }

  void _listenToCallEvents() {
    NativeBridge.callEventsStream.listen((event) {
      if (event is Map) {
        String eventName = event['event'] ?? 'unknown';
        String phoneNumber = event['phoneNumber'] ?? 'Unknown Number';
        setState(() {
          _latestEvent = "Incoming Call Event: $phoneNumber ($eventName)";
        });

        // Automatically start audio capture workaround when a call comes in
        _toggleAudioCapture(true);
      }
    }, onError: (dynamic error) {
      setState(() {
        _latestEvent = 'Error monitoring calls: $error';
      });
    });
  }

  Future<void> _toggleAudioCapture(bool start) async {
    bool success;
    if (start) {
      success = await NativeBridge.startAudioCapture();
    } else {
      success = await NativeBridge.stopAudioCapture();
    }

    if (success) {
      setState(() {
        _isAudioCapturing = start;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fake Call Detector'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              color: Colors.deepPurple.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const Icon(Icons.security, size: 64, color: Colors.deepPurple),
                    const SizedBox(height: 16),
                    const Text(
                      'AI Threat Protection Active',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _latestEvent,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.black87),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isAudioCapturing ? Colors.red.shade100 : Colors.green.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _isAudioCapturing ? Icons.mic : Icons.mic_off,
                    color: _isAudioCapturing ? Colors.red : Colors.green,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _isAudioCapturing
                          ? "Audio Analysis Active (Speakerphone Mode On)"
                          : "Audio Analysis Inactive",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _isAudioCapturing ? Colors.red.shade900 : Colors.green.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: () => _toggleAudioCapture(!_isAudioCapturing),
              icon: Icon(_isAudioCapturing ? Icons.stop : Icons.play_arrow),
              label: Text(_isAudioCapturing ? 'Stop Manual Capture' : 'Start Manual Capture'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: _isAudioCapturing ? Colors.red : Colors.deepPurple,
                foregroundColor: Colors.white,
              ),
            )
          ],
        ),
      ),
    );
  }
}
