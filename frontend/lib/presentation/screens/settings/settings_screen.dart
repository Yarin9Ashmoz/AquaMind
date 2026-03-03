import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("הגדרות מערכת")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            SwitchListTile(
              title: const Text("מצב אוטומטי"),
              value: true,
              onChanged: (_) {},
            ),
            const SizedBox(height: 20),
            const Text("טווח לחות רצוי"),
            Slider(
              value: 40,
              min: 10,
              max: 80,
              onChanged: (_) {},
            ),
          ],
        ),
      ),
    );
  }
}
