import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/holiday.dart';
import 'services/event_database.dart';
import 'services/notification_service.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();
  Hive.registerAdapter(HolidayAdapter());

  // ✅ If you recently changed the Hive model and had crash,
  // run ONCE then remove this line:
  // await Hive.deleteBoxFromDisk('custom_events');

  await EventDatabase.init();
  await NotificationService.instance.init();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Calendar App',
      theme: ThemeData(primarySwatch: Colors.blue, useMaterial3: true),
      darkTheme: ThemeData.dark().copyWith(useMaterial3: true),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}
