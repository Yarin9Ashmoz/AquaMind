import 'package:flutter/material.dart';
import 'package:frontend/presentation/screens/home/home_screen.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

import 'presentation/state/dashboard_state.dart';
import 'data/services/api_service.dart';
import 'data/repositories/sensor_repository.dart';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

Future<void> _registerTokenWithBackend(String token) async {
  try {
    await http.post(
      Uri.parse(
        "https://aquamind-0xli.onrender.com/api/v1/devices/register-token",
      ),
      headers: {
        "Content-Type": "application/json",
        "X-API-Key": ApiService.apiKey,
      },
      body: jsonEncode({"token": token}),
    );
    print("✅ FCM token registered with backend");
  } catch (e) {
    print("❌ Failed to register FCM token with backend: $e");
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp();

    FirebaseMessaging messaging = FirebaseMessaging.instance;

    NotificationSettings settings = await messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('✅ Firebase: User granted permission');

      String? token = await messaging.getToken();
      print("🔥 FCM Device Token: $token");

      if (token != null) {
        await _registerTokenWithBackend(token);
      }

      // Keep the backend in sync if the token ever rotates.
      messaging.onTokenRefresh.listen((newToken) {
        print("🔄 FCM token refreshed: $newToken");
        _registerTokenWithBackend(newToken);
      });
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
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.grey,
          primary: Colors.black,
          secondary: Colors.grey.shade700,
        ),
        scaffoldBackgroundColor: Colors.grey.shade100,
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
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontSize: 16, color: Colors.black87),
          titleLarge: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
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
