import 'package:flutter/services.dart';

class NativeBridge {
  static const MethodChannel _methodChannel = MethodChannel('com.example.fake_call_detector/methods');
  static const EventChannel _eventChannel = EventChannel('com.example.fake_call_detector/events');

  // Stream to listen to incoming call events
  static Stream<dynamic> get callEventsStream {
    return _eventChannel.receiveBroadcastStream();
  }

  static Future<bool> startAudioCapture() async {
    try {
      final bool result = await _methodChannel.invokeMethod('startAudioCapture');
      return result;
    } on PlatformException catch (e) {
      print("Failed to start audio capture: '${e.message}'.");
      return false;
    }
  }

  static Future<bool> stopAudioCapture() async {
    try {
      final bool result = await _methodChannel.invokeMethod('stopAudioCapture');
      return result;
    } on PlatformException catch (e) {
      print("Failed to stop audio capture: '${e.message}'.");
      return false;
    }
  }
}
