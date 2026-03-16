import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'add_sensor_wifi_screen.dart';

class AddSensorConfigScreen extends StatefulWidget {
  final String deviceName;
  final BluetoothDevice device;

  const AddSensorConfigScreen({super.key, required this.deviceName, required this.device});

  @override
  State<AddSensorConfigScreen> createState() => _AddSensorConfigScreenState();
}

class _AddSensorConfigScreenState extends State<AddSensorConfigScreen> {
  final TextEditingController _controller = TextEditingController();
  
  // הגדרת ערכי ברירת מחדל
  String plantType = "pot";
  String locationType = "indoor";

  @override
  void dispose() {
    _controller.dispose(); // חשוב לניקוי זיכרון
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Configure Sensor")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Device: ${widget.deviceName}", 
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
            const SizedBox(height: 16),
            
            TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: "Sensor Name",
                border: OutlineInputBorder(),
              ),
            ),
            
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: plantType,
              decoration: const InputDecoration(labelText: "Plant Type", border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: "pot", child: Text("Pot")),
                DropdownMenuItem(value: "garden", child: Text("Garden")),
              ],
              onChanged: (v) => setState(() => plantType = v!),
            ),
            
            const SizedBox(height: 16),
            
            DropdownButtonFormField<String>(
              value: locationType,
              decoration: const InputDecoration(labelText: "Location", border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: "indoor", child: Text("Indoor")),
                DropdownMenuItem(value: "outdoor", child: Text("Outdoor")),
              ],
              onChanged: (v) => setState(() => locationType = v!),
            ),
            
            const Spacer(),
            
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // בדיקה שהשם לא ריק
                  if (_controller.text.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please enter a sensor name")),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddSensorWifiScreen(
                        device: widget.device,
                        // כאן מחקנו את השורה של ה-deviceName כי היא לא קיימת ב-WifiScreen
                        sensorName: _controller.text,
                        plantType: plantType,
                        locationType: locationType,
                      ),
                    ),
                  );
                },
                child: const Text("Continue to WiFi"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}