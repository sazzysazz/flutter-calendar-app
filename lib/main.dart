import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/holiday.dart';
import 'services/event_database.dart';  // ← Import your EventDatabase
// import 'screens/calendar_page.dart';   // or 'pages/calendar_page.dart'
import 'screens/splash_screen.dart';
import 'services/notification_service.dart'; // 🔔 Import NotificationService

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Hive
  await Hive.initFlutter();

  // Register the generated adapter
  Hive.registerAdapter(HolidayAdapter());

   await NotificationService.init(); // 🔔 ADD THIS

  // Open the custom events box via EventDatabase (centralized)
  await EventDatabase.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Calendar App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      darkTheme: ThemeData.dark().copyWith(useMaterial3: true),
      themeMode: ThemeMode.system,
      // home: const CalendarPage()
      home: const SplashScreen(),   // ← Starts with splash
    );
  }
}