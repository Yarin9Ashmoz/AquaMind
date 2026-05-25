import 'package:flutter/material.dart';
import 'package:frontend/presentation/screens/home/home_screen.dart';
import 'package:provider/provider.dart';

import 'presentation/state/dashboard_state.dart';
import 'data/services/api_service.dart';
import 'data/repositories/sensor_repository.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  // Ensure that plugin services are initialized so that `availableCameras()` 
  // or other plugins can be called before `runApp()`
  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Initialize Firebase using the google-services.json file
    await Firebase.initializeApp();

    FirebaseMessaging messaging = FirebaseMessaging.instance;

    // Request notification permissions for iOS and Android 13+
    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Firebase: User granted permission');
      
      // Get the unique FCM token for this device
      // This token is required by the backend to send push notifications
      String? token = await messaging.getToken();
      print("🔥 FCM Device Token: $token");
      
    } else {
      print('❌ Firebase: User declined or has not accepted permission');
    }
  } catch (e) {
    print("❌ Firebase Initialization Error: $e");
  }

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
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        
        // Clean and neutral color scheme
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.grey,
          primary: Colors.black,
          secondary: Colors.grey.shade700,
        ),

        // Light scaffold background
        scaffoldBackgroundColor: Colors.grey.shade100,

        // Minimalist White AppBar
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 0,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),

        // Clean Typography
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 16, color: Colors.black87),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),

        // Rounded Cards with subtle elevation
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),

        // iOS-style Circular Floating Action Button
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}