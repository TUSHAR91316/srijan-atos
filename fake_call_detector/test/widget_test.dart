import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:fake_call_detector/main.dart';

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
          if (call.method == 'startAudioCapture') return true;
          if (call.method == 'stopAudioCapture') return true;
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

  testWidgets('shows initial monitoring state', (WidgetTester tester) async {
    await tester.pumpWidget(const FakeCallDetectorApp());

    expect(find.text('Fake Call Detector'), findsOneWidget);
    expect(find.text('PROTECTED'), findsOneWidget);
    expect(find.text('Monitoring for incoming calls…'), findsOneWidget);
    expect(find.text('Start Manual Capture'), findsOneWidget);
  });

  testWidgets('manual capture button toggles active and idle states', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const FakeCallDetectorApp());

    await tester.tap(find.text('Start Manual Capture'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Stop Manual Capture'), findsOneWidget);
    expect(find.text('Audio Analysis Active'), findsOneWidget);

    await tester.tap(find.text('Stop Manual Capture'));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Start Manual Capture'), findsOneWidget);
    expect(find.text('Audio Analysis Idle'), findsOneWidget);
  });
}
