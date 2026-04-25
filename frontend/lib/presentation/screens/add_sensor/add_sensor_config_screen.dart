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
  
  // הגדרת ערכי ברירת מחדל כולל השדה החדש
  String plantType = "pot";
  String locationType = "indoor";
  int dryToleranceDays = 3; // השדה החדש של ימי היובש

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

            const SizedBox(height: 16),

            // ה-Dropdown החדש שהוספנו
            DropdownButtonFormField<int>(
              value: dryToleranceDays,
              decoration: const InputDecoration(
                labelText: "Dry Tolerance (Days)", 
                helperText: "For how many days can the plant stay dry?",
                border: OutlineInputBorder()
              ),
              items: List.generate(15, (index) => index).map((int value) {
                return DropdownMenuItem<int>(
                  value: value,
                  child: Text(value == 0 ? "No delay (0 days)" : "$value Days"),
                );
              }).toList(),
              onChanged: (v) => setState(() => dryToleranceDays = v!),
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
                        sensorName: _controller.text,
                        plantType: plantType,
                        locationType: locationType,
                        dryToleranceDays: dryToleranceDays, // העברה למסך הבא
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