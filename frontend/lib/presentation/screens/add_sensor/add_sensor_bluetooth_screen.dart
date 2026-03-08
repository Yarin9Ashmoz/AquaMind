import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'add_sensor_config_screen.dart';

class AddSensorBluetoothScreen extends StatefulWidget {
  const AddSensorBluetoothScreen({super.key});

  @override
  State<AddSensorBluetoothScreen> createState() =>
      _AddSensorBluetoothScreenState();
}

class _AddSensorBluetoothScreenState extends State<AddSensorBluetoothScreen> {
  List<ScanResult> devices = [];
  bool scanning = false;

  @override
  void initState() {
    super.initState();
    startScan();
  }

  @override
  void dispose() {
    FlutterBluePlus.stopScan();
    super.dispose();
  }

  void startScan() async {
    setState(() => scanning = true);

    FlutterBluePlus.startScan(timeout: const Duration(seconds: 4));

    FlutterBluePlus.scanResults.listen((results) {
      if (mounted) {
        setState(() {
          devices = results
              .where((r) => r.device.name.contains("ESP32"))
              .toList();
        });
      }
    });

    await Future.delayed(const Duration(seconds: 4));
    if (mounted) {
      setState(() => scanning = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Sensor")),
      body: scanning
          ? const Center(child: CircularProgressIndicator())
          : devices.isEmpty
          ? const Center(child: Text("No ESP32 devices found"))
          : ListView.builder(
              itemCount: devices.length,
              itemBuilder: (context, i) {
                final d = devices[i];

                return ListTile(
                  title: Text(d.device.name),
                  subtitle: Text(d.device.id.toString()),
                  onTap: () async {
                    await d.device.connect();

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AddSensorConfigScreen(
                          deviceName: d.device.name,
                          device: d.device, // ⬅️ מעבירים את ה‑device
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
