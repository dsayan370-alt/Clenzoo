import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_screen.dart';
import 'services/call_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await CallService.init();
  runApp(const ClenzooApp());
}

class ClenzooApp extends StatelessWidget {
  const ClenzooApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Clenzoo Agent',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0a6cff)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
