import 'package:flutter/material.dart';
import '../dashboard/dashboard_screen.dart';
import '../sensors/sensors_screen.dart';
import '../settings/settings_screen.dart';

class HomeScreen extends StatefulWidget{
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int index = 0;

  final screens = const [
    DashboardScreen(),
    SensorsScreen(),
    SettingsScreen(),
  ];  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: screens[index],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: index,
        onTap: (i) => setState(() => index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: "Main",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.sensors),
            label: "Sensors",
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: "Settings",
          ),
        ],
      ),
    );
  }
}