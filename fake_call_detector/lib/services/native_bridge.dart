import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../models/call_event.dart';

class NativeBridge {
  NativeBridge._(); // prevent instantiation

  static const MethodChannel _methodChannel = MethodChannel(
    'com.example.fake_call_detector/methods',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.example.fake_call_detector/events',
  );

  /// Broadcast stream of incoming call events from the native layer.
  static Stream<CallEvent> get callEventsStream => _eventChannel
      .receiveBroadcastStream()
      .where((event) => event is Map)
      .map((event) => CallEvent.fromMap(event as Map<dynamic, dynamic>));

  static Future<bool> startAudioCapture() async {
    try {
      final bool result =
          await _methodChannel.invokeMethod<bool>('startAudioCapture') ?? false;
      return result;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('startAudioCapture error: $e');
      }
      return false;
    }
  }

  static Future<bool> stopAudioCapture() async {
    try {
      final bool result =
          await _methodChannel.invokeMethod<bool>('stopAudioCapture') ?? false;
      return result;
    } catch (e) {
      if (kDebugMode) {
        debugPrint('stopAudioCapture error: $e');
      }
      return false;
    }
  }

  static Future<List<String>> getTrustedNumbers() async {
    try {
      final List<dynamic>? result = await _methodChannel
          .invokeMethod<List<dynamic>>('getTrustedNumbers');
      if (result == null) return const <String>[];
      return result.map((e) => e.toString()).toList(growable: false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('getTrustedNumbers error: $e');
      }
      return const <String>[];
    }
  }

  static Future<List<double>?> getLatestVoiceEmbedding() async {
    try {
      final List<dynamic>? result = await _methodChannel
          .invokeMethod<List<dynamic>>('getLatestVoiceEmbedding');
      if (result == null || result.isEmpty) return null;
      return result
          .map((e) => e is num ? e.toDouble() : double.tryParse(e.toString()) ?? 0.0)
          .toList(growable: false);
    } catch (e) {
      if (kDebugMode) {
        debugPrint('getLatestVoiceEmbedding error: $e');
      }
      return null;
    }
  }
}
