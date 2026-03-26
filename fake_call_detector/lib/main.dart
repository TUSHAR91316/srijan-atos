import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'screens/login_screen.dart';
import 'screens/dashboard.dart';
import 'services/security_service.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final userEmail = await SecurityService.instance.getSessionUser();
  final hasPermissions = await _checkPermissions();

  runApp(
    ProviderScope(
      child: FakeCallDetectorApp(
        initialScreen: userEmail != null ? const DashboardScreen() : const LoginScreen(),
        shouldRequestPermissions: !hasPermissions,
      ),
    ),
  );
}

Future<bool> _checkPermissions() async {
  final status = await [
    Permission.phone,
    Permission.microphone,
    Permission.contacts,
  ].request();
  
  return status.values.every((s) => s.isGranted);
}

class FakeCallDetectorApp extends StatelessWidget {
  const FakeCallDetectorApp({
    super.key, 
    required this.initialScreen,
    this.shouldRequestPermissions = false,
  });

  final Widget initialScreen;
  final bool shouldRequestPermissions;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fake Call Detector',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: initialScreen,
    );
  }
}
