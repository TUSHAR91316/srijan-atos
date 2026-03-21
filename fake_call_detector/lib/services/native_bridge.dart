import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeBridge {
  NativeBridge._(); // prevent instantiation

  static const MethodChannel _methodChannel = MethodChannel(
    'com.example.fake_call_detector/methods',
  );
  static const EventChannel _eventChannel = EventChannel(
    'com.example.fake_call_detector/events',
  );

  /// Broadcast stream of incoming call events from the native layer.
  static Stream<dynamic> get callEventsStream =>
      _eventChannel.receiveBroadcastStream();

  static Future<bool> startAudioCapture() async {
    try {
      final bool result =
          await _methodChannel.invokeMethod<bool>('startAudioCapture') ?? false;
      return result;
    } on PlatformException catch (e) {
      debugPrint('startAudioCapture error: ${e.message}');
      return false;
    }
  }

  static Future<bool> stopAudioCapture() async {
    try {
      final bool result =
          await _methodChannel.invokeMethod<bool>('stopAudioCapture') ?? false;
      return result;
    } on PlatformException catch (e) {
      debugPrint('stopAudioCapture error: ${e.message}');
      return false;
    }
  }
}
