import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'add_sensor_bluetooth_screen.dart';

class AddSensorIntroScreen extends StatelessWidget {
  const AddSensorIntroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black87),
        centerTitle: true,
        title: const Text(
          "Setup Hardware",
          style: TextStyle(
            color: Colors.black87,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),

              // Visual Hero Icon for IoT setup sequence
              CircleAvatar(
                radius: 50,
                backgroundColor: Colors.blue.withOpacity(0.1),
                child: const Icon(
                  Icons.bluetooth_searching,
                  size: 44,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 32),

              const Text(
                "Connect New Sensor",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 12),

              Text(
                "Let's link your AquaMind IoT device to the cloud application dashboard.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                  height: 1.4,
                ),
              ),
              const Spacer(),

              // Instructional preparation guidelines
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  children: [
                    _buildStepRow(
                      Icons.power,
                      "Power on your ESP32 hardware device.",
                    ),
                    const Divider(height: 24),
                    _buildStepRow(
                      Icons.bluetooth,
                      "Ensure Bluetooth is enabled on this phone.",
                    ),
                  ],
                ),
              ),
              const Spacer(),

              // Proceed to next stage in the BLE scanning routine
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const AddSensorBluetoothScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    "Start Scanning",
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper widget to display structural system prerequisites nicely
  Widget _buildStepRow(IconData icon, String instruction) {
    return Row(
      children: [
        Icon(icon, color: Colors.grey[600], size: 22),
        const SizedBox(width: 16),
        Expanded(
          child: Text(
            instruction,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}
