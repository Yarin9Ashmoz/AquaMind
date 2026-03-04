import 'package:flutter/material.dart';
import 'package:frontend/presentation/screens/home/home_screen.dart';
import 'package:provider/provider.dart';

import 'presentation/state/dashboard_state.dart';
import 'data/services/api_service.dart';
import 'data/repositories/sensor_repository.dart';

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => DashboardState(SensorRepository(ApiService())),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primaryColor: Colors.green,
        scaffoldBackgroundColor: Colors.grey.shade100,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 18),
          titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      
      home: const HomeScreen(),
    ); 
  }
}
