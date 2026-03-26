import 'package:fake_call_detector/providers/dashboard_provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const MethodChannel methodChannel = MethodChannel(
    'com.example.fake_call_detector/methods',
  );
  const MethodChannel eventChannelControl = MethodChannel(
    'com.example.fake_call_detector/events',
  );

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall call) async {
          if (call.method == 'startAudioCapture') return false;
          if (call.method == 'stopAudioCapture') return true;
          if (call.method == 'getTrustedNumbers') return <String>[];
          return null;
        });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(eventChannelControl, (MethodCall call) async {
          if (call.method == 'listen' || call.method == 'cancel') return null;
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(eventChannelControl, null);
  });

  test('keeps audio capture disabled when permission or role gate fails', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final notifier = container.read(dashboardProvider.notifier);
    await notifier.toggleAudioCapture(true);

    final state = container.read(dashboardProvider);
    expect(state.isAudioCapturing, isFalse);
    expect(state.latestReason, contains('Audio capture unavailable'));
  });
}
