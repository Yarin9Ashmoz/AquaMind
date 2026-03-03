import 'package:flutter/material.dart';
import 'add_sensor_bluetooth_screen.dart';

class AddSensorIntroScreen extends StatelessWidget {
  const AddSensorIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add New Sensor")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Let's set up your new sensor",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            const Text(
              "Make sure your sensor is powered on.\n"
              "We'll scan for it using Bluetooth.",
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddSensorBluetoothScreen(),
                    ),
                  );
                },
                child: const Text("Start"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
