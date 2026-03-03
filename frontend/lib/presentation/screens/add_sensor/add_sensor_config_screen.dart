import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'add_sensor_wifi_screen.dart';

class AddSensorConfigScreen extends StatefulWidget {
  final String deviceName;
  final BluetoothDevice device;

  const AddSensorConfigScreen({
    super.key,
    required this.deviceName,
    required this.device,
  });

  @override
  State<AddSensorConfigScreen> createState() => _AddSensorConfigScreenState();
}

class _AddSensorConfigScreenState extends State<AddSensorConfigScreen> {
  String sensorName = "";
  String plantType = "pot";
  String locationType = "indoor";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Configure Sensor")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Device: ${widget.deviceName}"),
            const SizedBox(height: 16),

            TextField(
              decoration: const InputDecoration(labelText: "Sensor Name"),
              onChanged: (v) => sensorName = v,
            ),

            const SizedBox(height: 16),
            const Text("Plant Type"),
            DropdownButton(
              value: plantType,
              items: const [
                DropdownMenuItem(value: "pot", child: Text("Pot")),
                DropdownMenuItem(value: "garden", child: Text("Garden")),
              ],
              onChanged: (v) => setState(() => plantType = v!),
            ),

            const SizedBox(height: 16),
            const Text("Location"),
            DropdownButton(
              value: locationType,
              items: const [
                DropdownMenuItem(value: "indoor", child: Text("Indoor")),
                DropdownMenuItem(value: "outdoor", child: Text("Outdoor")),
              ],
              onChanged: (v) => setState(() => locationType = v!),
            ),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddSensorWifiScreen(
                        device: widget.device, // ⬅️ מעבירים את ה‑device
                        deviceName: widget.deviceName,
                        sensorName: sensorName,
                        plantType: plantType,
                        locationType: locationType,
                      ),
                    ),
                  );
                },
                child: const Text("Continue"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
