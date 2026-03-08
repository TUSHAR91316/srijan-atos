import 'package:flutter/material.dart';
import 'screens/dashboard.dart';

void main() {
  runApp(const FakeCallDetectorApp());
}

class FakeCallDetectorApp extends StatelessWidget {
  const FakeCallDetectorApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fake Call Detector',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const DashboardScreen(),
    );
  }
}
