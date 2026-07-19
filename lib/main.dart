import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'services/notification_service.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await NotificationService.instance.init();
  await NotificationService.instance.rescheduleEnabledReminders();
  runApp(const LunaApp());
}

class LunaApp extends StatelessWidget {
  const LunaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Luna Health',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF7F77DD),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F5FB),
        cardColor: Colors.white,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFFEEEDFE),
          foregroundColor: Color(0xFF3C3489),
          elevation: 0,
        ),
        dividerColor: const Color(0xFFEEEDFE),
      ),
      home: const LoginScreen(),
    );
  }
}
